//
//  TaskListView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//
//


import SwiftUI

struct MainTabView: View {
    @State private var showServerOffAlert = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {

            TabView {
                NavigationView {
                    TimetableView()
                        //.navigationTitle("時間割")
                }
                .tabItem {
                    Label("時間割", systemImage: "calendar")
                }

                NavigationView {
                    TaskListView()
                        .navigationTitle("課題")
                }
                .tabItem {
                    Label("課題", systemImage: "list.bullet")
                }

                NavigationView {
                    SettingsView()
                        .navigationTitle("設定")
                }
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
            }
        }
        // ✅ VStackに付けることで画面全体に作用
        .onAppear {
            checkServerTime()
            print("🧾 学籍番号（Firebase Auth）: \(appState.studentNumber)")
        }
        .alert(isPresented: $showServerOffAlert) {
            Alert(
                title: Text("サーバー停止中"),
                message: Text("現在（0:10〜6:00）はサーバーを停止しているため、新たな情報取得はできません。"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func checkServerTime() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)

        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let totalMinutes = hour * 60 + minute

        if totalMinutes >= 10 && totalMinutes < 360 {
            showServerOffAlert = true
        }
    }
}
