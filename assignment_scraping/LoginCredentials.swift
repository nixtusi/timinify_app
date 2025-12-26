//
//  LoginCredentials.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/26.
//

import Foundation
import FirebaseAuth

struct LoginCredentials {
    static var studentNumber: String {
        if let email = Auth.auth().currentUser?.email {
            return email.components(separatedBy: "@").first ?? ""
        }
        return UserDefaults.standard.string(forKey: "studentNumber") ?? ""
    }

    static var password: String {
        UserDefaults.standard.string(forKey: "loginPassword") ?? ""
    }
}
