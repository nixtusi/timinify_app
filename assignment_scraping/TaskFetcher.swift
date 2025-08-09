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

    // ✅ 変更: 空表示用のメッセージをUIへ渡すためのプロパティを追加
    @Published var infoMessage: String? = nil

    private let storageKey = "savedTasks"
    // ✅ 変更: 実運用のエンドポイントに合わせてURLを修正（ユーザーのcurl例と一致）
    private let apiURL = URL(string: "https://api.timinify.com/beefplus")!
    private let lastUpdatedKey = "lastUpdatedTime"

    init() {
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    // 保存済み課題を読み込む
    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }

    // APIから課題を取得
    func fetchTasksFromAPI(retryCount: Int = 2) {
        loadSavedTasks()

        // 学籍番号・パスワードの取得（Firebase Auth優先、無ければUserDefaults）
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
            infoMessage = nil // ✅ 変更: 取得開始時に文言を一旦クリア
        }

        var request = URLRequest(url: apiURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // JSONSerializationでエンコード（Codable不可）
        let requestBody: [String: String] = [
            "student_number": studentNumber,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 取得失敗 → 今までどおり（リトライ→最終的にエラー、最終更新は変えない）
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

                // ---- デコードフロー1: {"tasks":[...]} 形式 ----
                do {
                    struct ResponseWrapper: Decodable {
                        let tasks: [BeefTask]
                    }
                    let decodedResponse = try JSONDecoder().decode(ResponseWrapper.self, from: data)
                    let decodedTasks = decodedResponse.tasks

                    self.tasks = decodedTasks
                    self.saveTasksToLocal(decodedTasks)
                    NotificationManager.shared.scheduleNotifications(for: decodedTasks)
                    self.success = true
                    self.isLoading = false

                    if decodedTasks.isEmpty {
                        // ✅ 変更: tasksが空配列でも「未提出...」を表示し、最終更新時間を更新する方針に統一
                        self.infoMessage = "未提出の課題・テスト一覧はありません。"
                        self.lastUpdated = Date() // ✅ 変更: 更新する
                        UserDefaults.standard.set(self.lastUpdated, forKey: self.lastUpdatedKey)
                        UserDefaults(suiteName: "group.com.yuta.beefapp")?.set(self.lastUpdated, forKey: "widgetLastUpdated")
                    } else {
                        self.infoMessage = nil
                        self.lastUpdated = Date() // ✅ 変更: 1件以上なら更新
                        UserDefaults.standard.set(self.lastUpdated, forKey: self.lastUpdatedKey)
                        UserDefaults(suiteName: "group.com.yuta.beefapp")?.set(self.lastUpdated, forKey: "widgetLastUpdated")
                    }

                    print("✅ 課題取得成功（\(decodedTasks.count)件）")
                    if let updated = self.lastUpdated {
                        print("🕒 最終更新: \(updated)")
                    }
                    return

                } catch {
                    // ---- デコードフロー2: {"message":"未提出の課題・テスト一覧はありません。"} 形式 ----
                    do {
                        struct MessageResponse: Decodable { let message: String }
                        let msg = try JSONDecoder().decode(MessageResponse.self, from: data)

                        self.tasks = []
                        self.saveTasksToLocal([])
                        NotificationManager.shared.scheduleNotifications(for: [])
                        self.success = true
                        self.isLoading = false

                        // ✅ 変更: ご指定の仕様に合わせて最終更新も更新
                        self.infoMessage = msg.message.isEmpty ? "未提出の課題・テスト一覧はありません。" : msg.message
                        self.lastUpdated = Date() // ✅ 変更: 更新する
                        UserDefaults.standard.set(self.lastUpdated, forKey: self.lastUpdatedKey)
                        UserDefaults(suiteName: "group.com.yuta.beefapp")?.set(self.lastUpdated, forKey: "widgetLastUpdated")

                        print("✅ 課題0件（サーバーメッセージ）")
                        if let updated = self.lastUpdated {
                            print("🕒 最終更新: \(updated)")
                        }
                        return

                    } catch {
                        // ---- デコード失敗（その他エラー文など）→ 今までどおり、最終更新は変更しない ----
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
            }
        }.resume()
    }

    // ローカル保存
    private func saveTasksToLocal(_ tasks: [BeefTask]) {
        // メインアプリ用
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        // ウィジェット用（App Group）
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
