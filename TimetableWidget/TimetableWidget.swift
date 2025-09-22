//
//  TimetableWidget.swift
//  AssignmentTimetableWidget
//
//  端末の App Group(UserDefaults) にアプリ側が書き出した
//  「今日の時間割」(widgetTimetableToday) を読むだけ。
//  Firebase/Firestore には一切アクセスしない。
//  データ未保存時は空の表示を出す。
//

import WidgetKit
import SwiftUI

// MARK: - Keys (アプリと一致)
private enum WGKeys {
    static let appGroup  = "group.com.yuta.beefapp"
    static let storeKey  = "widgetTimetableToday"   // アプリ側 publishTodayToWidget と一致
    static let widgetKind = "TimetableWidgetKind"   // Widget の kind と一致
}

// MARK: - モデル（アプリ側の WidgetLecture/SharedLecture と互換）
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
        TimetableEntry(date: Date(), lectures: sample(), nextLecture: sample().first)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        // プレビュー時のみサンプル、実機スナップショットは実データ
        if context.isPreview {
            completion(TimetableEntry(date: Date(), lectures: sample(), nextLecture: sample().first))
            return
        }
        let lectures = loadLectures()
        completion(TimetableEntry(date: Date(), lectures: lectures, nextLecture: findNextLecture(from: lectures)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let lectures = loadLectures()
        let next = findNextLecture(from: lectures)
        let entry = TimetableEntry(date: Date(), lectures: lectures, nextLecture: next)

        // 次回更新タイミングを決める
        let refresh = nextRefreshDate(nextLecture: next)

        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    // MARK: - 読み込み

    private func loadLectures() -> [SharedLecture] {
        guard
            let ud = UserDefaults(suiteName: WGKeys.appGroup),
            let data = ud.data(forKey: WGKeys.storeKey),
            let lectures = try? JSONDecoder().decode([SharedLecture].self, from: data)
        else {
            // 実機では空配列。初回未設定で「空表示」とする
            return []
        }
        return lectures.sorted { $0.period < $1.period }
    }

    // MARK: - 次の授業探索 / 更新時刻決定

    private func findNextLecture(from list: [SharedLecture]) -> SharedLecture? {
        let now = Date()
        return list
            .sorted { $0.period < $1.period }
            .first { lec in
                if let s = Self.todayDate(lec.startTime) { return s > now }
                return false
            }
    }

    /// 次回更新は「次の授業開始+1分」or「0時」or フォールバック15分
    private func nextRefreshDate(nextLecture: SharedLecture?) -> Date {
        let now = Date()
        var candidates: [Date] = []

        if let n = nextLecture, let start = Self.todayDate(n.startTime) {
            if let afterStart = Calendar.current.date(byAdding: .minute, value: 1, to: start), afterStart > now {
                candidates.append(afterStart)
            }
        }
        // 深夜0:00（翌日）にも更新
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            candidates.append(midnight)
        }

        return candidates.min() ?? now.addingTimeInterval(60 * 15)
    }

    // MARK: - Utils

    static func todayDate(_ hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let d = cal.dateComponents([.year,.month,.day], from: Date())
        return cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: h, minute: m))
    }

    // プレビュー用サンプル
    private func sample() -> [SharedLecture] {
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
        .description("アプリが保存した“今日の時間割”を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium]) // Small/Medium対応
    }
}

// MARK: - Views

struct TimetableWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    var body: some View {
        Group {
            if entry.lectures.isEmpty {
                EmptyViewWidget()
            } else {
                switch family {
                case .systemSmall:
                    SmallView(entry: entry)
                default:
                    MediumView(entry: entry)
                }
            }
        }
        .containerBackground(.background, for: .widget)
        // ウィジェットタップでアプリを開く（任意のURLに変更OK）
        .widgetURL(URL(string: "beefapp://timetable"))
    }
}

// 空状態表示（初回まだ publish されていない場合）
private struct EmptyViewWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("時間割が未設定")
                .font(.headline)
            Text("アプリを開いて「時間割を更新」してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
    }
}

// Small：次の授業だけ
private struct SmallView: View {
    let entry: TimetableEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("次の授業").font(.caption).foregroundStyle(.secondary)
            if let n = entry.nextLecture {
                Text(n.title).font(.headline).lineLimit(2)
                HStack(spacing: 6) {
                    Label("P\(n.period)", systemImage: "clock").font(.caption2)
                    Text("\(n.startTime) - \(n.endTime)").font(.caption2)
                }
                if let room = n.room, !room.isEmpty {
                    Text(room).font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            } else {
                Text("本日の授業はありません").font(.footnote)
            }
            Spacer()
        }
        .padding(12)
    }
}

private struct MediumView: View {
    let entry: TimetableEntry
    private let periods = [1,2,3,4,5]

    // 色はコードハッシュで安定させる（色をペイロードに入れていないため）
    private let palette: [Color] = [
        Color(.systemBlue).opacity(0.15),
        Color(.systemGreen).opacity(0.15),
        Color(.systemOrange).opacity(0.15),
        Color(.systemPurple).opacity(0.15),
        Color(.systemPink).opacity(0.15)
    ]

    private func colorFor(_ lec: SharedLecture?) -> Color {
        guard let lec else { return Color(.secondarySystemBackground) }
        let h = abs(lec.code.hashValue)
        return palette[h % palette.count]
    }

    private func defaultTime(for period: Int) -> (start: String, end: String) {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(todayJP()).font(.headline)
                Spacer()
                if let n = entry.nextLecture {
                    Text("次: \(n.startTime)").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(periods, id: \.self) { p in
                    col(for: p)
                }
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func col(for period: Int) -> some View {
        let lec = entry.lectures.first { $0.period == period }
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(period)").font(.caption).bold()
                let t = lec != nil ? (lec!.startTime, lec!.endTime) : defaultTime(for: period)
                Text(t.0).font(.caption2).foregroundStyle(.secondary)
                Text(t.1).font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lec?.title ?? "")
                    .font(.caption).lineLimit(2)
                if let teacher = lec?.teacher, !teacher.isEmpty {
                    Text(teacher).font(.caption2).lineLimit(1)
                }
                if let room = lec?.room, !room.isEmpty {
                    Text(room).font(.caption2).lineLimit(1)
                }
            }
            .padding(8)
            .background(colorFor(lec), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func todayJP() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(EEE)"
        return f.string(from: Date())
    }
}
