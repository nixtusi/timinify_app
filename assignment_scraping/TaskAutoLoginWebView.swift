//
//  TaskAutoLoginWebView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/26.
//

import SwiftUI
import WebKit

struct TaskAutoLoginWebView: View {
    let taskURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showLoadError = false
    @State private var loadErrorMessage = ""

    var body: some View {
        NavigationStack {
            WebViewWrapper(taskURL: taskURL) { message in
                loadErrorMessage = message
                showLoadError = true
            }
                .navigationTitle("BEEF+")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる") { dismiss() }
                    }
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Button("再読み込み") {
//                            NotificationCenter.default.post(name: .taskWebViewReload, object: nil)
//                        }
//                    }
                }
                .alert("読み込みに失敗しました", isPresented: $showLoadError) {
                    Button("閉じる", role: .cancel) {}
                } message: {
                    Text(loadErrorMessage)
                }
        }
    }
}

extension Notification.Name {
    static let taskWebViewReload = Notification.Name("taskWebViewReload")
}

private struct WebViewWrapper: UIViewRepresentable {
    let taskURL: URL
    let onLoadError: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(webView: webView, taskURL: taskURL)

        // 初回ロード
        context.coordinator.request(taskURL)

        // 手動リロード
        context.coordinator.observeReload()

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(webView: webView, taskURL: taskURL)

        // taskURL が変わったら必ずロード（同じURLでも毎回開くなら下の条件外してOK）
        if context.coordinator.currentTaskURL != taskURL {
            context.coordinator.request(taskURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadError: onLoadError)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var currentTaskURL: URL?

        private var lastRequestedURL: URL?
        private var didTrySaml = false
        private var didInjectLogin = false
        private var injectRetryCount = 0
        private var navigationRetryCount = 0
        private let maxNavigationRetries = 5
        private var didNotifyLoadError = false

        private let beefHost = "beefplus.center.kobe-u.ac.jp"
        private let knossosHost = "knossos.center.kobe-u.ac.jp"

        private var reloadObserver: NSObjectProtocol?
        private let onLoadError: (String) -> Void

        init(onLoadError: @escaping (String) -> Void) {
            self.onLoadError = onLoadError
        }

        deinit {
            if let obs = reloadObserver { NotificationCenter.default.removeObserver(obs) }
        }

        func attach(webView: WKWebView, taskURL: URL) {
            self.webView = webView

            if currentTaskURL != taskURL {
                currentTaskURL = taskURL
                // URLが変わったらフラグも初期化
                didTrySaml = false
                didInjectLogin = false
                injectRetryCount = 0
                navigationRetryCount = 0
                didNotifyLoadError = false
            }
        }

        func observeReload() {
            guard reloadObserver == nil else { return }
            reloadObserver = NotificationCenter.default.addObserver(
                forName: .taskWebViewReload,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let url = self.lastRequestedURL ?? self.currentTaskURL {
                    self.request(url)
                }
            }
        }

        func request(_ url: URL) {
            guard let webView else { return }
            lastRequestedURL = url

            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            webView.load(req)
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let host = url.host ?? ""
            navigationRetryCount = 0
            didNotifyLoadError = false

            // 1) BEEF+ loginに落ちたらSAMLへ
            if host == beefHost, url.path.hasPrefix("/login"), !didTrySaml {
                didTrySaml = true
                let saml = URL(string: "https://\(beefHost)/saml/login?disco=true")!
                request(saml)
                return
            }

            // 2) KNOSSOS でログイン注入
            if host == knossosHost,
               url.absoluteString.contains("/login-actions/authenticate"),
               !didInjectLogin {
                tryInjectLogin(webView)
            }
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == -999 {
                // loadが重なったキャンセル。よくあるので放置でOK
                return
            }

            if navigationRetryCount >= maxNavigationRetries {
                if !didNotifyLoadError {
                    didNotifyLoadError = true
                    onLoadError("ページを開けませんでした。通信環境を確認して再度お試しください。")
                }
                return
            }

            navigationRetryCount += 1
            // “白画面固定”回避：少し待って再要求
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, let url = self.lastRequestedURL ?? self.currentTaskURL else { return }
                self.request(url)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // これが「真っ白のまま進まない」の主犯になりがち
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, let url = self.lastRequestedURL ?? self.currentTaskURL else { return }
                self.request(url)
            }
        }

        private func tryInjectLogin(_ webView: WKWebView) {
            if injectRetryCount >= 8 { return }
            injectRetryCount += 1

            let id = LoginCredentials.studentNumber
            let pw = LoginCredentials.password
            guard !id.isEmpty, !pw.isEmpty else { return }

            let js = """
            (function() {
                const u = document.querySelector('#username');
                const p = document.querySelector('#password');
                const btn = document.querySelector('#kc-login');
                if (!u || !p || !btn) { return 'no_form'; }
                u.value = \(jsonStringLiteral(id));
                p.value = \(jsonStringLiteral(pw));
                btn.click();
                return 'submitted';
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self else { return }
                let r = result as? String ?? ""

                if r == "submitted" {
                    self.didInjectLogin = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let taskURL = self.currentTaskURL {
                            self.request(taskURL)
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.tryInjectLogin(webView)
                    }
                }
            }
        }
    }
}

private func jsonStringLiteral(_ s: String) -> String {
    if let data = try? JSONEncoder().encode(s),
       let json = String(data: data, encoding: .utf8) {
        return json
    }
    return "\"\""
}
