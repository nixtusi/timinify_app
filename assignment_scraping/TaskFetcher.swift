
//
//  TaskFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import Foundation
import Combine
import WidgetKit

struct TaskListResponse: Codable {
    let tasks: [BeefTask]
}

class TaskFetcher: ObservableObject {
    @Published var tasks: [BeefTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let storageKey = "savedTasks"
    private let apiURL = URL(string: "https://beefplus.timinify.com/beefplus")!

    var loginID: String = ""
    var loginPassword: String = ""

    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }

    func fetchTasksFromAPI(retryCount: Int = 2) {
        guard !loginID.isEmpty, !loginPassword.isEmpty else {
            self.errorMessage = "ログイン情報が未設定です"
            return
        }

        if retryCount == 2 {
            isLoading = true
            errorMessage = nil
        }

        var request = URLRequest(url: apiURL, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: String] = [
            "student_number": loginID,
            "password": loginPassword
        ]
        request.httpBody = try? JSONEncoder().encode(requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("通信エラー: \(error.localizedDescription)")
                    if retryCount > 0 {
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.isLoading = false
                        self.errorMessage = "通信エラー: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data else {
                    print("データが取得できませんでした")
                    if retryCount > 0 {
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.isLoading = false
                        self.errorMessage = "データが取得できませんでした"
                    }
                    return
                }

                if let decoded = try? JSONDecoder().decode(TaskListResponse.self, from: data) {
                    self.tasks = decoded.tasks
                    self.saveTasksToLocal(decoded.tasks)
                    NotificationManager.shared.scheduleNotifications(for: decoded.tasks)
                    self.isLoading = false
                    return
                }

                print("デコード失敗: \(String(data: data, encoding: .utf8) ?? "不明")")
                if retryCount > 0 {
                    self.fetchTasksFromAPI(retryCount: retryCount - 1)
                } else {
                    self.isLoading = false
                    self.errorMessage = "取得失敗: \(String(data: data, encoding: .utf8) ?? "不明")"
                }
            }
        }.resume()
    }

    private func saveTasksToLocal(_ tasks: [BeefTask]) {
        // ① メインアプリ用に保存
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        // ② ウィジェット用にApp Groupへ保存
        let sharedTasks = tasks.map {
            SharedTask(title: $0.title, deadline: $0.deadline, url: $0.url)
        }

        if let sharedData = try? JSONEncoder().encode(sharedTasks) {
            if let sharedDefaults = UserDefaults(suiteName: "group.com.yuta.beefapp") {
                print("✅ Main App: AppGroup OK")
                sharedDefaults.set(sharedData, forKey: "widgetTasks")

                // ✅ 保存完了後にウィジェットを強制更新
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                print("❌ Main App: AppGroup nil")
            }
        }
    }
}
