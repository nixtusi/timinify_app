//
//  InitialSetupView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct InitialSetupView: View {
    @EnvironmentObject var appState: AppState
    var onComplete: () -> Void

    @State private var studentNumber: String = ""
    @State private var password: String = ""
    @State private var message: String = ""
    @State private var showConfirmationAlert = false
    @State private var isVerifying = false
    @State private var isRegistered = false
    @State private var timer: Timer?
    
    @State private var showSigninView = false
    @State private var showingTerms = false
    @State private var showingAlert = false
    
    @State private var didSendFirstEmail = false
    @State private var resendRemaining = 0
    @State private var resendTimer: Timer?

    // 変更: この登録フローで作成されたユーザーだけを厳密に追跡（誤判定防止）
    @State private var registeringUID: String? = nil               // 変更
    @State private var registeringEmail: String? = nil             // 変更（小文字で保持）

    // 変更: セッション内での verified 状態遷移（false→true のみ採用）
    @State private var initialVerified: Bool = false               // 変更
    @State private var lastVerified: Bool = false                  // 変更
    @State private var didReportVerified: Bool = false             // 変更（二重完了防止）

    // 変更: ポーリング安全装置（無限ポーリング防止）
    private let pollingTimeoutSec: Int = 10 * 60                   // 変更: 最大10分
    @State private var pollingStartAt: Date? = nil                 // 変更

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Text("Uni Time")
                    .font(.system(size: 32, weight: .bold))

                TextField("学籍番号（例: 2437109t）", text: $studentNumber)
                    .padding(10)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal)

                SecureField("パスワード", text: $password)
                    .padding(10)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Button(action: { showingTerms = true }) {
                            Text("利用規約")
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("および")
                            .foregroundColor(.primary)

                        Button(action: {
                            if let url = URL(string: "https://nixtusi.github.io/unitime-privacy/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("プライバシーポリシー")
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("に同意のうえ、ご利用ください。")
                        .foregroundColor(.primary)
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

                Button(isVerifying ? "処理中…" : "新規登録") {
                    registerUser()
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .frame(height: 48)
                .background((studentNumber.isEmpty || password.isEmpty || isVerifying) ? Color.gray : Color(hex: "#4B3F96"))
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(studentNumber.isEmpty || password.isEmpty || isVerifying) // 変更: 多重タップ防止
                .padding(.horizontal)
                
                if shouldShowResendButton {
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

                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                HStack {
                    Text("既にアカウントをお持ちの場合")
                        .font(.footnote)
                        .foregroundColor(.gray)

                    Button(action: { showSigninView = true }) {
                        Text("ログイン")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(.bottom)
                .fullScreenCover(isPresented: $showSigninView) {
                    SigninView(onComplete: onComplete)
                }
            }
            .padding()
            .onAppear {
                // 変更: 起動時点で verified 済みユーザーが載っている場合のみ先へ進む（誤判定はなし）
                if let user = Auth.auth().currentUser, user.isEmailVerified {
                    if let email = user.email {
                        appState.studentNumber = email.components(separatedBy: "@").first ?? ""
                    }
                    onComplete()
                } else {
                    self.message = ""              // 変更: 古い文言の残留をクリア
                    self.didReportVerified = false // 変更
                }
            }
            .onDisappear {
                timer?.invalidate()
                resendTimer?.invalidate()
                resendTimer = nil
            }
            .sheet(isPresented: $showingTerms) {
                TermsView()
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .alert("確認メールを送信しました", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(studentNumber)@stu.kobe-u.ac.jp に確認メールを送信しました。\nメールをご確認ください。")
            }
        }
        //.toolbar(.hidden, for: .keyboard) // 変更: 入力補助バーを抑止（安定化）
    }

    private func registerUser() {
        // 変更: 入力メールを小文字で正規化し、セッション状態を初期化
        let email = "\(studentNumber)@stu.kobe-u.ac.jp".lowercased()
        self.message = ""                 // 変更
        self.didReportVerified = false    // 変更
        self.isVerifying = true           // 変更: 多重タップ防止

        // 変更: 異なるアカウントが既にログイン中なら事前 signOut（誤判定の種を除去）
        if let current = Auth.auth().currentUser, current.email?.lowercased() != email {
            do { try Auth.auth().signOut() } catch {
                // コンソールのみ（画面には出さない）
                print("SignOut error before register: \(error.localizedDescription)")
            }
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.message = "登録に失敗しました: \(error.localizedDescription)"
                    self.isVerifying = false // 変更
                }
                return
            }

            guard let user = result?.user else {
                DispatchQueue.main.async { self.isVerifying = false } // 変更
                return
            }

            // 変更: この登録フローの対象ユーザー情報を保持（以降の判定はこれと一致する場合のみ有効）
            self.registeringUID = user.uid
            self.registeringEmail = email

            // 変更: セッション内の初期 verified 値を記録（false→true のみ採用するため）
            self.initialVerified = user.isEmailVerified
            self.lastVerified = self.initialVerified

            Auth.auth().languageCode = "ja"

            // 変更: ActionCodeSettings なしで確認メール送信
            user.sendEmailVerification { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.message = "認証メール送信エラー: \(error.localizedDescription)"
                        self.isVerifying = false // 変更
                    } else {
                        self.message = ""
                        self.showingAlert = true
                        self.didSendFirstEmail = true
                        self.isVerifying = false // 変更: 再送などの操作を許可
                        self.startVerificationPolling() // 変更: ポーリング開始
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
        if self.resendRemaining > 0 { return }

        // 変更: 現在のユーザーが登録対象（uid/email）と一致するかを厳密チェック
        guard let current = Auth.auth().currentUser else {
            self.message = "現在ログインしているユーザーが見つかりません。もう一度お試しください。"
            self.setCooldown(30)
            return
        }
        guard current.uid == self.registeringUID,
              current.email?.lowercased() == self.registeringEmail else {
            self.message = "登録中のメールアドレスと異なるアカウントでログインしています。ログアウト後にやり直してください。"
            self.setCooldown(30)
            return
        }

        Auth.auth().currentUser?.reload(completion: { reloadError in
            if let reloadError = reloadError {
                DispatchQueue.main.async {
                    self.message = "状態更新エラー: \(reloadError.localizedDescription)"
                    self.setCooldown(60)
                }
                return
            }

            let nowVerified = (Auth.auth().currentUser?.isEmailVerified == true)

            // 変更: セッション内の false→true への遷移のみ完了扱い
            if nowVerified && self.initialVerified == false && self.lastVerified == false && self.didReportVerified == false {
                if let u = Auth.auth().currentUser { self.handleVerifiedTransition(u) } // 変更
                return
            }

            // 未確認なら再送、確認済みなら案内のみ
            if !nowVerified {
                Auth.auth().currentUser?.sendEmailVerification(completion: { error in
                    DispatchQueue.main.async {
                        if let error = error as NSError? {
                            let code = AuthErrorCode(_bridgedNSError: error)?.code
                            switch code {
                            case .tooManyRequests:
                                self.message = "送信が多すぎます。しばらく待ってから再度お試しください。"
                                self.setCooldown(600)
                            case .networkError:
                                self.message = "ネットワークエラー。接続を確認してから再度お試しください。"
                                self.setCooldown(120)
                            case .userDisabled:
                                self.message = "このアカウントは無効化されています。"
                                self.setCooldown(600)
                            case .invalidRecipientEmail, .invalidSender, .invalidMessagePayload:
                                self.message = "メール送信設定に問題があります。時間をおいてお試しください。"
                                self.setCooldown(300)
                            default:
                                self.message = "再送信に失敗しました: \(error.localizedDescription)"
                                self.setCooldown(180)
                            }
                        } else {
                            self.message = "メールを再送信しました。受信トレイと迷惑メールをご確認ください。"
                            self.showingAlert = true
                            self.setCooldown(180)
                        }
                    }
                })
            } else {
                DispatchQueue.main.async {
                    self.message = "このメールアドレスは既に確認済みです。ログインからお進みください。"
                    self.didSendFirstEmail = false
                }
            }
        })
    }

    private func startVerificationPolling() {
        self.pollingStartAt = Date() // 変更

        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // 変更: タイムアウト
            if let started = self.pollingStartAt,
               Date().timeIntervalSince(started) > TimeInterval(self.pollingTimeoutSec) {
                self.timer?.invalidate()
                DispatchQueue.main.async {
                    self.message = "確認待ちを終了しました。メール内のリンクを開いた後、再度アプリに戻ってください。"
                }
                return
            }

            Auth.auth().currentUser?.reload(completion: { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.message = "確認エラー: \(error.localizedDescription)"
                    }
                    return
                }

                // 変更: 必ず「この登録フローのユーザー」であることを確認
                guard let user = Auth.auth().currentUser else { return }
                guard user.uid == self.registeringUID,
                      user.email?.lowercased() == self.registeringEmail else { return }

                let nowVerified = user.isEmailVerified

                // 変更: false→true の遷移のみで完了扱い（=メールリンクを実際に踏んだ場合のみ）
                if nowVerified && self.initialVerified == false && self.lastVerified == false && self.didReportVerified == false {
                    self.handleVerifiedTransition(user) // 変更
                } else {
                    self.lastVerified = nowVerified // 変更: 状態更新
                }
            })
        }
    }

    // 変更: 検証完了（IDトークン強制更新→Firestore保存 → UI更新）
    private func handleVerifiedTransition(_ user: User) {
        guard !self.didReportVerified else { return } // 変更: 二重実行防止
        self.didReportVerified = true
        self.timer?.invalidate()
        self.resendTimer?.invalidate()
        self.resendRemaining = 0

        // 変更: トークンの email_verified クレームを最新化（Firestore ルール対策）
        user.getIDTokenForcingRefresh(true) { _, _ in
            // 必要に応じてユーザードキュメントを保存（失敗しても画面には出さない）
            self.saveUserInfoToFirestore()
        }

        // 任意: ローカル保存
        UserDefaults.standard.set(self.studentNumber, forKey: "studentNumber")
        UserDefaults.standard.set(self.password, forKey: "loginPassword")

        DispatchQueue.main.async {
            self.message = "✅ メール確認が完了しました。ログインしてください。"
            self.isVerifying = false
            self.showConfirmationAlert = false
            self.isRegistered = true
            self.appState.studentNumber = self.studentNumber
        }
    }

    private func saveUserInfoToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        let data: [String: Any] = [
            "student_number": studentNumber,
            "created_at": Timestamp(date: Date())
        ]

        db.collection("users").document(uid).setData(data) { error in
            if let error = error {
                // 画面には出さず、コンソールのみ（リリース安定性のため最小限）
                print("Firestore保存エラー: \(error.localizedDescription)")
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension InitialSetupView {
    var shouldShowResendButton: Bool {
        return didSendFirstEmail
    }
}
