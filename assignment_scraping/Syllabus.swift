//
//  Syllabus.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/29.
//

// Syllabusモデルの定義

import Foundation

struct Syllabus: Identifiable, Codable {
    var id: String { code }  // 一意なIDとして時間割コードを仮定
    var title: String
    var teacher: String
    var credits: String?
    var evaluation: String?
    var textbooks: [TextbookContent]?
    var summary: String?
    var goals: String?
    var language: String?
    var method: String?
    var schedule: String?
    var remarks: String?
    var contact: String?
    var message: String?
    var keywords: String?
    var preparationReview: String?
    var improvements: String?
    var referenceURL: String?
    var evaluationTeacher: String?
    var evaluationMethod: String?
    var theme: String?
    var references: String?
    var code: String  // ← 時間割コード（例: "1G004"）
}
