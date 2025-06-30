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
    
    //@State private var isEditingRoom = false
    @State private var editedRoom: String = ""
    
    @State private var isShowingSyllabusDetail = false
    @State private var isShowingEditView = false
    
    
    var body: some View {
        let bgColor = Color(hex: viewModel.colorHex).opacity(0.18)
        
        return NavigationStack {
            Form {
                // 基本情報セクション
                Section(header: Text("基本情報")) {
                    Button {
                        isShowingEditView = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("授業名:")
                                    .fontWeight(.semibold)
                                Text(viewModel.title)
                            }

                            HStack {
                                Text("教員名:")
                                    .fontWeight(.semibold)
                                Text(viewModel.teacher)
                            }

                            HStack {
                                Text("教室:")
                                    .fontWeight(.semibold)
                                Text(viewModel.room)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(bgColor)
                    .background(
                        NavigationLink(
                            destination: LectureEditView(
                                lectureCode: lectureCode,
                                year: year,
                                quarter: quarter,
                                title: viewModel.title,
                                teacher: viewModel.teacher,
                                room: viewModel.room,
                                day: String(dayPeriod.prefix(1)),
                                period: Int(String(dayPeriod.suffix(1))) ?? 1
                            ),
                            isActive: $isShowingEditView,
                            label: { EmptyView() }
                        )
                        .opacity(0)
                    )
                }
                
                // シラバスセクション（ある場合のみ表示）
                if let syllabus = viewModel.syllabus {
                    Section(header: Text("シラバス")) {
                        // 遷移用の状態変数
                        Button {
                            // ボタン押下時にナビゲーション遷移
                            isShowingSyllabusDetail = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("単位数:")
                                        .fontWeight(.semibold)
                                    Text(viewModel.credits)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("評価基準:")
                                        .fontWeight(.semibold)
                                    Text(viewModel.evaluation)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("参考書:")
                                        .fontWeight(.semibold)
                                    Text(viewModel.references)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                            .foregroundColor(.primary)
                        }
                        // Hidden NavigationLink を使って画面遷移
                        .background(
                            NavigationLink("", destination: SyllabusDetailView(syllabus: syllabus), isActive: $isShowingSyllabusDetail)
                                .opacity(0)
                        )
                    }
                }
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
