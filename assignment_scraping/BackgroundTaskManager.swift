//
//  BackgroundTaskManager.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/17.
//

import BackgroundTasks
import Foundation
import FirebaseAuth

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
            if let email = Auth.auth().currentUser?.email,
               let studentNumber = email.components(separatedBy: "@").first {
                var fetcher = TaskFetcher()
                fetcher.fetchTasksFromAPI()
                task.setTaskCompleted(success: true)
            } else {
                print("❌ ログインユーザー情報が取得できませんでした")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }

        OperationQueue().addOperation(operation)
    }
}
