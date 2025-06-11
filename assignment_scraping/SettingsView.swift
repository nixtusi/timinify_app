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
        Form {
            Section(header: Text("アカウント")) {
                Text(studentNumber)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Section(header: Text("図書館入館証")) {
                if isFetchingBarcode {
                    ProgressView()
                } else if let image = barcodeImage {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                        Spacer()
                    }
                } else {
                    Text("バーコード未取得")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("その他")) {
                Button("データを更新する") {
                    fetchAndUpdateBarcode()
                }
                
                NavigationLink(destination: TermsView()) {
                    Text("利用規約を見る")
                }
                
                Button(role: .destructive) {
                    showingLogoutAlert = true
                } label: {
                    Text("ログアウト")
                }
            }
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

    // ✅ BarcodeManager.swift に処理を委譲
    private func fetchAndUpdateBarcode() {
        isFetchingBarcode = true
        BarcodeManager.shared.fetchAndSaveBarcode { image in
            DispatchQueue.main.async {
                self.barcodeImage = image
                self.isFetchingBarcode = false
            }
        }
    }

    private func loadSavedBarcodeImage() {
        self.barcodeImage = BarcodeManager.shared.loadSavedBarcodeImage()
    }
}
