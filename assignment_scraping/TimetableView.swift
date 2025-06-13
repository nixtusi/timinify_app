//
//  TimetableView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//
//

import SwiftUI

struct TimetableView: View {
    @StateObject private var fetcher = TimetableFetcher()
    
    @State private var selectedYear = 2025
    @State private var selectedQuarter = 2
    
    private let days = ["月", "火", "水", "木", "金"]
    private let periods = [1, 2, 3, 4, 5]
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 2) {
                controlPanel
                contentBody
            }
        }
        .task {
            await fetcher.loadFromFirestore(year: selectedYear, quarter: selectedQuarter)
        }
        .onChange(of: selectedYear) { _ in
            Task {
                await fetcher.loadFromFirestore(year: selectedYear, quarter: selectedQuarter)
            }
        }
        .onChange(of: selectedQuarter) { _ in
            Task {
                await fetcher.loadFromFirestore(year: selectedYear, quarter: selectedQuarter)
            }
        }
    }
    
    private var controlPanel: some View {
        HStack {
            Picker("年度", selection: $selectedYear) {
                ForEach(2023...2026, id: \.self) { year in
                    Text("\(year)年度").tag(year)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Picker("クォーター", selection: $selectedQuarter) {
                ForEach(1...4, id: \.self) { q in
                    Text("\(q)Q").tag(q)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Spacer() //右に余白を押し出して左寄せに
        }
        .padding(.horizontal)            // 左右は維持
        .padding(.vertical, 4)           // ✅ 上下の余白を狭く（デフォルト16）
    }
    
    private var contentBody: some View {
        if fetcher.isLoading {
            AnyView(
                ProgressView("読み込み中…")
                    .padding()
            )
        } else if let error = fetcher.errorMessage {
            AnyView(
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            )
        } else {
            AnyView(
                timetableGrid
                //  .padding(.horizontal)
            )
        }
    }
    
    private var timetableGrid: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height

            let timeColW: CGFloat = 35
            let headerH: CGFloat = 40
            let verticalPadding: CGFloat = 44
            let horizontalMargin: CGFloat = 15 // ✅ 右側に追加したい余白

            let colW = (totalW - timeColW - horizontalMargin) / CGFloat(days.count)
            let rowH = (totalH - headerH - verticalPadding) / CGFloat(periods.count)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: timeColW, height: headerH)
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.callout).bold()
                            .frame(width: colW, height: headerH)
                    }
                }

                ForEach(periods, id: \.self) { period in
                    HStack(spacing: 0) {
                        PeriodTimeLabel(period: period)
                            .frame(width: timeColW, height: rowH)

                        ForEach(days, id: \.self) { day in
                            let course = fetcher.timetableItems.first {
                                $0.day == day && $0.period == period && $0.quarter == selectedQuarter
                            }
                            TimetableCell(course: course)
                                .frame(width: colW, height: rowH)
                                .padding(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading) // ✅ 左寄せ
            .padding(.trailing, horizontalMargin) // ✅ 右に余白を加える
        }
    }
    
    struct PeriodTimeLabel: View {
        let period: Int
        
        var body: some View {
            VStack(spacing: 2) {
                Text("\(period)").bold()
                Text(timeForPeriod(period))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        
        private func timeForPeriod(_ p: Int) -> String {
            switch p {
            case 1: return "08:50\n10:20"
            case 2: return "10:40\n12:10"
            case 3: return "13:20\n14:50"
            case 4: return "15:10\n16:40"
            case 5: return "17:00\n18:30"
            default: return ""
            }
        }
    }
    
    struct TimetableCell: View {
        let course: TimetableItem?
        
        var body: some View {
            ZStack {
                if let c = course {
                    VStack(spacing: 2) {
                        Spacer(minLength: 4)
                        
                        Text(c.title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                        
                        Spacer()
                        
                        Text(c.teacher)
                            .font(.caption2)
                        
                        Text(c.room ?? "")
                            .font(.caption2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white)
                            )
                            .padding(.horizontal, 1.7)
                            .padding(.bottom, 2.1)
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.pink.opacity(0.18))
                    )
                } else {
                    // ✅ 空のセルにも枠線表示
                    Color.clear
                }
            }
            .padding(1.7)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
