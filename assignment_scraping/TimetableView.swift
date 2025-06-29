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
    
    @State private var selectedCourse: TimetableItem?
    @State private var selectedDay: String = ""
    @State private var selectedPeriod: Int = 0
    
    private let days = ["月", "火", "水", "木", "金"]
    private let periods = [1, 2, 3, 4, 5]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 2) {
                controlPanel
                contentBody
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(item: $selectedCourse) { course in
                LectureDetailView(
                    lectureCode: course.code,
                    dayPeriod: "\(course.day)\(course.period)",
                    year: String(selectedYear),
                    quarter: "Q\(selectedQuarter)"
                )
            }
            .navigationTitle("時間割")
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
    }
    
    private var controlPanel: some View {
        HStack {
            // 年度ピッカー
            Picker(selection: $selectedYear, label:
                Text("\(String(selectedYear))年度")
                    .font(.body.weight(.bold))
                    .foregroundColor(.gray)
            ) {
                ForEach(2023...2026, id: \.self) { year in
                    Text("\(String(year))年度").tag(year)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .tint(.gray)

            // クォーターピッカー
            Picker(selection: $selectedQuarter, label:
                Text("\(selectedQuarter)Q")
                    .font(.body.weight(.bold))
                    .foregroundColor(.gray)
            ) {
                ForEach(1...4, id: \.self) { q in
                    Text("\(q)Q").tag(q)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .tint(.gray)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var contentBody: some View {
//        if fetcher.isLoading {
//            AnyView(
//                ProgressView("読み込み中…")
//                    .padding()
//            )
//        } else if let error = fetcher.errorMessage {
//            AnyView(
//                Text(error)
//                    .foregroundColor(.red)
//                    .multilineTextAlignment(.center)
//                    .padding()
//            )
//        } else {
//            AnyView(
//                timetableGrid
//                //  .padding(.horizontal)
//            )
//        }
        
        timetableGrid
    }
    
    private var timetableGrid: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height

            let timeColW: CGFloat = 35
            let headerH: CGFloat = 40
            let verticalPadding: CGFloat = 44

            let spacingPerSide: CGFloat = 2.0
            let fridayTrailing: CGFloat = 6.0

            // ✅ spacing: 各タイルの左右 (2px×2) × 5日 + 金曜追加px
            let totalColSpacing = spacingPerSide * 2 * CGFloat(days.count) + (fridayTrailing - spacingPerSide)
            let colW = (totalW - timeColW - totalColSpacing) / CGFloat(days.count)

            let rowSpacing = spacingPerSide * 2
            let totalRowSpacing = rowSpacing * CGFloat(periods.count - 1)
            let rowH = (totalH - headerH - verticalPadding - totalRowSpacing) / CGFloat(periods.count)

            let todayWeekdaySymbol = weekdaySymbolFromToday()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: timeColW, height: headerH)
                    
                    ForEach(days, id: \.self) { day in
                        let isFriday = day == days.last

                        VStack {
                            Spacer()
                            ZStack {
                                if day == todayWeekdaySymbol {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 26, height: 26)
                                    Text(day)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                } else {
                                    Text(day)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: colW, height: headerH)
                        .padding(.leading, spacingPerSide)
                        .padding(.trailing, isFriday ? fridayTrailing : spacingPerSide) // ✅ タイルと同じようにパディング調整
                    }
                }

                ForEach(periods, id: \.self) { period in
                    HStack(spacing: 0) {
                        PeriodTimeLabel(period: period)
                            .frame(width: timeColW, height: rowH)

                        ForEach(days, id: \.self) { day in
                            let isFriday = day == days.last
                            let course = fetcher.timetableItems.first {
                                $0.day == day && $0.period == period && $0.quarter == selectedQuarter
                            }

                            TimetableCell(course: course)
                                .frame(width: colW, height: rowH)
                                .padding(.vertical, spacingPerSide)
                                .padding(.leading, spacingPerSide)
                                .padding(.trailing, isFriday ? fridayTrailing : spacingPerSide) // ✅ 金曜のみ4px
                                .onTapGesture { //時間割詳細画面へ移動
                                    if let c = course {
                                        selectedCourse = c
                                        selectedDay = day
                                        selectedPeriod = period
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        var isLoading: Bool = false
        
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
                            //.foregroundColor(.black)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    //.fill(Color.white)
                                    .fill(Color(UIColor.systemBackground))
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
            //.padding(1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    //.stroke(Color.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    /// 今日の曜日（"月", "火", …）を返す
    private func weekdaySymbolFromToday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        let weekdaySymbols = formatter.shortWeekdaySymbols! // ["日", "月", "火", …]

        let weekday = Calendar.current.component(.weekday, from: Date())
        // .weekday は 1(日)〜7(土) → 月=2
        return weekdaySymbols[weekday - 1]
    }
}


