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
    
    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    @AppStorage("taskOpenMode") private var taskOpenModeRaw: String = TaskOpenMode.external.rawValue
    @State private var selectedTask: SelectedTaskURL? = nil
    @Binding var pendingTaskURL: URL?

    init(pendingTaskURL: Binding<URL?> = .constant(nil)) {
        _pendingTaskURL = pendingTaskURL
    }

    // ✅ 緊急度に応じた色を判定する関数
    private func urgencyColor(deadline: String, now: Date) -> Color {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let date = formatter.date(from: deadline) else { return .green }

        let diff = date.timeIntervalSince(now)
        if diff < 24 * 60 * 60 { return .red }
        else if diff < 3 * 24 * 60 * 60 { return .yellow }
        else { return .green }
    }

    var body: some View {
        ZStack {
            // 背景色を少しグレーにしてカードを目立たせる
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) { // LazyVStackで描画効率化

                        // ✅ 1. 更新ボタン・残り回数・最終更新時間のヘッダー
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // 手動更新ボタン
                                Button {
                                    fetcher.fetchTasksFromAPI()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                        Text("更新")
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    // 制限に達しているかロード中はグレーアウト
                                    .background(fetcher.isLoading || fetcher.fetchLimitReached ? Color(.systemGray5) : Color.accentColor.opacity(0.1))
                                    .foregroundColor(fetcher.isLoading || fetcher.fetchLimitReached ? .secondary : Color.accentColor)
                                    .cornerRadius(8)
                                }
                                .disabled(fetcher.isLoading || fetcher.fetchLimitReached)
                                
                                // ✅ 変更: インスタンスプロパティの maxDailyFetches を使用
                                Text("残り \(fetcher.remainingFetches)/\(fetcher.maxDailyFetches)回")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // 最終更新時間
                                if fetcher.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("更新中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let updated = fetcher.lastUpdated {
//                                    Image(systemName: "clock")
//                                        .font(.caption2)
//                                        .foregroundColor(.secondary)
                                    
                                    Text("最終更新:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if Date().timeIntervalSince(updated) > 24 * 60 * 60 {
                                        Text("1日前")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(formattedDate(updated))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // ✅ 自動更新停止の注意書き
                            Text("※自動更新は行われません。ボタンorスワイプで更新してください。")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        // 0件時の空表示
                        if fetcher.tasks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text(fetcher.infoMessage ?? "未提出の課題・テスト一覧はありません。")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.top, 60)
                        }

                        // 課題リスト
                        ForEach(fetcher.tasks) { beefTask in
                            TaskCardView(
                                task: beefTask,
                                color: urgencyColor(deadline: beefTask.deadline, now: now)
                            )
                            .onTapGesture {
                                guard let url = URL(string: beefTask.url) else { return }

                                let mode = TaskOpenMode(rawValue: taskOpenModeRaw) ?? .external
                                if mode == .external {
                                    UIApplication.shared.open(url)
                                } else {
                                    selectedTask = SelectedTaskURL(url: url)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20) // 下部の余白
                }
                .refreshable {
                    fetcher.fetchTasksFromAPI()
                }
            }
        }
        .onAppear {
            // fetcher.fetchTasksFromAPI() // ✅ コメントアウト: 自動取得停止
            now = Date()
            fetcher.loadSavedTasks() // 保存データのロードのみ
            fetcher.checkDailyLimit() // 回数制限のチェック
            consumePendingTaskURL()
        }
        .onChange(of: pendingTaskURL) { _, _ in
            consumePendingTaskURL()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                now = Date()
                // fetcher.fetchTasksFromAPI() // ✅ コメントアウト: 自動取得停止
                fetcher.checkDailyLimit() // 日付変更チェック
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
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
        .onReceive(ticker) { now = $0 }
        .sheet(item: $selectedTask) { item in
            TaskAutoLoginWebView(taskURL: item.url)
        }
    }

    private func consumePendingTaskURL() {
        guard let url = pendingTaskURL else { return }
        selectedTask = SelectedTaskURL(url: url)
        pendingTaskURL = nil
    }
}

private struct SelectedTaskURL: Identifiable {
    let id = UUID()
    let url: URL
}


// ✅ デザインを整えたカードView（別構造体にしてスッキリさせる）
struct TaskCardView: View {
    let task: BeefTask
    let color: Color
    
    var body: some View {
        HStack(spacing: 0) {
            // 左側のカラーバー
            Rectangle()
                .fill(color)
                .frame(width: 5)
            
            VStack(alignment: .leading, spacing: 8) {
                // コース名（少し小さく控えめに）
                Text(task.course)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // タイトル（大きく目立たせる）
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true) // 複数行になっても表示崩れを防ぐ
                
                Divider() // 区切り線を入れて情報を整理
                
                // 締切と残り時間
                HStack {
                    // 締切
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(task.formattedDeadlineWithDay)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 残り時間 (緊急度色を反映)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(task.timeRemaining)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color) // 文字色もバーの色と合わせる
                }
            }
            .padding(12) // カード内部の余白
        }
        .background(Color(.secondarySystemGroupedBackground)) // カード背景色
        .cornerRadius(10) // 角丸
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2) // 優しい影をつける
        .padding(.horizontal) // 画面端からの余白
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return formatter.string(from: date)
}
