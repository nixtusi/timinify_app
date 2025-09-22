//
//  LibraryBarcodeWidget.swift
//  LibraryBarcodeWidget
//
//  Created by Yuta Nisimatsu on 2025/07/01.
//

import WidgetKit
import SwiftUI

struct BarcodeEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BarcodeEntry {
        BarcodeEntry(date: Date(), image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BarcodeEntry) -> ()) {
        let image = BarcodeManager.shared.loadSavedBarcodeImage()
        let entry = BarcodeEntry(date: Date(), image: image)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BarcodeEntry>) -> ()) {
        let image = BarcodeManager.shared.loadSavedBarcodeImage()
        let entry = BarcodeEntry(date: Date(), image: image)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct LibraryBarcodeWidgetEntryView: View {
    var entry: BarcodeEntry

    var body: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                Text("バーコード未取得")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .containerBackground(Color.white, for: .widget)
    }
}

struct LibraryBarcodeWidget: Widget {
    let kind: String = "LibraryBarcodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LibraryBarcodeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("図書館入館証")
        .description("図書館へ入館するためのバーコードを常に表示します。")
        .supportedFamilies([.systemMedium])
    }
}
