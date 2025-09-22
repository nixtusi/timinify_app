//
//  TimetableLocalStore.swift
//  assignment_scraping
//
//  目的: TimetableFetcher が UserDefaults("cachedTimetableItems") に保存済みの
//       ローカル時間割を読み出して表示に供し、必要に応じてウィジェットへ連携する。
//  注意: Firebase/Firestore へは一切アクセスしません。
//  作成日: 2025/09/22
//

import Foundation
import WidgetKit

@MainActor
final class TimetableLocalStore: ObservableObject {

    // ✅ 変更: TimetableItem は TimetableFetcher.swift の既存定義を使用（このファイルでは再定義しない）
    @Published var items: [TimetableItem] = []

    @Published var errorMessage: String?

    // TimetableFetcher.saveToLocal() と同じキー
    private let localKey = "cachedTimetableItems"

    // App Group（Widget共有）
    private enum WGKeys {
        static let appGroup = "group.com.yuta.beefapp"   // ✅ 変更: あなたの App Group に合わせてください
        static let storeKey = "widgetTimetableToday"
        static let widgetKind = "TimetableWidgetKind"     // ✅ 変更: ウィジェットの kind と一致させる
    }

    // ✅ 変更: Widget 連携用の構造体は重複を避けるため、名前を "WidgetLecture" に変更
    //         （型名はJSONに含まれないため、Widget側の SharedLecture と互換です）
    private struct WidgetLecture: Codable, Identifiable {
        var id: String { code + String(period) }
        let code: String
        let title: String
        let room: String?
        let teacher: String?
        let period: Int
        let startTime: String
        let endTime: String
    }

    // MARK: - 公開API

    /// ローカル（UserDefaults.standard）から時間割を読み込み、`items` に反映します。
    /// TimetableFetcher.saveToLocal() 済みのデータのみを対象とします。
    func loadFromLocal() {
        errorMessage = nil
        guard let data = UserDefaults.standard.data(forKey: localKey) else {
            self.items = []
            self.errorMessage = "ローカルの時間割データが見つかりません。"
            print("⚠️ ローカルデータなし (\(localKey))")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([TimetableItem].self, from: data)
            self.items = decoded
            print("✅ ローカルから時間割を読み込みました: \(decoded.count)件")
        } catch {
            self.items = []
            self.errorMessage = "ローカルデータの読み込みに失敗しました。"
            print("❌ デコード失敗: \(error.localizedDescription)")
        }
    }

    /// 今日の時間割（曜日一致かつ period 昇順）を返します。
    func todaysLectures() -> [TimetableItem] {
        let today = Self.weekdayJP(Date())
        return items
            .filter { $0.day == today }
            .sorted { $0.period < $1.period }
    }

    /// ウィジェットへ「今日の時間割」を公開します（App Group 経由）。
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
                endTime: Self.periodToEnd($0.period)
            )
        }

        guard let data = try? JSONEncoder().encode(payload),
              let ud = UserDefaults(suiteName: WGKeys.appGroup) else {
            print("❌ App Group への保存に失敗（suiteNameや権限をご確認ください）")
            return
        }

        ud.set(data, forKey: WGKeys.storeKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WGKeys.widgetKind)
        print("📤 Widgetへ今日の時間割を公開: \(payload.count)件")
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

    /// 時限→開始時刻（TimetableView の表示に合わせています）
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

    /// 時限→終了時刻（TimetableView の表示に合わせています）
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
