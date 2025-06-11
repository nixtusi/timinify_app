//
//  TimetableView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//

import SwiftUI

struct TimetableScreen: View {
    @StateObject private var fetcher = TimetableFetcher()

    let days = ["月", "火", "水", "木", "金"]
    let periods = [1, 2, 3, 4, 5]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                contentBody

//                Spacer(minLength: 0) // ⬅️ これでDividerを下に押しやる
//                Divider()            // ⬅️ これがタブバーのすぐ上にくる
//                    .frame(height: 0.5)
            }
        }
        .onAppear {
            fetcher.fetchTimetableFromAPI() // 🔁 @AppStorageはfetcher内に移動済み
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if fetcher.isLoading {
            ProgressView("読み込み中...")
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
        } else if let errorMessage = fetcher.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        } else {
            timetableGrid
        }
    }

    private var timetableGrid: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let timeColumnWidth: CGFloat = 35
            let columnWidth = (totalWidth - timeColumnWidth) / CGFloat(days.count)
            let rowHeight = (totalHeight - 40) * 2 / 13

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: timeColumnWidth, height: 40)
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.callout)
                            .bold()
                            .frame(width: columnWidth, height: 40)
                    }
                }

                ForEach(periods, id: \.self) { period in
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("\(period)")
                                .font(.callout)
                                .bold()
                            Text(timeForPeriod(period))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: timeColumnWidth, height: rowHeight)

                        ForEach(days, id: \.self) { day in
                            let course = fetcher.timetableItems.first {
                                $0.day == day && $0.period == period
                            }

                            ZStack {
                                if let course = course {
                                    VStack(spacing: 2) {
                                        Spacer(minLength: 4)
                                        Text(course.title)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                            .minimumScaleFactor(0.6)
                                        Spacer()
                                        Text(course.teacher)
                                            .font(.caption2)
                                        HStack {
                                            Text("room")
                                                .font(.caption2)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 3).fill(Color.white)
                                                )
                                                .padding(.horizontal, 2)
                                                .padding(.bottom, 3)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6).fill(Color.pink.opacity(0.18))
                                    )
                                }
                            }
                            .padding(1.7)
                            .frame(width: columnWidth, height: rowHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func timeForPeriod(_ period: Int) -> String {
        switch period {
        case 1: return "08:50\n10:20"
        case 2: return "10:40\n12:10"
        case 3: return "13:20\n14:50"
        case 4: return "15:10\n16:40"
        case 5: return "17:00\n18:30"
        default: return ""
        }
    }
}
