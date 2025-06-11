//
//  TimetableFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//

import Foundation
import FirebaseFirestore

class TimetableFetcher: ObservableObject {
    @Published var timetableItems: [TimetableItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiURL = URL(string: "https://uribonet.timinify.com/uribonet")!
    private let scheduleAPIURL = URL(string: "https://uribonet.timinify.com/schedules")!

    func fetchTimetableFromAPI(quarter: String = "2", retryCount: Int = 2) {
        let studentNumber = UserDefaults.standard.string(forKey: "studentNumber") ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        guard !studentNumber.isEmpty, !password.isEmpty else {
            self.errorMessage = "ログイン情報が未設定です"
            return
        }

        if retryCount == 2 {
            isLoading = true
            errorMessage = nil
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = [
            "student_number": studentNumber,
            "password": password,
            "quarter": quarter
        ]
        request.httpBody = try? JSONEncoder().encode(requestBody)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleError(error.localizedDescription, quarter: quarter, retryCount: retryCount)
                    return
                }

                guard let data = data else {
                    self.handleError("データが取得できませんでした", quarter: quarter, retryCount: retryCount)
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(TimetableResponse.self, from: data)
                    self.timetableItems = decoded.timetable
                    self.fetchRoomsAndUpload(studentNumber: studentNumber, quarter: quarter)
                } catch {
                    self.handleError("デコード失敗: \(error.localizedDescription)", quarter: quarter, retryCount: retryCount)
                }
            }
        }.resume()
    }

    private func handleError(_ message: String, quarter: String, retryCount: Int) {
        if retryCount > 0 {
            self.fetchTimetableFromAPI(quarter: quarter, retryCount: retryCount - 1)
        } else {
            self.isLoading = false
            self.errorMessage = message
        }
    }

    private func fetchRoomsAndUpload(studentNumber: String, quarter: String) {
        let startDate = "2025-06-15"
        let endDate = "2025-07-14"

        var request = URLRequest(url: scheduleAPIURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "student_number": studentNumber,
            "password": UserDefaults.standard.string(forKey: "loginPassword") ?? "",
            "quarter": quarter,
            "start_date": startDate,
            "end_date": endDate
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let schedules = try? JSONDecoder().decode([ScheduleItem].self, from: data) else {
                    print("教室データ取得失敗")
                    return
                }

                let db = Firestore.firestore()
                let collection = "Timetable-2025-\(studentNumber)"

                for item in self.timetableItems {
                    let room = schedules.first(where: {
                        $0.period == item.period &&
                        $0.subject == item.title &&
                        !$0.room.contains("[休日]")
                    })?.room ?? "" //""を代入

                    let doc: [String: Any] = [
                        "code": item.code,
                        "day": item.day,
                        "period": item.period,
                        "teacher": item.teacher,
                        "title": item.title,
                        "room": room
                    ]

                    db.collection(collection).document(item.id).setData(doc)
                }

                self.isLoading = false
            }
        }.resume()
    }
}

struct TimetableItem: Codable, Identifiable {
    var id: String { code + day + String(period) }
    let code: String
    let day: String
    let period: Int
    let teacher: String
    let title: String
}

struct TimetableResponse: Codable {
    let timetable: [TimetableItem]
}

struct ScheduleItem: Codable {
    let period: Int
    let subject: String
    let room: String
}
