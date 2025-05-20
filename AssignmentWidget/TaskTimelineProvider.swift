//
//  TaskTimelineProvider.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import WidgetKit
import Foundation

struct TaskTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        let entry = TaskEntry(date: Date(), tasks: loadTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
        let tasks = loadTasks() // ← 課題情報を読み込み

        // ✅ 自動更新時に課題情報だけを再保存
        if let defaults = UserDefaults(suiteName: "group.com.yuta.beefapp") {
            if let encoded = try? JSONEncoder().encode(tasks) {
                defaults.set(encoded, forKey: "widgetTasks")
                print("✅ Widget: 課題情報を再保存（件数=\(tasks.count)）")
            } else {
                print("❌ Widget: 課題のエンコード失敗")
            }
        } else {
            print("❌ Widget: AppGroupのUserDefaults取得失敗")
        }

        let entry = TaskEntry(date: currentDate, tasks: tasks)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadTasks() -> [SharedTask] {
        let defaults = UserDefaults(suiteName: "group.com.yuta.beefapp")
        if defaults == nil {
            print("❌ Widget: AppGroup nil")
        } else {
            print("✅ Widget: AppGroup OK")
        }

        guard let data = defaults?.data(forKey: "widgetTasks"),
              let tasks = try? JSONDecoder().decode([SharedTask].self, from: data) else {
            print("❌ Widget: 課題読み込み失敗")
            return []
        }

        print("✅ Widget: 課題読み込み成功 件数=\(tasks.count)")
        return tasks
    }
}
