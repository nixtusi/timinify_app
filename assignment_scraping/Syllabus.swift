//
//  Syllabus.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/29.
//

// Syllabusモデルの定義

import Foundation

struct Syllabus: Codable {
    var title: String
    var teacher: String
    var credits: String?
    var evaluation: String?
    var textbooks: String?
    var summary: String?
    var goals: String?
    var language: String?
    var method: String?
    var schedule: String?
    var remarks: String?
    var contact: String?
    var message: String?
}
