//
//  SearchView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/01.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedScope: SearchScope = .all
    
    // 検索結果の状態管理
    @State private var searchResultsClasses: [ClassSearchResult] = []
    @State private var isSearching = false
    
    private let provider = SearchDataProvider.shared
    
    // ローカルフィルタリング（アカウント・地図）
    private var filteredUsers: [UserAccount] {
        if searchText.isEmpty { return provider.dummyUsers }
        return provider.dummyUsers.filter { $0.name.contains(searchText) }
    }
    
    private var filteredMaps: [MapLocation] {
        if searchText.isEmpty { return provider.locations }
        return provider.locations.filter { $0.name.contains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // スコープ選択
                Picker("Scope", selection: $selectedScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemBackground))
                
                List {
                    // アカウントセクション
                    if shouldShow(.account) && !filteredUsers.isEmpty {
                        Section(header: Text("アカウント")) {
                            ForEach(filteredUsers) { user in
                                HStack(spacing: 12) {
                                    Image(systemName: user.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                    Text(user.name)
                                        .font(.body)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // 授業セクション（Firestore検索結果）
                    if shouldShow(.class) {
                        Section(header: Text("授業")) {
                            if isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView("検索中...")
                                    Spacer()
                                }
                            } else if searchResultsClasses.isEmpty && !searchText.isEmpty {
                                Text("該当なし")
                                    .foregroundColor(.secondary)
                            } else if searchText.isEmpty {
                                Text("授業名を入力して検索")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(searchResultsClasses) { item in
                                    // 修正: シートを経由せず直接画面遷移
                                    NavigationLink(destination: SyllabusDetailView(
                                        syllabus: item.toSyllabus,
                                        day: "ー", // 検索からの場合は「ー」を渡してタイトルを「シラバス」にする
                                        period: 0
                                    )) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "book.closed.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .foregroundColor(.blue)
                                            
                                            // リストでは「アイコン＋名前」のみシンプルに
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                
                                                Text(item.teacher)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 地図セクション
                    if shouldShow(.map) && !filteredMaps.isEmpty {
                        Section(header: Text("地図")) {
                            ForEach(filteredMaps) { location in
                                NavigationLink(destination: MapDetailView(location: location)) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "map.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.green)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(location.name)
                                                .font(.body)
                                                .lineLimit(1)
                                            
                                            Text(location.campus)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("検索")
            // ✅ 変更: タイトルを小さく（インライン）して、検索バーを最初から最上部に持ってくる
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "検索")
            // 検索テキスト変更時の処理
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
        }
    }
    
    private func shouldShow(_ scope: SearchScope) -> Bool {
        return selectedScope == .all || selectedScope == scope
    }
    
    // Firestore検索実行
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                searchResultsClasses = []
            }
            return
        }
        
        // 授業スコープが含まれていなければスキップ
        guard shouldShow(.class) else { return }
        
        // デバウンス（連打防止）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        if query != searchText { return }
        
        await MainActor.run { isSearching = true }
        
        let results = await provider.searchClasses(text: query)
        
        await MainActor.run {
            self.searchResultsClasses = results
            self.isSearching = false
        }
    }
}
