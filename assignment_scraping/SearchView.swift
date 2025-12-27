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
    @StateObject private var clubManager = ClubDataManager.shared // ✅ サークル検索用
    
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
    
    // ✅ サークルのフィルタリング
    private var filteredClubs: [Club] {
        clubManager.searchClubs(text: searchText)
    }
    
    var body: some View {
        content
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "検索"
            )
            .onChange(of: searchText) { _, newValue in
                Task { await performSearch(query: newValue) }
            }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            scopePicker
            resultsList
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $selectedScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in   // ← id追加（保険）
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
    }

    private var resultsList: some View {
        List {
            classSection
            mapSection
            //clubSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
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
    
    @ViewBuilder private var classSection: some View {
        if shouldShow(.class) {
            Section(header: Text("授業")) {
                if isSearching {
                    HStack { Spacer(); ProgressView("検索中..."); Spacer() }
                } else if searchResultsClasses.isEmpty && !searchText.isEmpty {
                    Text("該当なし").foregroundColor(.secondary)
                } else if searchText.isEmpty {
                    Text("授業名を入力して検索").foregroundColor(.secondary)
                } else {
                    ForEach(searchResultsClasses) { item in
                        NavigationLink {
                            SyllabusDetailView(syllabus: item.toSyllabus, day: "ー", period: 0)
                        } label: {
                            classRow(item)
                        }
                    }
                }
            }
        }
    }

    private func classRow(_ item: ClassSearchResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                Text(item.teacher).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var mapSection: some View {
        if shouldShow(.map) && !filteredMaps.isEmpty {
            Section(header: Text("地図")) {
                ForEach(filteredMaps) { location in
                    NavigationLink {
                        MapDetailView(location: location)
                    } label: {
                        mapRow(location)
                    }
                }
            }
        }
    }

    private func mapRow(_ location: MapLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "map.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name).lineLimit(1)
                Text(location.campus).font(.caption).foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

//    @ViewBuilder private var clubSection: some View {
//        if shouldShow(.circle) && !filteredClubs.isEmpty {
//            Section(header: Text("サークル")) {
//                ForEach(filteredClubs) { club in
//                    NavigationLink {
//                        ClubDetailView(club: club)
//                    } label: {
//                        clubRow(club)
//                    }
//                }
//            }
//        }
//    }

    private func clubRow(_ club: Club) -> some View {
        HStack(spacing: 12) {
            if let url = URL(string: club.imgURL), !club.imgURL.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.3.fill")
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(club.genre)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)

                Text(club.clubName).font(.body.weight(.medium))

                if !club.keywords.isEmpty {
                    Text(club.keywords.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

