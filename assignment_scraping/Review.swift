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
    var student_id: String
    var rating: Int
    var easyScore: Int
    var attendanceFrequency: String
    var freeComment: String
    var createdAt: Date
    
    let upCount: Int
    let downCount: Int
    
    var helpfulScore: Int { upCount - downCount }

    init?(document: QueryDocumentSnapshot) {
        let d = document.data()

        self.id = document.documentID
        self.student_id = d["student_id"] as? String ?? ""
        self.rating = d["rating"] as? Int ?? 0
        self.easyScore = d["easyScore"] as? Int ?? 0
        self.attendanceFrequency = d["attendanceFrequency"] as? String ?? ""
        self.freeComment = d["freeComment"] as? String ?? ""

        let ts = d["createdAt"] as? Timestamp
        self.createdAt = ts?.dateValue() ?? Date(timeIntervalSince1970: 0)

        self.upCount = d["upCount"] as? Int ?? 0
        self.downCount = d["downCount"] as? Int ?? 0
    }
}
