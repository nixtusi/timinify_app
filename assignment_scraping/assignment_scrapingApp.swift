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
    
    @State private var showEmailVerificationAlert = false

    init() {
        //通知許可
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
                .onAppear {
                    checkEmailVerification()
                }
                // ✅ 追加: メール未認証時のアラート
                .alert("メール認証が必要です", isPresented: $showEmailVerificationAlert) {
                    Button("メールを送信") {
                        resendVerificationEmail()
                    }
                    Button("閉じる", role: .cancel) {}
                } message: {
                    Text("メール認証が完了していません。確認メールを送信しますか？")
                }
        }
    }
    
    private func checkEmailVerification() {
        if let user = Auth.auth().currentUser {
            user.reload { _ in
                if user.isEmailVerified {
                    appState.isLoggedIn = true
                } else {
                    // ログイン済みだが未認証の場合にアラートを表示
                    showEmailVerificationAlert = true
                }
            }
        }
        if let email = Auth.auth().currentUser?.email {
            appState.studentNumber = email.components(separatedBy: "@").first ?? ""
        }
    }
    
    private func resendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification { error in
            if let error = error {
                print("メール送信エラー: \(error.localizedDescription)")
            } else {
                print("確認メールを送信しました")
            }
        }
    }

    //ログイン状態に応じて遷移先を分岐
    @ViewBuilder
    private func RootView() -> some View {
        if appState.isLoggedIn {
            MainTabView()
        } else {
            AuthView {
                appState.isLoggedIn = true
            }
        }
    }

    //課題取得タスク処理
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

    //課題情報を取得してWidgetに保存
    // 課題情報を取得してWidgetに保存（オンデバイス・スクレイピング版）
    @MainActor // WKWebViewを操作するためメインスレッドで実行
    static func fetchAndStoreAssignments() async {
        // 1. 保存されているログイン情報を取得
        guard let studentID = UserDefaults.standard.string(forKey: "studentNumber"),
              let password = UserDefaults.standard.string(forKey: "loginPassword"),
              !studentID.isEmpty, !password.isEmpty else {
            print("❌ [Background] ログイン情報が保存されていないため、自動更新をスキップします")
            return
        }

        print("📡 [Background] オンデバイス・スクレイピングを開始します...")

        // 2. AssignmentScraperを使って課題を取得（非同期処理）
        await withCheckedContinuation { continuation in
            AssignmentScraper.shared.fetchAssignments(studentID: studentID, password: password) { result in
                
                switch result {
                case .success(let tasks):
                    // 3. 取得した課題をWidget用に変換
                    let sharedTasks = tasks.map {
                        SharedTask(title: $0.title, deadline: $0.deadline, url: $0.url)
                    }
                    
                    // 4. App GroupのUserDefaultsに保存
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.yuta.beefapp") {
                        if let encoded = try? JSONEncoder().encode(sharedTasks) {
                            sharedDefaults.set(encoded, forKey: "widgetTasks")
                            sharedDefaults.set(Date(), forKey: "widgetLastUpdated") // 最終更新日時
                            
                            // 5. ウィジェットを更新
                            WidgetCenter.shared.reloadAllTimelines()
                            print("✅ [Background] 課題データの更新・保存完了 (\(tasks.count)件)")
                        }
                    } else {
                        print("❌ [Background] App Groupへのアクセスに失敗しました")
                    }
                    
                case .failure(let error):
                    print("❌ [Background] スクレイピング失敗: \(error.localizedDescription)")
                }
                
                // 処理完了を通知
                continuation.resume()
            }
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
