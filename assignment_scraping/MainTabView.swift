//
//  MainTabView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI

struct MainTabView: View {
    @State private var showServerOffAlert = false

    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("課題", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
        .onAppear {
            checkServerTime()
        }
        .alert(isPresented: $showServerOffAlert) {
            Alert(
                title: Text("サーバー停止中"),
                message: Text("現在（0:10〜6:00）はサーバーを停止しているため、新たな課題取得はできません。"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func checkServerTime() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)

        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let totalMinutes = hour * 60 + minute

        // 0:10 = 10分, 6:00 = 360分
        if totalMinutes >= 10 && totalMinutes < 360 {
            showServerOffAlert = true
        }
    }
}
