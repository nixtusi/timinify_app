//
//  ReviewDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/09.
//

import SwiftUI

struct ReviewDetailView: View {
    let review: Review
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ReviewRow(review: review, lineLimit: nil) // 全文表示
            }
            .padding()
        }
        .navigationTitle("口コミ詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
