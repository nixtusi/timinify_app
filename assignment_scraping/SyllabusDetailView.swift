//
//  SyllabusDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/30.
//

import SwiftUI

struct SyllabusDetailView: View {
    let syllabus: Syllabus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    sectionView(title: "開講科目名", content: syllabus.title)
                    
                    if !syllabus.code.isEmpty {
                        sectionView(title: "時間割コード", content: syllabus.code)
                    }
                    if let input = syllabus.evaluationTeacher {
                        sectionView(title: "成績入力担当", content: input)
                    }
                    if let method = syllabus.method {
                        sectionView(title: "授業形態", content: method)
                    }
                    if let period = syllabus.schedule {
                        sectionView(title: "開講期間", content: period)
                    }
                    
                    Divider()
                    
                    if let theme = syllabus.theme {
                        sectionView(title: "授業のテーマ", content: theme)
                    }
                    if let goals = syllabus.goals {
                        sectionView(title: "授業の到達目標", content: goals)
                    }
                    if let summary = syllabus.summary {
                        sectionView(title: "授業の概要と計画", content: formatSyllabusText(summary))
                    }
                    if let method = syllabus.evaluationMethod {
                        sectionView(title: "成績評価方法", content: method)
                    }
                    if let evaluation = syllabus.evaluation {
                        sectionView(title: "成績評価基準", content: evaluation)
                    }
                    if let remarks = syllabus.remarks {
                        sectionView(title: "履修上の注意", content: remarks)
                    }
                    if let prep = syllabus.preparationReview {
                        sectionView(title: "事前・事後学習", content: prep)
                    }
                    if let contact = syllabus.contact {
                        sectionView(title: "連絡先", content: contact)
                    }
                    if let message = syllabus.message {
                        sectionView(title: "学生へのメッセージ", content: message)
                    }
                    if let improv = syllabus.improvements {
                        sectionView(title: "今年度の工夫", content: improv)
                    }
                    if let textbooks = syllabus.textbooks {
                        let textbookText = textbooks.map { $0.displayText }.joined(separator: "\n")
                        sectionView(title: "教科書", content: textbookText)
                    }
                    if let references = syllabus.references {
                        sectionView(title: "参考書・参考資料等", content: references) // ← textbooks → references に修正
                    }
                    if let language = syllabus.language {
                        sectionView(title: "使用言語", content: language)
                    }
                    if let keywords = syllabus.keywords {
                        sectionView(title: "キーワード", content: keywords)
                    }
                    if let url = syllabus.referenceURL {
                        sectionView(title: "参考URL", content: url)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("シラバス詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    // 共通表示スタイルを関数化
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                //.foregroundColor(.blue)
            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
    
    //改行
    func formatSyllabusText(_ text: String) -> String {
        var formatted = text
        
        // 全角数字を半角に変換
        let fullToHalfNumbers: [Character: Character] = [
            "１":"1", "２":"2", "３":"3", "４":"4", "５":"5",
            "６":"6", "７":"7", "８":"8", "９":"9", "０":"0"
        ]
        formatted = String(formatted.map { fullToHalfNumbers[$0] ?? $0 })

        // 「。」のあとに改行を挿入（段落）
        formatted = formatted.replacingOccurrences(of: "。", with: "。\n")

        // 「第〇回」「1 内容」などの前に改行
        let patterns = [
            "(?<!\\n)(第[0-9]{1,2}回)",           // 例: 第1回
            "(?<!\\n)([0-9]{1,2}[．\\.、\\s])"    // 例: 1. や 2．や 3、
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: formatted.utf16.count)
                formatted = regex.stringByReplacingMatches(in: formatted, options: [], range: range, withTemplate: "\n$1")
            }
        }

        // 連続改行を2つまでに制限
        while formatted.contains("\n\n\n") {
            formatted = formatted.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
