//
//  TimetableWidget.swift
//  AssignmentTimetableWidget
//
//  ✅ 変更: App Groupの共有UserDefaultsから読み込んで描画（Firebaseアクセスなし）
//

import WidgetKit
import SwiftUI

private extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self = Color(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// ✅ 変更: アプリ側のキーと一致させる
private enum WGKeys {
    static let appGroup = "group.com.yuta.beefapp"   // あなたのApp Group ID
    static let storeKey = "widgetTimetableToday"
    static let widgetKind = "TimetableWidgetKind"    // Widget.swiftのkindと一致させる
}

// ✅ 変更: 共有モデル（アプリ側と同じ定義に合わせる）
struct SharedLecture: Codable, Identifiable {
    var id: String { code + String(period) }
    let code: String
    let title: String
    let room: String?
    let teacher: String?
    let period: Int
    let startTime: String
    let endTime: String
}

// MARK: - Provider

struct TimetableProvider: TimelineProvider {

    func placeholder(in context: Context) -> TimetableEntry {
        TimetableEntry(date: Date(), lectures: Self.sample(), nextLecture: Self.sample().first)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        completion(TimetableEntry(date: Date(), lectures: loadLectures(), nextLecture: findNextLecture()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let lectures = loadLectures()
        let next = findNextLecture(from: lectures)
        let entry = TimetableEntry(date: Date(), lectures: lectures, nextLecture: next)

        // ✅ 変更: 次の授業開始の1分後 or 15分後で更新
        let refresh: Date = {
            if let n = next, let d = Self.todayDate(n.startTime) {
                return Calendar.current.date(byAdding: .minute, value: 1, to: d) ?? Date().addingTimeInterval(60*15)
            }
            return Date().addingTimeInterval(60 * 15)
        }()

        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    // MARK: - 読み込み

    private func loadLectures() -> [SharedLecture] {
        guard
            let ud = UserDefaults(suiteName: WGKeys.appGroup),
            let data = ud.data(forKey: WGKeys.storeKey),
            let lectures = try? JSONDecoder().decode([SharedLecture].self, from: data)
        else { return Self.sample() }
        return lectures.sorted { $0.period < $1.period }
    }

    private func findNextLecture(from list: [SharedLecture]? = nil) -> SharedLecture? {
        let lectures = list ?? loadLectures()
        let now = Date()
        for lec in lectures.sorted(by: { $0.period < $1.period }) {
            if let start = Self.todayDate(lec.startTime), start > now {
                return lec
            }
        }
        return nil
    }

    // MARK: - Utils

    static func todayDate(_ hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = Date()
        let d = cal.dateComponents([.year,.month,.day], from: now)
        return cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: h, minute: m))
    }

    static func sample() -> [SharedLecture] {
        [
            SharedLecture(code: "1G004", title: "線形代数A", room: "E201", teacher: "桔梗", period: 1, startTime: "08:50", endTime: "10:20"),
            SharedLecture(code: "1B453", title: "プログラミング基礎", room: "情報実習室", teacher: "井上", period: 2, startTime: "10:40", endTime: "12:10"),
            SharedLecture(code: "1X006", title: "アルゴリズム演習", room: "I302", teacher: "山本", period: 3, startTime: "13:10", endTime: "14:40"),
            SharedLecture(code: "1T303", title: "確率統計", room: "S105", teacher: "佐藤", period: 4, startTime: "15:10", endTime: "16:40"),
            SharedLecture(code: "1A101", title: "英語コミュニケーション", room: "L2", teacher: "Smith", period: 5, startTime: "17:00", endTime: "18:30")
        ]
    }
}

// MARK: - Entry

struct TimetableEntry: TimelineEntry {
    let date: Date
    let lectures: [SharedLecture]
    let nextLecture: SharedLecture?
}

// MARK: - Widget

struct TimetableWidget: Widget {
    let kind: String = WGKeys.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableProvider()) { entry in
            TimetableWidgetView(entry: entry)
        }
        .configurationDisplayName("時間割")
        .description("デバイスに保存された“今日の時間割”を表示します。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Views

struct TimetableWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    var body: some View {
        MediumView(entry: entry)
            .containerBackground(Color.white, for: .widget)
    }
}

private struct MediumView: View {
    let entry: TimetableEntry
    private let periods = [1,2,3,4,5]

    private let palette: [Color] = [
        Color(hex: "#E6F3FF"), // blue
        Color(hex: "#EAF7E6"), // green
        Color(hex: "#FFF6E6"), // orange
        Color(hex: "#F3E6FF"), // purple
        Color(hex: "#FFE6EC")  // pink
    ]

    private func colorFor(_ lec: SharedLecture?) -> Color {
        guard let lec else { return Color(.secondarySystemBackground) }
        // Hash by code to keep stable per class
        let h = abs(lec.code.hashValue)
        return palette[h % palette.count]
    }

    private func defaultTime(for period: Int) -> (start: String, end: String) {
        // 神大の一般的なコマ（例）
        switch period {
        case 1: return ("08:50", "10:20")
        case 2: return ("10:40", "12:10")
        case 3: return ("13:10", "14:40")
        case 4: return ("15:10", "16:40")
        case 5: return ("17:00", "18:30")
        default: return ("", "")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(periods, id: \.self) { p in
                col(for: p)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func col(for period: Int) -> some View {
        let lec = entry.lectures.first { $0.period == period }
        VStack(alignment: .leading, spacing: 6) {
            // Top: period + times
            VStack(alignment: .leading, spacing: 2) {
                Text("\(period)")
                    .font(.caption).bold()
                let t = lec != nil ? (lec!.startTime, lec!.endTime) : defaultTime(for: period)
                Text(t.0)
                    .font(.caption2).foregroundStyle(.secondary)
                Text(t.1)
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // Block: timetable-like box
            VStack(alignment: .leading, spacing: 4) {
                Text(lec?.title ?? "")
                    .font(.caption).lineLimit(2)
                Text(lec?.teacher ?? "")
                    .font(.caption2).lineLimit(1)
                Text(lec?.room ?? "")
                    .font(.caption2).lineLimit(1)
            }
            .padding(8)
            .background(
                colorFor(lec), in: RoundedRectangle(cornerRadius: 8)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
