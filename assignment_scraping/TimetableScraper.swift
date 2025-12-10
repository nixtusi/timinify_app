//
//  TimetableScraper.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import Foundation
import WebKit

// スクレイピング結果をまとめる構造体
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
}

@MainActor
class TimetableScraper: NSObject, WKNavigationDelegate {
    static let shared = TimetableScraper()
    
    private var webView: WKWebView!
    private var continuation: CheckedContinuation<ScrapedTimetableData, Error>?
    
    // 状態管理
    private enum State: Equatable {
        case idle
        case loggingIn
        case checkingSurvey
        case navigatingToTimetable
        case switchingQuarter(Int) // インデックス
        case navigatingToSchedule
        case switchingMonth(Date)
    }
    private var state: State = .idle
    
    // パラメータ保持
    private var studentID = ""
    private var password = ""
    private var targetQuarters: [Int] = []
    private var startDate: Date = Date()
    private var endDate: Date = Date()
    
    // 取得データ保持
    private var scrapedItems: [TimetableItem] = []
    private var scrapedSchedules: [DailySchedule] = []
    
    // タイマー系
    private var timeoutTimer: Timer?
    private var waitTimer: Timer? // DOM待機用
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // クリーンな状態で開始
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    }
    
    // MARK: - 公開メソッド
    
    func fetch(studentID: String, password: String, quarters: [Int], start: Date, end: Date) async throws -> ScrapedTimetableData {
        // 多重実行防止
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
    
    // MARK: - 処理フロー
    
    private func startScraping() {
        print("🚀 オンデバイス・スクレイピング開始")
        self.state = .loggingIn
        
        // タイムアウト設定 (全体で90秒)
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] _ in
            self?.finish(with: .failure(ScraperError.timeout))
        }
        
        let url = URL(string: "https://kym22-web.ofc.kobe-u.ac.jp/campusweb")!
        webView.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        print("🌍 Loaded: \(url)")
        
        // 1. ログイン処理
        if url.contains("knossos.center.kobe-u.ac.jp/auth") || url.contains("idp") {
            handleLogin()
        }
        // 2. ログイン完了（トップページ） -> アンケートチェック & 次へ
        else if url.contains("campusweb/portal.do") {
            handleHomeOrSurvey()
        }
        // 3. 履修登録画面
        else if url.contains("rishu/crg0101") { // URLは適宜確認が必要
            // DOMロード待ち後に処理を開始（didFinishだけではテーブル描画が終わっていない可能性があるため）
            waitForSelector(".rishu-koma-inner") { [weak self] success in
                self?.processTimetable()
            }
        }
        // 4. スケジュール画面
        else if url.contains("cws/schedule") {
            waitForSelector("#schedule-calender") { [weak self] success in
                self?.processSchedule()
            }
        }
    }
    
    // MARK: - 各ステップのロジック
    
    private func handleLogin() {
        print("🔑 ログインフォーム入力")
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
            // エラー表示があるかチェック
            if (document.querySelector('.kc-feedback-text')) {
                return 'auth_error';
            }
            return 'waiting';
        })();
        """
        webView.evaluateJavaScript(js) { res, _ in
            if let str = res as? String, str == "auth_error" {
                self.finish(with: .failure(ScraperError.loginFailed("IDまたはパスワードが違います")))
            }
        }
    }
    
    private func handleHomeOrSurvey() {
        print("🏠 ホーム画面チェック")
        // Pythonの `ensure_home_after_login` に相当
        let js = """
        (function() {
            // アンケート等の「トップ画面へ」ボタンがあるか
            var topBtn = document.querySelector("input[type=submit][value='トップ画面へ']");
            if (topBtn) {
                topBtn.click();
                return 'clicked_top';
            }
            // 通常のメニューがあるか
            if (document.getElementById('menu-link-mt-sy')) {
                return 'on_home';
            }
            return 'unknown';
        })();
        """
        
        webView.evaluateJavaScript(js) { res, _ in
            let status = res as? String
            if status == "clicked_top" {
                print("ℹ️ アンケート中間ページをスキップしました")
                // ページ遷移を待つ
            } else if status == "on_home" {
                // 次のステップへ：履修登録画面へ移動
                self.navigateToTimetable()
            }
        }
    }
    
    private func navigateToTimetable() {
        print("📂 履修登録画面へ移動中...")
        self.state = .navigatingToTimetable
        // メニューのクリック（Pythonの click_by_text に相当）
        executeClickByText(text: "履修・抽選", thenWait: 1.0) {
            self.executeClickByText(text: "履修登録・登録状況照会", thenWait: 0) {
                // ページ遷移待ち (didFinishが呼ばれる)
            }
        }
    }
    
    private func processTimetable() {
        // 現在の処理対象クォーターを決定
        if case .switchingQuarter(let index) = state {
            scrapeCurrentQuarter(index: index)
        } else {
            // 最初はターゲットの先頭から
            self.state = .switchingQuarter(0)
            switchToQuarter(index: 0)
        }
    }
    
    private func switchToQuarter(index: Int) {
        guard index < targetQuarters.count else {
            // 全クォーター完了 → スケジュール取得へ
            navigateToSchedule()
            return
        }
        
        let q = targetQuarters[index]
        print("➡️ 第\(q)クォーターへ切り替え")
        
        // タブ切り替え（AJAX遷移の可能性が高いため、クリック後に少し待機して解析）
        executeClickByText(text: "第\(q)クォーター", thenWait: 2.0) {
            self.scrapeCurrentQuarter(index: index)
        }
    }
    
    private func scrapeCurrentQuarter(index: Int) {
        // Pythonの `get_timetable_data` 内の解析ロジック
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
                
                // [コード, 科目名, 教員名] または [科目名, 教員名]
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
            return result;
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] res, error in
            if let dicts = res as? [[String: Any]] {
                print("📋 Q\(q): \(dicts.count)件取得")
                let items = dicts.compactMap { dict -> TimetableItem? in
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
            
            // 次のクォーターへ
            self?.state = .switchingQuarter(index + 1)
            self?.switchToQuarter(index: index + 1)
        }
    }
    
    // MARK: - スケジュール処理 (教室情報取得)
    
    private func navigateToSchedule() {
        print("📂 スケジュール画面へ移動中...")
        self.state = .navigatingToSchedule
        // 一度ホームに戻るか、メニューから移動（Pythonスクリプトはホームに戻っている）
        let homeUrl = "https://kym22-web.ofc.kobe-u.ac.jp/campusweb/portal.do?page=main"
        webView.load(URLRequest(url: URL(string: homeUrl)!))
        
        // didFinishでホーム検知 -> 「休補・スケジュール」->「スケジュール管理」の流れを作る
        // ここでは簡略化のため、didFinishのロジックで分岐させる
    }
    
    private func processSchedule() {
        // 月ごとのループ処理（開始月から終了月まで）
        // 簡易実装として、現在表示されている月を取得し、必要なら「次月」ボタンを押すロジック
        // ここでは「表示中の月のデータを取得」→「期間内なら次へ」を繰り返す再帰処理にします。
        
        scrapeCurrentMonthSchedule { [weak self] hasMore in
            if hasMore {
                self?.clickNextMonth()
            } else {
                self?.finalize()
            }
        }
    }
    
    private func scrapeCurrentMonthSchedule(completion: @escaping (Bool) -> Void) {
        // Pythonの `parse_day_cell` 相当をJSで実行
        // 教室情報(room)を取得するのが主な目的
        let js = """
        (function() {
            var events = [];
            var yearMonth = document.getElementById('header-title').innerText; // "2025年 4月"
            
            var cells = document.querySelectorAll('td div.cal-content');
            cells.forEach(function(div) {
                var spans = div.querySelectorAll('span.kaiko');
                spans.forEach(function(span) {
                    var text = span.innerText;
                    // 例: "1限:線形代数@D102"
                    var match = text.match(/(\\d)限:(.+)@(.+)/);
                    if (match) {
                        events.push({
                            period: parseInt(match[1]),
                            subject: match[2].trim(),
                            room: match[3].trim()
                        });
                    } else {
                        // 教室なしパターン
                        var match2 = text.match(/(\\d)限:(.+)/);
                        if (match2) {
                            events.push({
                                period: parseInt(match2[1]),
                                subject: match2[2].trim(),
                                room: null
                            });
                        }
                    }
                });
            });
            return { yearMonth: yearMonth, events: events };
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] res, _ in
            guard let self = self,
                  let data = res as? [String: Any],
                  let ymStr = data["yearMonth"] as? String,
                  let events = data["events"] as? [[String: Any]] else {
                completion(false)
                return
            }
            
            print("🗓 \(ymStr): \(events.count)件の授業情報を解析")
            
            // DailySchedule形式に変換して保存（今回は簡易的に教室情報のマッピング用に保持）
            // 実際は日付ごとの構造体ですが、ここでは「科目名+時限」で教室を特定できれば良いので
            // 簡易的な構造で保持するか、DailyScheduleに合わせる
            let dailySchedules = events.map { dict -> DailySchedule in
                // ダミーの日付データ（Roomマッピング用なので日付は一旦無視しても良いが、正確にするならHTMLの構造解析が必要）
                return DailySchedule(day: 1, day_of_week: "", month: 1, schedule: [
                    ScheduleDetail(
                        period: dict["period"] as? Int,
                        room: dict["room"] as? String,
                        subject: dict["subject"] as? String
                    )
                ], year: 2025)
            }
            self.scrapedSchedules.append(contentsOf: dailySchedules)
            
            // 終了判定（現在表示中の年月が endDate を超えているか）
            if self.isMonthAfterEndDate(ymStr: ymStr) {
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    private func clickNextMonth() {
        print("🗓 次の月へ移動...")
        executeClickByXPath(xpath: "//a[contains(@onClick, 'loadNextMonth')]", thenWait: 2.0) {
            self.processSchedule()
        }
    }
    
    // MARK: - ヘルパー
    
    private func executeClickByText(text: String, thenWait: TimeInterval, completion: @escaping () -> Void) {
        let js = """
        (function() {
            var links = document.querySelectorAll('a, button, input[type=button], input[type=submit]');
            for (var i = 0; i < links.length; i++) {
                if (links[i].innerText && links[i].innerText.includes('\(text)')) {
                    links[i].click();
                    return true;
                }
                if (links[i].value && links[i].value.includes('\(text)')) {
                    links[i].click();
                    return true;
                }
            }
            return false;
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in
            if thenWait > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + thenWait) { completion() }
            } else {
                completion()
            }
        }
    }
    
    private func executeClickByXPath(xpath: String, thenWait: TimeInterval, completion: @escaping () -> Void) {
        let js = """
        (function() {
            var res = document.evaluate("\(xpath)", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            if (res.singleNodeValue) {
                res.singleNodeValue.click();
                return true;
            }
            return false;
        })();
        """
        webView.evaluateJavaScript(js) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + thenWait) { completion() }
        }
    }
    
    private func waitForSelector(_ selector: String, timeout: TimeInterval = 10.0, completion: @escaping (Bool) -> Void) {
        let start = Date()
        waitTimer?.invalidate()
        
        waitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let js = "document.querySelector('\(selector)') != null"
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
    
    private func isMonthAfterEndDate(ymStr: String) -> Bool {
        // ymStr: "2025年 4月" -> Parseして endDate と比較
        // 実装は省略しますが、ここがTrueになればループ終了
        return false // 仮: 1ヶ月だけ取得して終わるなど
    }
    
    internal override func finalize() {
        print("🏁 スクレイピング完了")
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
