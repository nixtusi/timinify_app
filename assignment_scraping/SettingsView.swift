//
//  SettingsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI
import LocalAuthentication //生体認証のために必要

struct SettingsView: View {
    @AppStorage("loginID") private var loginID: String = ""
    @AppStorage("loginPassword") private var loginPassword: String = ""

    @State private var isEditing = false
    @State private var tempLoginID = ""
    @State private var tempPassword = ""

    @State private var showAuthError = false // 生体認証失敗時のアラート用

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ログイン情報")) {
                    TextField("学籍番号(例:2437109t)", text: $tempLoginID)
                        //.keyboardType(.numberPad)
                        .autocapitalization(.none)
                        .disabled(!isEditing)

                    SecureField("BEEF+パスワード", text: $tempPassword)
                        .disabled(!isEditing)
                }

                Section {
                    Button(action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                        if isEditing {
                            //編集終了 → 保存
                            loginID = tempLoginID
                            loginPassword = tempPassword
                            isEditing = false
                        } else {
                            //編集開始前に生体認証
                            authenticateWithBiometrics { success in
                                if success {
                                    // 認証成功 → 編集開始
                                    tempLoginID = loginID
                                    tempPassword = loginPassword
                                    isEditing = true
                                } else {
                                    // 認証失敗 → アラート
                                    showAuthError = true
                                }
                            }
                        }
                    }) {
                        Text(isEditing ? "保存" : "編集")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                    }
                }

                Section(footer: Text("※ これらの情報は端末内（AppStorage）に安全に保存されます。")) {
                    EmptyView()
                }

                // ✅ 利用規約へのリンクを追加
                Section {
                    NavigationLink("利用規約を見る") {
                        TermsView()
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear {
                //アプリ起動時に保存済み情報を表示
                tempLoginID = loginID
                tempPassword = loginPassword
            }
            .alert(isPresented: $showAuthError) {
                Alert(
                    title: Text("認証失敗"),
                    message: Text("Face ID / Touch ID の認証に失敗しました。"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    //生体認証処理
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "設定を編集するにはFace ID / Touch IDによる認証が必要です。"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // デバイスが生体認証に対応していない
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
