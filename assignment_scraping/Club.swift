//
//  Club.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import Foundation
import FirebaseFirestore

struct Club: Identifiable, Codable {
    // IDはClubNameを使用
    var id: String { clubName }
    
    let clubName: String
    let genre: String
    let imgURL: String
    let kuOnly: Bool
    let linkForInstagram: String
    let linkForX: String
    let official: Bool
    let beginner: Bool
    let doubleDuty: Bool
    let frequency: String
    let keywords: [String]
    let manager: Bool
    let population: String
    
    // Firestoreのフィールド名とマッピング
    enum CodingKeys: String, CodingKey {
        case clubName = "ClubName"
        case genre = "Genle" // ⚠️ Firestore側のスペル通り
        case imgURL = "Img"
        case kuOnly = "KUonly"
        case linkForInstagram = "LinkForInstagram"
        case linkForX = "LinkForX"
        case official = "Official"
        case beginner
        case doubleDuty = "double_duty"
        case frequency
        case keywords
        case manager
        case population
    }
}
