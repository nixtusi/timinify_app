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
    //var onSaved: (() -> Void)? = nil

    @StateObject private var viewModel = LectureDetailViewModel()
    @State private var isEditingRoom = false
    @State private var newRoom: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedColorHex: String = "#FF3B30" // ← デフォルト赤
    @State private var showRoomEditConfirm = false
    
    @State private var showSaveAlert = false
    @State private var didSave = false
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
                        Text("授業名")
                            .fontWeight(.semibold)
                        Text(title) // 修正済み
                    }

                    Divider()

                    HStack {
                        Text("教員名")
                            .fontWeight(.semibold)
                        Text(teacher) // 修正済み
                    }

                    Divider()

                    HStack {
                        Text("教室")
                            .fontWeight(.semibold)
                        if isEditingRoom {
                            TextField("教室を入力", text: $newRoom)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(room) // 修正済み
                            Button("編集") {
                                showRoomEditConfirm = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                }
                .onTapGesture {
                    UIApplication.shared.endEditing() //キーボード外をタップでキーボードを閉じる
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
        .alert("教室の変更", isPresented: $showRoomEditConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("変更") {
                newRoom = room
                isEditingRoom = true
            }
        } message: {
            Text("教室を変更すると、この授業の教室情報は全ユーザーに反映されます。")
        }
        .alert("保存できました", isPresented: $showSaveAlert) { //保存成功時のアラート
            Button("OK") {
                // 色更新を他画面へ通知しておく（TimetableViewが受け取り次第リロード）
                NotificationCenter.default.post(name: .timetableDidChange, object: nil)
                didSave = true
                dismiss() //OKボタンで画面を閉じる
            }
        }
        
        // 画面を閉じた“後”に通知（didSaveのときだけ）
        .onDisappear {
            if didSave {
                NotificationCenter.default.post(name: .timetableDidChange, object: nil)
            }
        }
    }
    
    private func uploadLectureData() {
        let db = Firestore.firestore()

        // Paths & Refs
        let admissionYear = "20" + String(studentNumber.prefix(2))
        let timetablePath = "Timetable/\(admissionYear)/\(studentNumber)/\(year)/\(quarter)/\(lectureCode)\(day)\(period)"
        let timetableRef = db.document(timetablePath)

        let classPath = "/class/\(year)/Q\(quarter.replacingOccurrences(of: "Q", with: ""))/\(lectureCode)"
        let classRef = db.document(classPath)

        // ① 共有 (/class) が正 → 個人 (/Timetable) と差があれば個人を共有に同期
        classRef.getDocument { classSnap, _ in
            let sharedRoom = (classSnap?.data()? ["room"] as? String) ?? ""
            timetableRef.getDocument { personalSnap, _ in
                let personalRoom = (personalSnap?.data()? ["room"] as? String) ?? ""
                if !sharedRoom.isEmpty, sharedRoom != personalRoom {
                    timetableRef.setData(["room": sharedRoom], merge: true) { err in
                        if let err = err { print("⚠️ 個人room同期エラー: \(err.localizedDescription)") }
                        else { print("↩️ 個人roomを共有roomで同期: \(timetablePath)") }
                    }
                }
            }
        }

        // ② ユーザーが保存した内容を /class と /Timetable の両方に保存（共有が常に正）
        let group = DispatchGroup()
        var errors: [Error] = []

        // /class ... に保存（作成 or 更新）
        group.enter()
        classRef.setData(["room": newRoom, "teacher": teacher, "title": title, "code": lectureCode], merge: true) { err in
            if let err = err { errors.append(err); print("Firestore /class 保存エラー: \(err.localizedDescription)") }
            else { print("/class に教室を保存: \(newRoom)") }
            group.leave()
        }

        // /Timetable ... にも room を保存（共有に合わせる）
        group.enter()
        timetableRef.setData(["room": newRoom], merge: true) { err in
            if let err = err { errors.append(err); print("Firestore /Timetable 保存エラー(room): \(err.localizedDescription)") }
            else { print("/Timetable に教室を保存: \(newRoom)") }
            group.leave()
        }

        // Timetable 側に色情報も保存
        group.enter()
        timetableRef.setData(["color": selectedColorHex], merge: true) { err in
            if let err = err { errors.append(err); print("Timetable 色保存エラー: \(err.localizedDescription)") }
            else { print("Timetable に色 \(selectedColorHex) を保存") }
            group.leave()
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                showSaveAlert = true
            } else {
                // 少なくとも一つ失敗したらログのみ表示（必要ならUIに反映）
                showSaveAlert = true
            }
        }

        print("教室: \(newRoom), 色: \(selectedColorHex)")
    }
}
