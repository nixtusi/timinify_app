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
    @State private var sort: ReviewSort = .high

    @State private var deleteTarget: Review? = nil
    @State private var showDeleteAlert = false

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

                // 並び順
                VStack(alignment: .leading, spacing: 8) {
                    Text("並び順")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("並び順", selection: $sort) {
                        ForEach(ReviewSort.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                

                // 全自由記述コメント（折りたたみ/展開）
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.sortedReviews(sort).filter { !$0.freeComment.isEmpty }) { review in
                        NavigationLink {
                            ReviewDetailView(
                                viewModel: viewModel,
                                year: year,
                                quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                                lectureCode: lectureCode,
                                currentStudentID: currentStudentID,
                                review: review
                            )
                        } label: {
                            ReviewRow(review: review, lineLimit: 3)
                                .reviewContextMenu(
                                    review: review,
                                    year: year,
                                    quarter: quarter,
                                    lectureCode: lectureCode,
                                    currentStudentID: currentStudentID,
                                    viewModel: viewModel,
                                    onRequestDelete: {
                                        deleteTarget = review
                                        showDeleteAlert = true
                                    }
                                )
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("口コミ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
        }
        .alert("口コミを削除しますか？",
               isPresented: $showDeleteAlert,
               presenting: deleteTarget) { target in
            Button("削除", role: .destructive) {
                Task {
                    await viewModel.deleteReview(
                        year: year,
                        quarter: quarter,
                        lectureCode: lectureCode,
                        reviewId: target.id
                    )
                    // 削除後に最新化したいならここで再取得（任意）
                    await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
                }
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { _ in
            Text("この操作は取り消せません。")
        }
    }
}
