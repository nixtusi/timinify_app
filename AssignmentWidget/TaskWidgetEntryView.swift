//
//  TaskWidgetEntryView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import SwiftUI
import WidgetKit

struct TaskWidgetEntryView: View {
    var entry: TaskTimelineProvider.Entry

    private func shortDate(from dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let date = formatter.date(from: dateStr) else { return "???" }

        let output = DateFormatter()
        output.dateFormat = "M/d HH:mm"
        return output.string(from: date)
    }

    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.date(from: str)
    }

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())

        let sortedTasks = entry.tasks.sorted {
            guard let date1 = dateFromString($0.deadline),
                  let date2 = dateFromString($1.deadline) else { return false }
            return date1 < date2
        }

        let nearestDate: Date? = sortedTasks
            .compactMap { dateFromString($0.deadline) }
            .first

        let leftTasks = sortedTasks.filter {
            guard let taskDate = dateFromString($0.deadline),
                  let targetDate = nearestDate else { return false }
            return Calendar.current.isDate(taskDate, inSameDayAs: targetDate)
        }

        let rightTasks = sortedTasks.filter {
            guard let taskDate = dateFromString($0.deadline),
                  let targetDate = nearestDate else { return false }
            return !Calendar.current.isDate(taskDate, inSameDayAs: targetDate)
        }

        let leftTitle: String = {
            if let date = nearestDate, Calendar.current.isDate(date, inSameDayAs: today) {
                return "今日"
            } else {
                return "次の提出"
            }
        }()

        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー：タイトルとロゴ
            HStack {
                Rectangle()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.60))
                    .frame(width: 4, height: 16)
                    .cornerRadius(2)

                Text("課題一覧")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.30, green: 0.78, blue: 0.60))
                
//                Text("更新 \(formattedTime(from: entry.date))")
//                    .font(.caption2)
//                    .foregroundColor(.gray)
                
                Text("更新 \(formattedTime(from: entry.lastUpdated ?? entry.date))")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Spacer()
                HStack(spacing: 4) {
                    Image("Unitime_wid")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("Uni Time")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }

            if sortedTasks.isEmpty {
                //課題が0件のとき
                Spacer()
                HStack {
                    Spacer()
                    Text("現在、課題はありません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else if rightTasks.isEmpty {
                //提出日が1日分だけのとき：Dividerなしで全体表示
                VStack(alignment: .leading, spacing: 6) {
                    Text(leftTitle)
                        .font(.caption2)
                        .foregroundColor(.gray)

                    ForEach(leftTasks.prefix(2)) { task in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .frame(maxHeight: 32)
                            Text(shortDate(from: task.deadline))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    let additionalCount = max(0, leftTasks.count - 2)
                    if additionalCount > 0 {
                        Text("その他 +\(additionalCount)件")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                }
            } else {
                // 通常：左右に分けて表示
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 0) //左余白確保
                    VStack(alignment: .leading, spacing: 6) {
                        Text(leftTitle)
                            .font(.caption2)
                            .foregroundColor(.gray)

                        ForEach(leftTasks.prefix(2)) { task in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .frame(maxHeight: 32)
                                Text(shortDate(from: task.deadline))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        let additionalCount = max(0, leftTasks.count - 2)
                        if additionalCount > 0 {
                            Text("その他 +\(additionalCount)件")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("それ以降")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        ForEach(rightTasks.prefix(2)) { task in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .frame(maxHeight: 32)
                                Text(shortDate(from: task.deadline))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        let additionalCount = max(0, rightTasks.count - 2)
                        if additionalCount > 0 {
                            Text("その他 +\(additionalCount)件")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0) //右余白確保
                }
            }
        }
        .padding()
        .ifAvailableiOS17 {
            $0.containerBackground(Color(.tertiarySystemBackground), for: .widget)
        }
    }
}

// iOS 17対応拡張
extension View {
    @ViewBuilder
    func ifAvailableiOS17<T: View>(_ transform: (Self) -> T) -> some View {
        if #available(iOS 17.0, *) {
            transform(self)
        } else {
            self
        }
    }
}

private func formattedTime(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return formatter.string(from: date)
}
