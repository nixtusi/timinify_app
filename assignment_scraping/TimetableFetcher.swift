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
    private let baseURL = "https://api.timinify.com"
    
    private let localKey = "cachedTimetableItems" // UserDefaultsキー名

    @MainActor
    func fetchAndUpload(
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

        do {
        try Task.checkCancellation()   // ✅ 最初にチェック
        let response = try await requestUribonet(
                studentNumber: studentNumber,
                password: password,
                quarter: quarter,
                startDate: startDate,
                endDate: endDate
            )
            try Task.checkCancellation()

            timetableItems = response.timetables.flatMap { (key, quarterData) in
                let q = Int(key) ?? 1
                let list = quarterData.timetable ?? []
                return list.map { item in
                    var modified = item
                    modified.quarter = q
                    return modified
                }
            }

            try Task.checkCancellation()   // ✅ Firestore書き込み前にも
            await uploadToFirestore(
                studentNumber: studentNumber,
                schedules: response.schedules
            )

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        
        if let errorMessage = errorMessage {
            print("❌ 時間割取得エラー: \(errorMessage)")
        } else {
            print("✅ 時間割取得成功: \(timetableItems.count)件取得")
        }
    }

    private func requestUribonet(
        studentNumber: String,
        password: String,
        quarter: String,
        startDate: String,
        endDate: String,
        retries: Int = 2
    ) async throws -> UribonetResponse {
        let url = URL(string: baseURL + "/uribonet")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "student_number": studentNumber,
            "password": password,
            "quarter": quarter,
            "start_date": startDate,
            "end_date": endDate
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "APIエラー"])
            }

            let decoder = JSONDecoder()
            // Keep explicit keys (no convertFromSnakeCase) because the payload keys already match.
            do {
                return try decoder.decode(UribonetResponse.self, from: data)
            } catch let DecodingError.keyNotFound(key, context) {
                let raw = String(data: data, encoding: .utf8) ?? "<non‑utf8>"
                throw NSError(
                    domain: "JSONDecoding",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing key: \(key.stringValue) at \(context.codingPath.map{ $0.stringValue }.joined(separator: "."))\nRAW: \(raw.prefix(1000))..."]
                )
            } catch let DecodingError.typeMismatch(type, context) {
                let raw = String(data: data, encoding: .utf8) ?? "<non‑utf8>"
                throw NSError(
                    domain: "JSONDecoding",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Type mismatch for \(type) at \(context.codingPath.map{ $0.stringValue }.joined(separator: "."))\nRAW: \(raw.prefix(1000))..."]
                )
            } catch let DecodingError.valueNotFound(type, context) {
                let raw = String(data: data, encoding: .utf8) ?? "<non‑utf8>"
                throw NSError(
                    domain: "JSONDecoding",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Value not found for \(type) at \(context.codingPath.map{ $0.stringValue }.joined(separator: "."))\nRAW: \(raw.prefix(1000))..."]
                )
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "<non‑utf8>"
                throw NSError(
                    domain: "JSONDecoding",
                    code: -5,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown decode error: \(error.localizedDescription)\nRAW: \(raw.prefix(1000))..."]
                )
            }

        } catch {
            if retries > 0 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await requestUribonet(
                    studentNumber: studentNumber,
                    password: password,
                    quarter: quarter,
                    startDate: startDate,
                    endDate: endDate,
                    retries: retries - 1
                )
            }
            throw error
        }
    }

    @MainActor
    private func uploadToFirestore(
        studentNumber: String,
        schedules: [DailySchedule]
    ) async {
        let entryYear = "20" + String(studentNumber.prefix(2))
        let academicYear = "2025"

        for item in timetableItems {
            if Task.isCancelled { return }        // ✅ 早期終了
            try? Task.checkCancellation()
        
            let rawRoom = schedules.first(where: { daySched in
                daySched.schedule.contains(where: {
                    ($0.period == item.period) && (($0.subject ?? "") == item.title) && ($0.room != nil)
                })
            })?
            .schedule.first(where: { ($0.period == item.period) && (($0.subject ?? "") == item.title) })?
            .room ?? ""

            let room = rawRoom.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? rawRoom

            let docData: [String: Any] = [
                "code": item.code,
                "day": item.day,
                "period": item.period,
                "teacher": item.teacher,
                "title": item.title,
                "room": room,
                "quarter": item.quarter ?? 1
            ]

            let path = firestore
                .collection("Timetable")
                .document(entryYear)
                .collection(studentNumber)
                .document(academicYear)
                .collection("Q\(item.quarter ?? 1)")

            do {
                try await path.document(item.id).setData(docData)
            } catch {
                print("❌ Firestore 保存エラー: \(error.localizedDescription)")
            }
        }
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

                if item.room == nil || item.room == "" {
                    let classRef = firestore
                        .collection("class")
                        .document(String(year))
                        .collection("Q\(quarter)")
                        .document(item.code)
                    //let classDoc = try await classRef.getDocument()
                    let classDoc = try await classRef.getDocument(source: .server)

                    let sharedRoom = classDoc.data()?["room"] as? String ?? ""
                    let personalRoom = item.room ?? ""
                    let finalRoom: String
                    if !sharedRoom.isEmpty {
                        finalRoom = sharedRoom
                        // 共有が正として、個人値が異なる場合は個人側を同期
                        if sharedRoom != personalRoom {
                            try await path.document(item.id).setData([
                                "room": sharedRoom
                            ], merge: true)
                            print("↩️ 個人roomを共有roomで同期: \(item.id)")
                        }
                    } else if !personalRoom.isEmpty {
                        finalRoom = personalRoom
                        // 共有が未登録なら個人値を共有に反映（初回補完）
                        try await classRef.setData([
                            "room": personalRoom,
                            "teacher": item.teacher,
                            "title": item.title,
                            "code": item.code
                        ], merge: true)
                        print("✅ classに反映: \(item.code)")
                    } else {
                        finalRoom = ""
                    }
                    //roomだけ差し替える（item再生成せず直接書き換え）
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
                items.append(item) //どんな状態でも item を追加
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
