//
//  AssignmentWidgetLiveActivity.swift
//  AssignmentWidget
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AssignmentWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AssignmentWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AssignmentWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AssignmentWidgetAttributes {
    fileprivate static var preview: AssignmentWidgetAttributes {
        AssignmentWidgetAttributes(name: "World")
    }
}

extension AssignmentWidgetAttributes.ContentState {
    fileprivate static var smiley: AssignmentWidgetAttributes.ContentState {
        AssignmentWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AssignmentWidgetAttributes.ContentState {
         AssignmentWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AssignmentWidgetAttributes.preview) {
   AssignmentWidgetLiveActivity()
} contentStates: {
    AssignmentWidgetAttributes.ContentState.smiley
    AssignmentWidgetAttributes.ContentState.starEyes
}
