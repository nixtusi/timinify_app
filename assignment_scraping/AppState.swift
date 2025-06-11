//
//  AppState.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import FirebaseAuth
import SwiftUI
import Foundation

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var studentNumber: String = ""

    init() {
        checkLoginStatus()
    }

    func checkLoginStatus() {
        if let user = Auth.auth().currentUser, user.isEmailVerified {
            self.isLoggedIn = true
        } else {
            self.isLoggedIn = false
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
        } catch {
            print("ログアウトエラー: \(error.localizedDescription)")
        }
    }
    
}
