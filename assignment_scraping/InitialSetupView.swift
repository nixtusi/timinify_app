//
//  InitialSetupView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//import SwiftUI
//

import SwiftUI

struct InitialSetupView: View {
    @AppStorage("loginID") private var loginID: String = ""
    @AppStorage("loginPassword") private var loginPassword: String = ""
    @AppStorage("agreedToTerms") private var agreedToTerms: Bool = false

    @State private var tempLoginID: String = ""
    @State private var tempPassword: String = ""
    @State private var agreed: Bool = false
    @State private var showingTerms = false

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 24) {
                Spacer()

                Text("Uni Time")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.bottom, 30)

                VStack(spacing: 16) {
                    TextField("学籍番号（例: 2437109t）", text: $tempLoginID)
                        .padding(10)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    SecureField("BEEF+ パスワード", text: $tempPassword)
                        .padding(10)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                HStack(spacing: 8) {
                    Button(action: {
                        agreed.toggle()
                    }) {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(agreed ? .blue : .gray)
                    }

                    Group {
                        Text("利用規約")
                            .foregroundColor(.blue)
                            .underline()
                            .onTapGesture {
                                showingTerms = true
                            }

                        Text("に同意する")
                            .foregroundColor(.primary)
                    }
                    .font(.body)

                    Spacer()
                }
                .padding(.horizontal)

                Button(action: {
                    loginID = tempLoginID
                    loginPassword = tempPassword
                    agreedToTerms = true
                    onComplete()
                }) {
                    Text("はじめる")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreed ? Color.black : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(!agreed || tempLoginID.isEmpty || tempPassword.isEmpty)

                Spacer()
            }
        }
        .onAppear {
            tempLoginID = loginID
            tempPassword = loginPassword
        }
        .sheet(isPresented: $showingTerms) {
            TermsView()
        }
    }
}
