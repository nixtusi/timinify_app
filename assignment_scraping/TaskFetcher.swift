//
//  TaskFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import Foundation
import Combine
import WidgetKit
import FirebaseAuth

struct TaskListResponse: Codable {
    let tasks: [BeefTask]
}

class TaskFetcher: ObservableObject {
    @Published var tasks: [BeefTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success: Bool? = nil //更新時間の変更に使用
    @Published var lastUpdated: Date? = nil

    private let storageKey = "savedTasks"
    private let apiURL = URL(string: "https://beefplus.timinify.com/beefplus")!
    private let lastUpdatedKey = "lastUpdatedTime" // 🔸① 追加
    
    init() {
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date // 🔸読み込み
    }

    // 🔄 保存済み課題を読み込む
    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }

    // 🔄 APIから課題を取得
    func fetchTasksFromAPI(retryCount: Int = 2) {
        loadSavedTasks() //最初にローカル課題を一時的に表示（前回の課題）
        
        // ✅ UserDefaultsからログイン情報を取得
        let studentNumber = UserDefaults.standard.string(forKey: "studentNumber") ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        // ✅ ログイン情報が未設定なら中止
        guard !studentNumber.isEmpty, !password.isEmpty else {
            self.errorMessage = "ログイン情報が未設定です"
            return
        }

        print("📦 課題取得用ログイン情報: \(studentNumber), \(password)")

        if retryCount == 2 {
            isLoading = true
            errorMessage = nil
        }

        var request = URLRequest(url: apiURL, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: String] = [
            "student_number": studentNumber,
            "password": password
        ]
        request.httpBody = try? JSONEncoder().encode(requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if retryCount > 0 {
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.success = false
                        self.isLoading = false
                        self.errorMessage = "通信エラー: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data else {
                    if retryCount > 0 {
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.success = false   // ✅ ← ここを追加
                        self.isLoading = false
                        self.errorMessage = "データが取得できませんでした"
                    }
                    return
                }

                if let decoded = try? JSONDecoder().decode(TaskListResponse.self, from: data) {
                    self.tasks = decoded.tasks
                    self.saveTasksToLocal(decoded.tasks)
                    NotificationManager.shared.scheduleNotifications(for: decoded.tasks)
                    self.success = true    // ✅ ← ここを追加
                    self.lastUpdated = Date() //成功時！！
                    UserDefaults.standard.set(self.lastUpdated, forKey: self.lastUpdatedKey) // 🔸保存
                    self.isLoading = false
                    return
                }

                if retryCount > 0 {
                    self.fetchTasksFromAPI(retryCount: retryCount - 1)
                } else {
                    self.success = false   // ✅ ← ここを追加
                    self.isLoading = false
                    self.errorMessage = "デコード失敗: \(String(data: data, encoding: .utf8) ?? "不明")"
                }
                
            }
        }.resume()
    }

    // 🔐 ローカル保存
    private func saveTasksToLocal(_ tasks: [BeefTask]) {
        // ① メインアプリ用
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        // ② ウィジェット用（App Group）
        let sharedTasks = tasks.map {
            SharedTask(title: $0.title, deadline: $0.deadline, url: $0.url)
        }

        if let sharedData = try? JSONEncoder().encode(sharedTasks),
           let sharedDefaults = UserDefaults(suiteName: "group.com.yuta.beefapp") {
            sharedDefaults.set(sharedData, forKey: "widgetTasks")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
