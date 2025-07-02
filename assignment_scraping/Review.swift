//
//  Review.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/02.
//

import Foundation
import FirebaseFirestore

struct Review: Identifiable {
    var id: String
    var rating: Int
    var easyScore: Int
    var attendanceFrequency: String
    var freeComment: String
    //var admissionYear: Int
    var createdAt: Date
    var student_id: String

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard let rating = data["rating"] as? Int,
              let easyScore = data["easyScore"] as? Int,
              let attendanceFrequency = data["attendanceFrequency"] as? String,
              let freeComment = data["freeComment"] as? String,
              //let admissionYear = data["admissionYear"] as? Int,
              let timestamp = data["createdAt"] as? Timestamp,
              let student_id = data["student_id"] as? String else {
            print("❌ Review初期化失敗: \(data)")
            return nil
        }

        self.id = document.documentID
        self.rating = rating
        self.easyScore = easyScore
        self.attendanceFrequency = attendanceFrequency
        self.freeComment = freeComment
        //self.admissionYear = admissionYear
        self.createdAt = timestamp.dateValue()
        self.student_id = student_id
    }
}
