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
        // デフォルトのUserAgent（スマホ版）を使用
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
        print("🚀 [Scraper] 処理開始 (タブ構造対応版)")
        self.state = .loggingIn
        
        timeoutTimer?.invalidate()
        // タイムアウトを少し長めに確保
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { [weak self] _ in
            print("⏰ [Scraper] タイムアウト")
            self?.finish(with: .failure(ScraperError.timeout))
        }
        
        let url = URL(string: "https://kym22-web.ofc.kobe-u.ac.jp/campusweb")!
        webView.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        print("🌐 [Scraper] Loaded: \(url)")
        
        checkForContactInfoScreen { [weak self] isContactScreen in
            guard let self = self else { return }
            if isContactScreen {
                print("🛑 [Scraper] 本人連絡先変更確認画面を検出")
                self.finish(with: .failure(ScraperError.contactInfoCheckRequired))
                return
            }
            
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
                    // タブ切り替え処理を開始
                    self.processTimetable()
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
            if (document.querySelector('.portal-panel') || document.title.includes('ポータル')) { return 'on_home'; }
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
        // スマホメニューを開いてからクリック
        let jsOpenMenu = """
        (function() {
            var menuBtn = document.querySelector('#menu_icon, .sp-menu-btn, img[alt="メニュー"]');
            if (menuBtn && menuBtn.offsetParent !== null) { menuBtn.click(); return true; }
            return false;
        })();
        """
        webView.evaluateJavaScript(jsOpenMenu) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.executeClickByText(text: "履修", thenWait: 1.0) {
                    self.executeClickByText(text: "履修登録・登録状況照会", thenWait: 0) {}
                }
            }
        }
    }
    
    private func processTimetable() {
        if case .switchingQuarter(let index) = state {
            // すでに処理中のクォーターがある場合（タブ切り替え後のロード完了時など）
            scrapeCurrentQuarter(index: index)
        } else {
            // 最初のクォーターから開始
            self.state = .switchingQuarter(0)
            switchToQuarter(index: 0)
        }
    }
    
    // 【重要修正】タブの状態を見てクリックするか判断する
    private func switchToQuarter(index: Int) {
        guard index < targetQuarters.count else {
            navigateToSchedule()
            return
        }
        let q = targetQuarters[index]
        print("🔄 [Scraper] 第\(q)クォーター の処理を開始")
        
        // 専用のタブ切り替え関数を実行
        switchQuarterTab(quarter: q) { result in
            if result == "already_selected" {
                // すでに選択されているのでクリック不要。すぐにデータ取得へ。
                print("ℹ️ [Scraper] Q\(q)は既に選択されています。データ取得へ進みます。")
                self.scrapeCurrentQuarter(index: index)
                
            } else if result == "clicked" {
                // クリックした。didFinishが呼ばれるのを待つ（何もしない）
                print("👆 [Scraper] Q\(q)のタブをクリックしました。ページ遷移を待ちます。")
                
            } else {
                // 見つからなかった場合など
                print("⚠️ [Scraper] Q\(q)のタブが見つかりませんでした。スキップして次へ。")
                self.state = .switchingQuarter(index + 1)
                self.switchToQuarter(index: index + 1)
            }
        }
    }
    
    // 【新規】タブ専用のクリック処理
    private func switchQuarterTab(quarter: Int, completion: @escaping (String) -> Void) {
        let js = """
        (function() {
            var qText = '第' + \(quarter) + 'クォーター';
            // タブのセル（td）を探す
            var cells = document.querySelectorAll('td.rishu-tab, td.rishu-tab-sel');
            
            for (var i = 0; i < cells.length; i++) {
                var cell = cells[i];
                // テキストが含まれているか（空白除去して比較）
                var cellText = (cell.innerText || '').replace(/\\s+/g, '');
                
                if (cellText.includes(qText)) {
                    // 1. 選択済みクラス(rishu-tab-sel)を持っているか？
                    if (cell.classList.contains('rishu-tab-sel')) {
                        return 'already_selected';
                    }
                    // 2. 持っていなければリンク(aタグ)を探してクリック
                    var link = cell.querySelector('a');
                    if (link) {
                        link.click();
                        return 'clicked';
                    }
                }
            }
            return 'not_found';
        })();
        """
        
        webView.evaluateJavaScript(js) { res, _ in
            completion((res as? String) ?? "not_found")
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
            
            // データ取得が終わったら次のクォーターへ
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
        let jsOpenMenu = """
        (function() {
            var menuBtn = document.querySelector('#menu_icon, .sp-menu-btn, img[alt="メニュー"]');
            if (menuBtn && menuBtn.offsetParent !== null) { menuBtn.click(); return true; }
            return false;
        })();
        """
        webView.evaluateJavaScript(jsOpenMenu) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.executeClickByText(text: "休補", thenWait: 1.0) {
                    self.executeClickByText(text: "スケジュール管理", thenWait: 0) {}
                }
            }
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

    // MARK: - ヘルパー関数
    
    private func executeClickByText(text: String, thenWait: TimeInterval, completion: @escaping () -> Void) {
        let cleanTarget = text.replacingOccurrences(of: " ", with: "")
        
        let js = """
        (function() {
            var target = '\(cleanTarget)';
            var elements = document.querySelectorAll('a, button, input[type=button], input[type=submit], div, span, li, p');
            
            for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                var t = (el.innerText || el.value || '').replace(/\\s+/g, '');
                
                if (t.includes(target)) {
                    if (el.closest('a')) {
                        el.closest('a').click();
                        return true;
                    }
                    el.click();
                    return true;
                }
            }
            return false;
        })();
        """
        
        webView.evaluateJavaScript(js) { res, _ in
            let clicked = (res as? Bool) ?? false
            if !clicked { print("⚠️ [Scraper] クリック失敗: \(text)") }
            DispatchQueue.main.asyncAfter(deadline: .now() + (thenWait > 0 ? thenWait : 0.5)) { completion() }
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
