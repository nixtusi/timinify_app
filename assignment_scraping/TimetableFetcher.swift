//
//  TimetableFetcher.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/05.
//  /uribonet API のレスポンスを Firestore に入学年度構造でアップロード（Qごと分類）
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

struct TimetableItem: Codable, Identifiable {
    var id: String { code + day + String(period) }
    let code: String
    let day: String
    let period: Int
    let teacher: String
    let title: String
    let room: String?
    var quarter: Int = 1

    private enum CodingKeys: String, CodingKey {
        case code, day, period, teacher, title, room
    }
}

struct QuarterTimetable: Codable {
    let timetable: [TimetableItem]
    let year: String
    let year_semester: String
}

struct ScheduleDetail: Codable {
    let period: Int?
    let room: String?
    let subject: String
}

struct DailySchedule: Codable {
    let day: Int
    let day_of_week: String
    let month: Int
    let schedule: [ScheduleDetail]
    let year: Int
}

struct UribonetResponse: Codable {
    let schedules: [DailySchedule]
    let timetables: [String: QuarterTimetable]
}

// MARK: - TimetableFetcher

class TimetableFetcher: ObservableObject {
    @Published var timetableItems: [TimetableItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestore = Firestore.firestore()
    private let baseURL = "https://uribonet.timinify.com"

    @MainActor
    func fetchAndUpload(
        quarter: String = "1,2",
        startDate: String = "2025-04-01",
        endDate: String = "2025-08-30"
    ) async {
        isLoading = true
        errorMessage = nil

        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "ログイン情報が取得できませんでした"
            isLoading = false
            return
        }

        let studentNumber = email.components(separatedBy: "@").first ?? ""
        let password = UserDefaults.standard.string(forKey: "loginPassword") ?? ""

        do {
            let response = try await requestUribonet(
                studentNumber: studentNumber,
                password: password,
                quarter: quarter,
                startDate: startDate,
                endDate: endDate
            )

            timetableItems = response.timetables.flatMap { (key, quarterData) in
                let q = Int(key) ?? 1
                return quarterData.timetable.map { item in
                    var modified = item
                    modified.quarter = q
                    return modified
                }
            }

            await uploadToFirestore(
                studentNumber: studentNumber,
                schedules: response.schedules
            )

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        
        if let errorMessage = errorMessage {
            print("❌ 時間割取得エラー: \(errorMessage)")
        } else {
            print("✅ 時間割取得成功: \(timetableItems.count)件取得")
        }
    }

    private func requestUribonet(
        studentNumber: String,
        password: String,
        quarter: String,
        startDate: String,
        endDate: String,
        retries: Int = 2
    ) async throws -> UribonetResponse {
        let url = URL(string: baseURL + "/uribonet")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "student_number": studentNumber,
            "password": password,
            "quarter": quarter,
            "start_date": startDate,
            "end_date": endDate
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "APIエラー"])
            }

            return try JSONDecoder().decode(UribonetResponse.self, from: data)

        } catch {
            if retries > 0 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await requestUribonet(
                    studentNumber: studentNumber,
                    password: password,
                    quarter: quarter,
                    startDate: startDate,
                    endDate: endDate,
                    retries: retries - 1
                )
            }
            throw error
        }
    }

    @MainActor
    private func uploadToFirestore(
        studentNumber: String,
        schedules: [DailySchedule]
    ) async {
        let entryYear = "20" + String(studentNumber.prefix(2))
        let academicYear = "2025"

        for item in timetableItems {
            let rawRoom = schedules.first(where: { daySched in
                daySched.schedule.contains(where: {
                    $0.period == item.period && $0.subject == item.title && $0.room != nil
                })
            })?
            .schedule.first(where: { $0.period == item.period && $0.subject == item.title })?
            .room ?? ""

            let room = rawRoom.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? rawRoom

            let docData: [String: Any] = [
                "code": item.code,
                "day": item.day,
                "period": item.period,
                "teacher": item.teacher,
                "title": item.title,
                "room": room,
                "quarter": item.quarter
            ]

            let path = firestore
                .collection("Timetable")
                .document(entryYear)
                .collection(studentNumber)
                .document(academicYear)
                .collection("Q\(item.quarter)")

            do {
                try await path.document(item.id).setData(docData)
            } catch {
                print("❌ Firestore 保存エラー: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func loadFromFirestore(year: Int, quarter: Int) async {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "ログイン情報が取得できませんでした"
            return
        }

        let studentNumber = email.components(separatedBy: "@").first ?? ""
        let entryYear = "20" + String(studentNumber.prefix(2))

        let path = firestore
            .collection("Timetable")
            .document(entryYear)
            .collection(studentNumber)
            .document(String(year))
            .collection("Q\(quarter)")

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await path.getDocuments()
            timetableItems = snapshot.documents.compactMap { doc in
                var item = try? doc.data(as: TimetableItem.self)
                item?.quarter = quarter  // ✅ ここでquarterを手動でセット
                return item
            }
        } catch {
            errorMessage = "Firestore 読み込み失敗: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
