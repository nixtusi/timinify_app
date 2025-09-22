//
//  AddMemoView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/08/07.
//

import SwiftUI

struct AddMemoView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storage: MemoStorage
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    TextEditor(text: $text)
                        .padding()
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 200)

                    Spacer()
                }
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .padding()
            .navigationTitle("メモを追加")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                            storage.addMemo(text)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
