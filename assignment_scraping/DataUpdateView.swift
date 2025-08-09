//
//  DataUpdateView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/23.
//
//

import SwiftUI
import FirebaseAuth

struct DataUpdateView: View {
    @State private var isUpdating = false
    @State private var updateProgress: Double = 0.0
    @State private var updateCompleted = false
    @State private var errorMessage: String?
    @State private var isFetchingBarcode = false

    @StateObject private var fetcher = TimetableFetcher()

    // ✅ 追加：実行中タスクとタイマーを握る
    @State private var updateTask: Task<Void, Never>?
    @State private var progressTimer: Timer?

    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("データ更新について")
                    .font(.title2)
                    .bold()

                Text("""
この処理では以下のデータを取得します：
・時間割情報(今年度分のみ)
・図書館入館証（バーコード）

※この処理には約1分程度かかります。
※更新中は他の画面に移動しないようにしてください。
""")
                    .font(.body)

                if isUpdating {
                    VStack(spacing: 16) {
                        ProgressView(value: updateProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.vertical)

                        Text("更新中です… 他の画面に移動しないでください。")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        // ✅ 追加：キャンセルボタン
                        Button(role: .destructive) {
                            cancelUpdate()
                        } label: {
                            Text("キャンセル")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemRed))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else if updateCompleted {
                    Label("データ更新が完了しました", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.headline)
                } else if let error = errorMessage {
                    Label("更新中にエラーが発生しました: \(error)", systemImage: "xmark.octagon")
                        .foregroundColor(.red)
                        .font(.headline)
                } else {
                    Button(action: startUpdate) {
                        Text("更新を開始する")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#4B3F96"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .navigationTitle("データ更新")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startUpdate() {
        isUpdating = true
        updateProgress = 0.0
        errorMessage = nil
        updateCompleted = false

        // ✅ タイマーを保持（後で無効化できるように）
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            updateProgress = min(updateProgress + 0.02, 1.0)
            if updateProgress >= 1.0 { timer.invalidate() }
        }

        // ✅ 実タスクを保持（後で cancel できるように）
        updateTask?.cancel()
        updateTask = Task {
            do {
                let startDate = "2025-04-01"
                let endDate   = "2025-08-30"

                // ❗️フェッチ側もキャンセル協調が必要（下で解説）
                try await fetcher.fetchAndUpload(
                    quarter: "1,2",
                    startDate: startDate,
                    endDate: endDate
                )

                try Task.checkCancellation() // ✅ 途中でキャンセルされたらここで throw

                try await fetchAndUpdateBarcodeCancellable()

                await MainActor.run {
                    isUpdating = false
                    updateCompleted = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = "キャンセルしました"
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                }
            }

            // ✅ 後片付け
            await MainActor.run {
                progressTimer?.invalidate()
                progressTimer = nil
                updateTask = nil
            }
        }
    }

    private func cancelUpdate() {
        // ✅ タスク・タイマーを止め、UIを即座に更新
        updateTask?.cancel()
        progressTimer?.invalidate()
        progressTimer = nil

        isUpdating = false
        if !updateCompleted { errorMessage = "ユーザーがキャンセルしました" }
    }

    // MARK: - バーコードのキャンセル協調版
    private func fetchAndUpdateBarcodeCancellable() async throws {
        try Task.checkCancellation()
        isFetchingBarcode = true
        defer { isFetchingBarcode = false }

        // ✅ 1) 継続の型を明示（CheckedContinuation<Void, Error>）
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            BarcodeManager.shared.fetchAndSaveBarcode { image in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if image != nil {
                    print("✅ バーコード取得・保存成功（DataUpdateView）")
                    continuation.resume(returning: ())   // ✅ 2) Void を返す
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "Barcode",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "バーコードの取得に失敗しました"]
                        )
                    )
                }
            }
        }
    }
}
