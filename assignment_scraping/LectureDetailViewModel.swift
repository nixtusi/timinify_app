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
    @Published var colorHex: String = "#FF3B30" // ← デフォルト赤
    
    @Published var reviews: [Review] = []
    
    private var db = Firestore.firestore()
    
    /// Firestoreからデータを取得し、必要なら/classに授業を登録
    func fetchLectureDetails(studentId: String, admissionYear: String, year: String, quarter: String, day: String, period: Int, lectureCode: String) async {
        do {
            // Timetableの情報取得
            let timetablePath = "Timetable/\(admissionYear)/\(studentId)/\(year)/Q\(quarter)/\(lectureCode)\(day)\(period)"
            let timetableRef = db.document(timetablePath)
            let timetableSnapshot = try await timetableRef.getDocument()
            let timetableData = timetableSnapshot.data()

            // class情報を取得し、room補完または新規登録
            let classPath = "class/\(year)/Q\(quarter)/\(lectureCode)"
            let classRef = db.document(classPath)
            let classDoc = try await classRef.getDocument()
            let classData = classDoc.data()

            // シラバス情報の取得
            let syllabusRef = db.document("NewSyllabus/\(year)/第\(quarter)クォーター/\(day)/lectures/\(lectureCode)")
            let syllabusDoc = try await syllabusRef.getDocument()
            let sData = syllabusDoc.data()

            // 🔽 UI更新はメインスレッドでまとめて行う
            await MainActor.run {
                self.title = timetableData?["title"] as? String ?? ""
                self.teacher = timetableData?["teacher"] as? String ?? ""
                self.room = timetableData?["room"] as? String ?? ""
                self.colorHex = timetableData?["color"] as? String ?? "#FF3B30"

                if let classData = classData, self.room.isEmpty {
                    self.room = classData["room"] as? String ?? ""
                }

                if let sData = sData {
                    self.credits = sData["単位数"] as? String ?? ""
                    self.evaluation = sData["成績評価基準"] as? String ?? ""
                    self.references = sData["参考書・参考資料等"] as? String ?? ""
                }
            }

            // classが未登録なら登録
            if classData == nil {
                try await classRef.setData([
                    "room": self.room,
                    "title": self.title,
                    "teacher": self.teacher,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }

        } catch {
            print("❌ データ取得エラー: \(error.localizedDescription)")
        }
    }
    
    // 教室情報を更新してFirestoreに保存
    func updateRoomInfo(year: String, quarter: String, code: String, newRoom: String) async {
        let docRef = db.collection("class").document(year)
            .collection("Q\(quarter)").document(code)
        
        do {
            try await docRef.setData(["room": newRoom], merge: true)
            print("✅ 教室情報を更新: \(newRoom)")
        } catch {
            print("❌ 教室情報の更新エラー: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func fetchSyllabus(year: String, quarter: String, day: String, code: String) async {
        // クォーターごとの探索順を定義
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
        
        for q in quartersToTry {
            let path = "NewSyllabus/\(year)/\(q)/\(day)/lectures/\(code)"
            print("📘 Firestoreアクセスパス: \(path)")
            
            let docRef = db.collection("NewSyllabus")
                .document(year)
                .collection(q)
                .document(day)
                .collection("lectures")
                .document(code)
            
            do {
                let snapshot = try await docRef.getDocument()
                
                if snapshot.exists {
                    guard let data = snapshot.data() else {
                        print("⚠️ ドキュメントはあるがデータが空（\(q)）")
                        return
                    }
                    
                    // 🔽 textbooks フィールドのデコード補完
                    var decodedTextbooks: [TextbookContent]? = nil
                    if let rawTextbooks = data["教科書"] {
                        do {
                            decodedTextbooks = try decodeTextbookContent(from: rawTextbooks)
                        } catch {
                            print("⚠️ 教科書デコード失敗: \(error.localizedDescription)")
                        }
                    }
                    
                    // 🔽 syllabus オブジェクトを生成
                    let syllabus = Syllabus(
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
                        preparationReview: data["事前・事後学習"] as? String,
                        improvements: data["今年度の工夫"] as? String,
                        referenceURL: data["参考URL"] as? String,
                        evaluationTeacher: data["成績入力担当"] as? String,
                        evaluationMethod: data["成績評価方法"] as? String,
                        theme: data["授業のテーマ"] as? String,
                        references: data["参考書・参考資料等"] as? String,
                        code: data["時間割コード"] as? String ?? ""
                    )
                    
                    self.syllabus = syllabus
                    self.credits = syllabus.credits
                    self.evaluation = syllabus.evaluation
                    self.references = syllabus.references
                    
                    print("✅ シラバス情報を取得しました（\(q)）")
                    return
                }
            } catch {
                print("❌ Firestore取得エラー（\(q)）: \(error.localizedDescription)")
            }
        }
        
        print("❌ いずれのクォーターにもシラバスが存在しません")
    }
    
    private func decodeTextbookContent(from raw: Any?) throws -> [TextbookContent] {
        guard let array = raw as? [Any] else { return [] }
        
        return array.compactMap { item in
            if let str = item as? String {
                return .string(str)
            } else if let dict = item as? [String: Any],
                      let text = dict["text"] as? String,
                      let link = dict["link"] as? String {
                return .object(text: text, link: link)
            } else {
                return nil
            }
        }
    }
    
    //口コミを取得
    @MainActor // ← SwiftUIの@Published更新に必須
    func fetchReviews(year: String, quarter: String, lectureCode: String) async {
        let path = "class/\(year)/Q\(quarter)/\(lectureCode)/reviews"
        print("📘 Firestore口コミアクセスパス: \(path)")
        do {
            let snapshot = try await Firestore.firestore().collection(path).getDocuments()
            self.reviews = snapshot.documents.compactMap { Review(document: $0) }
            print("✅ 口コミ件数: \(self.reviews.count)")
        } catch {
            print("❌ 口コミの取得に失敗: \(error.localizedDescription)")
        }
    }
    
    //平均値プロパティ
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
        for review in reviews {
            counts[review.attendanceFrequency, default: 0] += 1
        }
        return counts
    }
}
