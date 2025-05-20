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

        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(leftTitle)
                    .font(.caption2)
                    .foregroundColor(.gray)

                ForEach(leftTasks.prefix(2)) { task in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                        Text(shortDate(from: task.deadline))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
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
                        Text(shortDate(from: task.deadline))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
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
