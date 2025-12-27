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
        .configurationDisplayName("課題一覧")
        .description("次に提出するべき課題を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
