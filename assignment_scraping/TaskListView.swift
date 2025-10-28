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

                        // ✅ 変更: 0件時の空表示（infoMessage を優先）
                        if fetcher.tasks.isEmpty {
                            VStack(spacing: 8) {
                                Text(fetcher.infoMessage ?? "未提出の課題・テスト一覧はありません。")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.top, 24)
                        }

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

                        // ✅ 変更: 下部情報は infoMessage / lastUpdated / isLoading いずれかがあれば表示
                        if !fetcher.tasks.isEmpty || fetcher.lastUpdated != nil || fetcher.isLoading || fetcher.infoMessage != nil {
                            HStack(spacing: 8) {
                                if let updated = fetcher.lastUpdated {
                                    if Date().timeIntervalSince(updated) > 24*60*60 {
                                        Text("最終更新 24時間以上前")
                                    } else {
                                        Text("最終更新 \(formattedDate(updated))")
                                    }
                                }
                                if fetcher.isLoading {
                                    Text("最新データ取得中…")
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.bottom, 12)
                        }

                        // ❌（削除方針）従来の赤字テキストによるエラー表示は不要に
                        // ✅ 変更: アラートに一本化するためコメントアウト
                        /*
                        if let error = fetcher.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        }
                        */
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                fetcher.fetchTasksFromAPI()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        // ✅ 変更: アラート追加（サーバー停止メッセージを優先表示）
        .alert(isPresented: $fetcher.showErrorAlert) {
            let title = fetcher.isServerDown ? "サーバー停止中" : "エラー"
            let message = fetcher.isServerDown
            ? (fetcher.errorMessage ?? "サーバーが停止しているため新たな課題取得をできません。時間をおいて再度お試しください。")
            : (fetcher.errorMessage ?? "不明なエラーが発生しました。")

            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}


private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return formatter.string(from: date)
}
