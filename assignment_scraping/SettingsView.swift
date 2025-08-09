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
    
    @State private var barcodeImage: UIImage? = nil
    @State private var isFetchingBarcode = false

    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }

    var body: some View {
        ZStack {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0) // ダーク時のベージュ風
                : UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1.0) // 通常のベージュ
            })
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
