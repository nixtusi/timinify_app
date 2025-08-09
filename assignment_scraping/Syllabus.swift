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
    var title: String //授業名
    var teacher: String //担当教員名
    var credits: String? //単位数
    var evaluation: String? //成績評価基準
    var textbooks: [TextbookContent]? //教科書
    var summary: String? //授業概要と計画
    var goals: String? //到達目標
    var language: String? //使用言語
    var method: String? //授業形態
    var schedule: String? //開講期間
    var remarks: String? //履修上の注意
    var contact: String? //連絡先
    var message: String? //学へのメッセージ
    var keywords: String? //キーワード
    var preparationReview: String? //事前事後学修
    var improvements: String? //今年度の工夫
    var referenceURL: String? //参考URL
    var evaluationTeacher: String? //成績入力担当
    var evaluationMethod: String? //成績評価方法
    var theme: String? //授業のテーマ
    var references: String? //参考書、参考資料など
    var code: String  // ← 時間割コード（例: "1G004"）
}
