//
//  TimetableWidgetBundle.swift
//  AssignmentTimetableWidget
//
//  ✅ 変更: ウィジェット拡張のエントリポイント
//

import WidgetKit
import SwiftUI

@main // ✅ 変更: これが拡張の“入口”です（1つだけ定義）
struct TimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        //TimetableWidget() // ✅ 変更: いただいた TimetableWidget.swift の本体を登録
    }
}
