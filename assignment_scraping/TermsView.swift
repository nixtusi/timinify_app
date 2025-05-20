//
//  TermsView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/05/15.
//

import SwiftUI

struct TermsView: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "Terms", withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let content = String(data: data, encoding: .utf8) {
            ScrollView {
                Text(LocalizedStringKey(content)) // Markdownをレンダリング
                    .padding()
            }
            .navigationTitle("利用規約")
        } else {
            Text("利用規約を読み込めませんでした。")
                .foregroundColor(.red)
        }
    }
}
