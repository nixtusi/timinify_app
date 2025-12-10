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
    case contactInfoCheckRequired // 本人連絡先確認が必要
}

@MainActor
class TimetableScraper: NSObject, WKNavigationDelegate {
    static let shared = TimetableScraper()
    
    private var webView: WKWebView!
    private var continuation: CheckedContinuation<ScrapedTimetableData, Error>?
    
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
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        // UserAgentはデフォルト（スマホ版）のままにするため設定しない
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
        print("🚀 [Scraper] 処理開始 (Mobileモード)")
        self.state = .loggingIn
        
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { [weak self] _ in
            print("⏰ [Scraper] タイムアウト")
            self?.finish(with: .failure(ScraperError.timeout))
        }
        
        let url = URL(string: "https://kym22-web.ofc.kobe-u.ac.jp/campusweb")!
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - ページ遷移ハンドリング
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        print("🌐 [Scraper] Loaded: \(url)")
        
        // どの画面でも、まず「本人連絡先確認」が出ていないかチェック
        checkForContactInfoScreen { [weak self] isContactScreen in
            guard let self = self else { return }
            
            if isContactScreen {
                print("🛑 [Scraper] 本人連絡先変更確認画面を検出しました")
                self.finish(with: .failure(ScraperError.contactInfoCheckRequired))
                return
            }
            
            // 以下、通常のフロー
            if url.contains("knossos.center.kobe-u.ac.jp/auth") || url.contains("idp") {
                self.handleLogin()
            } else if url.contains("campusweb/portal.do") {
                if self.state == .navigatingToSchedule {
                    print("🏠 [Scraper] ポータル到達 → スケジュールへ")
                    self.navigateToSchedulePageFromPortal()
                } else {
                    print("🏠 [Scraper] ポータル到達 → 履修登録へ")
                    self.handleHomeOrSurvey()
                }
            } else if url.contains("rishu/crg0101") || url.contains("campussquare.do") {
                if self.state == .navigatingToSchedule {
                    print("🗓 [Scraper] スケジュール画面に到達")
                    self.waitForSelector("#schedule-calender") { success in
                        if success { self.processSchedule() }
                    }
                } else {
                    print("📖 [Scraper] 履修登録画面に到達")
                    // スマホ版はロードやタブ表示に時間がかかることがあるため少し待つ
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.processTimetable()
                    }
                }
            } else if url.contains("cws/schedule") {
                print("🗓 [Scraper] スケジュール画面(cws)に到達")
                self.waitForSelector("#schedule-calender") { success in
                    if success { self.processSchedule() }
                }
            }
        }
    }
    
    // MARK: - 本人連絡先確認画面の検出
    private func checkForContactInfoScreen(completion: @escaping (Bool) -> Void) {
        // ID: gakusekiAddressInputForm があるかどうかで判定
        let js = "document.getElementById('gakusekiAddressInputForm') != null"
        webView.evaluateJavaScript(js) { res, _ in
            completion((res as? Bool) ?? false)
        }
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
    
    // MARK: - 履修登録
    private func navigateToTimetable() {
        self.state = .navigatingToTimetable
        // スマホ版のメニューは隠れている可能性があるため、強制クリックする
        executeClickByText(text: "履修・抽選", thenWait: 1.0) {
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
        print("🔄 [Scraper] 第\(q)クォーター タブをクリック試行")
        
        waitForElementContainingText(text: "第\(q)クォーター", timeout: 5.0) { found in
            self.executeClickByText(text: "第\(q)クォーター", thenWait: 3.0) {
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
            return { items: result };
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] res, _ in
            if let data = res as? [String: Any], let itemsDict = data["items"] as? [[String: Any]] {
                print("📋 [Scraper] Q\(q): \(itemsDict.count)件 取得")
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
            self?.state = .switchingQuarter(index + 1)
            self?.switchToQuarter(index: index + 1)
        }
    }
    
    // MARK: - スケジュール
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

    // MARK: - ヘルパー関数 (修正版)
    
    /// テキストを含む要素をクリック（空白除去・部分一致・隠れていてもクリック）
    private func executeClickByText(text: String, thenWait: TimeInterval, completion: @escaping () -> Void) {
        let cleanTarget = text.replacingOccurrences(of: " ", with: "")
        
        let js = """
        (function() {
            var target = '\(cleanTarget)';
            // button や a タグだけでなく、div や span も対象にする
            var elements = document.querySelectorAll('a, button, input[type=button], input[type=submit], div, span, li');
            
            for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                var t = (el.innerText || el.value || '').replace(/\\s+/g, '');
                
                if (t.includes(target)) {
                    // ★修正: 可視チェック(offsetParent)を削除し、隠れていてもクリックする
                    el.click();
                    return true;
                }
            }
            return false;
        })();
        """
        
        webView.evaluateJavaScript(js) { res, _ in
            let success = (res as? Bool) ?? false
            if success {
                print("👆 [Scraper] クリック成功: \(text)")
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
                var elements = document.querySelectorAll('a, button, input, div, span, li');
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
                    print("⚠️ [Scraper] 待機タイムアウト: \(text)")
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
