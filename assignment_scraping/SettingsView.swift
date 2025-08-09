//
//  SettingsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var fetcher = TimetableFetcher()

    @State private var showingLogoutAlert = false
    @State private var resetMessage: String?
    @State private var showingResetAlert = false
    @State private var showingResetConfirmAlert = false
    
    @State private var barcodeImage: UIImage? = nil
    @State private var isFetchingBarcode = false

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
                        Text("利用規約を見る")
                            .foregroundColor(.primary)
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

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("ログアウト")
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
}
