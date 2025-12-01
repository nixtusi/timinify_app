//
//  SyllabusDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/30.
//

import SwiftUI

struct SyllabusDetailView: View {
    let syllabus: Syllabus
    // ✅ 追加: 曜日と時限を受け取る
    let day: String
    let period: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 20) { // セクション間のスペースを広めに
                
                // MARK: - 基本情報セクション
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
                        
                        if let credits = syllabus.credits {
                            sectionViewInline(title: "単位数", content: credits)
                        }
                        
                        if let period = syllabus.schedule {
                            sectionViewInline(title: "開講期間", content: period)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground)) // カード風背景
                .cornerRadius(12)
                
                // MARK: - 授業概要セクション
                VStack(alignment: .leading, spacing: 16) {
                    if let theme = syllabus.theme {
                        sectionView(title: "授業のテーマ", content: theme)
                    }
                    if let goals = syllabus.goals {
                        sectionView(title: "授業の到達目標", content: goals)
                    }
                    if let summary = syllabus.summary {
                        sectionView(title: "授業の概要と計画", content: summary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // MARK: - 評価・履修情報セクション
                VStack(alignment: .leading, spacing: 16) {
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
                        sectionView(title: "事前・事後学修", content: prep)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // MARK: - その他セクション
                VStack(alignment: .leading, spacing: 16) {
                    if let contact = syllabus.contact {
                        sectionView(title: "オフィスアワー・連絡先", content: contact)
                    }
                    if let message = syllabus.message {
                        sectionView(title: "学生へのメッセージ", content: message)
                    }
                    if let improv = syllabus.improvements {
                        sectionView(title: "今年度の工夫", content: improv)
                    }
                    
                    if let textbooks = syllabus.textbooks, !textbooks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("教科書")
                                .font(.headline)
                                .foregroundColor(.primary)
                            ForEach(textbooks) { book in
                                if let url = book.url {
                                    Link(destination: url) {
                                        Text(book.displayText)
                                            .font(.body)
                                            .underline()
                                    }
                                    .foregroundStyle(.blue)
                                    .buttonStyle(.plain)
                                } else {
                                    Text(book.displayText)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    if let references = syllabus.references {
                        sectionView(title: "参考書・参考資料等", content: references)
                    }
                    if let language = syllabus.language {
                        sectionView(title: "授業における使用言語", content: language)
                    }
                    if let keywords = syllabus.keywords {
                        sectionView(title: "キーワード", content: keywords)
                    }
                    
                    if let urlStr = syllabus.referenceURL,
                       let url = URL(string: urlStr),
                       !urlStr.isEmpty {
                        sectionViewLink(title: "参考URL", label: urlStr, url: url)
                    } else if let urlStr = syllabus.referenceURL, !urlStr.isEmpty {
                        sectionView(title: "参考URL", content: urlStr)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding() // 全体の余白
        }
        .background(Color(.systemGroupedBackground)) // 全体の背景色
        // ✅ 変更: 検索から("ー")の場合は「シラバス」、それ以外は「曜日 時限」を表示
        .navigationTitle(day == "ー" ? "シラバス" : "\(day)曜 \(period)限")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 一行表示用 ViewBuilder
    @ViewBuilder
    private func sectionViewInline(title: String, content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary) // ラベルは少し薄く
                .frame(width: 120, alignment: .leading) // 幅を固定して整列
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 従来の縦並び表示
    @ViewBuilder
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(content)
                .font(.body)
                .foregroundColor(.primary) // 本文は濃い色で
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 8) // 少しインデント
                .padding(.top, 2)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - リンク付き表示
    @ViewBuilder
    private func sectionViewLink(title: String, label: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Link(label, destination: url)
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
                .font(.body)
                .padding(.leading, 8)
        }
        .padding(.bottom, 8)
    }
}
