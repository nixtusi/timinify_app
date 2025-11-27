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

@MainActor
class TaskFetcher: ObservableObject {
    @Published var tasks: [BeefTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success: Bool? = nil
    @Published var lastUpdated: Date? = nil
    @Published var infoMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    @Published var isServerDown: Bool = false

    private enum Keys {
        static let storageKey = "savedTasks"
        static let lastUpdatedKey = "lastUpdatedTime"
        static let appGroupSuite = "group.com.yuta.beefapp"
        static let widgetTasksKey = "widgetTasks"
        static let widgetLastUpdatedKey = "widgetLastUpdated"
    }

    init() {
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: Keys.lastUpdatedKey) as? Date
    }

    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: Keys.storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }

    // APIではなくScraperを使用
    func fetchTasksFromAPI() {
        loadSavedTasks()

        let studentNumber = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ??
            UserDefaults.standard.string(forKey: "studentNumber") ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        guard !studentNumber.isEmpty, !password.isEmpty else {
            self.errorMessage = "ログイン情報が未設定です。設定画面から学籍番号・パスワードを登録してください。"
            self.showErrorAlert = true
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        isServerDown = false

        // スクレイピング実行
        AssignmentScraper.shared.fetchAssignments(studentID: studentNumber, password: password) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let fetchedTasks):
                self.success = true
                self.tasks = fetchedTasks
                self.saveTasksToLocal(fetchedTasks)
                NotificationManager.shared.scheduleNotifications(for: fetchedTasks)
                
                if fetchedTasks.isEmpty {
                    self.infoMessage = "未提出の課題・テスト一覧はありません。"
                }
                self.updateLastUpdated()
                print("✅ 課題取得成功（スクレイピング）: \(fetchedTasks.count)件")
                
            case .failure(let error):
                self.success = false
                print("❌ 課題取得失敗: \(error)")
                if let se = error as? ScrapeError, se == .timeout {
                    self.errorMessage = "接続がタイムアウトしました。通信環境を確認してください。"
                } else {
                    self.errorMessage = "課題の取得に失敗しました。BEEF+のパスワードが変更されていないか確認してください。"
                }
                self.showErrorAlert = true
            }
        }
    }

    private func updateLastUpdated() {
        let now = Date()
        self.lastUpdated = now
        UserDefaults.standard.set(now, forKey: Keys.lastUpdatedKey)
        if let sharedDefaults = UserDefaults(suiteName: Keys.appGroupSuite) {
            sharedDefaults.set(now, forKey: Keys.widgetLastUpdatedKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveTasksToLocal(_ tasks: [BeefTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Keys.storageKey)
        }

        let sharedTasks = tasks.map {
            SharedTask(title: $0.title, deadline: $0.deadline, url: $0.url)
        }
        if let sharedData = try? JSONEncoder().encode(sharedTasks),
           let sharedDefaults = UserDefaults(suiteName: Keys.appGroupSuite) {
            sharedDefaults.set(sharedData, forKey: Keys.widgetTasksKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
