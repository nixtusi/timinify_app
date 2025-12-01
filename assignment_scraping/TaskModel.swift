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
        
        if diff <= 0 {
            return "締切済み"
        } else if diff < 3600 {
            // 1時間未満: 分のみ (例: あと45分)
            return "あと\(Int(diff / 60))分"
        } else if diff < 3 * 3600 {
            // 3時間未満: 時間+分 (例: あと2時間15分)
            let hours = Int(diff / 3600)
            let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            return "あと\(hours)時間\(minutes)分"
        } else if diff < 24 * 3600 {
            // 3時間〜24時間: 時間のみ (例: あと5時間)
            return "あと\(Int(diff / 3600))時間"
        } else {
            // 24時間以上
            let days = Int(diff / 86400)
            let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
            
            if days < 3 {
                // 3日以内: 日+時間 (例: あと1日15時間)
                return "あと\(days)日\(hours)時間"
            } else {
                // 3日以上: 日のみ (例: あと5日)
                return "あと\(days)日"
            }
        }
    }
}
