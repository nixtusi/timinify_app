//
//  LectureEditView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/01.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LectureEditView: View {
    let lectureCode: String
    let year: String
    let quarter: String
    var title: String
    var teacher: String
    var room: String
    var day: String
    var period: Int

    @StateObject private var viewModel = LectureDetailViewModel()
    @State private var isEditingRoom = false
    @State private var newRoom: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedColorHex: String = "#FF3B30" // ← デフォルト赤
    
    @State private var showSaveAlert = false
    @Environment(\.dismiss) private var dismiss
    
    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }
    
    let colorOptions: [(label: String, hex: String)] = [
        ("レッド", "#FF3B30"),
        ("オレンジ", "#FF9500"),
        ("イエロー", "#FFCC00"),
        ("グリーン", "#34C759"),
        ("ターコイズ", "#30D5C8"),
        ("ブルー", "#007AFF"),
        ("パープル", "#AF52DE"),
        ("ブラウン", "#A2845E"),
        ("ネイビー", "#001F3F")
        //("グレー", "#808080")
    ]

    var body: some View {
        Form {
            Section(header: Text("基本情報")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("授業名:")
                            .fontWeight(.semibold)
                        Text(title) // 修正済み
                    }

                    Divider()

                    HStack {
                        Text("教員名:")
                            .fontWeight(.semibold)
                        Text(teacher) // 修正済み
                    }

                    Divider()

                    HStack {
                        Text("教室:")
                            .fontWeight(.semibold)
                        if isEditingRoom {
                            TextField("教室を入力", text: $newRoom)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(room) // 修正済み
                            Button {
                                newRoom = room
                                isEditingRoom = true
                            } label: {
                                Image(systemName: "lock")
                            }
                        }
                    }
                }
            }

            Section(header: Text("背景色")) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        selectedColorHex = option.hex
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: option.hex)).opacity(0.18)
                                .frame(width: 20, height: 20)
                            Text(option.label)
                                .foregroundColor(.primary)
                            if selectedColorHex == option.hex {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: uploadLectureData) {
                    Text("保存")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#4B3F96"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .listRowBackground(Color.clear) // 背景透明でボタンデザインをそのまま使う
            }
        }
        .navigationTitle("授業の設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            newRoom = room
            let db = Firestore.firestore()
            let admissionYear = "20" + String(studentNumber.prefix(2))
            let path = "Timetable/\(admissionYear)/\(studentNumber)/\(year)/\(quarter)/\(lectureCode)\(day)\(period)" // ← 修正

            db.document(path).getDocument { snapshot, error in
                if let data = snapshot?.data(), let savedColor = data["color"] as? String {
                    DispatchQueue.main.async {
                        selectedColorHex = savedColor // ✅ これでクラッシュ回避
                    }
                } else {
                    DispatchQueue.main.async {
                        selectedColorHex = "#FF3B30" // ← なければ赤に（メインスレッドで）
                    }
                }
            }
        }
        .alert("保存できました", isPresented: $showSaveAlert) { //保存成功時のアラート
              Button("OK") {
                  dismiss() //OKボタンで画面を閉じる
              }
          }
    }
    
    private func uploadLectureData() {
        // Firestoreのroomを取得して比較・変更
        let db = Firestore.firestore()
        let classPath = "/class/\(year)/Q\(quarter.replacingOccurrences(of: "Q", with: ""))/\(lectureCode)"
        let classRef = db.document(classPath)

        classRef.getDocument { document, error in
            if let document = document, document.exists {
                let currentRoom = document.get("room") as? String ?? ""
                if currentRoom != newRoom {
                    classRef.updateData(["room": newRoom]) { err in
                        if let err = err {
                            print("Firestore更新エラー: \(err.localizedDescription)")
                        } else {
                            print("教室情報を更新しました: \(newRoom)")
                        }
                    }
                } else {
                    print("教室情報に変更なし")
                }
            } else {
                print("Firestoreドキュメントが存在しません")
            }
        }

        // 🎯 Timetable側にも色情報を保存（←ここが追加）
        let admissionYear = "20" + String(studentNumber.prefix(2)) // 学籍番号から入学年度を取得（例: 2435109t → 2024）
        let timetablePath = "Timetable/\(admissionYear)/\(studentNumber)/\(year)/\(quarter)/\(lectureCode)\(day)\(period)"
        
        print(selectedColorHex)
        print(timetablePath)

        db.document(timetablePath).setData(["color": selectedColorHex], merge: true) { error in
            if let error = error {
                print("Timetableへの色保存エラー: \(error.localizedDescription)")
            } else {
                print("Timetableに色 \(selectedColorHex) を保存しました")
                DispatchQueue.main.async {
                   showSaveAlert = true // ✅ 保存完了後にアラート表示
               }
            }
        }
        print("教室: \(newRoom), 色: \(selectedColorHex)")
    }
}
