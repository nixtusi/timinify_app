//
//  TaskEntry.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import WidgetKit
import Foundation

struct SharedTask: Identifiable, Codable {
    var id: String { url }
    let title: String
    let deadline: String
    let url: String
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [SharedTask]
    let lastUpdated: Date?
}
