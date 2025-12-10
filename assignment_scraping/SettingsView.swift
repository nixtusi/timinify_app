//
//  SettingsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var fetcher = TimetableFetcher()

    @State private var showingLogoutAlert = false
    @State private var resetMessage: String?
    @State private var showingResetAlert = false
    @State private var showingResetConfirmAlert = false
    
    @State private var barcodeImage: UIImage? = nil
    @State private var isFetchingBarcode = false
    
    @State private var showingDeleteAlert = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var deleteStep: String?

    // 変更: 確認メール/リセットメールのクールダウン管理
    @State private var verifyResendRemaining = 0            // 変更: 確認メールクールダウン（秒）
    @State private var verifyResendTimer: Timer?            // 変更: タイマー
    @State private var resetResendRemaining = 0             // 変更: パスワードリセットクールダウン（秒）
    @State private var resetResendTimer: Timer?             // 変更: タイマー

    private var studentNumber: String {
        let email = Auth.auth().currentUser?.email ?? ""
        return email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
    }
    private var email: String {
        Auth.auth().currentUser?.email ?? ""
    }

    // 変更: メール確認済みを都度反映
    @State private var isVerified: Bool = false             // 変更: 確認状態キャッシュ

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            Form {
                Section(header: Text("図書館入館証")) {
                    ZStack {
                        Color.white // ダークモード時でも白背景に固定
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        
                        VStack {
                            if isFetchingBarcode {
                                ProgressView()
                                    .padding()
                            } else if let image = barcodeImage {
                                HStack {
                                    Spacer()
                                    // ✅ VStackで画像とテキストを縦並びに
                                    VStack(spacing: 4) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                        
                                        // ✅ 追加: バーコード番号の表示
                                        if let code = BarcodeManager.shared.getBarcodeNumber(for: studentNumber) {
                                            Text(code)
                                                .font(.caption)
                                                .monospacedDigit() // 等幅数字で見やすく
                                                .foregroundColor(.black)
                                                .padding(.bottom, 8)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.top) // 上の余白
                            } else {
                                Text("バーコード未取得")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets()) // セクション外の余白を詰める
                }
                
                Section(header: Text("アカウント")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(studentNumber)
                            .font(.body)
                            .foregroundColor(.primary)

                        // 変更: 確認状態の表示
                        HStack {
                            Label(isVerified ? "メール確認済み" : "メール未確認", systemImage: isVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isVerified ? .green : .orange)
                                .font(.subheadline)

                            Spacer()

                            // 変更: 未確認の場合のみ「確認メール再送」
                            if !isVerified {
                                Button {
                                    resendVerificationEmail()
                                } label: {
                                    Text(verifyResendRemaining > 0 ? "再送 (\(verifyResendRemaining)s)" : "確認メールを再送")
                                        .font(.footnote.weight(.semibold))
                                }
                                .disabled(verifyResendRemaining > 0)
                            }
                        }

                        if !isVerified {
                            Text("※ 受信トレイ／迷惑メールをご確認ください。リンクは一定時間で失効します。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("その他")) {
                    NavigationLink(destination: DataUpdateView()) {
                        Text("データを更新する")
                            .foregroundColor(.primary)
                    }

                    NavigationLink(destination: TermsView()) {
                        Text("利用規約")
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://nixtusi.github.io/unitime-privacy/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("プライバシーポリシー (外部リンク)")
                    }

                    // 変更: パスワード再設定メールもクールダウン付きに
                    Button {
                        showingResetConfirmAlert = true
                    } label: {
                        Text(resetResendRemaining > 0 ? "パスワードを変更（\(resetResendRemaining)s）" : "パスワードを変更")
                    }
                    .disabled(resetResendRemaining > 0)
                    .alert("パスワード変更のためのメールを送信しますか？", isPresented: $showingResetConfirmAlert) {
                        Button("送信", role: .none) {
                            sendPasswordResetEmail()
                        }
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("※BEEF+ とは異なるパスワードでアカウントを作成してしまった場合のみ使用してください。")
                    }

                    Button(action: {
                        if let url = URL(string: "https://forms.gle/1bdUg6UyFgASGwNR6") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("お問い合わせ")
                    }

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("ログアウト")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Text("アカウント削除")
                    }
                    .alert("本当に削除しますか？", isPresented: $showingDeleteAlert) {
                        Button("削除する", role: .destructive) {
                            Task {
                                await deleteAccount()
                            }
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        Text("Uni Timeサービスにおける時間割などのあなたのアカウントは削除されます。口コミは匿名のまま残ります。")
                    }
                }
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
        }
        .onAppear {
            loadSavedBarcodeImage()
            refreshVerificationState() // 変更: 画面表示時に確認状態を更新
        }
        .alert("パスワード再設定", isPresented: $showingResetAlert, presenting: resetMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .alert("ログアウトしますか？", isPresented: $showingLogoutAlert) {
            Button("ログアウト", role: .destructive, action: logout)
            Button("キャンセル", role: .cancel) {}
        }
        .onDisappear {
            // 変更: タイマーのクリーンアップ
            verifyResendTimer?.invalidate()
            verifyResendTimer = nil
            resetResendTimer?.invalidate()
            resetResendTimer = nil
        }
    }

    // MARK: - メール確認（再送）

    // 変更: 確認状態の即時更新
    private func refreshVerificationState() {
        Auth.auth().currentUser?.reload { _ in
            self.isVerified = Auth.auth().currentUser?.isEmailVerified ?? false
        }
    }

    // 変更: 汎用クールダウンセット（確認メール）
    private func startVerifyCooldown(_ sec: Int) {
        verifyResendRemaining = max(0, sec)
        verifyResendTimer?.invalidate()
        guard sec > 0 else { return }
        verifyResendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.verifyResendRemaining > 0 {
                self.verifyResendRemaining -= 1
            } else {
                t.invalidate()
            }
        }
    }

    // 変更: 汎用クールダウンセット（パスワードリセット）
    private func startResetCooldown(_ sec: Int) {
        resetResendRemaining = max(0, sec)
        resetResendTimer?.invalidate()
        guard sec > 0 else { return }
        resetResendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if self.resetResendRemaining > 0 {
                self.resetResendRemaining -= 1
            } else {
                t.invalidate()
            }
        }
    }

    // 変更: Dynamic Links 非依存（ActionCodeSettings なし）で再送
    private func resendVerificationEmail() {
        // クールダウン中は何もしない
        guard verifyResendRemaining == 0 else { return }

        // 状態更新
        Auth.auth().currentUser?.reload(completion: { reloadError in
            if let e = reloadError {
                // ネットワーク等の一時的な失敗 → 短いクールダウン
                self.resetMessage = "状態更新エラー: \(e.localizedDescription)"
                self.showingResetAlert = true
                self.startVerifyCooldown(60) // 変更: 60秒
                return
            }

            // すでに確認済みなら終了
            if Auth.auth().currentUser?.isEmailVerified == true {
                self.isVerified = true
                self.resetMessage = "✅ すでにメール確認が完了しています。"
                self.showingResetAlert = true
                return
            }

            Auth.auth().currentUser?.sendEmailVerification(completion: { error in
                if let error = error as NSError? {
                    let code = AuthErrorCode(_bridgedNSError: error)?.code
                    switch code {
                    case .tooManyRequests:
                        self.resetMessage = "送信が多すぎます。しばらく待ってから再度お試しください。"
                        self.startVerifyCooldown(600) // 変更: 10分
                    case .networkError:
                        self.resetMessage = "ネットワークエラー。接続を確認してから再度お試しください。"
                        self.startVerifyCooldown(120) // 変更: 2分
                    case .userDisabled:
                        self.resetMessage = "このアカウントは無効化されています。"
                        self.startVerifyCooldown(600)
                    case .invalidRecipientEmail, .invalidSender, .invalidMessagePayload:
                        self.resetMessage = "メール送信設定に問題があります。時間をおいてお試しください。"
                        self.startVerifyCooldown(300)
                    default:
                        self.resetMessage = "再送信に失敗しました: \(error.localizedDescription)"
                        self.startVerifyCooldown(180) // 変更: デフォルト3分
                    }
                } else {
                    self.resetMessage = "\(self.email) に確認メールを再送しました。受信トレイと迷惑メールをご確認ください。"
                    self.startVerifyCooldown(180) // 変更: 成功時3分
                }
                self.showingResetAlert = true
            })
        })
    }

    // MARK: - パスワード再設定

    private func sendPasswordResetEmail() {
        guard !email.isEmpty else {
            self.resetMessage = "メールアドレスを確認できませんでした。再度ログインし直してください。"
            self.showingResetAlert = true
            return
        }

        // 変更: クールダウン中は送信せず
        guard resetResendRemaining == 0 else { return }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error as NSError? {
                let code = AuthErrorCode(_bridgedNSError: error)?.code
                switch code {
                case .tooManyRequests:
                    self.resetMessage = "送信が多すぎます。しばらく待ってから再度お試しください。"
                    self.startResetCooldown(600) // 変更: 10分
                case .networkError:
                    self.resetMessage = "ネットワークエラー。接続を確認してから再度お試しください。"
                    self.startResetCooldown(120) // 変更: 2分
                case .userNotFound:
                    self.resetMessage = "ユーザーが見つかりません。再ログイン後にお試しください。"
                    self.startResetCooldown(180)
                default:
                    self.resetMessage = "送信に失敗しました: \(error.localizedDescription)"
                    self.startResetCooldown(180) // 変更: デフォルト3分
                }
            } else {
                self.resetMessage = "\(self.email) にパスワード再設定用のメールを送信しました。受信トレイと迷惑メールをご確認ください。"
                self.startResetCooldown(180) // 変更: 成功時3分
            }
            self.showingResetAlert = true
        }
    }

    // MARK: - ログアウト

    private func logout() {
        do {
            try Auth.auth().signOut()
            appState.isLoggedIn = false
            UserDefaults.standard.removeObject(forKey: "studentNumber")
            UserDefaults.standard.removeObject(forKey: "loginPassword")
        } catch {
            resetMessage = "ログアウトに失敗しました: \(error.localizedDescription)"
            showingResetAlert = true
        }
    }

    // MARK: - 図書館バーコード

    private func loadSavedBarcodeImage() {
        isFetchingBarcode = true
        DispatchQueue.global().async {
            let image = BarcodeManager.shared.loadSavedBarcodeImage()
            DispatchQueue.main.async {
                self.barcodeImage = image
                self.isFetchingBarcode = false
            }
        }
    }
    
    // MARK: - アカウント削除

    @MainActor
    private func deleteAccount() async {
        deleting = true
        deleteError = nil
        deleteStep = "再認証中…"

        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            deleting = false
            deleteError = "ユーザー情報を取得できませんでした。"
            return
        }

        // 再認証（直近ログインでないと削除が失敗する）
        if let password = UserDefaults.standard.string(forKey: "loginPassword"), !password.isEmpty {
            do {
                let cred = EmailAuthProvider.credential(withEmail: email, password: password)
                _ = try await user.reauthenticate(with: cred)
            } catch {
                deleting = false
                deleteError = "再認証に失敗しました。再ログイン後にお試しください。\n\(error.localizedDescription)"
                return
            }
        } else {
            deleting = false
            deleteError = "端末にパスワードが見つかりません。再ログイン後、もう一度お試しください。"
            return
        }

        let db = Firestore.firestore()

        // 学籍番号・入学年度など
        let studentNumber = email.replacingOccurrences(of: "@stu.kobe-u.ac.jp", with: "")
        let entryYear: Int? = {
            guard let two = Int(studentNumber.prefix(2)) else { return nil }
            return 2000 + two
        }()

        // 1) Firestore: users/{uid} を削除
        do {
            deleteStep = "ユーザーデータ削除中…"
            try await db.collection("users").document(user.uid).delete()
        } catch {
            // users が無くても続行
            print("users削除エラー: \(error.localizedDescription)")
        }

        // 2) Firestore: Timetable ツリーを削除（既知の構造のみ）
        // /Timetable/{entryYear}/{studentNumber}/{AY}/Q{1..4}/{doc}
        if let ent = entryYear {
            let base = db.collection("Timetable").document("\(ent)").collection(studentNumber)
            // 学年は4年分をざっくりスキャン（必要に応じて調整）
            let thisYear = Calendar.current.component(.year, from: Date())
            let years = (thisYear-3)...(thisYear+1)
            for y in years {
                deleteStep = "時間割 \(y) 年度の削除中…"
                let yearDoc = base.document("\(y)")
                for q in 1...4 {
                    let qsnap = try? await yearDoc.collection("Q\(q)").getDocuments()
                    if let docs = qsnap?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        do { try await batch.commit() } catch { print("Q\(q) バッチ削除失敗: \(error.localizedDescription)") }
                    }
                }
                // 年度ドキュメント本体はフィールド無しなら何もせず。必要なら yearDoc.delete()
            }
        }

        // 3) 端末ローカルのクリア
        deleteStep = "ローカルデータの消去中…"
        UserDefaults.standard.removeObject(forKey: "studentNumber")
        UserDefaults.standard.removeObject(forKey: "loginPassword")
        UserDefaults.standard.removeObject(forKey: "cachedTimetableItems")

        // ウィジェットのキャッシュ消去（App Group）
        if let ud = UserDefaults(suiteName: "group.com.yuta.beefapp") {
            ud.removeObject(forKey: "widgetTimetableToday")
        }
        WidgetCenter.shared.reloadAllTimelines()

        // 図書館バーコード画像があれば削除
        BarcodeManager.shared.deleteSavedBarcode()

        // 4) Firebase Auth のユーザー削除
        deleteStep = "アカウント削除中…"
        do {
            try await user.delete()
        } catch {
            deleting = false
            deleteError = "アカウント削除に失敗しました: \(error.localizedDescription)"
            return
        }

        // 5) ログアウト状態へ
        deleteStep = "サインアウト中…"
        try? Auth.auth().signOut()
        appState.isLoggedIn = false

        deleting = false
        deleteStep = nil
    }
}
