//
//  assignment_scrapingApp.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/04/29.
//

import SwiftUI
import BackgroundTasks
import WidgetKit
import Firebase
import FirebaseCore
import FirebaseAuth

@main
struct BeefTaskApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    init() {
        //通知許可
        NotificationManager.shared.requestAuthorization()

        //💩BGTask登録(後ほどコメントアウトを外す)
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: "com.yuta.beefapp.refresh",
//            using: nil
//        ) { task in
//            BeefTaskApp.handleAppRefresh(task: task as! BGAppRefreshTask)
//        }

        // 💩スケジュール登録(後ほどコメントアウトを外す)
        //BeefTaskApp.scheduleAppRefresh()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onAppear {
                    // ✅ FirebaseAuth からログイン状態を判定（メール認証済みのみ）
                    if let user = Auth.auth().currentUser {
                        user.reload { _ in
                            if user.isEmailVerified {
                                appState.isLoggedIn = true
                            }
                        }
                    }
                    // ✅ FirebaseAuth のメールアドレスから学籍番号を取得（AppStorage は不要）
                    if let email = Auth.auth().currentUser?.email {
                        appState.studentNumber = email.components(separatedBy: "@").first ?? ""
                    }
                }
        }
    }

    // ✅ ログイン状態に応じて遷移先を分岐
    @ViewBuilder
    private func RootView() -> some View {
        if appState.isLoggedIn {
            MainTabView()
        } else {
            InitialSetupView {
                appState.isLoggedIn = true
            }
        }
    }

    // ✅ 課題取得タスク処理
    static func handleAppRefresh(task: BGAppRefreshTask) {
        print("📡 BGTask: 開始")

        task.expirationHandler = {
            print("⚠️ BGTask: タイムアウト")
            task.setTaskCompleted(success: false)
        }

        Task {
            await fetchAndStoreAssignments()
            task.setTaskCompleted(success: true)
            //scheduleAppRefresh() //💩(後ほどコメントアウトを外す)
        }
    }

    // 💩BGTaskスケジュール登録(後ほどコメントアウトを外す)
//    static func scheduleAppRefresh() {
//        let request = BGAppRefreshTaskRequest(identifier: "com.yuta.beefapp.refresh")
//        request.earliestBeginDate = Date(timeIntervalSinceNow: 600)
//
//        do {
//            try BGTaskScheduler.shared.submit(request)
//            print("✅ BGTask: スケジュール登録完了")
//        } catch {
//            print("❌ BGTask: スケジュール登録失敗 - \(error)")
//        }
//    }

    // ✅ 課題情報を取得してWidgetに保存
    static func fetchAndStoreAssignments() async {
        do {
            let url = URL(string: "https://your-api.com/assignments")! // ← 必要に応じて差し替え
            let (data, _) = try await URLSession.shared.data(from: url)
            let tasks = try JSONDecoder().decode([SharedTask].self, from: data)

            let defaults = UserDefaults(suiteName: "group.com.yuta.beefapp")
            let encoded = try JSONEncoder().encode(tasks)
            defaults?.set(encoded, forKey: "widgetTasks")

            WidgetCenter.shared.reloadAllTimelines()
            print("✅ 課題情報を更新し、Widget再読込")
        } catch {
            print("❌ 課題取得エラー: \(error)")
        }
    }
}

// MARK: - Firebase用 AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
