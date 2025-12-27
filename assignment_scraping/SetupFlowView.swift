//
//  SetupFlowView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/09/22.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SetupFlowView: View {
    var onComplete: () -> Void
    
    @State private var isUpdating = false
    @State private var updateProgress: Double = 0.0
    @State private var updateCompleted = false
    @State private var errorMessage: String?
    
    @StateObject private var fetcher = TimetableFetcher()
    
    @State private var updateTask: Task<Void, Never>?
    @State private var progressTimer: Timer?
    
    // Progress bar config
    private let progressTotalDuration: TimeInterval = 120.0 // 全体の想定時間（秒）
    private let progressTickInterval: TimeInterval = 0.1    // 更新間隔（秒）
    
    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }
    
    // MARK: - Academic Year Logic
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
        if (3...8).contains(month) { return year }     // 4〜8月 → その年
        if (9...12).contains(month) { return year }    // 9〜12月 → その年
        return year - 1                                // 1〜2月 → 前年
    }
    private func computeDefaultWindow(today: Date) -> (ay: Int, start: String, end: String, quarters: String) {
        let comps = calendar.dateComponents([.year, .month], from: today)
        let year = comps.year ?? 0
        let month = comps.month ?? 1
        let ay = academicYear(for: today)

        if (3...8).contains(month) {
            return (ay, ymd(ay, 4, 1), ymd(ay, 8, 30), "1,2")
        } else if (9...12).contains(month) {
            let endFeb = isLeapYear(ay + 1) ? 29 : 28
            return (ay, ymd(ay, 9, 1), ymd(ay + 1, 2, endFeb), "3,4")
        } else {
            let endFeb = isLeapYear(year) ? 29 : 28
            return (ay, ymd(ay, 9, 1), ymd(ay + 1, 2, endFeb), "3,4")
        }
    }
    private func entranceYear(from studentNumber: String) -> Int? {
        guard let two = Int(studentNumber.prefix(2)) else { return nil }
        return 2000 + two
    }
    private func hasQ1Q2Data(studentNumber: String, academicYear ay: Int) async -> Bool {
        guard let ent = entranceYear(from: studentNumber) else { return false }
        let db = Firestore.firestore()
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
    
    // MARK: - View
    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("初期セットアップ")
                        .font(.title2)
                        .bold()
                    
                    Text("""
ここでは以下のデータを取得します：
・時間割情報(今年度分のみ)

※この処理には約2分程度かかります。
※更新中は他の画面に移動しないようにしてください。

あとからデータを取得することもできます。
""")
                        .font(.body)
                        .padding(.bottom)
                    
                    if isUpdating {
                        ProgressView(value: updateProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.vertical)
                        Text("更新中です… 他の画面に移動しないでください。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button(role: .destructive, action: cancelUpdate) {
                            Text("キャンセル")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else if updateCompleted {
                        Label("データ更新が完了しました", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                        Button {
                            onComplete()
                        } label: {
                            Text("次へ")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#4B3F96"))
                    } else if let error = errorMessage {
                        Label("エラー: \(error)", systemImage: "xmark.octagon")
                            .foregroundColor(.red)
                            .font(.headline)
                        Button(action: startUpdate) {
                            Text("再試行")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#4B3F96"))
                        Button {
                            onComplete()
                        } label: {
                            Text("スキップ")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#4B3F96"))
                    } else {
                        Button(action: startUpdate) {
                            Text("データ取得を開始")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#4B3F96"))
                        Button {
                            onComplete()
                        } label: {
                            Text("スキップ")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#4B3F96"))
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - 更新処理
    private func startUpdate() {
        isUpdating = true
        updateProgress = 0.0
        errorMessage = nil
        updateCompleted = false
        
        progressTimer?.invalidate()
        let perTick = progressTickInterval / max(progressTotalDuration, 0.1)
        progressTimer = Timer.scheduledTimer(withTimeInterval: progressTickInterval, repeats: true) { timer in
            updateProgress = min(updateProgress + perTick, 1.0)
            if updateProgress >= 1.0 { timer.invalidate() }
        }
        
        updateTask?.cancel()
        updateTask = Task {
            do {
                // ✅ DataUpdateView と同じ期間ロジックを使用
                var window = computeDefaultWindow(today: Date())

                let comps = calendar.dateComponents([.month], from: Date())
                let month = comps.month ?? 1

                let isSecondHalf = (9...12).contains(month) || (1...2).contains(month)

                if isSecondHalf {
                    // 9〜2月は「前期データがあるなら後期だけ、無ければ通年」
                    let hasEarly = await hasQ1Q2Data(studentNumber: studentNumber, academicYear: window.ay)

                    let endFeb = isLeapYear(window.ay + 1) ? 29 : 28

                    if hasEarly {
                        // ✅ すでに1,2Qあるなら 3,4Q だけ
                        window.start = ymd(window.ay, 9, 1)
                        window.end = ymd(window.ay + 1, 2, endFeb)
                        window.quarters = "3,4"
                    } else {
                        // ✅ 1,2Qが無いなら通年（1〜4Q）
                        window.start = ymd(window.ay, 4, 1)
                        window.end = ymd(window.ay + 1, 2, endFeb)
                        window.quarters = "1,2,3,4"
                    }
                }
                // 3〜8月は computeDefaultWindow のまま（1,2Q）
                
                try await fetcher.fetchAndUpload(
                    academicYear: window.ay,
                    quarter: window.quarters,
                    startDate: window.start,
                    endDate: window.end
                )
                
                try Task.checkCancellation()
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
            await MainActor.run {
                progressTimer?.invalidate()
                progressTimer = nil
                updateTask = nil
            }
        }
    }
    
    private func cancelUpdate() {
        updateTask?.cancel()
        progressTimer?.invalidate()
        progressTimer = nil
        isUpdating = false
        if !updateCompleted { errorMessage = "ユーザーがキャンセルしました" }
    }
    
    private func fetchAndUpdateBarcodeCancellable() async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            BarcodeManager.shared.fetchAndSaveBarcode { image in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if image != nil {
                    continuation.resume(returning: ())
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
