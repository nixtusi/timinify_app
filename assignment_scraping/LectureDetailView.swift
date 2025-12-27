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
    
    @State private var deleteTarget: Review? = nil
    @State private var showDeleteAlert = false
    
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
                        SyllabusDetailView(
                            syllabus: syllabus,
                            day: String(dayPeriod.prefix(1)),
                            period: Int(String(dayPeriod.suffix(1))) ?? 0
                        )
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
            
            // 口コミセクション（置き換え）
            Section(header: Text("口コミ")) {
                if viewModel.reviews.isEmpty {
                    Text("口コミはまだありません")
                } else {
                    // ✅ 統計カード全体をタップで ReviewsView へ
                    NavigationLink {
                        ReviewsView(
                            viewModel: viewModel,
                            year: year,
                            quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                            lectureCode: lectureCode,
                            currentStudentID: currentStudentID
                        )
                    } label: {
                        ReviewStatsCard(viewModel: viewModel)   // 下で定義
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            
            // ▼ 統計カードの直後に追加
            let canPost = !currentStudentID.isEmpty &&
            !viewModel.reviews.contains { $0.student_id == currentStudentID }
            
            if canPost {
                AddReviewCard {
                    isShowingReviewPost = true
                }
                .sheet(isPresented: $isShowingReviewPost, onDismiss: {
                    Task {
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
            
            // 自由記述コメント（最大3件、各3行、タップで詳細画面へ）
            Section {
                ForEach(
                    viewModel.sortedReviews(.high)
                        .filter { !$0.freeComment.isEmpty }
                        .prefix(3)
                ) { review in
                    
                    NavigationLink {
                        ReviewDetailView(
                            viewModel: viewModel,
                            year: year,
                            quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                            lectureCode: lectureCode,
                            currentStudentID: currentStudentID,
                            review: review
                        )
                    } label: {
                        ReviewRow(review: review, lineLimit: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .reviewContextMenu(
                        review: review,
                        year: year,
                        quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                        lectureCode: lectureCode,
                        currentStudentID: currentStudentID,
                        viewModel: viewModel,
                        onRequestDelete: {
                            deleteTarget = review
                            showDeleteAlert = true
                        }
                    )
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
        .notifyOnDisappear(.timetableDidChange)
        .alert("口コミを削除しますか？",
               isPresented: $showDeleteAlert,
               presenting: deleteTarget) { target in
            Button("削除", role: .destructive) {
                Task {
                    await viewModel.deleteReview(
                        year: year,
                        quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                        lectureCode: lectureCode,
                        reviewId: target.id
                    )
                    await viewModel.fetchReviews(
                        year: year,
                        quarter: quarter.replacingOccurrences(of: "Q", with: ""),
                        lectureCode: lectureCode
                    )
                }
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { _ in
            Text("この操作は取り消せません。")
        }
    }
}

// 統計カード（LectureDetailViewでもReviewsViewでも使い回し）
//struct ReviewStatsCard: View {
//    @ObservedObject var viewModel: LectureDetailViewModel
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("総合評価").fontWeight(.semibold)
//                Spacer()
//                HStack(spacing: 4) {
//                    StarRatingView(score: Float(viewModel.averageRating), starSize: 14, spacing: 2)
//                    Text(String(format: "%.1f", viewModel.averageRating))
//                }
//            }
//            HStack {
//                Text("楽単度").fontWeight(.semibold)
//                Spacer()
//                HStack(spacing: 4) {
//                    StarRatingView(score: Float(viewModel.averageEasyScore), starSize: 14, spacing: 2)
//                    Text(String(format: "%.1f", viewModel.averageEasyScore))
//                }
//            }
//            HStack {
//                Text("出欠確認").fontWeight(.semibold)
//                Spacer()
//                Text(topAttendanceLabel(counts: viewModel.attendanceFrequencyCounts))
//                    .foregroundColor(.primary)
//            }
//        }
//    }
//
//    private func topAttendanceLabel(counts: [String: Int]) -> String {
//        let options = ["毎回確認される", "ときどき確認される", "ほとんど確認されない", "出席確認なし"]
//        let top = options.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
//        if let t = top, (counts[t] ?? 0) > 0 { return t }
//        return "データがありません"
//    }
//}



// コメント1件の行表示（学籍/日付も表示、本文は行数制限可能）
//struct ReviewRow: View {
//    let review: Review
//    var lineLimit: Int? = nil
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            // 1行目：評価
//            HStack {
//                Text("総合評価").font(.subheadline).foregroundColor(.secondary)
//                StarRatingView(score: Float(review.rating), starSize: 12, spacing: 1)
//                Spacer()
//                Text("楽単度").font(.subheadline).foregroundColor(.secondary)
//                StarRatingView(score: Float(review.easyScore), starSize: 12, spacing: 1)
//            }
//            // 本文
//            if !review.freeComment.isEmpty {
//                Text(review.freeComment)
//                    .font(.body)
//                    .lineLimit(lineLimit)
//                    .padding(.top, 2)
//            }
//            // メタ
//            HStack {
//                Text(review.createdAt, style: .date)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                Spacer()
//                Text(studentYearFaculty(review.student_id))
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        }
//    }
//
//    private func studentYearFaculty(_ id: String) -> String {
//        guard id.count > 7 else { return "学籍番号エラー" }
//        let yearPrefix = id.prefix(2)
//        let i = id.index(id.startIndex, offsetBy: 7)
//        let code = String(id[i])
//        let map = [
//            "l": "文学部","c": "国際文化学部","d": "発達科学部",
//            "h": "国際人間科学部","j": "法学部","e": "経済学部",
//            "b": "経営学部","s": "理学部","m": "医学部",
//            "t": "工学部","a": "農学部","z": "海洋政策科学部"
//        ]
//        return "(20\(yearPrefix)年度入学・\(map[code] ?? "不明"))"
//    }
//}

struct AddReviewCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .imageScale(.large)
                    .symbolRenderingMode(.monochrome)
                Text("口コミを追加").bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.blue)
            //.background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// 共通: 消えるタイミングで通知を飛ばすモディファイア
struct NotifyOnDisappear: ViewModifier {
    let name: Notification.Name
    func body(content: Content) -> some View {
        content.onDisappear {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}
extension View {
    func notifyOnDisappear(_ name: Notification.Name) -> some View {
        modifier(NotifyOnDisappear(name: name))
    }
}

//extension View {
//    func reviewContextMenu(
//        review: Review,
//        year: String,
//        quarter: String,
//        lectureCode: String,
//        currentStudentID: String,
//        viewModel: LectureDetailViewModel,
//        onRequestDelete: @escaping () -> Void
//    ) -> some View {
//        self.contextMenu {
//            Button("👍 高評価") {
//                guard !currentStudentID.isEmpty else { return }
//                Task {
//                    await viewModel.voteReview(
//                        year: year, quarter: quarter, lectureCode: lectureCode,
//                        reviewId: review.id, voterId: currentStudentID, voteValue: 1
//                    )
//                }
//            }
//
//            Button("👎 低評価") {
//                guard !currentStudentID.isEmpty else { return }
//                Task {
//                    await viewModel.voteReview(
//                        year: year, quarter: quarter, lectureCode: lectureCode,
//                        reviewId: review.id, voterId: currentStudentID, voteValue: -1
//                    )
//                }
//            }
//
//            if review.student_id == currentStudentID {
//                Divider()
//                Button(role: .destructive) {
//                    onRequestDelete()   // ✅ ここでは削除しない
//                } label: {
//                    Text("削除する")
//                }
//            }
//        }
//    }
//}
