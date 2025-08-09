//
//  SigninView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import SwiftUI
import FirebaseAuth

struct SigninView: View {
    var onComplete: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var studentID = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    @State private var showResendSection = false
    @State private var resendRemaining = 0
    @State private var resendTimer: Timer?
    
    @State private var showInitialSetupView = false //画面遷移トリガー

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Text("ログイン")
                    .font(.system(size: 32, weight: .bold))

                VStack(spacing: 16) {
                    TextField("学籍番号（例: 2437109t）", text: $studentID)
                        .padding(10)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textContentType(.username)
                        .keyboardType(.asciiCapable)
                        .padding(.horizontal)

                    SecureField("パスワード", text: $password)
                        .padding(10)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textContentType(.password)
                        .padding(.horizontal)
                }

                if let error = errorMessage, !showResendSection {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: login) {
                    if isLoggingIn {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("ログイン")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .disabled(studentID.isEmpty || password.isEmpty || isLoggingIn)
                .background((studentID.isEmpty || password.isEmpty) ? Color.gray : Color(hex: "#4B3F96"))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)

                if showResendSection {
                    VStack(spacing: 6) {
                        Text("メール認証がまだ完了していません。受信トレイ（迷惑メール含む）をご確認ください。")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 6) {
                            Text("メールが届きませんか？")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Button(action: resendVerificationEmail) {
                                Text(resendRemaining > 0 ? "メールを再送信（\(resendRemaining)s）" : "メールを再送信")
                                    .font(.footnote.weight(.semibold))
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(resendRemaining > 0)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // 下部のログインリンク表示
                HStack {
                    Text("まだアカウントをお持ちでない場合")
                        .font(.footnote)
                        .foregroundColor(.gray)

                    Button(action: {
                        showInitialSetupView = true
                    }) {
                        Text("新規登録")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(.bottom)

                //.fullScreenCover は VStack全体に適用
                .fullScreenCover(isPresented: $showInitialSetupView) {
                    InitialSetupView(onComplete: onComplete)
                }
            }
            .padding()
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .onTapGesture {
                UIApplication.shared.endEditing() //キーボード外をタップでキーボードを閉じる
            }
            .onDisappear {
                resendTimer?.invalidate()
                resendTimer = nil
            }
        }
    }

    private func login() {
        isLoggingIn = true
        errorMessage = nil
        showResendSection = false

        let email = "\(studentID)@stu.kobe-u.ac.jp"

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isLoggingIn = false

                if let error = error {
                    self.errorMessage = "ログイン失敗: \(error.localizedDescription)"
                    return
                }

                guard let user = result?.user else {
                    self.errorMessage = "ユーザー情報を取得できませんでした。"
                    return
                }

                user.reload { reloadError in
                    if let reloadError = reloadError {
                        self.errorMessage = "再取得に失敗しました: \(reloadError.localizedDescription)"
                        return
                    }

                    if user.isEmailVerified {
                        // 保存と状態更新
                        UserDefaults.standard.set(self.studentID, forKey: "studentNumber")
                        UserDefaults.standard.set(self.password, forKey: "loginPassword")
                        self.appState.isLoggedIn = true
                        self.appState.studentNumber = self.studentID
                        self.onComplete()
                    } else {
                        // メール未認証 → ログアウトして再送UIを出す
                        self.errorMessage = "メール認証がまだ完了していません。受信トレイ（迷惑メール含む）をご確認ください。"
                        self.showResendSection = true
                        try? Auth.auth().signOut()
                    }
                }
            }
        }
    }

    private func setCooldown(_ seconds: Int) {
        self.resendRemaining = max(0, seconds)
        self.resendTimer?.invalidate()
        guard seconds > 0 else { return }
        self.resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.resendRemaining > 0 {
                self.resendRemaining -= 1
            } else {
                t.invalidate()
            }
        }
    }

    private func resendVerificationEmail() {
        // クールダウン中は何もしない
        if self.resendRemaining > 0 { return }

        // 最新状態を確認（既に確認済みなら案内して終わり）
        Auth.auth().currentUser?.reload(completion: { reloadError in
            if let reloadError = reloadError {
                self.errorMessage = "状態更新エラー: \(reloadError.localizedDescription)"
                self.setCooldown(60) // 一旦短めの待機
                return
            }

            if Auth.auth().currentUser?.isEmailVerified == true {
                self.errorMessage = "✅ すでにメール確認が完了しています。ログインしてください。"
                self.showResendSection = false
                return
            }

            // 未確認 → 再送信
            Auth.auth().currentUser?.sendEmailVerification(completion: { err in
                if let err = err as NSError? {
                    let code = AuthErrorCode(_bridgedNSError: err)?.code
                    switch code {
                    case .tooManyRequests:
                        self.errorMessage = "送信が多すぎます。しばらく待ってから再度お試しください。"
                        self.setCooldown(600) // 10分待機
                    case .networkError:
                        self.errorMessage = "ネットワークエラー。接続を確認してから再度お試しください。"
                        self.setCooldown(120) // 2分
                    case .userDisabled:
                        self.errorMessage = "このアカウントは無効化されています。"
                        self.setCooldown(600)
                    case .invalidRecipientEmail, .invalidSender, .invalidMessagePayload:
                        self.errorMessage = "メール送信設定に問題があります。時間をおいてお試しください。"
                        self.setCooldown(300)
                    default:
                        self.errorMessage = "再送信に失敗しました: \(err.localizedDescription)"
                        self.setCooldown(180)
                    }
                } else {
                    self.errorMessage = "確認メールを再送しました。受信トレイと迷惑メールをご確認ください。"
                    self.setCooldown(180) // 成功時は長めに
                }
            })
        })
    }
}
