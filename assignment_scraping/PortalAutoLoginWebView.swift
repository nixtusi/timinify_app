//
//  PortalAutoLoginWebView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/26.
//

import SwiftUI
import WebKit

struct PortalAutoLoginWebView: UIViewRepresentable {
    let portal: PortalKind
    let destinationURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(portal: portal, destinationURL: destinationURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.add(context.coordinator, name: "log")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Scraperと同じUAにする（効くこと多い）
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"

        let startURL: URL = {
            switch portal {
            case .beef:
                return URL(string: "https://beefplus.center.kobe-u.ac.jp/login")!
            case .uribo:
                return URL(string: "https://www.uriboportal.ofc.kobe-u.ac.jp/")!
            }
        }()

        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let portal: PortalKind
        let destinationURL: URL

        private var didNavigateToDestinationAfterLogin = false
        private var didSubmitLogin = false
        private var didClickSurvey = false
        private var didKickStartUriboPortal = false
        // ✅ Beef+ 状態
        private var didClickComAuth = false
        private var didSubmitKnossos = false
        private var didGoDestination = false

        init(portal: PortalKind, destinationURL: URL) {
            self.portal = portal
            self.destinationURL = destinationURL
        }

        // JS → Swift log
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            print("🌐JS:", message.body)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        // window.open / target=_blank 対策（同じwebViewに吸収）
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }

