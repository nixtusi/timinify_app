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

                        Text("更新中です… 他の画面には移動しないでください。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
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
                            .padding() // ← 内側に配置
                            .background(Color(hex: "#4B3F96"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal) // ← 外側にマージン
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

        // 疑似プログレス（1分想定）
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            updateProgress += 0.02
            if updateProgress >= 1.0 {
                timer.invalidate()
            }
        }

        Task {
            let startDate = "2025-04-01"
            let endDate = "2025-08-30"
            print("時間割情報の取得開始")

            await fetcher.fetchAndUpload(
                quarter: "1,2",
                startDate: startDate,
                endDate: endDate
            )

            print("バーコードの取得開始")
            await fetchAndUpdateBarcode()

            isUpdating = false
            updateCompleted = true
        }
    }

    // MARK: - 修正された fetchAndUpdateBarcode()
    private func fetchAndUpdateBarcode() async {
        isFetchingBarcode = true
        await withCheckedContinuation { continuation in
            BarcodeManager.shared.fetchAndSaveBarcode { image in
                if let image = image {
                    print("✅ バーコード取得・保存成功（DataUpdateView）")
                } else {
                    self.errorMessage = "バーコードの取得に失敗しました"
                }
                isFetchingBarcode = false
                continuation.resume()
            }
        }
    }
}

