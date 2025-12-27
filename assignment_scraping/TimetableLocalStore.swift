//
//  TimetableLocalStore.swift
//  assignment_scraping
//
//  目的:
//   - 年度+クォーターごとにローカルへ保存された時間割を読み出す
//   - 今日の時間割を App Group 経由でウィジェットへ連携する
//  注意: Firebase/Firestore へは一切アクセスしません。
//  作成日: 2025/09/22
//

import Foundation
import WidgetKit

@MainActor
final class TimetableLocalStore: ObservableObject {

    // TimetableItem は TimetableFetcher.swift の既存定義を利用（再定義しない）
    @Published var items: [TimetableItem] = []
    @Published var errorMessage: String?

    // ローカル保存キー（TimetableFetcher と揃える）
    private func localKey(year: Int, quarter: Int) -> String {
        "cachedTimetableItems"
    }

    // App Group（Widget共有）
    private enum WGKeys {
        static let appGroup  = "group.com.yuta.beefapp"   // ← あなたの App Group ID
        static let storeKey  = "widgetTimetableToday"
        static let widgetKind = "TimetableWidgetKind"   // ← Widget 側の kind と一致させる
    }

    // ウィジェットへ渡す軽量ペイロード（Widget 側の SharedLecture と互換）
    private struct WidgetLecture: Codable, Identifiable {
        var id: String { code + String(period) }
        let code: String
        let title: String
        let room: String?
        let teacher: String?
        let period: Int
        let startTime: String
        let endTime: String
        let colorHex: String?
    }

    // MARK: - 公開API

    /// 指定の 年度+Q でローカル保存された時間割を読み込み、`items` に反映
    func loadFromLocal(year: Int, quarter: Int) {
        errorMessage = nil
        let key = localKey(year: year, quarter: quarter)

        guard let data = UserDefaults.standard.data(forKey: key) else {
            self.items = []
            self.errorMessage = "ローカルの時間割が見つかりません"
            print("⚠️ ローカルデータなし (\(key))")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([TimetableItem].self, from: data)
            self.items = decoded
            print("✅ ローカル読込 (\(year) Q\(quarter)): \(decoded.count)件")
        } catch {
            self.items = []
            self.errorMessage = "ローカルデータの読み込みに失敗しました。"
            print("❌ デコード失敗: \(error.localizedDescription)")
        }
    }

    /// 今日の時間割（曜日一致かつ period 昇順）
    func todaysLectures() -> [TimetableItem] {
        let today = Self.weekdayJP(Date())
        return items
            .filter { $0.day == today }
            .sorted { $0.period < $1.period }
    }

    /// いま `items` に載っているデータを元に、ウィジェットへ「今日の時間割」を公開
    func publishTodayToWidget() {
        let todays = todaysLectures()
        let payload: [WidgetLecture] = todays.map {
            WidgetLecture(
                code: $0.code,
                title: $0.title,
                room: $0.room,
                teacher: $0.teacher,
                period: $0.period,
                startTime: Self.periodToStart($0.period),
                endTime: Self.periodToEnd($0.period),
                colorHex: $0.color
            )
        }

        guard
            let data = try? JSONEncoder().encode(payload),
            let ud = UserDefaults(suiteName: WGKeys.appGroup)
        else {
            print("❌ App Group への保存に失敗（suiteNameや権限を確認）")
            return
        }

        ud.set(data, forKey: WGKeys.storeKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WGKeys.widgetKind)
        print("📤 Widgetへ今日の時間割を公開: \(payload.count)件")
    }

    /// まとめて: ローカル（指定の 年度+Q）→読込→ウィジェット公開
    func syncWidgetFromLocal(year: Int, quarter: Int) {
        loadFromLocal(year: year, quarter: quarter)
        publishTodayToWidget()
    }

    // MARK: - ユーティリティ

    private static func weekdayJP(_ date: Date) -> String {
        let w = Calendar.current.component(.weekday, from: date) // 1(日)〜7(土)
        switch w {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        default: return "土"
        }
    }

    /// 時限→開始時刻（アプリ表示に合わせる）
    private static func periodToStart(_ p: Int) -> String {
        switch p {
        case 1: return "08:50"
        case 2: return "10:40"
        case 3: return "13:20"
        case 4: return "15:10"
        case 5: return "17:00"
        default: return "00:00"
        }
    }

    /// 時限→終了時刻（アプリ表示に合わせる）
    private static func periodToEnd(_ p: Int) -> String {
        switch p {
        case 1: return "10:20"
        case 2: return "12:10"
        case 3: return "14:50"
        case 4: return "16:40"
        case 5: return "18:30"
        default: return "00:00"
        }
    }
}
