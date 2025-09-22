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

@MainActor // ✅ 変更: UI更新の一貫性を担保
class TaskFetcher: ObservableObject {
    @Published var tasks: [BeefTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success: Bool? = nil
    @Published var lastUpdated: Date? = nil
    @Published var infoMessage: String? = nil

    // ✅ 変更: アラート表示トリガ（UI側で .alert にバインド）
    @Published var showErrorAlert: Bool = false

    // ✅ 変更: サーバーダウンをUIでも判定できるように
    @Published var isServerDown: Bool = false

    private enum Keys {
        static let storageKey = "savedTasks"
        static let lastUpdatedKey = "lastUpdatedTime"
        static let appGroupSuite = "group.com.yuta.beefapp"
        static let widgetTasksKey = "widgetTasks"
        static let widgetLastUpdatedKey = "widgetLastUpdated"
        static let apiURLString = "https://api.timinify.com/beefplus"
    }

    private let apiURL = URL(string: Keys.apiURLString)!
    private let urlSession: URLSession

    init(session: URLSession = .shared) {
        self.urlSession = session
        loadSavedTasks()
        self.lastUpdated = UserDefaults.standard.object(forKey: Keys.lastUpdatedKey) as? Date
    }

    // 保存済み課題を読み込む
    func loadSavedTasks() {
        if let data = UserDefaults.standard.data(forKey: Keys.storageKey),
           let decoded = try? JSONDecoder().decode([BeefTask].self, from: data) {
            self.tasks = decoded
        }
    }

    // MARK: - 課題取得（従来版・リトライ付き）
    func fetchTasksFromAPI(retryCount: Int = 2) {
        loadSavedTasks()

        // 学籍番号・パスワードの取得（Firebase Auth優先、無ければUserDefaults）
        let studentNumber = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ??
            UserDefaults.standard.string(forKey: "studentNumber") ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        guard !studentNumber.isEmpty, !password.isEmpty else {
            // ✅ 変更: アラート表示も同時に
            self.errorMessage = "ログイン情報が未設定です。設定画面から学籍番号・パスワードを登録してください。"
            self.isServerDown = false // ✅ 変更: サーバーダウン扱いではない
            self.showErrorAlert = true
            return
        }

        print("📦 課題取得用ログイン情報: \(studentNumber), \(password)")

        if retryCount == 2 {
            isLoading = true
            errorMessage = nil
            infoMessage = nil
            isServerDown = false // ✅ 変更: 開始時リセット
        }

        var request = URLRequest(url: apiURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: String] = [
            "student_number": studentNumber,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }

                // ---- (1) 通信レベルのエラー ----
                if let error = error {
                    if retryCount > 0 {
                        // ✅ 変更: 指数バックオフ
                        let delay: Double = pow(2.0, Double(2 - retryCount)) * 0.8
                        await self.sleep(seconds: delay)
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.success = false
                        self.isLoading = false
                        self.isServerDown = false // ✅ 変更
                        self.errorMessage = "通信エラー: \(error.localizedDescription)"
                        self.showErrorAlert = true // ✅ 変更: アラート表示
                    }
                    return
                }

                // ---- (2) HTTPステータス判定 ----
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    // ✅ 変更: 530（ご提示ログ）や503/502等を「サーバー停止」とみなす
                    let status = http.statusCode
                    let consideredServerDown = (status == 530) || (status == 503) || (status == 502) || (status == 504)
                    if retryCount > 0, (500...599).contains(status) {
                        // 5xx は再試行（最終的にダメなら下でアラート）
                        let delay: Double = pow(2.0, Double(2 - retryCount)) * 0.8
                        await self.sleep(seconds: delay)
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                        return
                    }
                    self.success = false
                    self.isLoading = false

                    if consideredServerDown {
                        // ✅ 変更: サーバーダウン専用メッセージ＆フラグ
                        self.isServerDown = true
                        self.errorMessage = "サーバーが停止しているため新たな課題取得をできません。時間をおいて再度お試しください。（HTTP \(status)）"
                    } else {
                        self.isServerDown = false
                        self.errorMessage = "取得失敗（HTTP \(status)）: サービスが一時的に利用できない可能性があります。"
                    }
                    // ✅ 変更: 失敗時は最終更新を変更しない（仕様維持）
                    self.showErrorAlert = true
                    return
                }

                // ---- (3) データ有無 ----
                guard let data = data, !data.isEmpty else {
                    if retryCount > 0 {
                        let delay: Double = pow(2.0, Double(2 - retryCount)) * 0.8
                        await self.sleep(seconds: delay)
                        self.fetchTasksFromAPI(retryCount: retryCount - 1)
                    } else {
                        self.success = false
                        self.isLoading = false
                        self.isServerDown = false // ✅ 変更
                        self.errorMessage = "データが取得できませんでした。"
                        self.showErrorAlert = true
                    }
                    return
                }

                // ---- (4) JSON デコード1: {"tasks":[...]} ----
                do {
                    struct ResponseWrapper: Decodable { let tasks: [BeefTask] }
                    let decodedResponse = try JSONDecoder().decode(ResponseWrapper.self, from: data)
                    let decodedTasks = decodedResponse.tasks

                    self.tasks = decodedTasks
                    self.saveTasksToLocal(decodedTasks)
                    NotificationManager.shared.scheduleNotifications(for: decodedTasks)
                    self.success = true
                    self.isLoading = false
                    self.isServerDown = false // ✅ 変更

                    if decodedTasks.isEmpty {
                        self.infoMessage = "未提出の課題・テスト一覧はありません。"
                    } else {
                        self.infoMessage = nil
                    }
                    self.updateLastUpdated() // ✅ 変更: 0件でも更新
                    self.logSuccess(count: decodedTasks.count)
                    return

                } catch {
                    // ---- (5) JSON デコード2: {"message":"未提出..."} ----
                    do {
                        struct MessageResponse: Decodable { let message: String }
                        let msg = try JSONDecoder().decode(MessageResponse.self, from: data)

                        self.tasks = []
                        self.saveTasksToLocal([])
                        NotificationManager.shared.scheduleNotifications(for: [])
                        self.success = true
                        self.isLoading = false
                        self.isServerDown = false // ✅ 変更

                        self.infoMessage = msg.message.isEmpty ? "未提出の課題・テスト一覧はありません。" : msg.message
                        self.updateLastUpdated() // ✅ 変更
                        self.logSuccess(count: 0, zeroByMessage: true)
                        return

                    } catch {
                        // ---- (6) 想定外データ（HTML等）→ 失敗。最終更新は変更しない ----
                        if retryCount > 0 {
                            let delay: Double = pow(2.0, Double(2 - retryCount)) * 0.8
                            await self.sleep(seconds: delay)
                            self.fetchTasksFromAPI(retryCount: retryCount - 1)
                        } else {
                            self.success = false
                            self.isLoading = false
                            self.isServerDown = false // ✅ 変更
                            let responseStr = String(data: data, encoding: .utf8) ?? "不明なデータ"
                            self.errorMessage = "デコード失敗: \(responseStr)"
                            self.showErrorAlert = true
                        }
                    }
                }
            }
        }.resume()
    }

    // MARK: - 共通ユーティリティ

    private func updateLastUpdated() {
        let now = Date()
        self.lastUpdated = now
        UserDefaults.standard.set(now, forKey: Keys.lastUpdatedKey)
        if let sharedDefaults = UserDefaults(suiteName: Keys.appGroupSuite) {
            sharedDefaults.set(now, forKey: Keys.widgetLastUpdatedKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func logSuccess(count: Int, zeroByMessage: Bool = false) {
        print("✅ 課題取得成功（\(count)件）" + (zeroByMessage ? "（サーバーメッセージ）" : ""))
        if let updated = self.lastUpdated {
            print("🕒 最終更新: \(updated)")
        }
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

    private func sleep(seconds: Double) async {
        let ns = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }
}
