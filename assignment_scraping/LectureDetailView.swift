import SwiftUI

struct LectureDetailView: View {
    let lectureCode: String
    let dayPeriod: String
    let year: String
    let quarter: String
    
    @StateObject private var viewModel = LectureDetailViewModel()
    
    @State private var editedRoom: String = ""
    @State private var isShowingSyllabusDetail = false
    @State private var isShowingEditView = false
    @State private var isShowingReviewPostView = false // 口コミ投稿シート用
    
    @AppStorage("studentNumber") private var currentStudentID: String = ""
    
    var body: some View {
        let bgColor = Color(hex: viewModel.colorHex).opacity(0.18)
        
        NavigationStack {
            Form {
                basicInfoSection(bgColor: bgColor)
                syllabusSection()
                reviewSection()
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
                    
                    await viewModel.fetchReviews(
                       year: year,
                       quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                       lectureCode: lectureCode
                   )
                }
            }
        }
    }
    
    // MARK: - 基本情報セクション
    @ViewBuilder
    private func basicInfoSection(bgColor: Color) -> some View {
        Section(header: Text("基本情報")) {
            Button {
                isShowingEditView = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("授業名").fontWeight(.semibold)
                        Text(viewModel.title)
                    }
                    HStack {
                        Text("教員名").fontWeight(.semibold)
                        Text(viewModel.teacher)
                    }
                    HStack {
                        Text("教室").fontWeight(.semibold)
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
    }
    
    // MARK: - シラバスセクション
    @ViewBuilder
    private func syllabusSection() -> some View {
        if let syllabus = viewModel.syllabus {
            Section(header: Text("シラバス")) {
                ZStack {
                    Button {
                        isShowingSyllabusDetail = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let credits = viewModel.credits {
                                HStack {
                                    Text("単位数").fontWeight(.semibold)
                                    Text(credits)
                                }
                            }
                            
                            if let evaluation = viewModel.evaluation {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("評価基準").fontWeight(.semibold)
                                    Text(evaluation)
                                }
                            }

                            if let textbooks = syllabus.textbooks, !textbooks.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("教科書")
                                        .fontWeight(.semibold)
                                    ForEach(textbooks) { book in
                                        textbookRow(book)
                                    }
                                }
                            }

                            if hasReferences {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("参考書・参考資料等").fontWeight(.semibold)
                                    Text(viewModel.references ?? "")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(.primary)
                    }
                    
                    NavigationLink(
                        destination: SyllabusDetailView(syllabus: syllabus),
                        isActive: $isShowingSyllabusDetail,
                        label: { EmptyView() }
                    )
                    .hidden()
                }
            }
        }
    }
    
    // MARK: - 口コミセクション
    @ViewBuilder
    private func reviewSection() -> some View {
        Section(header: Text("口コミ")) {
            if viewModel.reviews.isEmpty {
                Text("口コミはまだありません")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // 総合評価表示（星 + 数字）に変更
                    HStack {
                        Text("総合評価").fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 4) {
                            StarRatingView(score: Float(viewModel.averageRating), starSize: 14, spacing: 2)
                            Text(String(format: "%.1f", viewModel.averageRating))
                                .foregroundColor(.black)
                        }
                    }
                    
                    // 楽単度表示（星 + 数字）に変更
                    HStack {
                        Text("楽単度").fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 4) {
                            StarRatingView(score: Float(viewModel.averageEasyScore), starSize: 14, spacing: 2)
                            Text(String(format: "%.1f", viewModel.averageEasyScore))
                                .foregroundColor(.black)
                        }
                    }
                    
                    HStack {
                        Text("出席頻度").fontWeight(.semibold)
                        Spacer()
                        let options = ["毎回確認される", "ときどき確認される", "ほとんど確認されない", "出席確認なし"]
                        let counts = viewModel.attendanceFrequencyCounts
                        let mostFrequent = options.max { lhs, rhs in
                            (counts[lhs] ?? 0, options.firstIndex(of: lhs) ?? 0) <
                                (counts[rhs] ?? 0, options.firstIndex(of: rhs) ?? 0)
                        }
                        if let top = mostFrequent, let count = counts[top], count > 0 {
                            Text(top)
                        } else {
                            Text("データがありません").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        
        Section {
            // student_id が空でないことを確認
            if !currentStudentID.isEmpty {
                // すでに投稿済みか確認
                let alreadyPosted = viewModel.reviews.contains { $0.student_id == currentStudentID }
                if !alreadyPosted {
                    Button("口コミを追加") {
                        isShowingReviewPostView = true
                    }
                    .sheet(isPresented: $isShowingReviewPostView, onDismiss: {
                        Task {
                            // 投稿後に再取得
                            await viewModel.fetchReviews(
                                year: year,
                                quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                                lectureCode: lectureCode
                            )
                        }
                    }) {
                        ReviewPostView(
                            year: year,
                            quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                            lectureCode: lectureCode
                        )
                    }
                }
            }
        }

        // 口コミリスト（コメントがあるものだけ表示）
        Section {
            ForEach(viewModel.reviews.filter { !$0.freeComment.isEmpty }) { review in
                VStack(alignment: .leading, spacing: 6) {
                    // ⭐ 総合評価
                    HStack {
                        Text("総合評価")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 2) {
                            StarRatingView(score: Float(review.rating), starSize: 12, spacing: 1)
                        }
                        
                        Spacer()
                        
                        Text("楽単度")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 2) {
                            StarRatingView(score: Float(review.easyScore), starSize: 12, spacing: 1)
                        }
                    }
                    
                    // 自由記述コメント（空でない場合のみ）
                    if !review.freeComment.isEmpty {
                        //Divider()
                        Text(review.freeComment)
                            .font(.body)
                            .padding(.top, 4)
                    }

                    // 投稿日と学籍情報の表示
                    HStack {
                        Text(review.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let id = review.student_id
                        let yearPrefix = id.prefix(2)
                        let facultyMap = [
                            "l": "文学部",
                            "c": "国際文化学部",
                            "d": "発達科学部",
                            "h": "国際人間科学部",
                            "j": "法学部",
                            "e": "経済学部",
                            "b": "経営学部",
                            "s": "理学部",
                            "m": "医学部",
                            "t": "工学部",
                            "a": "農学部",
                            "z": "海洋政策科学部"
                        ]
                        
                        if id.count > 7 {
                            let facultyIndex = id.index(id.startIndex, offsetBy: 7)
                            let facultyCode = String(id[facultyIndex])
                            let faculty = facultyMap[facultyCode] ?? "不明"
                            Text("(20\(yearPrefix)年度入学・\(faculty))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("学籍番号エラー")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - 補助プロパティ
    private var hasReferences: Bool {
        !(viewModel.references ?? "").isEmpty
    }
    
    @ViewBuilder
    private func textbookRow(_ book: TextbookContent) -> some View {
        if let url = book.url {
            Link(book.displayText, destination: url)
        } else {
            Text(book.displayText)
        }
    }
}
