//
//  ReviewPostView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/02.
//

import SwiftUI
import FirebaseFirestore

enum AttendanceFrequency: String, CaseIterable, Identifiable {
    case everyTime = "毎回確認される"
    case sometimes = "ときどき確認される"
    case rarely = "ほとんど確認されない"
    case none = "出席確認なし"
    var id: String { rawValue }
}

struct ReviewPostView: View {
    let year: String
    let quarter: String
    let lectureCode: String

    @Environment(\.dismiss) var dismiss

    @State private var rating: Int = 0
    @State private var easyScore: Int = 0
    @State private var attendanceFrequency: AttendanceFrequency? = nil
    @State private var freeComment: String = ""
    @State private var showSaveAlert = false

    // ⬇︎ キーボード制御
    @FocusState private var commentFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // 評価
                    Section(header: Text("評価(必須)")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack{
                                Text("総合評価").fontWeight(.semibold)
                                Spacer()
                                HStack {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundStyle(Color.blue)
                                            .onTapGesture {
                                                rating = star
                                                print("⭐️ rating tapped -> \(star)")
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
                                            .foregroundStyle(Color.blue)
                                            .onTapGesture {
                                                easyScore = star
                                                print("⭐️ easyScore tapped -> \(star)")
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 出席頻度
                    Section(header: Text("出席確認の頻度（択一）")) {
                        Picker("出席確認の頻度", selection: $attendanceFrequency) {
                            Text("未選択").tag(nil as AttendanceFrequency?)
                            ForEach(AttendanceFrequency.allCases) { option in
                                Text(option.rawValue).tag(Optional(option))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // コメント
                    Section(header: Text("コメント")) {
                        TextEditor(text: $freeComment)
                            .frame(height: 120)
                            .focused($commentFocused)
                    }

                    // 投稿ボタン
                    Section {
                        Button {
                            print("📨 投稿ボタン tapped")
                            Task { await submitReview() }
                        } label: {
                            Text("口コミを投稿")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#4B3F96"))
                        .disabled(rating == 0 || easyScore == 0)
                        .listRowInsets(.init()) // 端まで広げて押しやすく
                    }
                }
                // ⬇︎ フォーム外タップでキーボードを閉じる（ボタンのタップを奪わない）
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("口コミ投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                // ⌨️ キーボード閉じるボタン
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("閉じる") { commentFocused = false }
                }
            }
            .alert("送信できました", isPresented: $showSaveAlert) {
                Button("OK") { dismiss() }
            }
        }
    }

    // MARK: - Firestore投稿処理
    @MainActor
    private func submitReview() async {
        guard let studentId = UserDefaults.standard.string(forKey: "studentNumber") else {
            print("❌ 学籍番号が未設定")
            return
        }

        let reviewData: [String: Any] = [
            "rating": rating,
            "easyScore": easyScore,
            "attendanceFrequency": attendanceFrequency?.rawValue ?? "",
            "freeComment": freeComment,
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
            showSaveAlert = true
        } catch {
            print("❌ 投稿エラー: \(error.localizedDescription)")
        }
    }
}
