//
//  MainTabView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI
import Foundation

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    // ✅ 標準TabViewの選択状態
    @State private var selection: Tab = .timetable
    @State private var pendingTaskURL: URL? = nil

    // ✅ 各タブのNavigationStack用パス（今の設計をそのまま活かす）
    @State private var timetablePath = NavigationPath()
    @State private var taskPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    @State private var taskRefreshToken = UUID()

    enum Tab: CaseIterable {
        case timetable, task, search, settings

        var title: String {
            switch self {
            case .timetable: return "時間割"
            case .task: return "課題"
            case .search: return "検索"
            case .settings: return "設定"
            }
        }

        var icon: String {
            switch self {
            case .timetable: return "calendar"
            case .task: return "list.bullet"
            case .search: return "magnifyingglass"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {

            // ---- 時間割 ----
            NavigationStack(path: $timetablePath) {
                TimetableView()
                    .navigationTitle("時間割")
                    .navigationBarTitleDisplayMode(.inline) // ✅ タイトル上固定
            }
            .tabItem { Label(Tab.timetable.title, systemImage: Tab.timetable.icon) }
            .tag(Tab.timetable)

            // ---- 課題 ----
            NavigationStack(path: $taskPath) {
                TaskListView(pendingTaskURL: $pendingTaskURL)
                    .id(taskRefreshToken) // ✅ タブを開くたびリフレッシュしたい用途
                    .navigationTitle("課題")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label(Tab.task.title, systemImage: Tab.task.icon) }
            .tag(Tab.task)

            // ---- 検索 ----
            NavigationStack(path: $searchPath) {
                SearchView()
                    .navigationTitle("検索")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label(Tab.search.title, systemImage: Tab.search.icon) }
            .tag(Tab.search)

            // ---- 設定 ----
            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("設定")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.icon) }
            .tag(Tab.settings)
        }
        .tint(Color(hex: "#4B3F96"))
        .onChange(of: selection) { _, newValue in
            // ✅ 既存の「タブ切替でパスをリセット」挙動を再現
            switch newValue {
            case .timetable:
                taskPath = NavigationPath()
                searchPath = NavigationPath()
                settingsPath = NavigationPath()

            case .task:
                timetablePath = NavigationPath()
                searchPath = NavigationPath()
                settingsPath = NavigationPath()
                taskRefreshToken = UUID()

            case .search:
                timetablePath = NavigationPath()
                taskPath = NavigationPath()
                settingsPath = NavigationPath()

            case .settings:
                timetablePath = NavigationPath()
                taskPath = NavigationPath()
                searchPath = NavigationPath()
            }
        }
        .onAppear {
            guard let url = appState.pendingDeepLink else { return }
            handleDeepLink(url)
            appState.pendingDeepLink = nil
        }
        .onChange(of: appState.pendingDeepLink) { _, newValue in
            guard let url = newValue else { return }
            handleDeepLink(url)
            appState.pendingDeepLink = nil
        }
        .onOpenURL(perform: handleDeepLink)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "beefapp" else { return }

        switch url.host {
        case "timetable":
            selection = .timetable
        case "task":
            selection = .task
            taskRefreshToken = UUID()
            pendingTaskURL = taskURL(from: url)
        case "search":
            selection = .search
        case "settings":
            selection = .settings
        default:
            break
        }
    }

    private func taskURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            return nil
        }

        let decoded = value.removingPercentEncoding ?? value
        return URL(string: decoded)
    }
}
