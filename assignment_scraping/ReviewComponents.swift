//
//  ReviewComponents.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/27.
//

import SwiftUI

// 並び順
enum ReviewSort: String, CaseIterable, Identifiable {
    case high = "高評価"
    case low  = "低評価"
    case newest = "最新"
    var id: String { rawValue }
}

// 統計カード
struct ReviewStatsCard: View {
    @ObservedObject var viewModel: LectureDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("総合評価").fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    StarRatingView(score: Float(viewModel.averageRating), starSize: 14, spacing: 2)
                    Text(String(format: "%.1f", viewModel.averageRating))
                }
            }
            HStack {
                Text("楽単度").fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    StarRatingView(score: Float(viewModel.averageEasyScore), starSize: 14, spacing: 2)
                    Text(String(format: "%.1f", viewModel.averageEasyScore))
                }
            }
            HStack {
                Text("出欠確認").fontWeight(.semibold)
                Spacer()
                Text(topAttendanceLabel(counts: viewModel.attendanceFrequencyCounts))
                    .foregroundColor(.primary)
            }
        }
    }

    private func topAttendanceLabel(counts: [String: Int]) -> String {
        let options = ["毎回確認される", "ときどき確認される", "ほとんど確認されない", "出席確認なし"]
        let top = options.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        if let t = top, (counts[t] ?? 0) > 0 { return t }
        return "データがありません"
    }
}

// コメント1件表示
struct ReviewRow: View {
    let review: Review
    var lineLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Text("総合評価").font(.subheadline).foregroundColor(.secondary)
                StarRatingView(score: Float(review.rating), starSize: 12, spacing: 1)

                Spacer()

                Text("楽単度").font(.subheadline).foregroundColor(.secondary)
                StarRatingView(score: Float(review.easyScore), starSize: 12, spacing: 1)
            }

//            // 👍/👎 カウント表示（分かりやすくするならここで出す）
//            HStack(spacing: 10) {
//                Text("👍 \(review.upCount)")
//                Text("👎 \(review.downCount)")
//                Spacer()
//                Text("スコア \(review.helpfulScore)")
//                    .foregroundColor(.secondary)
//            }
//            .font(.caption)

            if !review.freeComment.isEmpty {
                Text(review.freeComment)
                    .font(.body)
                    .lineLimit(lineLimit)
                    .padding(.top, 2)
            }

            HStack {
                Text(review.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(studentYearFaculty(review.student_id))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func studentYearFaculty(_ id: String) -> String {
        guard id.count > 7 else { return "学籍番号エラー" }
        let yearPrefix = id.prefix(2)
        let i = id.index(id.startIndex, offsetBy: 7)
        let code = String(id[i])
        let map = [
            "l": "文学部","c": "国際文化学部","d": "発達科学部",
            "h": "国際人間科学部","j": "法学部","e": "経済学部",
            "b": "経営学部","s": "理学部","m": "医学部",
            "t": "工学部","a": "農学部","z": "海洋政策科学部"
        ]
        return "(20\(yearPrefix)年度入学・\(map[code] ?? "不明"))"
    }
}

// 長押しメニュー（共通）
extension View {
    func reviewContextMenu(
        review: Review,
        year: String,
        quarter: String,
        lectureCode: String,
        currentStudentID: String,
        viewModel: LectureDetailViewModel,
        onRequestDelete: @escaping () -> Void
    ) -> some View {
        self.contextMenu {
            Button("👍 高評価") {
                guard !currentStudentID.isEmpty else { return }
                Task {
                    await viewModel.voteReview(
                        year: year,
                        quarter: quarter,
                        lectureCode: lectureCode,
                        reviewId: review.id,
                        voterId: currentStudentID,
                        voteValue: 1
                    )
                    await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
                }
            }

            Button("👎 低評価") {
                guard !currentStudentID.isEmpty else { return }
                Task {
                    await viewModel.voteReview(
                        year: year,
                        quarter: quarter,
                        lectureCode: lectureCode,
                        reviewId: review.id,
                        voterId: currentStudentID,
                        voteValue: -1
                    )
                    await viewModel.fetchReviews(year: year, quarter: quarter, lectureCode: lectureCode)
                }
            }

            if review.student_id == currentStudentID {
                Divider()
                Button(role: .destructive) {
                    onRequestDelete() // ✅ アラート表示だけ
                } label: {
                    Text("削除する")
                }
            }
        }
    }
}
