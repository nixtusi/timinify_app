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

                    if !syllabus.code.isEmpty {
                        sectionViewInline(title: "時間割コード", content: syllabus.code)
                    }
                    
                    sectionViewInline(title: "開講科目名", content: syllabus.title)
                    
                    if let input = syllabus.evaluationTeacher {
                        sectionViewInline(title: "成績入力担当", content: input)
                    }
                    
                    if let method = syllabus.method {
                        sectionViewInline(title: "授業形態", content: method)
                    }
                    
                    //単位数
                    if let credits = syllabus.credits {
                        sectionViewInline(title: "単位数", content: credits)
                    }
                    
                    if let period = syllabus.schedule {
                        sectionViewInline(title: "開講期間", content: period)
                    }
                }
                    
                Divider()
            
                Group{
                    
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
                    
                    //機能してる？
                    if let prep = syllabus.preparationReview {
                        sectionView(title: "事前・事後学修", content: prep)
                    }
                    
                    if let contact = syllabus.contact {
                        sectionView(title: "オフィスアワー・連絡先", content: contact)
                    }
                    if let message = syllabus.message {
                        sectionView(title: "学生へのメッセージ", content: message)
                    }
                    if let improv = syllabus.improvements {
                        sectionView(title: "今年度の工夫", content: improv)
                    }
                    
                    // ✅ ここ差し替え（元の joined してた箇所を削除して↓に）
                    if let textbooks = syllabus.textbooks, !textbooks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("教科書").font(.headline)
                            ForEach(textbooks) { book in
                                if let url = book.url {
                                    Link(destination: url) {
                                        Text(book.displayText)
                                            .font(.body)
                                    }
                                    //.tint(.blue)               // ✅ 青文字
                                    .foregroundStyle(.blue)
                                    .buttonStyle(.plain)       // （余計な装飾を消す）
                                } else {
                                    Text(book.displayText)
                                        .font(.body)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    if let references = syllabus.references {
                        sectionView(title: "参考書・参考資料等", content: references) // ← textbooks → references に修正
                    }
                    if let language = syllabus.language {
                        sectionView(title: "授業における使用言語", content: language)
                    }
                    if let keywords = syllabus.keywords {
                        sectionView(title: "キーワード", content: keywords)
                    }
                    
//                    if let url = syllabus.referenceURL {
//                        sectionView(title: "参考URL", content: url)
//                    }
                    
                    // ✅ 参考URL（URLとして有効なら青文字リンク）
                    if let urlStr = syllabus.referenceURL,
                       let url = URL(string: urlStr),
                       !urlStr.isEmpty {
                        sectionViewLink(title: "参考URL", label: urlStr, url: url)   // ✅ 新関数
                    } else if let urlStr = syllabus.referenceURL, !urlStr.isEmpty {
                        sectionView(title: "参考URL", content: urlStr)               // URLじゃなければ従来どおり
                    }
                }
            }
            .padding()
        }
        .onAppear { //確認
            print("📝 preparationReview:", syllabus.preparationReview as Any)
            print("📚 textbooks:", syllabus.textbooks as Any)
        }
        .navigationTitle("シラバス詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 一行表示用 ViewBuilder
    @ViewBuilder
    private func sectionViewInline(title: String, content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .lineLimit(1)                // 必要なら省略
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)
    }

      // MARK: - 従来の縦並び表示
      private func sectionView(title: String, content: String) -> some View {
          VStack(alignment: .leading, spacing: 6) {
              Text(title)
                  .font(.headline)
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

// ✅ タイトル＋青文字リンクの共通ビュー
@ViewBuilder
private func sectionViewLink(title: String, label: String, url: URL) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.headline)
        Link(label, destination: url)
            //.tint(.blue)                // 青文字
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
            .font(.body)
    }
    .padding(.bottom, 8)
}
