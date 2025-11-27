//
//  TaskModel.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import Foundation

struct BeefTask: Identifiable, Codable {
    var id: String { url }  // URLをIDとして利用
    let course: String
    let content: String
    let title: String
    let deadline: String
    let url: String

    var formattedDeadlineWithDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        guard let date = formatter.date(from: deadline) else {
            return deadline
        }
        
        let output = DateFormatter()
        output.locale = Locale(identifier: "ja_JP")
        output.dateFormat = "MM/dd(EEE) HH:mm"
        return output.string(from: date)
    }

    var timeRemaining: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let date = formatter.date(from: deadline) else { return "" }
        
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "締切済み" }
        else if diff < 3600 { return "あと\(Int(diff/60))分" }
        else if diff < 86400 { return "あと\(Int(diff/3600))時間" }
        else { return "あと\(Int(diff/86400))日" }
    }
}
