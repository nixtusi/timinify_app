//
//  TimetableFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//

import Foundation
import Combine

class TimetableFetcher: ObservableObject {
    @Published var timetableItems: [TimetableItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var studentNumber: String = ""
    var password: String = ""

    private let apiURL = URL(string: "https://uribonet.timinify.com/uribonet")!

    func fetchTimetableFromAPI(quarter: String = "2", retryCount: Int = 2) {
        guard !studentNumber.isEmpty, !password.isEmpty else {
            self.errorMessage = "ログイン情報が未設定です"
            return
        }

        if retryCount == 2 {
            isLoading = true
            errorMessage = nil
        }

        var request = URLRequest(url: apiURL, timeoutInterval: 60) //timrout60sに変更
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: String] = [
            "student_number": studentNumber,
            "password": password,
            "quarter": quarter
        ]
        request.httpBody = try? JSONEncoder().encode(requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if retryCount > 0 {
                        self.fetchTimetableFromAPI(quarter: quarter, retryCount: retryCount - 1)
                    } else {
                        self.isLoading = false
                        self.errorMessage = "通信エラー: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data else {
                    if retryCount > 0 {
                        self.fetchTimetableFromAPI(quarter: quarter, retryCount: retryCount - 1)
                    } else {
                        self.isLoading = false
                        self.errorMessage = "データが取得できませんでした"
                    }
                    return
                }

                do {
                    let text = String(data: data, encoding: .utf8) ?? "データを文字列に変換できません"
                    print("📦 APIからのレスポンス: \(text)")

                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode(TimetableResponse.self, from: data)
                    print("✅ デコード成功: \(decoded.timetable.count) 件")
                    self.timetableItems = decoded.timetable
                    self.isLoading = false
                } catch {
                    print("❌ デコード失敗: \(error)")
                    print("📦 レスポンス: \(String(data: data, encoding: .utf8) ?? "nil")")
                    self.isLoading = false
                    self.errorMessage = "デコード失敗: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// モデル定義
struct TimetableItem: Codable, Identifiable {
    var id: String { code + day + String(period) }
    let code: String
    let day: String
    let period: Int
    let teacher: String
    let title: String
}

struct TimetableResponse: Codable {
    let timetable: [TimetableItem]
}
