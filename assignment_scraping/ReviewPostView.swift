//
//  ReviewPostView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/02.
//

import SwiftUI
import FirebaseFirestore

struct ReviewPostView: View {
    let year: String
    let quarter: String
    let lectureCode: String

    @Environment(\.dismiss) var dismiss

    @State private var rating: Int = 0  // 必須
    @State private var easyScore: Int = 0  // 必須
    @State private var attendanceFrequency: String = ""
    //@State private var evaluationMethod: String = ""
    @State private var freeComment: String = ""
    @State private var showSaveAlert = false

    // 出席頻度の選択肢
    let attendanceFrequencyOptions = [
        "毎回確認される",
        "ときどき確認される",
        "ほとんど確認されない",
        "出席確認なし"
    ]

    //private let evaluationOptions = ["テスト", "レポート", "その他"]

    var body: some View {
        NavigationStack {
            Form {
                // 評価セクション（星）
                Section(header: Text("評価(必須)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack{
                            Text("総合評価").fontWeight(.semibold)
                            Spacer()
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(.blue)
                                        .onTapGesture {
                                            rating = star
                                        }
                                }
                            }
                        }
                        
                        HStack {
                            Text("楽単度").fontWeight(.semibold)
                            Spacer()
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= easyScore ? "star.fill" : "star")
                                        .foregroundColor(.blue)
                                        .onTapGesture {
                                            easyScore = star
                                        }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 出欠・評価方法セクション（チェック付き選択）
                Section(header: Text("出席確認の頻度")) {
                    ForEach(attendanceFrequencyOptions, id: \.self) { option in
                        Button {
                            if attendanceFrequency == option {
                                attendanceFrequency = "" // 同じものをもう一度押すと解除
                            } else {
                                attendanceFrequency = option
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                if attendanceFrequency == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
//                Section(header: Text("評価方法")) {
//                    ForEach(evaluationOptions, id: \.self) { option in
//                        Button {
//                            if evaluationMethod == option {
//                                evaluationMethod = "" // 選択解除
//                            } else {
//                                evaluationMethod = option
//                            }
//                        } label: {
//                            HStack {
//                                Text(option).foregroundColor(.primary)
//                                if evaluationMethod == option {
//                                    Spacer()
//                                    Image(systemName: "checkmark")
//                                        .foregroundColor(.blue)
//                                }
//                            }
//                        }
//                    }
//                }
                
                // 自由コメント
                Section(header: Text("コメント")) {
                    TextEditor(text: $freeComment)
                        .frame(height: 100)
                }

                // 投稿ボタン（必須項目のチェック付き）
                Section {
                    Button("口コミを投稿") {
                        Task {
                            await submitReview()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .frame(height: 48)
                    //.background((studentNumber.isEmpty || password.isEmpty) ? Color.gray : Color(hex: "#6EC1E4"))
                    .background((rating == 0 || easyScore == 0) ? Color.gray : Color(hex: "#4B3F96"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(rating == 0 || easyScore == 0)
                    .padding(.horizontal)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("口コミ投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("送信できました", isPresented: $showSaveAlert) {
                Button("OK") {
                    dismiss() // 🔸 OKで画面を閉じる
                }
            }
        }
    }

    // MARK: - Firestore投稿処理
    private func submitReview() async {
        guard let studentId = UserDefaults.standard.string(forKey: "studentNumber") else {
            print("❌ 学籍番号が未設定")
            return
        }

        let reviewData: [String: Any] = [
            "rating": rating,
            "easyScore": easyScore,
            "attendanceFrequency": attendanceFrequency,
            //"evaluationMethod": evaluationMethod,
            "freeComment": freeComment,
            //"admissionYear": 2024, //studentIdからわかるので不要
            "createdAt": Timestamp(),
            "student_id": studentId
        ]

        let db = Firestore.firestore()
        let docRef = db
            .collection("class")
            .document(year)
            .collection("Q\(quarter)")
            .document(lectureCode)
            .collection("reviews")
            .document()
        
        do {
            try await docRef.setData(reviewData)
            print("✅ 口コミを投稿しました")
            showSaveAlert = true // 🔸 成功時にアラートを表示
        } catch {
            print("❌ 投稿エラー: \(error.localizedDescription)")
        }
    }
}
