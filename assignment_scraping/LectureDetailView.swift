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
        NavigationStack{
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
                    
                    Text("授業情報")
                        .font(.title3)
                        .bold()
                        //.padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("単位数:")
                                .fontWeight(.semibold)
                            Text(viewModel.credits)
                        }
                        HStack {
                            Text("評価基準:")
                                .fontWeight(.semibold)
                            Text(viewModel.evaluation)
                        }
                        HStack {
                            Text("参考書:")
                                .fontWeight(.semibold)
                            Text(viewModel.references)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    if let syllabus = viewModel.syllabus {
                        NavigationLink(destination: SyllabusDetailView(syllabus: syllabus)) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("シラバスの詳細を表示")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
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
    }
}

