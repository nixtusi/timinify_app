//
//  TaskWidget.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import WidgetKit
import SwiftUI

struct TaskWidget: Widget {
    let kind: String = "TaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            TaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("課題一覧ウィジェット")
        .description("次に提出する課題を表示します。")
        .supportedFamilies([.systemMedium])
    }
}
