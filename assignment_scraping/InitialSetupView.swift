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
                    .autocapitalization(.none)
                    .padding(.horizontal)

                SecureField("パスワード", text: $password)
                    .padding(10)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                HStack(spacing: 0) {
                    Button(action: {
                        showingTerms = true
                    }) {
                        Text("利用規約")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle()) // ✅ ボタンっぽさを消す

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

                // somewhere in body
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("確認メールを送信しました"),
                        message: Text("\(studentNumber)@stu.kobe-u.ac.jp に確認メールを送信しました。\nメールをご確認ください。"),
                        dismissButton: .default(Text("OK"))
                    )
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // ✅ ログインリンク追加部分
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
            }
            .sheet(isPresented: $showingTerms) {
                TermsView()
            }
            .onTapGesture {
                UIApplication.shared.endEditing() //画面外をタップでキーボードを閉じる
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

            result?.user.sendEmailVerification { error in
                if let error = error {
                    self.message = "認証メール送信エラー: \(error.localizedDescription)"
                } else {
                    self.message = ""
                    self.showingAlert = true // ✅ アラートを表示
                }
            }
        }
        
        
    }

    private func resendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification(completion: { error in
            if let error = error {
                self.message = "再送信エラー: \(error.localizedDescription)"
            } else {
                self.message = "メールを再送しました"
            }
        })
    }

    private func startVerificationPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Auth.auth().currentUser?.reload(completion: { error in
                if let error = error {
                    self.message = "確認エラー: \(error.localizedDescription)"
                    return
                }

                if Auth.auth().currentUser?.isEmailVerified == true {
                    timer?.invalidate()
                    saveUserInfoToFirestore()

                    UserDefaults.standard.set(studentNumber, forKey: "studentNumber")
                    UserDefaults.standard.set(password, forKey: "loginPassword")

                    self.message = "✅ メール確認が完了しました。ログインしてください。"
                    self.isVerifying = false
                    self.showConfirmationAlert = false
                    self.isRegistered = true
                    appState.studentNumber = studentNumber
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
