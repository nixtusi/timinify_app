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
    @Published var credits: String = ""
    @Published var evaluation: String = ""
    @Published var references: String = ""
    @Published var syllabus: Syllabus? = nil
    @Published var colorHex: String = "#FF3B30" // ← デフォルト赤

    private var db = Firestore.firestore()

    /// Firestoreからデータを取得し、必要なら/classに授業を登録
    func fetchLectureDetails(studentId: String, admissionYear: String, year: String, quarter: String, day: String, period: Int, lectureCode: String) async {
        do {
            // Timetableの情報取得
            let timetablePath = "Timetable/\(admissionYear)/\(studentId)/\(year)/Q\(quarter)/\(lectureCode)\(day)\(period)"
            let timetableRef = db.document(timetablePath)
            let timetableSnapshot = try await timetableRef.getDocument()
            let timetableData = timetableSnapshot.data()

            // Main ThreadでUI更新
            DispatchQueue.main.async {
                self.title = timetableData?["title"] as? String ?? ""
                self.teacher = timetableData?["teacher"] as? String ?? ""
                self.room = timetableData?["room"] as? String ?? ""
                self.colorHex = timetableData?["color"] as? String ?? "#FF3B30" // ← 色がなければ赤
            }

            // class情報を取得し、room補完または新規登録
            let classPath = "class/\(year)/Q\(quarter)/\(lectureCode)"
            let classRef = db.document(classPath)
            let classDoc = try await classRef.getDocument()

            if let classData = classDoc.data() {
                if self.room.isEmpty {
                    DispatchQueue.main.async {
                        self.room = classData["room"] as? String ?? ""
                    }
                }
            } else {
                try await classRef.setData([
                    "room": self.room,
                    "title": self.title,
                    "teacher": self.teacher,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }

            // シラバス情報の取得
            let syllabusRef = db.document("NewSyllabus/\(year)/第\(quarter)クォーター/\(day)/lectures/\(lectureCode)")
            let syllabusDoc = try await syllabusRef.getDocument()

            if let sData = syllabusDoc.data() {
                DispatchQueue.main.async {
                    self.credits = sData["単位数"] as? String ?? ""
                    self.evaluation = sData["成績評価基準"] as? String ?? ""
                    self.references = sData["参考書・参考資料等"] as? String ?? ""
                }
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

                    self.credits = data["単位数"] as? String ?? ""
                    self.evaluation = data["成績評価基準"] as? String ?? ""
                    self.references = data["参考書・参考資料等"] as? String ?? ""

                    self.syllabus = Syllabus(
                        title: data["開講科目名"] as? String ?? "",
                        teacher: data["担当"] as? String ?? "",
                        credits: data["単位数"] as? String,
                        evaluation: data["成績評価基準"] as? String,
                        textbooks: data["教科書"] as? String,
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
                        code: data["時間割コード"] as? String ?? ""
                    )

                    print("✅ シラバス情報を取得しました（\(q)）")
                    return
                } else {
                    print("⚠️ ドキュメントが存在しません（\(q)）")
                }
            } catch {
                print("❌ Firestore取得エラー（\(q)）: \(error.localizedDescription)")
            }
        }

        print("❌ いずれのクォーターにもシラバスが存在しません")
    }
}
