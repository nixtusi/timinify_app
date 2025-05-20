//
//  assignment_scrapingApp.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/04/29.
//
import SwiftUI
import BackgroundTasks

@main
struct BeefTaskApp: App {
    @AppStorage("agreedToTerms") private var agreedToTerms: Bool = false

    init() {
        // ✅ 通知許可
        NotificationManager.shared.requestAuthorization()

        // ✅ BGTask 登録（self を使わず static 関数に変更）
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: "com.yuta.beefapp.refresh",
//            using: nil
//        ) { task in
//            BeefTaskApp.handleAppRefresh(task: task as! BGAppRefreshTask)
//        }

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
        scheduleAppRefresh() // 次回予約も static 関数として呼ぶ

        let operation = BlockOperation {
            print("📡 BGTask: API実行中")
            TaskFetcher().fetchTasksFromAPI()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            operation.cancel()
        }

        OperationQueue().addOperation(operation)
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yuta.beefapp.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15) // 15分後以降

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ BGTask: スケジュール登録完了")
        } catch {
            print("❌ BGTask: スケジュール登録失敗 - \(error)")
        }
    }
}
