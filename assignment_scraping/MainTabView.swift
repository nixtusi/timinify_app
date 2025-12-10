//
//  MainTabView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    // タブ選択状態の管理 (TabViewの代わりに手動で管理)
    @State private var selection: Tab = .timetable
    
    // 各タブのNavigationStack用パス (NavigationStackをContentView内に入れるため、Path管理は継続)
    @State private var timetablePath = NavigationPath()
    @State private var taskPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    enum Tab: CaseIterable { // CaseIterableを追加
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
        // 従来のTabViewをZStackに置き換え
        ZStack(alignment: .bottom) {
            
            // 1. コンテンツ領域
            contentView
                // Bottom Bar分のマージンを確保
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. カスタムタブバー
            customTabBar
        }
        // タブの選択色を最上位で設定
        .accentColor(Color(hex: "#4B3F96"))
    }
    
    // MARK: - コンテンツビュー
    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .timetable:
            NavigationStack(path: $timetablePath) {
                TimetableView()
            }
            // タブを切り替えるたびにパスをリセット (既存のTabViewと同じ動作)
            .onChange(of: selection) { _, newValue in
                if newValue != .timetable { timetablePath = NavigationPath() }
            }
        case .task:
            NavigationStack(path: $taskPath) {
                TaskListView()
                    .navigationTitle("課題")
            }
            .onChange(of: selection) { _, newValue in
                if newValue != .task { taskPath = NavigationPath() }
            }
        case .search:
            // SearchはNavigationStack不要 (SearchView内で完結しているため)
            SearchView()
            
        case .settings:
            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("設定")
            }
            .onChange(of: selection) { _, newValue in
                if newValue != .settings { settingsPath = NavigationPath() }
            }
        }
    }
    
    // MARK: - カスタムタブバービュー
    private var customTabBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    // タップで選択タブを変更
                    if selection == tab {
                        // 同じタブがタップされたらルートに戻る (既存のTabViewと同じ動作)
                        resetNavigationPath(for: tab)
                    }
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                // 選択状態に応じて色を変更
                .foregroundColor(selection == tab ? Color(hex: "#4B3F96") : Color(.systemGray))
            }
        }
        .frame(height: 49) // 標準的なタブバーの高さ
        .padding(.top, 8)
        // 👇 修正: セーフエリアのパディングから 12pt を引いて、さらにタブバーを画面下端に食い込ませます。
        .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) - 40)
        .background(Color(.systemGray6).ignoresSafeArea(edges: .bottom)) // 常に不透明な背景
        .shadow(color: .black.opacity(0.08), radius: 0.5, x: 0, y: -0.5) // わずかな上部影
    }
    
    // MARK: - ユーティリティ
    private func resetNavigationPath(for tab: Tab) {
        // 同じタブを再タップしたときのルートリセット処理
        switch tab {
        case .timetable: timetablePath = NavigationPath()
        case .task: taskPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        case .search: break // SearchはStack管理外のため何もしない
        }
    }
}
