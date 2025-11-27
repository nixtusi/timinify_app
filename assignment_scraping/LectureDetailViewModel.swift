//
//  LectureDetailViewModel.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/29.
//

import Foundation
import FirebaseFirestore
import SwiftUI

class LectureDetailViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var teacher: String = ""
    @Published var room: String = ""
    @Published var credits: String?
    @Published var evaluation: String?
    @Published var references: String?
    @Published var syllabus: Syllabus? = nil
    @Published var colorHex: String = "#FF3B30"
    
    @Published var reviews: [Review] = []
    
    private let db = Firestore.firestore()
    
    // MARK: - ① Timetable & class情報を取得
    func fetchLectureDetails(studentId: String, admissionYear: String, year: String, quarter: String, day: String, period: Int, lectureCode: String) async {
        do {
            // Timetable参照
            let timetablePath = "Timetable/\(admissionYear)/\(studentId)/\(year)/Q\(quarter)/\(lectureCode)\(day)\(period)"
            let timetableRef = db.document(timetablePath)
            let timetableSnap = try await timetableRef.getDocument()
            let timetableData = timetableSnap.data()
            
            // class参照
            let classPath = "class/\(year)/Q\(quarter)/\(lectureCode)"
            let classRef = db.document(classPath)
            let classSnap = try await classRef.getDocument()
            let classData = classSnap.data()
            
            // UI更新
            await MainActor.run {
                self.title = timetableData?["title"] as? String ?? ""
                self.teacher = timetableData?["teacher"] as? String ?? ""
                self.room = timetableData?["room"] as? String ?? ""
                self.colorHex = timetableData?["color"] as? String ?? "#FF3B30"
                
                if let cData = classData, self.room.isEmpty {
                    self.room = cData["room"] as? String ?? ""
                }
            }
            
            // class未登録なら作成
            if classData == nil {
                try await classRef.setData([
                    "room": self.room,
                    "title": self.title,
                    "teacher": self.teacher,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
            
        } catch {
            print("❌ fetchLectureDetails エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ② シラバス情報を取得（ローカルキャッシュ対応 + 完全一致→前方一致）
    @MainActor
    func fetchSyllabus(year: String, quarter: String, day: String, code: String) async {
        let cacheKey = "syllabus_\(year)_\(code)"
        
        // 1. キャッシュ確認
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedSyllabus = try? JSONDecoder().decode(Syllabus.self, from: cachedData) {
            self.syllabus   = cachedSyllabus
            self.credits    = cachedSyllabus.credits
            self.evaluation = cachedSyllabus.evaluation
            self.references = cachedSyllabus.references
            print("📦 シラバス: キャッシュから読み込み (\(code))")
            return
        }
        
        // 2. なければFirestoreから取得（既存ロジック）
        let quarterSearchOrder: [String: [String]] = [
            "第1クォーター": ["第1クォーター"],
            "第2クォーター": ["第2クォーター", "第1クォーター"],
            "第3クォーター": ["第3クォーター"],
            "第4クォーター": ["第4クォーター", "第3クォーター"]
        ]
        guard let quartersToTry = quarterSearchOrder[quarter] else {
            print("❌ 無効なクォーター: \(quarter)")
            return
        }
        
        let codePrefix = String(code.prefix(5))
        
        for q in quartersToTry {
            let collectionRef = db.collection("NewSyllabus")
                .document(year)
                .collection(q)
                .document(day)
                .collection("lectures")
            
            // --- 完全一致 ---
            do {
                let exactDoc = try await collectionRef.document(code).getDocument()
                if exactDoc.exists, let data = exactDoc.data() {
                    applySyllabusData(data, year: year, code: code)
                    print("✅ シラバス取得（完全一致）: \(q) / \(day) / \(code)")
                    return
                }
            } catch {
                print("⚠️ 完全一致取得エラー（\(q)）: \(error.localizedDescription)")
            }
            
            // --- 前5文字一致 ---
            do {
                let snapshot = try await collectionRef.getDocuments()
                if let matched = snapshot.documents.first(where: { $0.documentID.hasPrefix(codePrefix) }) {
                    applySyllabusData(matched.data(), year: year, code: code)
                    print("✅ シラバス取得（前方一致: \(matched.documentID)）")
                    return
                }
            } catch {
                print("❌ 前方一致探索エラー（\(q)）: \(error.localizedDescription)")
            }
        }
        
        print("❌ シラバスが見つかりませんでした (\(code))")
    }
    
    // MARK: - シラバスデータをViewModelに反映
    @MainActor
    private func applySyllabusData(_ data: [String: Any], year: String, code: String) {
        let decodedTextbooks = decodeTextbookContent(from: data["教科書"])
        
        let s = Syllabus(
            title: data["開講科目名"] as? String ?? "",
            teacher: data["担当"] as? String ?? "",
            credits: data["単位数"] as? String,
            evaluation: data["成績評価基準"] as? String,
            textbooks: decodedTextbooks,
            summary: data["授業の概要と計画"] as? String,
            goals: data["授業の到達目標"] as? String,
            language: data["授業における使用言語"] as? String,
            method: data["授業形態"] as? String,
            schedule: data["開講期間"] as? String,
            remarks: data["履修上の注意"] as? String,
            contact: data["オフィスアワー・連絡先"] as? String,
            message: data["学生へのメッセージ"] as? String,
            keywords: data["キーワード"] as? String,
            preparationReview: data["事前・事後学修"] as? String,
            improvements: data["今年度の工夫"] as? String,
            referenceURL: data["参考URL"] as? String,
            evaluationTeacher: data["成績入力担当"] as? String,
            evaluationMethod: data["成績評価方法"] as? String,
            theme: data["授業のテーマ"] as? String,
            references: data["参考書・参考資料等"] as? String,
            code: data["時間割コード"] as? String ?? ""
        )
        
        self.syllabus   = s
        self.credits    = s.credits
        self.evaluation = s.evaluation
        self.references = s.references
        
        // キャッシュ保存
        if let encoded = try? JSONEncoder().encode(s) {
            let cacheKey = "syllabus_\(year)_\(code)"
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            print("💾 シラバス: キャッシュへ保存 (\(code))")
        }
    }
    
    // MARK: - 教科書データの柔軟デコード
    private func decodeTextbookContent(from raw: Any?) -> [TextbookContent] {
        func cleaned(_ s: String?) -> String? {
            let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }
        func makeFromDict(_ dict: [String: Any]) -> TextbookContent? {
            guard let text = cleaned(dict["text"] as? String
                                     ?? dict["title"] as? String
                                     ?? dict["name"] as? String) else { return nil }
            let linkAny = dict["link"] ?? dict["url"] ?? dict["URL"]
            let link: String? = {
                if let s = linkAny as? String { return cleaned(s) }
                if let u = linkAny as? URL    { return cleaned(u.absoluteString) }
                return nil
            }()
            if let l = link {
                return .object(text: text, link: l)
            } else {
                return .string(text)
            }
        }
        
        if let s = cleaned(raw as? String) { return [.string(s)] }
        if let dict = raw as? [String: Any], let item = makeFromDict(dict) { return [item] }
        if let array = raw as? [Any] {
            var out: [TextbookContent] = []
            var seen = Set<String>()
            for el in array {
                let items = decodeTextbookContent(from: el)
                for it in items {
                    let key: String = switch it {
                    case .string(let t): "S|\(t)"
                    case .object(let t, let l): "O|\(t)|\(l)"
                    }
                    if seen.insert(key).inserted { out.append(it) }
                }
            }
            return out
        }
        return []
    }
    
    // MARK: - 教室情報更新
    func updateRoomInfo(year: String, quarter: String, code: String, newRoom: String) async {
        let docRef = db.collection("class").document(year)
            .collection("Q\(quarter)").document(code)
        do {
            try await docRef.setData(["room": newRoom], merge: true)
            print("✅ 教室情報を更新: \(newRoom)")
        } catch {
            print("❌ 教室情報更新エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 口コミ取得
    @MainActor
    func fetchReviews(year: String, quarter: String, lectureCode: String) async {
        let path = "class/\(year)/Q\(quarter)/\(lectureCode)/reviews"
        print("📘 Firestore口コミアクセスパス: \(path)")
        do {
            let snapshot = try await db.collection(path).getDocuments()
            self.reviews = snapshot.documents.compactMap { Review(document: $0) }
            print("✅ 口コミ件数: \(self.reviews.count)")
        } catch {
            print("❌ 口コミ取得失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 統計系プロパティ
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.map { Double($0.rating) }.reduce(0, +) / Double(reviews.count)
    }
    var averageEasyScore: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.map { Double($0.easyScore) }.reduce(0, +) / Double(reviews.count)
    }
    var attendanceFrequencyCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for r in reviews { counts[r.attendanceFrequency, default: 0] += 1 }
        return counts
    }
}
