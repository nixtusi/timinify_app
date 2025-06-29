//
//  LectureDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/29.
//

import SwiftUI

struct LectureDetailView: View {
    let lectureCode: String
    let dayPeriod: String
    let year: String
    let quarter: String
    
    @StateObject private var viewModel = LectureDetailViewModel()
    
    @State private var isEditingRoom = false
    @State private var editedRoom: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("授業名: \(viewModel.title)")
                Text("教員名: \(viewModel.teacher)")
                
                HStack {
                    if isEditingRoom {
                        TextField("教室を入力", text: $editedRoom)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("保存") {
                            Task {
                                await viewModel.updateRoomInfo(
                                    year: year,
                                    quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                                    code: lectureCode,
                                    newRoom: editedRoom
                                )
                                viewModel.room = editedRoom
                                isEditingRoom = false
                            }
                        }
                    } else {
                        Text("教室: \(viewModel.room)")
                        Button {
                            editedRoom = viewModel.room
                            isEditingRoom = true
                        } label: {
                            Image(systemName: "lock")
                        }
                    }
                }
                
                Divider() //後々いらない
                
                Text("単位数: \(viewModel.credits)")
                Text("評価方法: \(viewModel.evaluation)")
                Text("参考書: \(viewModel.references)")
                
                // Viewの末尾にシラバス情報を追加
                syllabusView
            }
            .padding()
        }
        .navigationTitle(String(dayPeriod.prefix(1)) + "曜 " + String(dayPeriod.suffix(1)) + "限")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.fetchLectureDetails(
                    studentId: UserDefaults.standard.string(forKey: "studentNumber") ?? "",
                    admissionYear: "2024",
                    year: year,
                    quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                    day: String(dayPeriod.first ?? "月"),
                    period: Int(String(dayPeriod.last ?? "1")) ?? 1,
                    lectureCode: lectureCode
                )
                
                
                let quarterDisplay = quarter.replacingOccurrences(of: "Q", with: "第") + "クォーター"
                await viewModel.fetchSyllabus(
                    year: year,
                    quarter: quarterDisplay,
                    day: String(dayPeriod.prefix(1)),
                    code: lectureCode
                )
            }
        }
    }
    
    var syllabusView: some View {
        Group {
            if let syllabus = viewModel.syllabus {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                    Text("【シラバス概要】").font(.headline)

                    if let summary = syllabus.summary {
                        Text("授業の概要と計画:  \(summary)").fixedSize(horizontal: false, vertical: true)
                    }

                    if let goals = syllabus.goals {
                        Text("授業の到達目標: \(goals)").fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !viewModel.evaluationCriteria.isEmpty {
                        Text("評価基準: \(viewModel.evaluationCriteria)")
                    }

                    if let evaluation = syllabus.evaluation {
                        Text("評価方法: \(evaluation)")
                    }
                }
            }
        }
    }
}

