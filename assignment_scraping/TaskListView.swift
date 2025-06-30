//
//  TaskListView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.

import SwiftUI
import WidgetKit

struct TaskListView: View {
    @StateObject private var fetcher = TaskFetcher()
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(fetcher.tasks) { beefTask in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(beefTask.course)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(beefTask.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("締切: \(beefTask.deadline)")
                                        .font(.footnote)
                                    Spacer()
                                    Text(beefTask.timeRemaining)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                            .onTapGesture {
                                if let url = URL(string: beefTask.url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        
                        //リスト下部に更新時間を表示
                        if !fetcher.tasks.isEmpty || fetcher.lastUpdated != nil || fetcher.isLoading {
                            HStack(spacing: 8) {
                                if let updated = fetcher.lastUpdated {
                                    Text("最終更新 \(formattedDate(updated))")
                                }

                                if fetcher.isLoading {
                                    Text("最新データ取得中…")
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.bottom, 12)
                        }
                        
                    }
                    .padding(.top)
                }
                .refreshable {
                    fetcher.fetchTasksFromAPI()
                }
            }
        }
        .onAppear {
            fetcher.fetchTasksFromAPI()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                fetcher.fetchTasksFromAPI()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return formatter.string(from: date)
}
