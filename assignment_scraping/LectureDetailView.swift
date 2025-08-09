//LectureDetailView.swift

import SwiftUI

struct LectureDetailView: View {
    let lectureCode: String
    let dayPeriod: String
    let year: String
    let quarter: String

    @StateObject private var viewModel = LectureDetailViewModel()
    @StateObject private var memoStorage: MemoStorage
    @AppStorage("studentNumber") private var currentStudentID: String = ""
    @State private var isShowingReviewPost = false

    init(lectureCode: String,
         dayPeriod: String,
         year: String,
         quarter: String)
    {
        self.lectureCode = lectureCode
        self.dayPeriod = dayPeriod
        self.year = year
        self.quarter = quarter
        _memoStorage = StateObject(wrappedValue: MemoStorage(lectureCode: lectureCode))
    }

    var body: some View {
        Form {
            // ────────────────────────────────
            // 基本情報セクション
            // ────────────────────────────────
            Section(header: Text("基本情報")) {
                NavigationLink {
                    LectureEditView(
                        lectureCode: lectureCode,
                        year: year,
                        quarter: quarter,
                        title: viewModel.title,
                        teacher: viewModel.teacher,
                        room: viewModel.room,
                        day: String(dayPeriod.prefix(1)),
                        period: Int(String(dayPeriod.suffix(1))) ?? 1
                    )
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
                    .padding(.vertical, 4)
                }
                //.navigationLinkIndicatorVisibility(.hidden)
                .listRowBackground(Color(hex: viewModel.colorHex).opacity(0.18))
            }

            // ────────────────────────────────
            // シラバスセクション
            // ────────────────────────────────
            if let syllabus = viewModel.syllabus {
                Section(header: Text("シラバス")) {
                    NavigationLink {
                        SyllabusDetailView(syllabus: syllabus)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let credits = viewModel.credits {
                                HStack {
                                    Text("単位数").fontWeight(.semibold)
                                    Text(credits)
                                }
                            }

                            if let method = syllabus.evaluationMethod {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("評価方法").fontWeight(.semibold)
                                    Text(method)
                                }
                            }
                            
                            if let textbooks = syllabus.textbooks, !textbooks.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("教科書").fontWeight(.semibold)
                                    ForEach(textbooks) { book in
                                        // ✅ リンクを使わず、常に黒文字で表示
                                        Text(book.displayText)
                                            //.foregroundColor(.black)      // ← いつでも黒
                                            .foregroundStyle(.primary)  // ← ダークモード対応にするならこっち
                                    }
                                }
                            }
                            
                            if !(viewModel.references ?? "").isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("参考書・参考資料等").fontWeight(.semibold)
                                    Text(viewModel.references ?? "")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    //.hideDisclosureAccessory()
                }
            }

            // ────────────────────────────────
            // メモセクション
            // ────────────────────────────────
            Section(header: Text("メモ")) {
                NavigationLink {
                    AddMemoView(storage: memoStorage)
                } label: {
                    Text("メモを追加")
                        .foregroundColor(.blue)  // ここで文字色を青に
                }                //.hideDisclosureAccessory()

                ForEach(memoStorage.memos) { memo in
                    if let idx = memoStorage.memos.firstIndex(where: { $0.id == memo.id }) {
                        NavigationLink {
                            EditMemoView(storage: memoStorage,
                                         memo: $memoStorage.memos[idx])
                        } label: {
                            VStack(alignment: .leading) {
                                Text(memo.text)
                                Text(memo.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: memoStorage.deleteMemo)
            }

            // ────────────────────────────────
            // 口コミセクション
            // ────────────────────────────────
            Section(header: Text("口コミ")) {
                if viewModel.reviews.isEmpty {
                    Text("口コミはまだありません")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // 総合評価
                        HStack {
                            Text("総合評価").fontWeight(.semibold)
                            Spacer()
                            HStack(spacing: 4) {
                                StarRatingView(score: Float(viewModel.averageRating),
                                               starSize: 14,
                                               spacing: 2)
                                Text(String(format: "%.1f", viewModel.averageRating))
                            }
                        }
                        // 楽単度
                        HStack {
                            Text("楽単度").fontWeight(.semibold)
                            Spacer()
                            HStack(spacing: 4) {
                                StarRatingView(score: Float(viewModel.averageEasyScore),
                                               starSize: 14,
                                               spacing: 2)
                                Text(String(format: "%.1f", viewModel.averageEasyScore))
                            }
                        }
                        // 出席頻度
                        HStack {
                            Text("出席頻度").fontWeight(.semibold)
                            Spacer()
                            let options = ["毎回確認される", "ときどき確認される", "ほとんど確認されない", "出席確認なし"]
                            let counts = viewModel.attendanceFrequencyCounts
                            if let top = options.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }),
                               (counts[top] ?? 0) > 0 {
                                Text(top)
                            } else {
                                Text("データがありません").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // ────────────────────────────────
            // 口コミ投稿ボタン
            // ────────────────────────────────
            Section {
                if !currentStudentID.isEmpty
                   && !viewModel.reviews.contains(where: { $0.student_id == currentStudentID })
                {
                    Button("口コミを追加") {
                        isShowingReviewPost = true
                    }
                    .sheet(isPresented: $isShowingReviewPost) {
                        ReviewPostView(
                            year: year,
                            quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                            lectureCode: lectureCode
                        )
                        .onDisappear {
                            Task {
                                await viewModel.fetchReviews(
                                    year: year,
                                    quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                                    lectureCode: lectureCode
                                )
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────
            // 自由記述コメント一覧
            // ────────────────────────────────
            Section {
                ForEach(viewModel.reviews.filter { !$0.freeComment.isEmpty }) { review in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("総合評価").font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            StarRatingView(score: Float(review.rating),
                                           starSize: 12, spacing: 1)
                            Spacer()
                            Text("楽単度").font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            StarRatingView(score: Float(review.easyScore),
                                           starSize: 12, spacing: 1)
                        }
                        if !review.freeComment.isEmpty {
                            Text(review.freeComment)
                                .font(.body)
                                .padding(.top, 4)
                        }
                        HStack {
                            Text(review.createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            let id = review.student_id
                            if id.count > 7 {
                                let yearPrefix = id.prefix(2)
                                let codeIdx = id.index(id.startIndex, offsetBy: 7)
                                let facultyCode = String(id[codeIdx])
                                let facultyMap = [
                                    "l": "文学部","c": "国際文化学部","d": "発達科学部",
                                    "h": "国際人間科学部","j": "法学部","e": "経済学部",
                                    "b": "経営学部","s": "理学部","m": "医学部",
                                    "t": "工学部","a": "農学部","z": "海洋政策科学部"
                                ]
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
        .navigationTitle("\(dayPeriod.prefix(1))曜 \(dayPeriod.suffix(1))限")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.fetchLectureDetails(
                    studentId: currentStudentID,
                    admissionYear: "2024",
                    year: year,
                    quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                    day: String(dayPeriod.prefix(1)),
                    period: Int(String(dayPeriod.suffix(1))) ?? 1,
                    lectureCode: lectureCode
                )
                let qDisp = quarter.replacingOccurrences(of: "Q", with: "第") + "クォーター"
                await viewModel.fetchSyllabus(
                    year: year,
                    quarter: qDisp,
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

