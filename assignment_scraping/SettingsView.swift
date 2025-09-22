//
//  SettingsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var fetcher = TimetableFetcher()

    @State private var showingLogoutAlert = false
    @State private var resetMessage: String?
    @State private var showingResetAlert = false
    @State private var showingResetConfirmAlert = false
    
    @State private var barcodeImage: UIImage? = nil
    @State private var isFetchingBarcode = false
    
    @State private var showingDeleteAlert = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var deleteStep: String?

    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            Form {
                Section(header: Text("アカウント")) {
                    Text(studentNumber)
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Section(header: Text("図書館入館証")) {
                    ZStack {
                        Color.white //ダークモード時でも白背景に固定
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        
                        VStack {
                            if isFetchingBarcode {
                                ProgressView()
                                    .padding()
                            } else if let image = barcodeImage {
                                HStack {
                                    Spacer()
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                    Spacer()
                                }
                                .padding()
                            } else {
                                Text("バーコード未取得")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets()) //セクション外の余白を詰める
                }

                Section(header: Text("その他")) {
                    NavigationLink(destination: DataUpdateView()) {
                        Text("データを更新する")
                            .foregroundColor(.primary) //明示的に指定（必要に応じて）
                    }

                    NavigationLink(destination: TermsView()) {
                        Text("利用規約")
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://nixtusi.github.io/unitime-privacy/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("プライバシーポリシー (外部リンク)")
                    }

                    Button {
                        showingResetConfirmAlert = true
                    } label: {
                        Text("パスワードを変更")
                    }
                    .alert("パスワード変更のためのメールを送信しますか？", isPresented: $showingResetConfirmAlert) {
                        Button("送信", role: .none) {
                            sendPasswordResetEmail()
                        }
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("※BEEF+ とは異なるパスワードでアカウントを作成してしまった場合のみ使用してください。")
                    }

//                    Text("BEEF+ と異なるパスワードで作成してしまった場合のみ使用してください。")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://forms.gle/1bdUg6UyFgASGwNR6") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("お問い合わせ")
                    }

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("ログアウト")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Text("アカウント削除")
                    }
                    .alert("本当に削除しますか？", isPresented: $showingDeleteAlert) {
                        Button("削除する", role: .destructive) {
                            Task {
                                await deleteAccount()
                            }
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        Text("Uni Timeサービスにおける時間割などのあなたのアカウントは削除されます。口コミは匿名のまま残ります。")
                    }
                }
            }
            .background(Color.clear) //Formの背景を透明にして親ビューに従わせる
            .scrollContentBackground(.hidden) //背景色の変更に使用
        }
        .onAppear {
            loadSavedBarcodeImage()
        }
        .alert("パスワード再設定", isPresented: $showingResetAlert, presenting: resetMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .alert("ログアウトしますか？", isPresented: $showingLogoutAlert) {
            Button("ログアウト", role: .destructive, action: logout)
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func sendPasswordResetEmail() {
        guard let email = Auth.auth().currentUser?.email, !email.isEmpty else {
            self.resetMessage = "メールアドレスを確認できませんでした。再度ログインし直してください。"
            self.showingResetAlert = true
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.resetMessage = "送信に失敗しました: \(error.localizedDescription)"
            } else {
                self.resetMessage = "\(email) にパスワード再設定用のメールを送信しました。受信トレイと迷惑メールをご確認ください。"
            }
            self.showingResetAlert = true
        }
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            appState.isLoggedIn = false
            UserDefaults.standard.removeObject(forKey: "studentNumber")
            UserDefaults.standard.removeObject(forKey: "loginPassword")
        } catch {
            resetMessage = "ログアウトに失敗しました: \(error.localizedDescription)"
            showingResetAlert = true
        }
    }

    private func loadSavedBarcodeImage() {
        isFetchingBarcode = true
        DispatchQueue.global().async {
            let image = BarcodeManager.shared.loadSavedBarcodeImage()
            DispatchQueue.main.async {
                self.barcodeImage = image
                self.isFetchingBarcode = false
            }
        }
    }
    
    @MainActor
    private func deleteAccount() async {
        deleting = true
        deleteError = nil
        deleteStep = "再認証中…"

        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            deleting = false
            deleteError = "ユーザー情報を取得できませんでした。"
            return
        }

        // 再認証（直近ログインでないと削除が失敗する）
        if let password = UserDefaults.standard.string(forKey: "loginPassword"), !password.isEmpty {
            do {
                let cred = EmailAuthProvider.credential(withEmail: email, password: password)
                _ = try await user.reauthenticate(with: cred)
            } catch {
                deleting = false
                deleteError = "再認証に失敗しました。再ログイン後にお試しください。\n\(error.localizedDescription)"
                return
            }
        } else {
            deleting = false
            deleteError = "端末にパスワードが見つかりません。再ログイン後、もう一度お試しください。"
            return
        }

        let db = Firestore.firestore()

        // 学籍番号・入学年度など
        let studentNumber = email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
        let entryYear: Int? = {
            guard let two = Int(studentNumber.prefix(2)) else { return nil }
            return 2000 + two
        }()

        // 1) Firestore: users/{uid} を削除
        do {
            deleteStep = "ユーザーデータ削除中…"
            try await db.collection("users").document(user.uid).delete()
        } catch {
            // users が無くても続行
            print("users削除エラー: \(error.localizedDescription)")
        }

        // 2) Firestore: Timetable ツリーを削除（既知の構造のみ）
        // /Timetable/{entryYear}/{studentNumber}/{AY}/Q{1..4}/{doc}
        if let ent = entryYear {
            let base = db.collection("Timetable").document("\(ent)").collection(studentNumber)
            // 学年は4年分をざっくりスキャン（必要に応じて調整）
            let thisYear = Calendar.current.component(.year, from: Date())
            let years = (thisYear-3)...(thisYear+1)
            for y in years {
                deleteStep = "時間割 \(y) 年度の削除中…"
                let yearDoc = base.document("\(y)")
                for q in 1...4 {
                    let qsnap = try? await yearDoc.collection("Q\(q)").getDocuments()
                    if let docs = qsnap?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        do { try await batch.commit() } catch { print("Q\(q) バッチ削除失敗: \(error.localizedDescription)") }
                    }
                }
                // 年度ドキュメント本体はフィールド無しなら何もせず。必要なら yearDoc.delete()
            }
        }

        // 3) 端末ローカルのクリア
        deleteStep = "ローカルデータの消去中…"
        UserDefaults.standard.removeObject(forKey: "studentNumber")
        UserDefaults.standard.removeObject(forKey: "loginPassword")
        UserDefaults.standard.removeObject(forKey: "cachedTimetableItems")

        // ウィジェットのキャッシュ消去（App Group）
        if let ud = UserDefaults(suiteName: "group.com.yuta.beefapp") {
            ud.removeObject(forKey: "widgetTimetableToday")
        }
        WidgetCenter.shared.reloadAllTimelines()

        // 図書館バーコード画像があれば削除
        BarcodeManager.shared.deleteSavedBarcode()

        // 4) Firebase Auth のユーザー削除
        deleteStep = "アカウント削除中…"
        do {
            try await user.delete()
        } catch {
            deleting = false
            deleteError = "アカウント削除に失敗しました: \(error.localizedDescription)"
            return
        }

        // 5) ログアウト状態へ
        deleteStep = "サインアウト中…"
        try? Auth.auth().signOut()
        appState.isLoggedIn = false

        deleting = false
        deleteStep = nil
    }
}