            switch portal {
            case .beef:
                handleBeefLikeScraper(webView: webView, url: url.absoluteString)
            case .uribo:
                handleUribo(webView: webView, url: url)
            }
        }

        // MARK: - Beef+
        private func handleBeefLikeScraper(webView: WKWebView, url: String) {
            // 1) BEEF+ /login なら 共通認証ボタンを押す
            if url.hasPrefix("https://beefplus.center.kobe-u.ac.jp/login") {
                
                webView.load(URLRequest(url: URL(string:"https://beefplus.center.kobe-u.ac.jp/saml/loginyu?disco=true")!))
                
                if didClickComAuth { return }
                didClickComAuth = true

                let js = """
                (function() {
                    var btn = document.querySelector('#comAuth a.login-btn');
                    if (btn) { btn.click(); return 'clicked_saml'; }
                    return 'button_not_found';
                })();
                """
                webView.evaluateJavaScript(js)
                return
            }

            // 2) KNOSSOSログイン画面なら入力して submit
            if url.contains("knossos.center.kobe-u.ac.jp/auth") {
                if didSubmitKnossos { return }

                let id = LoginCredentials.studentNumber
                let pw = LoginCredentials.password
                guard !id.isEmpty, !pw.isEmpty else { return }

                didSubmitKnossos = true

                let js = """
                (function() {
                    var u = document.getElementById('username');
                    var p = document.getElementById('password');
                    var b = document.getElementById('kc-login');
                    if (u && p && b) {
                        u.value = '\(escapeJS(id))';
                        u.dispatchEvent(new Event('input',{bubbles:true}));
                        p.value = '\(escapeJS(pw))';
                        p.dispatchEvent(new Event('input',{bubbles:true}));
                        b.click();
                        return 'submitted';
                    }
                    return 'form_not_found';
                })();
                """
                webView.evaluateJavaScript(js)
                return
            }

            // 3) BEEF+ドメインに戻ったら目的URLへ（1回だけ）
            if url.contains("beefplus.center.kobe-u.ac.jp") {
                if didGoDestination { return }
                // まだログイン途中のURLの可能性があるので、lmsに入れそうなら飛ばす
                didGoDestination = true
                webView.load(URLRequest(url: destinationURL))
                return
            }
        }

        // MARK: - Uribo
        private func handleUribo(webView: WKWebView, url: URL) {
            let host = url.host ?? ""
            let allowed =
                host.contains("uriboportal.ofc.kobe-u.ac.jp") ||
                host.contains("knossos.center.kobe-u.ac.jp") ||
                host.contains("kym22-web.ofc.kobe-u.ac.jp")

            guard allowed else { return }

            // ✅ uriboportal のトップではまず「ログイン」をクリックしてKnossosへ飛ばす
            if host.contains("uriboportal.ofc.kobe-u.ac.jp"), !didKickStartUriboPortal {
                didKickStartUriboPortal = true

                let log = "window.webkit?.messageHandlers?.log?.postMessage"
                let jsKick = """
                (function(){
                    \(log)('kickstart: try click login');

                    // まずテキストで探す
                    const btns = Array.from(document.querySelectorAll('a,button,input[type=button],input[type=submit]'));
                    const pick = btns.find(el => {
                        const t = (el.innerText || el.value || '').trim();
                        return /ログイン|サインイン|Login/i.test(t);
                    });

                    if (pick) {
                        \(log)('kickstart: found by text');
                        // aタグならhrefに飛ぶ（target=_blank対策）
                        if (pick.tagName.toLowerCase() === 'a' && pick.href) {
                            location.href = pick.href;
                        } else {
                            pick.click();
                        }
                        return 'clicked';
                    }

                    // href で探す（Shibboleth/Knossos系）
                    const a = Array.from(document.querySelectorAll('a[href]')).find(a =>
                        /Shibboleth\\.sso\\/Login|knossos\\.center\\.kobe-u\\.ac\\.jp/i.test(a.href)
                    );
                    if (a) {
                        \(log)('kickstart: found by href -> ' + a.href);
                        location.href = a.href;
                        return 'clicked_href';
                    }

                    \(log)('kickstart: no login link/button found');
                    return 'no';
                })();
                """
                webView.evaluateJavaScript(jsKick)
                return
            }

            // Logoutに飛んだら入口に戻す
            if url.absoluteString.contains("/Shibboleth.sso/Logout") {
                let start = URL(string: "https://www.uriboportal.ofc.kobe-u.ac.jp/")!
                webView.load(URLRequest(url: start))
                return
            }

            let id = LoginCredentials.studentNumber
            let pw = LoginCredentials.password
            guard !id.isEmpty, !pw.isEmpty else { return }

            let log = "window.webkit?.messageHandlers?.log?.postMessage"

            // ① ログインフォームがあるなら1回だけsubmit
            if !didSubmitLogin {
                let jsLogin = """
                (function(){
                    \(log)('URIBO url=' + location.href);

                    var u = document.querySelector('#username');
                    var p = document.querySelector('#password');
                    var btn = document.querySelector('#kc-login');

                    if(u && p && btn){
                        \(log)('login form found -> submit');
                        u.value='\(escapeJS(id))';
                        u.dispatchEvent(new Event('input',{bubbles:true}));

                        p.value='\(escapeJS(pw))';
                        p.dispatchEvent(new Event('input',{bubbles:true}));

                        btn.click();
                        return 'submitted';
                    }
                    return 'no_form';
                })();
                """

                webView.evaluateJavaScript(jsLogin) { [weak self] res, _ in
                    guard let self = self else { return }
                    if (res as? String) == "submitted" {
                        self.didSubmitLogin = true
                    }
                }
                return
            }

            // ② アンケート中間ページ（トップ画面へ）があれば1回だけ押す
            if !didClickSurvey {
                let jsSurvey = """
                (function(){
                    var topBtn = document.querySelector("input[value='トップ画面へ']");
                    if(topBtn){
                        \(log)('survey page -> click Top');
                        topBtn.click();
                        return 'clicked';
                    }
                    return 'no';
                })();
                """
                webView.evaluateJavaScript(jsSurvey) { [weak self] r, _ in
                    if (r as? String) == "clicked" {
                        self?.didClickSurvey = true
                    }
                }
            }

            // ③ トップ到達したら目的URLへ（1回だけ）
            let jsIsTop = """
            (function(){ return !!document.querySelector('#menu-link-mt-sy'); })();
            """
            webView.evaluateJavaScript(jsIsTop) { [weak self] isTop, _ in
                guard let self = self else { return }
                let ok = (isTop as? Bool) == true
                let log = "window.webkit?.messageHandlers?.log?.postMessage"
                let js = "\(log)('isTop=' + \(ok ? "true" : "false") + ' url=' + location.href);"
                webView.evaluateJavaScript(js)

                if ok, !self.didNavigateToDestinationAfterLogin, url != self.destinationURL {
                    self.didNavigateToDestinationAfterLogin = true
                    webView.load(URLRequest(url: self.destinationURL))
                }
            }
        }

        private func escapeJS(_ s: String) -> String {
            s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
        }
    }
}

/// BEEF+ / うりぼー 共通: 閉じるボタン付きの画面ラッパー
struct PortalAutoLoginWebViewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let portal: PortalKind
    let destinationURL: URL

    private var title: String {
        switch portal {
        case .beef: return "BEEF+"
        case .uribo: return "うりぼー"
        }
    }

    var body: some View {
        NavigationStack {
            PortalAutoLoginWebView(portal: portal, destinationURL: destinationURL)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}
