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
    
    @State private var taskRefreshToken = UUID()

    private let tabBarContentHeight: CGFloat = 49  // “中身”の高さ（純正と同じ）

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
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                contentView
                    // タブバーに“被らない”ように、コンテンツ側だけ49pt押し上げる
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: tabBarContentHeight)
                    }

                customTabBar(bottomInset: bottomInset)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .tint(Color(hex: "#4B3F96"))
        }
    }
    
    // MARK: - コンテンツビュー
    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .timetable:
            NavigationStack(path: $timetablePath) {
                TimetableView()
                    .navigationTitle("時間割")
                    .navigationBarTitleDisplayMode(.inline) // ← タイトル上固定（Largeをやめる）
            }
            // タブを切り替えるたびにパスをリセット (既存のTabViewと同じ動作)
            .onChange(of: selection) { _, newValue in
                if newValue != .timetable { timetablePath = NavigationPath() }
            }
        case .task:
            NavigationStack(path: $taskPath) {
                TaskListView()
                    .id(taskRefreshToken)
                    .navigationTitle("課題")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .onChange(of: selection) { _, newValue in
                if newValue != .task { taskPath = NavigationPath() }
            }
        case .search:
            NavigationStack { // ✅ Searchも揃えるならStackで包む
                SearchView()
                    .navigationTitle("検索")
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .settings:
            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("設定")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .onChange(of: selection) { _, newValue in
                if newValue != .settings { settingsPath = NavigationPath() }
            }
        }
    }
    
    // MARK: - カスタムタブバー
    private func customTabBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        if selection == tab { resetNavigationPath(for: tab) }
                        selection = tab

                        if tab == .task {
                            taskRefreshToken = UUID()
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.title)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(selection == tab ? Color(hex: "#4B3F96") : Color(.systemGray))
                }
            }
            .frame(height: tabBarContentHeight)
            // ホームインジケータ分だけ “下に余白” を足す（背景は後で下まで伸ばす）
            .padding(.bottom, bottomInset)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom) // ← 背景を下まで
    }
    
    // MARK: - ユーティリティ
    private func resetNavigationPath(for tab: Tab) {
        // 同じタブを再タップしたときのルートリセット処理
        switch tab {
        case .timetable: timetablePath = NavigationPath()
        case .task:
            taskPath = NavigationPath()
            taskRefreshToken = UUID() //課題タブ再タップでルート戻る時も更新
        case .settings: settingsPath = NavigationPath()
        case .search: break // SearchはStack管理外のため何もしない
        }
    }
}
