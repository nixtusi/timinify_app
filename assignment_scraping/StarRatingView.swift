//
//  StarRatingView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/02.
//

import SwiftUI

struct StarRatingView: View {
    //let title: String           // 例: "総合評価"
    let score: Float            // 例: 4.3
    let starSize: CGFloat       // 星のサイズ
    let spacing: CGFloat        // 星間のスペース

    var body: some View {
        HStack {
            HStack(spacing: spacing) {
                RatingBar(reviewRating: score, spacing: spacing, size: starSize)
            }
        }
    }
}
