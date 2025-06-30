//
//  NotificationManager.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/05.
//

import Foundation
import UserNotifications
import FirebaseAuth

class NotificationManager {
    
    static let shared = NotificationManager()
    
    private init() {}
    
    //通知の許可リクエスト
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            } else {
                print("通知許可: \(granted)")
            }
        }
    }
    
    //既存通知を削除（再登録前に呼ぶ）
    func clearAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    //通知をスケジュール
    func scheduleNotifications(for tasks: [BeefTask]) {
        guard let email = Auth.auth().currentUser?.email,
              let studentNumber = email.components(separatedBy: "@").first else {
            print("❌ 通知スケジュール時に学籍番号が取得できませんでした")
            return
        }
        print("🔔 通知スケジュール対象: \(studentNumber)")

        clearAllScheduledNotifications()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        for task in tasks {
            guard let deadlineDate = formatter.date(from: task.deadline) else { continue }
            
            let timesBefore: [TimeInterval] = [3600, 3*3600, 24*3600] // 1時間, 3時間, 24時間前

            for offset in timesBefore {
                let triggerDate = deadlineDate.addingTimeInterval(-offset)
                if triggerDate < Date() { continue } // 過去ならスキップ
                
                let content = UNMutableNotificationContent()
                content.title = "\(task.course)"
                content.body = "「\(task.title)」提出まであと\(Int(offset / 3600))時間です！"
                content.sound = UNNotificationSound.default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                    repeats: false
                )

                let identifier = "\(task.url)_\(Int(offset))"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("通知登録失敗: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
