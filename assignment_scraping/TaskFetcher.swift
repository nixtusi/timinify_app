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
    
    // 制限に達したかどうかのフラグ
    @Published var fetchLimitReached: Bool = false
    // 現在の取得回数（表示用）
    @Published var currentDailyFetchCount: Int = 0

    // ✅ 新規: 上限を50回にしたい学籍番号のリスト（適宜書き換えてください）
    private let specialStudentNumbers: Set<String> = ["2435109t","2415024t","2455092t","2425023t"]

    private enum Keys {
        static let storageKey = "savedTasks"
        static let lastUpdatedKey = "lastUpdatedTime"
        static let appGroupSuite = "group.com.yuta.beefapp"
        static let widgetTasksKey = "widgetTasks"
        static let widgetLastUpdatedKey = "widgetLastUpdated"
        // 回数制限用のキー
        static let dailyFetchCountKey = "dailyFetchCount"
        static let lastFetchDateKey = "lastFetchDate"
    }
    
    // ✅ 新規: 現在の学籍番号を取得するヘルパー
    private var currentStudentNumber: String {
        if let email = Auth.auth().currentUser?.email {
            return email.components(separatedBy: "@").first ?? ""
        }
        return UserDefaults.standard.string(forKey: "studentNumber") ?? ""
    }

    // ✅ 新規: 学籍番号に応じて最大回数を返すプロパティ
    var maxDailyFetches: Int {
        if specialStudentNumbers.contains(currentStudentNumber) {
            return 50 // 特定の人は50回
        } else {
            return 20 // 通常は10回
        }
    }
    
    // 残り回数を計算するプロパティ
    var remainingFetches: Int {
        return max(0, self.maxDailyFetches - currentDailyFetchCount) // ✅ 変更: self.maxDailyFetchesを使用
    }

    init() {
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: Keys.lastUpdatedKey) as? Date
        // 起動時に制限状態をチェック
        checkDailyLimit()
    }

    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: Keys.storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }
    
    // 日付を確認してカウントをリセット・更新するメソッド
    func checkDailyLimit() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        let lastDate = defaults.object(forKey: Keys.lastFetchDateKey) as? Date
        var currentCount = defaults.integer(forKey: Keys.dailyFetchCountKey)
        
        if let lastDate = lastDate, Calendar.current.isDate(lastDate, inSameDayAs: today) {
            // 同日なら何もしない
        } else {
            // 日付が変わっていればリセット
            currentCount = 0
            defaults.set(today, forKey: Keys.lastFetchDateKey)
            defaults.set(currentCount, forKey: Keys.dailyFetchCountKey)
        }
        
        self.currentDailyFetchCount = currentCount
        self.fetchLimitReached = currentCount >= self.maxDailyFetches // ✅ 変更
    }
    
    // カウントアップ処理
    private func incrementDailyFetchCount() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        var currentCount = defaults.integer(forKey: Keys.dailyFetchCountKey)
        currentCount += 1
        
        defaults.set(currentCount, forKey: Keys.dailyFetchCountKey)
        defaults.set(today, forKey: Keys.lastFetchDateKey)
        
        self.currentDailyFetchCount = currentCount
        self.fetchLimitReached = currentCount >= self.maxDailyFetches // ✅ 変更
        
        print("💡 本日の課題取得回数: \(currentCount)/\(self.maxDailyFetches)")
    }
    
    // カウントダウン処理（エラー時などのロールバック用）
    private func decrementDailyFetchCount() {
        let defaults = UserDefaults.standard
        var currentCount = defaults.integer(forKey: Keys.dailyFetchCountKey)
        currentCount = max(0, currentCount - 1)
        
        defaults.set(currentCount, forKey: Keys.dailyFetchCountKey)
        self.currentDailyFetchCount = currentCount
        self.fetchLimitReached = currentCount >= self.maxDailyFetches // ✅ 変更
    }

    // APIではなくScraperを使用
    func fetchTasksFromAPI(retries: Int = 5) {
        
        // 初回呼び出し時（リトライではない時）に制限チェックとカウントアップを行う
        if retries == 5 {
            checkDailyLimit()
            
            guard !fetchLimitReached else {
                self.isLoading = false
                // ✅ 変更: メッセージ内の回数も動的に
                self.errorMessage = "本日の課題取得回数（\(self.maxDailyFetches)回）の上限に達しました。明日改めてお試しください。"
                self.showErrorAlert = true
                return
            }
            
            // 実行前にカウントアップ（連打防止・実行済みとして扱う）
            incrementDailyFetchCount()
            
            isLoading = true
            errorMessage = nil
            infoMessage = nil
            isServerDown = false
        }
        
        loadSavedTasks()

        let studentNumber = currentStudentNumber // ヘルパーを利用
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        guard !studentNumber.isEmpty, !password.isEmpty else {
            // ログイン情報なしエラーの場合はカウントを戻す
            if retries == 5 { decrementDailyFetchCount() }
            
            self.isLoading = false
            self.errorMessage = "ログイン情報が未設定です。設定画面から学籍番号・パスワードを登録してください。"
            self.showErrorAlert = true
            return
        }

        // スクレイピング実行
        AssignmentScraper.shared.fetchAssignments(studentID: studentNumber, password: password) { [weak self] result in
            guard let self = self else { return }
            
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
                
                self.isLoading = false // 完了
                
            case .failure(let error):
                // 失敗時
                if retries > 1 {
                    // リトライ可能なら2秒後に再試行
                    print("⚠️ 課題取得失敗。残り\(retries - 1)回リトライします。")
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                        self.fetchTasksFromAPI(retries: retries - 1)
                    }
                } else {
                    // リトライ上限
                    self.success = false
                    self.isLoading = false
                    print("❌ 課題取得失敗: \(error)")
                    
                    if let se = error as? ScrapeError, se == .timeout {
                        self.errorMessage = "接続がタイムアウトしました。通信環境を確認してください。"
                    } else {
                        self.errorMessage = "課題の取得に失敗しました。もう一度取得をやり直しても、できなければ管理者に連絡してください。"
                    }
                    self.showErrorAlert = true
                }
            }
        }
    }

    // ... (残りのメソッドは変更なし)
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
