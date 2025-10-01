//
//  DataUpdateView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/23.
//
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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

    // Progress bar config
    private let progressTotalDuration: TimeInterval = 120.0 // 全体の想定時間（秒）
    private let progressTickInterval: TimeInterval = 0.1    // 更新間隔（秒）

    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }

    private let calendar = Calendar(identifier: .gregorian)

    private func isLeapYear(_ year: Int) -> Bool {
        if year % 400 == 0 { return true }
        if year % 100 == 0 { return false }
        return year % 4 == 0
    }
    private func ymd(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }
    private func academicYear(for date: Date) -> Int {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return 0 }
        // 3月〜8月はその年が学年、9月〜翌2月は9月の年が学年
        if (3...8).contains(month) { return year }
        if (9...12).contains(month) { return year }
        // 1〜2月は前年の学年に属する
        return year - 1
    }
    private func computeDefaultWindow(today: Date) -> (ay: Int, start: String, end: String, quarters: String) {
        let comps = calendar.dateComponents([.year, .month], from: today)
        let year = comps.year ?? 0
        let month = comps.month ?? 1
        let ay = academicYear(for: today)

        if (3...8).contains(month) {
            // Q1, Q2 within same academic year
            let start = ymd(ay, 4, 1)
            let end = ymd(ay, 8, 30)
            return (ay, start, end, "1,2")
        } else if (9...12).contains(month) {
            // Q3, Q4 spanning into next calendar year
            let endFeb = isLeapYear(ay + 1) ? 29 : 28
            let start = ymd(ay, 9, 1)
            let end = ymd(ay + 1, 2, endFeb)
            return (ay, start, end, "3,4")
        } else {
            // Jan-Feb belong to previous academic year's Q3/Q4
            let endFeb = isLeapYear(year) ? 29 : 28 // year here is the current calendar year which equals (ay+1)
            let start = ymd(ay, 9, 1)
            let end = ymd(ay + 1, 2, endFeb)
            return (ay, start, end, "3,4")
        }
    }
    private func entranceYear(from studentNumber: String) -> Int? {
        let prefix = String(studentNumber.prefix(2))
        guard let two = Int(prefix) else { return nil }
        return 2000 + two
    }
    private func hasQ1Q2Data(studentNumber: String, academicYear ay: Int) async -> Bool {
        guard let ent = entranceYear(from: studentNumber) else { return false }
        let db = Firestore.firestore()

        // paths like: /Timetable/{entranceYear}/{studentNumber}/{ay}/Q1 and Q2
        let base = db.collection("Timetable").document("\(ent)").collection(studentNumber).document("\(ay)")
        do {
            let q1Snap = try await base.collection("Q1").limit(to: 1).getDocuments()
            if !q1Snap.documents.isEmpty { return true }
            let q2Snap = try await base.collection("Q2").limit(to: 1).getDocuments()
            return !q2Snap.documents.isEmpty
        } catch {
            return false
        }
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("データ更新について")
                        .font(.title2)
                        .bold()

                    Text("""
この処理では以下のデータを取得します：
・時間割情報(今年度分のみ)
・図書館入館証（バーコード）

※この処理には約2分程度かかります。
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
//                        Button(action: startUpdate) {
//                            Text("更新を開始する")
//                                .bold()
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color(hex: "#4B3F96"))
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
                        
                        Button {
                            startUpdate()
                        } label: {
                            Text("更新を開始する")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#4B3F96"))
                        .listRowInsets(.init()) // 端まで広げて押しやすく
                    }
                }
                .padding()
            }
        }
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
        let perTick = progressTickInterval / max(progressTotalDuration, 0.1)
        progressTimer = Timer.scheduledTimer(withTimeInterval: progressTickInterval, repeats: true) { timer in
            updateProgress = min(updateProgress + perTick, 1.0)
            if updateProgress >= 1.0 { timer.invalidate() }
        }

        // ✅ 実タスクを保持（後で cancel できるように）
        updateTask?.cancel()
        updateTask = Task {
            do {
                var window = computeDefaultWindow(today: Date())
                let hasEarly = await hasQ1Q2Data(studentNumber: studentNumber, academicYear: window.ay)
                if !hasEarly {
                    let endFeb = isLeapYear(window.ay + 1) ? 29 : 28
                    window.start = ymd(window.ay, 4, 1)
                    window.end = ymd(window.ay + 1, 2, endFeb)
                    window.quarters = "1,2,3,4"
                }

                // ❗️フェッチ側もキャンセル協調が必要（下で解説）
                try await fetcher.fetchAndUpload(
                    quarter: window.quarters,
                    startDate: window.start,
                    endDate: window.end
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
