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

    var body: some View {
        NavigationStack {
            WebViewWrapper(taskURL: taskURL)
                .navigationTitle("BEEF+")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

private struct WebViewWrapper: UIViewRepresentable {
    let taskURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Cookie保持したいので default() を使う（消さない限り残る）
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        context.coordinator.taskURL = taskURL
        context.coordinator.webView = webView

        webView.load(URLRequest(url: taskURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var taskURL: URL?

        private var didTrySaml = false
        private var didInjectLogin = false

        // ★ ここは “自動ログインを注入して良いドメイン” を固定（超重要）
        private let beefHost = "beefplus.center.kobe-u.ac.jp"
        private let knossosHost = "knossos.center.kobe-u.ac.jp"

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let host = url.host ?? ""

            // 1) まずBEEF+側で login に落ちたら SAML に直行
            if host == beefHost, url.path.hasPrefix("/login") {
                // Pythonと同じ「SAMLログインへ直行」発想
                if !didTrySaml {
                    didTrySaml = true
                    let saml = URL(string: "https://\(beefHost)/saml/login?disco=true")!
                    webView.load(URLRequest(url: saml))
                }
                return
            }

            // 2) KNOSSOS のログインフォームが出たら JS でID/PW入力→submit
            if host == knossosHost,
               url.absoluteString.contains("/login-actions/authenticate"),
               !didInjectLogin {

                let id = LoginCredentials.studentNumber
                let pw = LoginCredentials.password
                guard !id.isEmpty, !pw.isEmpty else { return }

                didInjectLogin = true

                // JSで #username #password に入力してフォーム送信
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

                webView.evaluateJavaScript(js) { [weak self] result, error in
                    if error != nil { return }
                    // 送信後、BEEF+側へ戻ったら課題URLへ戻す（cookieが付く）
                    // ※戻り検知は didCommit / decidePolicy でもOK。ここでは単純に少し待ってからリロードでも可
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let taskURL = self?.taskURL {
                            webView.load(URLRequest(url: taskURL))
                        }
                    }
                }
                return
            }
        }
    }
}

// JSに安全に文字列を渡すための補助
private func jsonStringLiteral(_ s: String) -> String {
    // "..." のJSON文字列として埋め込む（改行や " を壊さない）
    if let data = try? JSONEncoder().encode(s),
       let json = String(data: data, encoding: .utf8) {
        return json
    }
    return "\"\""
}
