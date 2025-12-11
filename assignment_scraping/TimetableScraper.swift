//
//  TimetableScraper.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import Foundation
import WebKit

struct ScrapedTimetableData {
    let timetables: [TimetableItem]
    let schedules: [DailySchedule]
}

enum ScraperError: Error {
    case timeout
    case loginFailed(String)
    case navigationFailed
    case parsingFailed
    case surveyRequired
    case contactInfoCheckRequired
}

@MainActor
class TimetableScraper: NSObject, WKNavigationDelegate {
    static let shared = TimetableScraper()
    
    private var webView: WKWebView!
    private var continuation: CheckedContinuation<ScrapedTimetableData, Error>?
    
    // 状態定義
    private enum State: Equatable {
        case idle
        case loggingIn
        case checkingSurvey
        case navigatingToTimetable
        case switchingQuarter(Int)
        case navigatingToSchedule
        case switchingMonth(Date)
    }
    private var state: State = .idle
    
    private var studentID = ""
    private var password = ""
    private var targetQuarters: [Int] = []
    private var startDate: Date = Date()
    private var endDate: Date = Date()
    
    private var scrapedItems: [TimetableItem] = []
    private var scrapedSchedules: [DailySchedule] = []
    
    private var timeoutTimer: Timer?
    private var waitTimer: Timer?
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        // PC版として認識させるため、画面サイズとUserAgentを設定
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }
    
    func fetch(studentID: String, password: String, quarters: [Int], start: Date, end: Date) async throws -> ScrapedTimetableData {
        if state != .idle { throw ScraperError.navigationFailed }
        
        self.studentID = studentID
        self.password = password
        self.targetQuarters = quarters
        self.startDate = start
        self.endDate = end
        self.scrapedItems = []
        self.scrapedSchedules = []
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.startScraping()
        }
    }
    
    private func startScraping() {
        print("🚀 [Scraper] 処理開始")
        self.state = .loggingIn
        
        timeoutTimer?.invalidate()
        // 全体のタイムアウトを120秒に設定
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { [weak self] _ in
            print("⏰ [Scraper] タイムアウト（全体）")
            self?.finish(with: .failure(ScraperError.timeout))
        }
        
        let url = URL(string: "https://kym22-web.ofc.kobe-u.ac.jp/campusweb")!
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - ページ遷移ハンドリング
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        print("🌐 [Scraper] Loaded: \(url) (State: \(state))")
        
        if url.contains("knossos.center.kobe-u.ac.jp/auth") || url.contains("idp") {
            handleLogin()
        } else if url.contains("campusweb/portal.do") {
            if state == .navigatingToSchedule {
                print("🏠 [Scraper] ポータル到達 → スケジュールへ")
                navigateToSchedulePageFromPortal()
            } else {
                print("🏠 [Scraper] ポータル到達 → 履修登録へ")
                handleHomeOrSurvey()
            }
        } else if url.contains("rishu/crg0101") || url.contains("campussquare.do") {
            if state == .navigatingToSchedule {
                print("🗓 [Scraper] スケジュール画面に到達")
                waitForSelector("#schedule-calender") { [weak self] success in
                    if success { self?.processSchedule() }
                }
            } else {
                print("📖 [Scraper] 履修登録画面に到達")
                // 画面ロード完了後、2秒待ってから処理開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.processTimetable()
                }
            }
        } else if url.contains("cws/schedule") {
            print("🗓 [Scraper] スケジュール画面(cws)に到達")
            waitForSelector("#schedule-calender") { [weak self] success in
                if success { self?.processSchedule() }
            }
        }
    }
    
    // MARK: - 新しいウィンドウ対策 (重要修正)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            // ターゲットフレームがない（＝新しいウィンドウ）場合、同じWebViewで強制的に読み込む
            print("🔗 [Scraper] 別タブのリンクを検出。現在のWebViewで開きます: \(navigationAction.request.url?.absoluteString ?? "")")
            webView.load(navigationAction.request)
            decisionHandler(.cancel) // 元のアクションはキャンセルする
            return
        }
        decisionHandler(.allow)
    }
    
    // MARK: - ログイン & ポータル
    private func handleLogin() {
        let js = """
        (function() {
            var u = document.getElementById('username');
            var p = document.getElementById('password');
            var b = document.getElementById('kc-login');
            if (u && p && b) {
                u.value = '\(studentID)';
                p.value = '\(password)';
                b.click();
                return 'submitted';
            }
            if (document.querySelector('.kc-feedback-text')) { return 'auth_error'; }
            return 'waiting';
        })();
        """
        webView.evaluateJavaScript(js) { res, _ in
            if let str = res as? String, str == "auth_error" {
                self.finish(with: .failure(ScraperError.loginFailed("ID/Pass間違い")))
            }
        }
    }

    private func handleHomeOrSurvey() {
        let js = """
        (function() {
            var topBtn = document.querySelector("input[type=submit][value='トップ画面へ']");
            if (topBtn) { topBtn.click(); return 'clicked_top'; }
            if (document.getElementById('menu-link-mt-sy')) { return 'on_home'; }
            return 'unknown';
        })();
        """
        webView.evaluateJavaScript(js) { res, _ in
            if (res as? String) == "on_home" { self.navigateToTimetable() }
        }
    }
    
    // MARK: - 履修登録 (Timetable)
    private func navigateToTimetable() {
        self.state = .navigatingToTimetable
        // 履修ボタンを探してクリック
        executeClickByText(text: "履修・抽選", thenWait: 1.0) {
            // 次のボタンをクリック
            self.executeClickByText(text: "履修登録・登録状況照会", thenWait: 0) {}
        }
    }
    
    private func processTimetable() {
        if case .switchingQuarter(let index) = state {
            scrapeCurrentQuarter(index: index)
        } else {
            self.state = .switchingQuarter(0)
            switchToQuarter(index: 0)
        }
    }
    
    private func switchToQuarter(index: Int) {
        guard index < targetQuarters.count else {
            navigateToSchedule()
            return
        }
        let q = targetQuarters[index]
        print("🔄 [Scraper] 第\(q)クォーター の処理を開始します")
        
        // 念のため、タブ要素が表示されるまで待つ（タイムアウトを20秒に延長）
        print("⏳ [Scraper] '第\(q)クォーター' タブが表示されるのを待機中...")
        
        waitForElementContainingText(text: "第\(q)クォーター", timeout: 20.0) { found in
            if found {
                print("👀 [Scraper] '第\(q)クォーター' タブが見つかりました。クリック処理を実行します。")
            } else {
                print("⚠️ [Scraper] '第\(q)クォーター' タブが見つかりません（タイムアウト）。強制的にクリックを試みます。")
            }
            
            // 待機時間を長めに設定 (3.0 -> 4.0)
            self.executeClickByText(text: "第\(q)クォーター", thenWait: 4.0) {
                self.scrapeCurrentQuarter(index: index)
            }
        }
    }
    
    private func scrapeCurrentQuarter(index: Int) {
        let q = targetQuarters[index]
        let js = """
        (function() {
            var cells = document.querySelectorAll('.rishu-koma-inner');
            var result = [];
            var dayMap = ['月', '火', '水', '木', '金', '土', '日'];
            
            // 選択中のタブが目的のクォーターか確認（念のため）
            var selectedTab = document.querySelector('.rishu-tab-sel');
            var isCorrectTab = selectedTab && selectedTab.innerText.includes('第' + \(q) + 'クォーター');
            
            cells.forEach(function(el, idx) {
                var text = el.innerText.trim();
                if (text === '未登録' || text === '') return;
                var lines = text.split('\\n').map(s => s.trim()).filter(s => s);
                if (lines.length < 2) return;
                
                var code = '', title = '', teacher = '';
                if (lines.length >= 3) {
                    code = lines[0]; title = lines[1]; teacher = lines[2];
                } else {
                    title = lines[0]; teacher = lines[1];
                }
                result.push({
                    day: dayMap[idx % 7],
                    period: Math.floor(idx / 7) + 1,
                    code: code,
                    title: title,
                    teacher: teacher,
                    quarter: \(q)
                });
            });
            return { items: result, isCorrectTab: isCorrectTab };
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] res, _ in
            if let data = res as? [String: Any] {
                // タブ確認ログ
                if let isCorrect = data["isCorrectTab"] as? Bool, !isCorrect {
                    print("⚠️ [Scraper] 警告: 現在選択されているタブが第\(q)クォーターではない可能性があります")
                }
                
                if let itemsDict = data["items"] as? [[String: Any]] {
                    print("📋 [Scraper] Q\(q): \(itemsDict.count)件 取得成功")
                    let items = itemsDict.compactMap { dict -> TimetableItem? in
                        guard let code = dict["code"] as? String,
                              let day = dict["day"] as? String,
                              let period = dict["period"] as? Int,
                              let title = dict["title"] as? String,
                              let teacher = dict["teacher"] as? String,
                              let qVal = dict["quarter"] as? Int else { return nil }
                        return TimetableItem(code: code, day: day, period: period, teacher: teacher, title: title, room: nil, quarter: qVal)
                    }
                    self?.scrapedItems.append(contentsOf: items)
                }
            }
            
            self?.state = .switchingQuarter(index + 1)
            self?.switchToQuarter(index: index + 1)
        }
    }
    
    // MARK: - スケジュール (Schedule)
    private func navigateToSchedule() {
        print("📂 [Scraper] スケジュール画面へ移動開始")
        self.state = .navigatingToSchedule
        let homeUrl = "https://kym22-web.ofc.kobe-u.ac.jp/campusweb/portal.do?page=main"
        webView.load(URLRequest(url: URL(string: homeUrl)!))
    }
    
    private func navigateToSchedulePageFromPortal() {
        executeClickByText(text: "休補・スケジュール", thenWait: 1.0) {
            self.executeClickByText(text: "スケジュール管理", thenWait: 0) {}
        }
    }
    
    private func processSchedule() {
        scrapeCurrentMonthSchedule { [weak self] _ in
            self?.finalize()
        }
    }
    
    private func scrapeCurrentMonthSchedule(completion: @escaping (Bool) -> Void) {
        let js = """
        (function() {
            var events = [];
            var titleEl = document.getElementById('header-title');
            var yearMonth = titleEl ? titleEl.innerText : "不明";
            var cells = document.querySelectorAll('td div.cal-content');
            cells.forEach(function(div) {
                var spans = div.querySelectorAll('span.kaiko');
                spans.forEach(function(span) {
                    var text = span.innerText;
                    var match = text.match(/(\\d)限:(.+)@(.+)/);
                    if (match) {
                        events.push({ period: parseInt(match[1]), subject: match[2].trim(), room: match[3].trim() });
                    }
                });
            });
            return { yearMonth: yearMonth, events: events };
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] res, _ in
            if let data = res as? [String: Any], let events = data["events"] as? [[String: Any]] {
                print("🗓 [Scraper] スケジュール解析完了: \(events.count)件")
                let dailySchedules = events.map { dict in
                    DailySchedule(day: 1, day_of_week: "", month: 1, schedule: [
                        ScheduleDetail(period: dict["period"] as? Int, room: dict["room"] as? String, subject: dict["subject"] as? String)
                    ], year: 2025)
                }
                self?.scrapedSchedules.append(contentsOf: dailySchedules)
            }
            completion(false)
        }
    }

    // MARK: - ヘルパー関数 (強化版)
    
    private func executeClickByText(text: String, thenWait: TimeInterval, completion: @escaping () -> Void) {
        let cleanTarget = text.replacingOccurrences(of: " ", with: "")
        
        let js = """
        (function() {
            var target = '\(cleanTarget)';
            // 優先度順: リンク/ボタン > span/div
            var selectors = [
                'a, button, input[type=button], input[type=submit]',
                'span, div, li, td'
            ];
            
            for (var s = 0; s < selectors.length; s++) {
                var elements = document.querySelectorAll(selectors[s]);
                for (var i = 0; i < elements.length; i++) {
                    var el = elements[i];
                    var t = (el.innerText || el.value || '').replace(/\\s+/g, '');
                    
                    if (t.includes(target)) {
                        if (el.offsetParent === null) continue; // 不可視要素はスキップ
                        el.click();
                        return "clicked: " + el.tagName;
                    }
                }
            }
            return "not_found";
        })();
        """
        
        webView.evaluateJavaScript(js) { res, _ in
            let result = res as? String ?? "error"
            if result.contains("clicked") {
                print("👆 [Scraper] クリック成功: \(text) (\(result))")
            } else {
                print("⚠️ [Scraper] クリック失敗: \(text) が見つかりません")
            }
            
            if thenWait > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + thenWait) { completion() }
            } else {
                completion()
            }
        }
    }
    
    private func waitForElementContainingText(text: String, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let cleanTarget = text.replacingOccurrences(of: " ", with: "")
        let start = Date()
        waitTimer?.invalidate()
        
        waitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let js = """
            (function() {
                var target = '\(cleanTarget)';
                var elements = document.querySelectorAll('a, button, input, div, span, li, td');
                for (var i = 0; i < elements.length; i++) {
                    var t = (elements[i].innerText || elements[i].value || '').replace(/\\s+/g, '');
                    if (t.includes(target)) return true;
                }
                return false;
            })();
            """
            self?.webView.evaluateJavaScript(js) { res, _ in
                if let exists = res as? Bool, exists {
                    timer.invalidate()
                    completion(true)
                } else if Date().timeIntervalSince(start) > timeout {
                    timer.invalidate()
                    completion(false)
                }
            }
        }
    }
    
    private func waitForSelector(_ selector: String, completion: @escaping (Bool) -> Void) {
        let start = Date()
        waitTimer?.invalidate()
        
        waitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let js = "document.querySelector('\(selector)') != null"
            self?.webView.evaluateJavaScript(js) { res, _ in
                if let exists = res as? Bool, exists {
                    timer.invalidate()
                    completion(true)
                } else if Date().timeIntervalSince(start) > 10.0 {
                    timer.invalidate()
                    completion(false)
                }
            }
        }
    }
    
    internal override func finalize() {
        print("🎉 [Scraper] 全工程終了")
        finish(with: .success(ScrapedTimetableData(timetables: scrapedItems, schedules: scrapedSchedules)))
    }
    
    private func finish(with result: Result<ScrapedTimetableData, Error>) {
        timeoutTimer?.invalidate()
        waitTimer?.invalidate()
        state = .idle
        if case .failure(let error) = result {
            continuation?.resume(throwing: error)
        } else if case .success(let data) = result {
            continuation?.resume(returning: data)
        }
        continuation = nil
    }
}
