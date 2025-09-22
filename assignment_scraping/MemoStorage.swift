//
//  MemoStorage.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/07.
//

import Foundation

class MemoStorage: ObservableObject {
    @Published var memos: [LectureMemo] = []
    private let key: String
    
    init(lectureCode: String) {
        self.key = "lecture_memos_\(lectureCode)"
        load()
    }

    func addMemo(_ text: String) {
        let newMemo = LectureMemo(id: UUID(), text: text, date: Date())
        memos.insert(newMemo, at: 0)
        saveSorted()
    }
    
    func updateMemo(_ memo: LectureMemo) {
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            // 上書き保存時は更新時刻を新しい作成時刻として扱う（並び替え用）
            let updated = LectureMemo(id: memo.id, text: memo.text, date: Date())
            memos[index] = updated
            saveSorted()
        }
    }
    
    func deleteMemo(at offsets: IndexSet) {
        memos.remove(atOffsets: offsets)
        saveSorted()
    }
    
    private func saveSorted() {
        memos.sort { $0.date > $1.date }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(memos) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([LectureMemo].self, from: data) {
            memos = saved
        }
    }
}
