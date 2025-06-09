//
//  BackgroundTaskManager.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/17.
//

import BackgroundTasks
import Foundation

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private init() {}

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yuta.beefapp.refresh",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yuta.beefapp.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15) // 最短15分後
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ BGTask submit failed: \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // 次回の予約
        scheduleAppRefresh()

        let operation = BlockOperation {
            print("📡 バックグラウンドでAPI実行")
            TaskFetcher().fetchTasksFromAPI()  // Task → BeefTask に対応済のFetcherを使っている前提
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            operation.cancel()
        }

        OperationQueue().addOperation(operation)
    }
}
