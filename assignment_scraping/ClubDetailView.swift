//
//  ClubDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import SwiftUI

struct ClubDetailView: View {
    // 画面内で状態が変わるため @State に変更
    @State private var club: Club
    
    init(club: Club) {
        _club = State(initialValue: club)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // サムネイル画像
                if let url = URL(string: club.imgURL), !club.imgURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView())
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            Rectangle().fill(Color.gray.opacity(0.2))
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                }
                
                // タイトルとジャンル
                VStack(alignment: .leading, spacing: 8) {
                    Text(club.genre)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(club.clubName)
                        .font(.title)
                        .bold()
                }
                
                Divider()
                
                // 基本情報
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "person.3", label: "人数", value: "\(club.population)人")
                    InfoRow(icon: "calendar", label: "活動頻度", value: club.frequency)
                    InfoRow(icon: "checkmark.seal", label: "公認", value: club.official ? "公認団体" : "非公認")
                    InfoRow(icon: "figure.walk", label: "初心者歓迎", value: club.beginner ? "はい" : "いいえ")
                    InfoRow(icon: "arrow.triangle.2.circlepath", label: "兼部", value: club.doubleDuty ? "可" : "不可")
                    InfoRow(icon: "person.crop.circle.badge.exclamationmark", label: "マネージャー募集", value: club.manager ? "あり" : "なし")
                    InfoRow(icon: "graduationcap", label: "神大生限定", value: club.kuOnly ? "はい" : "いいえ")
                }
                
                Divider()
                
                // キーワード
                if !club.keywords.isEmpty {
                    Text("キーワード")
                        .font(.headline)
                    
                    FlowLayout(items: club.keywords) { keyword in
                        Text("#\(keyword)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // リンク
                VStack(spacing: 12) {
                    if let url = URL(string: club.linkForInstagram), !club.linkForInstagram.isEmpty {
                        LinkButton(title: "Instagram", url: url, color: .purple)
                    }
                    if let url = URL(string: club.linkForX), !club.linkForX.isEmpty {
                        LinkButton(title: "X (Twitter)", url: url, color: .black)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("サークル詳細")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ 画面表示時に最新データを取得して更新
        .task {
            if let latest = await ClubDataManager.shared.fetchSingleClub(clubName: club.clubName) {
                self.club = latest
            }
        }
    }
}

// 補助ビュー (変更なし)
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .bold()
        }
    }
}

struct LinkButton: View {
    let title: String
    let url: URL
    let color: Color
    
    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .bold()
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(10)
        }
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding([.horizontal, .vertical], 4)
                        .alignmentGuide(.leading) { d in
                            if (abs(width - d.width) > geo.size.width) {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item == items.last {
                                width = 0
                            } else {
                                width -= d.width
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item == items.last {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(height: 100)
    }
}
