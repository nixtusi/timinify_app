//
//  LectureMemo.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/07.
//

import Foundation

struct LectureMemo: Identifiable, Codable, Hashable { // ← ここに Hashable を追加
    var id = UUID()
    var text: String
    var date: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
