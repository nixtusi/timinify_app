//
//  MainTabView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("課題", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}
