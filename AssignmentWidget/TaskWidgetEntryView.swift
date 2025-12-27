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
    @Environment(\.widgetFamily) private var family

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

    private func urgencyColor(for deadline: String, now: Date) -> Color {
        guard let date = dateFromString(deadline) else { return .green }
        let diff = date.timeIntervalSince(now)
        if diff < 24 * 60 * 60 {
            return .red
        } else if diff < 3 * 24 * 60 * 60 {
            return .yellow
        } else {
            return .green
        }
    }

    private var sortedTasks: [SharedTask] {
        entry.tasks.sorted {
            guard let date1 = dateFromString($0.deadline),
                  let date2 = dateFromString($1.deadline) else { return false }
            return date1 < date2
        }
    }

    private var nearestDate: Date? {
        sortedTasks
            .compactMap { dateFromString($0.deadline) }
            .first
    }

    private var leftTasks: [SharedTask] {
        guard let targetDate = nearestDate else { return [] }
        return sortedTasks.filter {
            guard let taskDate = dateFromString($0.deadline) else { return false }
            return Calendar.current.isDate(taskDate, inSameDayAs: targetDate)
        }
    }

    private var rightTasks: [SharedTask] {
        guard let targetDate = nearestDate else { return [] }
        return sortedTasks.filter {
            guard let taskDate = dateFromString($0.deadline) else { return false }
            return !Calendar.current.isDate(taskDate, inSameDayAs: targetDate)
        }
    }

    private var leftTitle: String {
        let today = Calendar.current.startOfDay(for: Date())
        if let date = nearestDate, Calendar.current.isDate(date, inSameDayAs: today) {
            return "今日"
        }
        return "次の提出"
    }

    private func deadlineLabel(from deadline: String, now: Date) -> String {
        guard let date = dateFromString(deadline) else { return "??" }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "今日 \(timeOnly(from: date))"
        }
        if cal.isDateInTomorrow(date) {
            return "明日 \(timeOnly(from: date))"
        }
        let output = DateFormatter()
        output.locale = Locale(identifier: "ja_JP")
        output.dateFormat = "M/d(EEE)"
        return output.string(from: date)
    }

    private func timeOnly(from date: Date) -> String {
        let output = DateFormatter()
        output.dateFormat = "H:mm"
        output.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return output.string(from: date)
    }

    var body: some View {
        content
            .padding()
            .ifAvailableiOS17 {
                $0.containerBackground(Color(.tertiarySystemBackground), for: .widget)
            }
            .widgetURL(taskListURL)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            smallContent
        case .systemLarge:
            largeContent
        default:
            mediumContent
        }
    }

    private var header: some View {
        HStack {
            Rectangle()
                .fill(Color(red: 0.30, green: 0.78, blue: 0.60))
                .frame(width: 4, height: 16)
                .cornerRadius(2)

            Text("課題一覧")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.30, green: 0.78, blue: 0.60))

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
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("更新 \(formattedTime(from: entry.lastUpdated ?? entry.date))")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            if sortedTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("現在、課題はありません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(leftTitle)
                        .font(.caption2)
                        .foregroundColor(.gray)

                    ForEach(sortedTasks.prefix(2)) { task in
                        taskRow(task, lineLimit: 1, titleMaxHeight: nil)
                    }

                    let additionalCount = max(0, sortedTasks.count - 2)
                    if additionalCount > 0 {
                        Text("その他 +\(additionalCount)件")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

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
                        taskRow(task, lineLimit: 2, titleMaxHeight: 32)
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
                            taskRow(task, lineLimit: 2, titleMaxHeight: 32)
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
                            taskRow(task, lineLimit: 2, titleMaxHeight: 32)
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
    }

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最終更新: \(formattedTime(from: entry.lastUpdated ?? entry.date))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("課題一覧")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("次の提出期限まで")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let next = sortedTasks.first {
                        let badgeColor = urgencyColor(for: next.deadline, now: entry.date)
                        Text(deadlineLabel(from: next.deadline, now: entry.date))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(badgeColor.opacity(0.15), in: Capsule())
                    }
                }
            }

            if sortedTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("現在、課題はありません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedTasks.prefix(4)) { task in
                        largeTaskRow(task)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: SharedTask, lineLimit: Int, titleMaxHeight: CGFloat?) -> some View {
        let color = urgencyColor(for: task.deadline, now: entry.date)

        taskLink(task) {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    if let titleMaxHeight {
                        Text(task.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(lineLimit)
                            .truncationMode(.tail)
                            .frame(maxHeight: titleMaxHeight)
                    } else {
                        Text(task.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(lineLimit)
                            .truncationMode(.tail)
                    }

                    Text(shortDate(from: task.deadline))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func largeTaskRow(_ task: SharedTask) -> some View {
        let color = urgencyColor(for: task.deadline, now: entry.date)
        return taskLink(task) {
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    if let course = task.course, !course.isEmpty {
                        Text(course)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Text(deadlineLabel(from: task.deadline, now: entry.date))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            .padding(10)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var taskListURL: URL? {
        URL(string: "beefapp://task")
    }

    private func taskDeepLinkURL(for task: SharedTask) -> URL? {
        var components = URLComponents()
        components.scheme = "beefapp"
        components.host = "task"
        components.queryItems = [URLQueryItem(name: "url", value: task.url)]
        return components.url
    }

    @ViewBuilder
    private func taskLink<Content: View>(_ task: SharedTask, @ViewBuilder content: () -> Content) -> some View {
        if let url = taskDeepLinkURL(for: task) {
            Link(destination: url) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
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
