//
//  MainTabView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    // タブ選択状態の管理
    @State private var selection: Tab = .timetable
    
    // 各タブのNavigationStack用パス
    @State private var timetablePath = NavigationPath()
    @State private var taskPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    enum Tab {
        case timetable, task,search, settings
    }

    var body: some View {
        TabView(selection: Binding(
            get: { selection },
            set: { newSelection in
                if newSelection == selection {
                    // 同じタブがタップされたらルートに戻る
                    switch newSelection {
                    case .timetable: timetablePath = NavigationPath()
                    case .task: taskPath = NavigationPath()
                    case .settings: settingsPath = NavigationPath()
                    case .search: break
                    }
                }
                selection = newSelection
            }
        )) {
            NavigationStack(path: $timetablePath) {
                TimetableView()
            }
            .tabItem {
                Label("時間割", systemImage: "calendar")
            }
            .tag(Tab.timetable)

            NavigationStack(path: $taskPath) {
                TaskListView()
                    .navigationTitle("課題")
            }
            .tabItem {
                Label("課題", systemImage: "list.bullet")
            }
            .tag(Tab.task)
            
            SearchView()
           .tabItem {
               Label("検索", systemImage: "magnifyingglass")
           }
           .tag(Tab.search)

            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("設定")
            }
            .tabItem {
                Label("設定", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .accentColor(Color(hex: "#4B3F96")) // タブの選択色も統一
    }
}
