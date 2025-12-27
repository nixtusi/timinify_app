//
//  TimetableFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//uribonet API のレスポンスを Firestore に入学年度構造でアップロード（Qごと分類）
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

struct TimetableItem: Codable, Identifiable, Hashable, Equatable {
    var id: String { code + day + String(period) }
    let code: String
    let day: String
    let period: Int
    let teacher: String
    let title: String
    let room: String?
    var quarter: Int? = nil
    var color: String?
    
    private enum CodingKeys: String, CodingKey {
        case code, day, period, teacher, title, room, quarter, color
    }
    
    static func == (lhs: TimetableItem, rhs: TimetableItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct QuarterTimetable: Codable {
    let timetable: [TimetableItem]?
    let year: String?
    let year_semester: String?
}

struct ScheduleDetail: Codable {
    let period: Int?
    let room: String?
    let subject: String?
}

struct DailySchedule: Codable {
    let day: Int
    let day_of_week: String
    let month: Int
    let schedule: [ScheduleDetail]
    let year: Int
}

struct UribonetResponse: Codable {
    let schedules: [DailySchedule]
    let timetables: [String: QuarterTimetable]
}

// MARK: - TimetableFetcher

class TimetableFetcher: ObservableObject {
    @Published var timetableItems: [TimetableItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestore = Firestore.firestore()
    private let localKey = "cachedTimetableItems" // UserDefaultsキー名

    @MainActor
    func fetchAndUpload(
        academicYear: Int,
        quarter: String = "1,2",
        startDate: String = "2025-04-01",
        endDate: String = "2025-08-30"
    ) async throws {
        isLoading = true
        errorMessage = nil

        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "ログイン情報が取得できませんでした"
            isLoading = false
            return
        }

        let studentNumber = email.components(separatedBy: "@").first ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        // 文字列 "1,2" を [1, 2] に変換
        let targetQuarters = quarter
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        // 日付文字列を Date に変換
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.date(from: startDate) ?? Date()
        let end = formatter.date(from: endDate) ?? Date()

        do {
            try Task.checkCancellation()

            // ✅ API ではなくオンデバイススクレイピングを実行
            let data = try await TimetableScraper.shared.fetch(
                studentID: studentNumber,
                password: password,
                quarters: targetQuarters,
                start: start,
                end: end
            )

            try Task.checkCancellation()

            // 取得したデータを反映
            self.timetableItems = data.timetables

            // Firestore へのアップロード（スケジュール情報を使って教室をマージ）
            await uploadToFirestore(
                studentNumber: studentNumber,
                academicYear: academicYear,
                items: data.timetables,
                schedules: data.schedules
            )

//        } catch {
//            errorMessage = error.localizedDescription
//        }
        } catch {
            print("❌ [Fetcher] エラー発生: \(error)")
            
            if let scraperError = error as? ScraperError {
                switch scraperError {
                case .contactInfoCheckRequired:
                    // ✅ ユーザー指定のアラート文言を設定
                    errorMessage = "うりぼーにアクセスし、本人連絡先の変更がないかの確認をしてください"
                case .loginFailed(let msg):
                    errorMessage = msg
                case .timeout:
                    errorMessage = "接続がタイムアウトしました"
                default:
                    errorMessage = "データの取得に失敗しました (\(scraperError))"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false

        if let errorMessage = errorMessage {
            print("❌ 時間割取得エラー: \(errorMessage)")
        } else {
            print("✅ 時間割取得成功: \(timetableItems.count)件取得")
        }
    }

    @MainActor
    private func uploadToFirestore(
        studentNumber: String,
        academicYear: Int,
        items: [TimetableItem],
        schedules: [DailySchedule]
    ) async {
        print("🔥 [Firestore] アップロード処理開始: 合計 \(items.count) 件のデータを処理します")
        
        let entryYear = "20" + String(studentNumber.prefix(2))
        let academicYearStr = String(academicYear)

        for item in items {
            if Task.isCancelled {
                print("⚠️ [Firestore] アップロード処理がキャンセルされました")
                return
            }
            
            try? Task.checkCancellation()

            // スケジュールデータから、科目名と時限が一致する教室情報を探す
            let rawRoom = schedules
                .flatMap { $0.schedule }
                .first(where: {
                    ($0.period == item.period) &&
                    ($0.subject?.contains(item.title) ?? false) &&
                    ($0.room != nil)
                })?
                .room ?? ""

            // 全角英数を半角に変換などの処理
            let room = rawRoom.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? rawRoom

            let docData: [String: Any] = [
                "code": item.code,
                "day": item.day,
                "period": item.period,
                "teacher": item.teacher,
                "title": item.title,
                "room": room, // スクレイピングした教室情報をセット
                "quarter": item.quarter ?? 1
            ]

            let path = firestore
                .collection("Timetable")
                .document(entryYear)
                .collection(studentNumber)
                .document(academicYearStr)
                .collection("Q\(item.quarter ?? 1)")

            do {
                try await path.document(item.id).setData(docData, merge: true)
                
                print("✅ [Firestore] 保存成功: \(item.title) (Q\(item.quarter ?? 0) \(item.day)\(item.period))")
            } catch {
                print("❌ Firestore 保存エラー: \(error.localizedDescription)")
            }
        }
        
        print("🏁 [Firestore] 全データのアップロード処理が完了しました")
    }

    @MainActor
    func loadFromFirestore(year: Int, quarter: Int) async {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "ログイン情報が取得できませんでした"
            return
        }

        let studentNumber = email.components(separatedBy: "@").first ?? ""
        let entryYear = "20" + String(studentNumber.prefix(2))

        let path = firestore
            .collection("Timetable")
            .document(entryYear)
            .collection(studentNumber)
            .document(String(year))
            .collection("Q\(quarter)")

        isLoading = true
        errorMessage = nil

        do {
            //let snapshot = try await path.getDocuments()
            let snapshot = try await path.getDocuments(source: .server)
            var items: [TimetableItem] = []
            
            
            for doc in snapshot.documents {
                var item = try doc.data(as: TimetableItem.self)
                item.quarter = quarter
                
                let data = doc.data()
                if let colorHex = data["color"] as? String {
                    item.color = colorHex
                }

                // ✅ 常に共有データを参照しにいく
                let classRef = firestore
                    .collection("class")
                    .document(String(year))
                    .collection("Q\(quarter)")
                    .document(item.code)
                
                // エラーでループが止まらないように try? を使用
                if let classDoc = try? await classRef.getDocument(source: .server) {
                    
                    let sharedRoom = classDoc.data()?["room"] as? String ?? ""
                    let personalRoom = item.room ?? ""
                    
                    // 共有データ(class)のroomを最優先にする
                    let finalRoom: String
                    if !sharedRoom.isEmpty {
                        finalRoom = sharedRoom
                    } else {
                        finalRoom = personalRoom
                    }
                    
                    // roomを更新した新しいItemを作成
                    item = TimetableItem(
                        code: item.code,
                        day: item.day,
                        period: item.period,
                        teacher: item.teacher,
                        title: item.title,
                        room: finalRoom,
                        quarter: quarter,
                        color: item.color
                    )
                }
                
                items.append(item)
            }

            timetableItems = items
            saveToLocal()
            
        } catch {
            errorMessage = "Firestore 読み込み失敗: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    func saveToLocal() {
        if let encoded = try? JSONEncoder().encode(timetableItems) {
            UserDefaults.standard.set(encoded, forKey: localKey)
            print("📦 ローカルに時間割を保存しました")
        }
    }
    
    func loadFromLocal() {
        if let data = UserDefaults.standard.data(forKey: localKey),
           let decoded = try? JSONDecoder().decode([TimetableItem].self, from: data) {
            self.timetableItems = decoded
            print("✅ ローカルから時間割を読み込みました")
        } else {
            print("⚠️ ローカルデータが見つかりません")
        }
    }
}
