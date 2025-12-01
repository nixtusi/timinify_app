//
//  AuthView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    var onComplete: () -> Void
    @EnvironmentObject var appState: AppState

    // 入力・状態管理
    @State private var studentID = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    
    // メール確認・ポーリング用
    @State private var isVerificationSent = false
    @State private var resendRemaining = 0
    @State private var timer: Timer?
    @State private var resendTimer: Timer?
    
    // 登録フロー追跡用
    @State private var currentAuthUser: User? = nil
    @State private var pollingStartAt: Date? = nil
    private let pollingTimeoutSec: Int = 10 * 60

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("Uni Time")
                            .font(.system(size: 32, weight: .bold))
                        Text("神大生のための新しいツール")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 入力フォーム
                    VStack(spacing: 16) {
                        TextField("学籍番号（例: 2437109t）", text: $studentID)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textContentType(.username)
                            .keyboardType(.asciiCapable)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        SecureField("パスワード", text: $password)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)

                    // 利用規約（新規登録の可能性があるため常に表示）
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            NavigationLink(destination: TermsView()) {
                                Text("利用規約")
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Text(" と ")
                                .foregroundColor(.secondary)
                            Button(action: {
                                if let url = URL(string: "https://nixtusi.github.io/unitime-privacy/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("プライバシーポリシー")
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                        }
                        Text("に同意の上、次へ進んでください。")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)

                    // エラー/情報メッセージ
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    if let info = infoMessage {
                        Text(info)
                            .foregroundColor(.blue)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // メインボタン
                    Button(action: performAuth) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Text("ログイン / 新規登録")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .disabled(studentID.isEmpty || password.isEmpty || isLoading)
                    .background((studentID.isEmpty || password.isEmpty || isLoading) ? Color.gray : Color(hex: "#4B3F96"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // メール確認待ちUI
                    if isVerificationSent {
                        VStack(spacing: 12) {
                            Text("確認メールを送信しました。\nメール内のリンクをタップして認証を完了してください。\n自動的にログインします。")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(8)
                            
                            Button(action: resendVerificationEmail) {
                                Text(resendRemaining > 0 ? "メールを再送信 (\(resendRemaining)s)" : "メールを再送信")
                                    .font(.footnote.weight(.semibold))
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                            .disabled(resendRemaining > 0)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding()
            }
            .onTapGesture { UIApplication.shared.endEditing() }
            .onDisappear {
                timer?.invalidate()
                resendTimer?.invalidate()
            }
        }
    }

    // MARK: - 認証ロジック

    private func performAuth() {
        guard !studentID.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        let email = "\(studentID)@stu.kobe-u.ac.jp".lowercased()
        
        // 1. まずログインを試行
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                // ログイン成功 -> メール確認状態をチェック
                self.currentAuthUser = user
                checkVerificationState(user: user)
            } else {
                // ログイン失敗 -> エラー内容で分岐
                if let nsError = error as NSError?,
                   let errorCode = AuthErrorCode(rawValue: nsError.code) {
                    
                    if errorCode == .userNotFound {
                        // ユーザーが存在しない -> 新規登録へ
                        print("User not found, proceeding to registration.")
                        registerUser(email: email)
                    } else if errorCode == .wrongPassword {
                        // パスワード間違い
                        self.isLoading = false
                        self.errorMessage = "パスワードが間違っています。"
                    } else {
                        // その他のエラー
                        self.isLoading = false
                        self.errorMessage = "エラー: \(error?.localizedDescription ?? "不明なエラー")"
                    }
                }
            }
        }
    }

    // 新規登録処理
    private func registerUser(email: String) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.isLoading = false
                // すでに使われている等のエラーハンドリング
                if let nsError = error as NSError?, AuthErrorCode(rawValue: nsError.code) == .emailAlreadyInUse {
                    self.errorMessage = "このアカウントは既に存在します。パスワードを確認してください。"
                } else {
                    self.errorMessage = "登録エラー: \(error.localizedDescription)"
                }
                return
            }
            
            guard let user = result?.user else {
                self.isLoading = false
                return
            }
            
            // 登録成功 -> 確認メール送信
            self.currentAuthUser = user
            sendVerification(user: user)
        }
    }

    // メール確認状態のチェック
    private func checkVerificationState(user: User) {
        if user.isEmailVerified {
            // 確認済み -> ログイン完了
            finishLogin()
        } else {
            // 未確認 -> 待機モードへ
            self.isLoading = false
            self.isVerificationSent = true
            self.infoMessage = "メール認証が完了していません。"
            startPolling(user: user)
        }
    }

    // メール送信 & ポーリング開始
    private func sendVerification(user: User) {
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "メール送信エラー: \(error.localizedDescription)"
                } else {
                    self.isVerificationSent = true
                    self.infoMessage = "確認メールを送信しました。"
                    self.setCooldown(60)
                    self.startPolling(user: user)
                }
            }
        }
    }

    // 完了処理
    private func finishLogin() {
        UserDefaults.standard.set(studentID, forKey: "studentNumber")
        UserDefaults.standard.set(password, forKey: "loginPassword")
        
        // Firestoreへのユーザー情報保存（必要に応じて）
        if let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("users").document(uid).setData([
                "student_number": studentID,
                "last_login": Timestamp()
            ], merge: true)
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.appState.studentNumber = self.studentID
            self.appState.isLoggedIn = true // これで画面遷移
            self.onComplete()
        }
    }

    // MARK: - ポーリング & 再送

    private func startPolling(user: User) {
        timer?.invalidate()
        pollingStartAt = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // タイムアウト判定
            if let start = pollingStartAt, Date().timeIntervalSince(start) > TimeInterval(pollingTimeoutSec) {
                self.timer?.invalidate()
                self.infoMessage = "確認待ちを終了しました。認証完了後に再度ボタンを押してください。"
                return
            }
            
            // リロードして確認
            user.reload { error in
                if error == nil && user.isEmailVerified {
                    self.timer?.invalidate()
                    self.finishLogin()
                }
            }
        }
    }

    private func resendVerificationEmail() {
        guard let user = Auth.auth().currentUser else { return }
        
        user.sendEmailVerification { error in
            if let error = error {
                self.errorMessage = "再送エラー: \(error.localizedDescription)"
            } else {
                self.infoMessage = "メールを再送信しました。"
                self.setCooldown(60)
            }
        }
    }

    private func setCooldown(_ seconds: Int) {
        self.resendRemaining = seconds
        self.resendTimer?.invalidate()
        self.resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.resendRemaining > 0 {
                self.resendRemaining -= 1
            } else {
                t.invalidate()
            }
        }
    }
}
