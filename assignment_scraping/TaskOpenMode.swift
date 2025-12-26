//
//  TaskOpenMode.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/26.
//

import Foundation

enum TaskOpenMode: String, CaseIterable {
    case external
    case inApp

    var title: String {
        switch self {
        case .external: return "外部ブラウザ"
        case .inApp: return "アプリ内"
        }
    }
}
