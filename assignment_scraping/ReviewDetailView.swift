//
//  ReviewDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/09.
//

import SwiftUI

struct ReviewDetailView: View {
    @ObservedObject var viewModel: LectureDetailViewModel
    let year: String
    let quarter: String
    let lectureCode: String
    let currentStudentID: String
    let review: Review

    @State private var deleteTarget: Review? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ReviewRow(review: review, lineLimit: nil)
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
            .padding()
        }
        .navigationTitle("口コミ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .alert("口コミを削除しますか？",
               isPresented: $showDeleteAlert,
               presenting: deleteTarget) { target in
            Button("削除", role: .destructive) {
                Task {
                    await viewModel.deleteReview(year: year, quarter: quarter, lectureCode: lectureCode, reviewId: target.id)
                    await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
                }
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) { deleteTarget = nil }
        } message: { _ in
            Text("この操作は取り消せません。")
        }
    }
}
