//
//  TaskFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//
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

class TaskFetcher: ObservableObject {
    @Published var tasks: [BeefTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success: Bool? = nil
    @Published var lastUpdated: Date? = nil

    private let storageKey = "savedTasks"
    private let apiURL = URL(string: "https://beefplus.timinify.com/beefplus")! // ✅ URL修正
    private let lastUpdatedKey = "lastUpdatedTime"

    init() {
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
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
        loadSavedTasks()

        let studentNumber = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ??
            UserDefaults.standard.string(forKey: "studentNumber") ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

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

        // ✅ JSONSerializationでエンコード（Codable不可）
        let requestBody: [String: String] = [
            "student_number": studentNumber,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

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
                        self.success = false
                        self.isLoading = false
                        self.errorMessage = "データが取得できませんでした"
                    }
                    return
                }

                do {
                    // ✅ "tasks" キーでネストされているので構造体で包む
                    struct ResponseWrapper: Decodable {
                        let tasks: [BeefTask]
                    }

                    let decodedResponse = try JSONDecoder().decode(ResponseWrapper.self, from: data)
                    let decodedTasks = decodedResponse.tasks

                    self.tasks = decodedTasks
                    self.saveTasksToLocal(decodedTasks)
                    NotificationManager.shared.scheduleNotifications(for: decodedTasks)
                    self.success = true
                    self.lastUpdated = Date()
                    UserDefaults.standard.set(self.lastUpdated, forKey: self.lastUpdatedKey)
                    self.isLoading = false
                    
                    print("✅ 課題取得成功（\(decodedTasks.count)件）")
                    print("🕒 最終更新: \(self.lastUpdated!)")
                } catch {
                    if retryCount > 0 {
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.success = false
                        self.isLoading = false
                        let responseStr = String(data: data, encoding: .utf8) ?? "不明なデータ"
                        self.errorMessage = "デコード失敗: \(responseStr)"
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🌐 ステータスコード: \(httpResponse.statusCode)")
                    }
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
