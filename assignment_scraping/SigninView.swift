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
    
    @State private var showInitialSetupView = false // ← 画面遷移トリガー

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
                        .autocapitalization(.none)
                        .keyboardType(.asciiCapable)
                        .padding(.horizontal)

                    SecureField("パスワード", text: $password)
                        .padding(10)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                if let error = errorMessage {
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

                // ✅ .fullScreenCover は VStack全体に適用
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
        }
    }

    private func login() {
        isLoggingIn = true
        errorMessage = nil

        let email = "\(studentID)@stu.kobe-u.ac.jp"

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoggingIn = false

                if let error = error {
                    errorMessage = "ログイン失敗: \(error.localizedDescription)"
                    return
                }

                guard let user = result?.user else {
                    errorMessage = "ユーザー情報を取得できませんでした。"
                    return
                }

                user.reload { reloadError in
                    if let reloadError = reloadError {
                        errorMessage = "再取得に失敗しました: \(reloadError.localizedDescription)"
                    } else if user.isEmailVerified {
                        // ✅ 保存と状態更新
                        UserDefaults.standard.set(studentID, forKey: "studentNumber")
                        UserDefaults.standard.set(password, forKey: "loginPassword")
                        appState.isLoggedIn = true
                        appState.studentNumber = studentID
                        onComplete()
                    } else {
                        errorMessage = "メール認証がまだ完了していません。"
                        try? Auth.auth().signOut()
                    }
                }
            }
        }
    }
}
