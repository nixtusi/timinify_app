//
//  EditMemoView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/07.
//
//

import SwiftUI

struct EditMemoView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storage: MemoStorage
    @Binding var memo: LectureMemo

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $memo.text)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 200)

                Spacer()
            }
            .padding()
            .navigationTitle("メモの詳細")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        storage.updateMemo(memo)
                        dismiss()
                    }
                }
            }
        }
    }
}
