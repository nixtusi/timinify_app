//
//  ReviewsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/09.
//

import SwiftUI

struct ReviewsView: View {
    @ObservedObject var viewModel: LectureDetailViewModel
    let year: String
    let quarter: String      // 例: "2"（Q除去済み）
    let lectureCode: String
    let currentStudentID: String

    @State private var showPostSheet = false
    @State private var expanded: Set<String> = []   // 展開中のレビューID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 上：統計カード（タップなし）
                ReviewStatsCard(viewModel: viewModel)

                // 口コミを追加
                if !currentStudentID.isEmpty,
                   !viewModel.reviews.contains(where: { $0.student_id == currentStudentID }) {
                    Button {
                        showPostSheet = true
                    } label: {
                        VStack(alignment: .center, spacing: 6) {
                            Image(systemName: "square.and.pencil")
                            Text("口コミを追加").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .sheet(isPresented: $showPostSheet, onDismiss: {
                        Task { await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode) }
                    }) {
                        ReviewPostView(year: year, quarter: quarter, lectureCode: lectureCode)
                    }
                }

                // 全自由記述コメント（折りたたみ/展開）
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.reviews.filter { !$0.freeComment.isEmpty }) { review in
                        let isExpanded = expanded.contains(review.id)
                        ReviewRow(review: review, lineLimit: isExpanded ? nil : 3)
                            .contentShape(Rectangle()) // タップしやすく
                            .onTapGesture {
                                if isExpanded { expanded.remove(review.id) }
                                else { expanded.insert(review.id) }
                            }
                            .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("口コミ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 必要なら一覧画面で再取得
            await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
        }
    }
}
