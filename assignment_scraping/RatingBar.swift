//
//  RatingBar.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/02.
//

import SwiftUI

public struct RatingBar: View {
    private let reviewRating: Float?
    private let spacing: CGFloat?
    private let size: CGFloat?

    private let starImage: Image = Image(systemName: "star")
    private let fillStarImage: Image = Image(systemName: "star.fill")

    public init(
        reviewRating: Float?,
        spacing: CGFloat? = 2,
        size: CGFloat? = 6
    ) {
        self.reviewRating = reviewRating
        self.spacing = spacing
        self.size = size
    }

    @ViewBuilder
    public var body: some View {
        HStack(spacing: self.spacing) {
            if let reviewRating {
                ForEach(Array(0..<5), id: \.self) { index in
                    ZStack {
                        if index < Int(reviewRating) {
                            fillStar
                        } else if index == Int(reviewRating) {
                            lackedStar(reviewRating: reviewRating)
                        } else {
                            star
                        }
                    }
                }
            }
        }
    }

    var fillStar: some View {
        ratingIcon(image: fillStarImage)
    }

    var star: some View {
        ratingIcon(image: starImage)
    }

    func lackedStar(reviewRating: Float) -> some View {
        ratingIcon(image: starImage)
            .overlay(
                Rectangle()
                    .foregroundColor(.orange)
                    .mask(
                        ratingIcon(image: fillStarImage)
                    )
                    .clipShape(
                        RatingShape(rate: CGFloat(roundedDecimal(reviewRating: reviewRating)))
                    )
            )
    }

    func ratingIcon(image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: self.size, height: size)
            .foregroundColor(.orange)
    }

    func roundedDecimal(reviewRating: Float) -> Float {
        let rateDecimal = reviewRating.truncatingRemainder(dividingBy: 1)
        return round(rateDecimal * 10) / 10
    }

    struct RatingShape: Shape {
        var rate: CGFloat
        func path(in rect: CGRect) -> Path {
            return Rectangle().path(in: rect.divided(atDistance: rect.width * rate, from: .minXEdge).slice)
        }
    }
}
