//
//  AssignmentScraper.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/11/27.
//

import Foundation
import WebKit
import Combine

enum ScrapeError: Error {
    case loginFailed
    case navigationFailed
    case parsingFailed
    case timeout
}

@MainActor
class AssignmentScraper: NSObject, WKNavigationDelegate {
    static let shared = AssignmentScraper()
    
    private var webView: WKWebView!
    private var completion: ((Result<[BeefTask], Error>) -> Void)?
    private var timer: Timer?
    
    // URL設定
    private let beefLoginURL = URL(string: "https://beefplus.center.kobe-u.ac.jp/login")!
    private let taskURL = URL(string: "https://beefplus.center.kobe-u.ac.jp/lms/task")!
    
    private var studentID: String = ""
    private var password: String = ""
    
    override private init() {
        super.init()
        let config = WKWebViewConfiguration()
        // 毎回クリーンな状態でログイン試行するため非永続データストアを使用
        config.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        // デバッグ用: UserAgentを設定
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    }
    
    func fetchAssignments(studentID: String, password: String, completion: @escaping (Result<[BeefTask], Error>) -> Void) {
        self.studentID = studentID
        self.password = password
        self.completion = completion
        
        // タイムアウト設定 (45秒)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { [weak self] _ in
            self?.finish(with: .failure(ScrapeError.timeout))
        }
        
        // 処理開始
        print("🚀 Scraping started: Loading BEEF+ login page...")
        let request = URLRequest(url: beefLoginURL)
        webView.load(request)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url?.absoluteString else { return }
        print("🌍 Scraper Loaded: \(url)")
        
        // 1. KNOSSOS (SSO) ログインページ
        if url.contains("knossos.center.kobe-u.ac.jp/auth") {
            print("🔑 Filling KNOSSOS login form...")
            let js = """
            (function() {
                var u = document.getElementById('username');
                var p = document.getElementById('password');
                var b = document.getElementById('kc-login');
                if (u && p && b) {
                    u.value = '\(studentID)';
                    p.value = '\(password)';
                    b.click();
                    return "submitted";
                }
                return "form_not_found";
            })();
            """
            webView.evaluateJavaScript(js) { res, error in
                if let error = error { print("❌ KNOSSOS Script Error: \(error)") }
                else { print("✅ KNOSSOS Form Action: \(res ?? "nil")") }
            }
        }
        // 2. BEEF+ ログイン前トップページ
        else if url.contains("beefplus.center.kobe-u.ac.jp/login") {
            print("➡️ Clicking Common Auth (SAML) button...")
            let js = """
            (function() {
                var btn = document.querySelector('#comAuth a.login-btn');
                if (btn) {
                    btn.click();
                    return "clicked_saml";
                }
                return "button_not_found";
            })();
            """
            webView.evaluateJavaScript(js) { res, error in
                if let error = error { print("❌ BEEF Login Script Error: \(error)") }
                else { print("✅ BEEF Login Action: \(res ?? "nil")") }
            }
        }
        // 3. SAML認証処理中（リダイレクト待ち）
        else if url.contains("/saml/") {
            print("⏳ SAML processing... Waiting for redirect.")
        }
        // 4. BEEF+ 課題一覧ページ
        else if url.contains("lms/task") {
            print("📥 On Task Page. Extracting data (Div mode)...")
            extractTasksDivMode() // 新しい抽出ロジック
        }
        // 5. その他（ログイン後のトップページなど）
        else if url.contains("beefplus.center.kobe-u.ac.jp") {
            print("🔄 Redirecting to Task URL...")
            if url != taskURL.absoluteString {
                let req = URLRequest(url: taskURL)
                webView.load(req)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView Navigation Error: \(error.localizedDescription)")
        finish(with: .failure(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView Provisional Navigation Error: \(error.localizedDescription)")
        finish(with: .failure(error))
    }
    
    // リダイレクト許可
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    private func extractTasksDivMode() {
        // 提供されたHTML（Div構成）に基づく抽出ロジック
        let js = """
        (function() {
            // 各行のdivを取得
            const rows = Array.from(document.querySelectorAll('.result_list_line'));
            
            return rows.map(row => {
                // コース名
                const courseDiv = row.querySelector('.tasklist-course');
                const course = courseDiv ? courseDiv.innerText.trim() : "";
                
                // タイトルとURL
                // .tasklist-title 内の aタグを取得
                const titleAnchor = row.querySelector('.tasklist-title a');
                const title = titleAnchor ? titleAnchor.innerText.trim() : "";
                const url = titleAnchor ? titleAnchor.href : "";
                
                // 期限
                // .tasklist-deadline 内の .deadline クラスを持つ span を取得
                const deadlineSpan = row.querySelector('.tasklist-deadline .deadline');
                const deadline = deadlineSpan ? deadlineSpan.innerText.trim() : "";
                
                if (!title || !url) return null;
                
                return {
                    course: course,
                    title: title,
                    deadline: deadline,
                    url: url
                };
            }).filter(item => item !== null);
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ JS Parsing Error: \(error)")
                self.finish(with: .failure(ScrapeError.parsingFailed))
                return
            }
            
            guard let array = result as? [[String: String]] else {
                print("❌ Invalid Data Format: \(String(describing: result))")
                self.finish(with: .failure(ScrapeError.parsingFailed))
                return
            }
            
            print("📦 Found \(array.count) items.")
            
            let tasks: [BeefTask] = array.compactMap { dict in
                guard let title = dict["title"], !title.isEmpty,
                      let deadlineStr = dict["deadline"],
                      let url = dict["url"] else { return nil }
                
                let formattedDeadline = self.normalizeDate(deadlineStr)
                
                return BeefTask(
                    course: dict["course"] ?? "不明なコース",
                    content: "未提出",
                    title: title,
                    deadline: formattedDeadline,
                    url: url
                )
            }
            
            self.finish(with: .success(tasks))
        }
    }
    
    private func finish(with result: Result<[BeefTask], Error>) {
        timer?.invalidate()
        timer = nil
        completion?(result)
        completion = nil
        webView.loadHTMLString("", baseURL: nil)
    }
    
    // 日付変換（秒を含むパターンなどを追加）
    private func normalizeDate(_ dateStr: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "ja_JP")
        inputFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        // 実際のサイトで見られる形式（例: 2025/12/03 13:00:00）に対応
        let formats = [
            "yyyy/MM/dd HH:mm:ss",      // 新しい形式
            "yyyy/MM/dd HH:mm",
            "yyyy年MM月dd日(E) HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]
        
        for format in formats {
            inputFormatter.dateFormat = format
            if let date = inputFormatter.date(from: dateStr) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                outputFormatter.locale = Locale(identifier: "ja_JP")
                outputFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
                return outputFormatter.string(from: date)
            }
        }
        
        return dateStr
    }
}
