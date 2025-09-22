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
    
    @State private var didSendFirstEmail = false         // 🔺 初回送信済みフラグ
    @State private var resendRemaining = 0               // 🔺 クールダウン残り秒（0で即時可）
    @State private var resendTimer: Timer?               // 🔺 クールダウン用タイマー

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
                        Button(action: {
                            showingTerms = true
                        }) {
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

                Button("新規登録") {
                    registerUser()
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .frame(height: 48)
                //.background((studentNumber.isEmpty || password.isEmpty) ? Color.gray : Color(hex: "#6EC1E4"))
                .background((studentNumber.isEmpty || password.isEmpty) ? Color.gray : Color(hex: "#4B3F96"))
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(studentNumber.isEmpty || password.isEmpty)
                .padding(.horizontal)
                
                 // 🔺 再送信ボタン（未確認時のみ表示）
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

                //ログインリンク追加部分
                HStack {
                    Text("既にアカウントをお持ちの場合")
                        .font(.footnote)
                        .foregroundColor(.gray)

                    Button(action: {
                        showSigninView = true
                    }) {
                        Text("ログイン")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(.bottom)
                .fullScreenCover(isPresented: $showSigninView) {
                    SigninView(onComplete: onComplete) // ← SigninView に遷移
                }
            }
            .padding()
            //.navigationTitle("新規登録")
            .onAppear {
                if let user = Auth.auth().currentUser, user.isEmailVerified {
                    if let email = user.email {
                        appState.studentNumber = email.components(separatedBy: "@").first ?? ""
                    }
                    onComplete()
                }
            }
            .onDisappear {
                timer?.invalidate()
                resendTimer?.invalidate()   // 🔺クールダウンタイマーも止める
                resendTimer = nil
            }
            .sheet(isPresented: $showingTerms) {
                TermsView()
            }
            .onTapGesture {
                UIApplication.shared.endEditing() //画面外をタップでキーボードを閉じる
            }
            .alert("確認メールを送信しました", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(studentNumber)@stu.kobe-u.ac.jp に確認メールを送信しました。\nメールをご確認ください。")
            }
        }
    }

    private func registerUser() {
        let email = "\(studentNumber)@stu.kobe-u.ac.jp"
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.message = "登録に失敗しました: \(error.localizedDescription)"
                return
            }

            Auth.auth().languageCode = "ja" // 🔺日本語テンプレ（コンソール設定が必要）
            result?.user.sendEmailVerification { error in
                if let error = error {
                    self.message = "認証メール送信エラー: \(error.localizedDescription)"
                } else {
                    self.message = ""
                    self.showingAlert = true //アラートを表示
                    self.didSendFirstEmail = true         // 🔺 再送信ボタンを出す
                    self.startVerificationPolling()       // 🔺 確認完了ポーリング開始
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
        // 1) クールダウン中は何もしない
        if self.resendRemaining > 0 { return }

        // 2) 最新状態を確認（既に確認済みなら送らない）
        Auth.auth().currentUser?.reload(completion: { reloadError in
            if let reloadError = reloadError {
                self.message = "状態更新エラー: \(reloadError.localizedDescription)"
                // ネットワーク不調時などは短いクールダウン
                self.setCooldown(60)
                return
            }

            if Auth.auth().currentUser?.isEmailVerified == true {
                self.message = "✅ すでにメール確認が完了しています。ログインしてください。"
                self.didSendFirstEmail = false
                return
            }

            // 3) まだ未確認 → 再送信
            Auth.auth().currentUser?.sendEmailVerification(completion: { error in
                if let error = error as NSError? {
                    // エラーコードに応じて待ち時間を変える
                    let code = AuthErrorCode(_bridgedNSError: error)?.code
                    switch code {
                    case .tooManyRequests:
                        self.message = "送信が多すぎます。しばらく待ってから再度お試しください。"
                        self.setCooldown(600) // 10分の待機
                    case .networkError:
                        self.message = "ネットワークエラー。接続を確認してから再度お試しください。"
                        self.setCooldown(120) // 2分
                    case .userDisabled:
                        self.message = "このアカウントは無効化されています。"
                        self.setCooldown(600)
                    case .invalidRecipientEmail, .invalidSender, .invalidMessagePayload:
                        self.message = "メール送信設定に問題があります。時間をおいてお試しください。"
                        self.setCooldown(300)
                    default:
                        self.message = "再送信に失敗しました: \(error.localizedDescription)"
                        self.setCooldown(180) // デフォルトの待機
                    }
                } else {
                    self.message = "メールを再送信しました。受信トレイと迷惑メールをご確認ください。"
                    self.showingAlert = true
                    // 成功時のクールダウン（長め）
                    self.setCooldown(180) // 3分
                }
            })
        })
    }

    private func startVerificationPolling() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Auth.auth().currentUser?.reload(completion: { error in
                if let error = error {
                    self.message = "確認エラー: \(error.localizedDescription)"
                    return
                }

                if Auth.auth().currentUser?.isEmailVerified == true {
                    self.timer?.invalidate()
                    // 🔺 確認完了時に再送信UI/タイマーもクリア
                    self.didSendFirstEmail = false
                    self.resendTimer?.invalidate()
                    self.resendRemaining = 0
                    self.saveUserInfoToFirestore()

                    UserDefaults.standard.set(self.studentNumber, forKey: "studentNumber")
                    UserDefaults.standard.set(self.password, forKey: "loginPassword")

                    self.message = "✅ メール確認が完了しました。ログインしてください。"
                    self.isVerifying = false
                    self.showConfirmationAlert = false
                    self.isRegistered = true
                    self.appState.studentNumber = self.studentNumber
                }
            })
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
                print("Firestore保存エラー: \(error.localizedDescription)")
            } else {
                print("Firestoreにユーザー情報を保存しました")
            }
        }
        
        
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#") // "#" をスキップ

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension InitialSetupView {
    /// 🔺再送信リンクの表示条件：初回送信後のみ表示
    var shouldShowResendButton: Bool {
        return didSendFirstEmail
    }
}
