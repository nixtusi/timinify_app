//
//  TaskListView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import SwiftUI
import WidgetKit //ウィジェット更新用

struct TaskListView: View {
    @AppStorage("loginID") var loginID: String = ""
    @AppStorage("loginPassword") var loginPassword: String = ""
    @StateObject private var fetcher = TaskFetcher()
    @Environment(\.scenePhase) var scenePhase

    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationView {
            List(fetcher.tasks) { task in
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.course)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(task.title)
                        .font(.headline)

                    HStack {
                        Text("締切: \(task.deadline)")
                            .font(.footnote)
                        Spacer()
                        Text(task.timeRemaining)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle()) //VStack 全体がタップ可能領域として明示される
                .onTapGesture {
                    if let url = URL(string: task.url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .navigationTitle("課題一覧")
            .onAppear {
                fetcher.loginID = loginID
                fetcher.loginPassword = loginPassword

                if !hasLoadedOnce {
                    fetcher.loadSavedTasks()
                    hasLoadedOnce = true
                }

                //表示されるたびに取得 + ウィジェット更新
                fetcher.fetchTasksFromAPI()
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    //アプリがフォアグラウンドに復帰したときにも取得 + ウィジェット更新
                    fetcher.fetchTasksFromAPI()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .overlay {
                if fetcher.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = fetcher.errorMessage {
                    Text("⚠️ \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
    }
}
