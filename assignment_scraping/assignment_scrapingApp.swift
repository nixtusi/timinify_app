//
//  assignment_scrapingApp.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/04/29.
//
import SwiftUI
import BackgroundTasks
import WidgetKit

@main
struct BeefTaskApp: App {
    @AppStorage("agreedToTerms") private var agreedToTerms: Bool = false

    init() {
        // ✅ 通知許可
        NotificationManager.shared.requestAuthorization()

        // ✅ BGTask 登録（self を使わず static 関数に変更）
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yuta.beefapp.refresh",
            using: nil
        ) { task in
            BeefTaskApp.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        // ✅ スケジューリング
        BeefTaskApp.scheduleAppRefresh()
        
        
    }

    var body: some Scene {
        WindowGroup {
            if agreedToTerms {
                MainTabView()
            } else {
                InitialSetupView(onComplete: {
                    // 規約に同意後に呼ばれる（何もしなくてもOK）
                })
            }
        }
    }

    // ✅ static に変更（self を使わないため）
    static func handleAppRefresh(task: BGAppRefreshTask) {
        print("📡 BGTask: 開始")

        // タスクがタイムアウトする前に中止処理
        task.expirationHandler = {
            print("⚠️ BGTask: タイムアウト")
            task.setTaskCompleted(success: false)
        }

        // 非同期タスクで課題情報を取得して保存
        Task {
            await fetchAndStoreAssignments()
            task.setTaskCompleted(success: true)
            scheduleAppRefresh()  // 次回予約
        }
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yuta.beefapp.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 600) // 10分後

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ BGTask: スケジュール登録完了")
        } catch {
            print("❌ BGTask: スケジュール登録失敗 - \(error)")
        }
    }
    
    static func fetchAndStoreAssignments() async {
        do {
            let url = URL(string: "https://your-api.com/assignments")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let tasks = try JSONDecoder().decode([SharedTask].self, from: data)

            let defaults = UserDefaults(suiteName: "group.com.yuta.beefapp")
            let encoded = try JSONEncoder().encode(tasks)
            defaults?.set(encoded, forKey: "widgetTasks")

            WidgetCenter.shared.reloadAllTimelines()
            print("✅ 課題情報を更新し、Widget再読込")
        } catch {
            print("❌ 課題取得エラー: \(error)")
        }
    }
}

