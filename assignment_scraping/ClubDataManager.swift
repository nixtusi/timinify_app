//
//  ClubDataManager.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import Foundation
import FirebaseFirestore

class ClubDataManager: ObservableObject {
    static let shared = ClubDataManager()
    
    @Published var clubs: [Club] = []
    private let db = Firestore.firestore()
    private let localKey = "savedClubsData"
    
    init() {
        loadClubsFromLocal()
    }
    
    // MARK: - 全件取得 & 保存 (データ更新画面用)
    @MainActor
    func fetchAndSaveClubs() async throws {
        let snapshot = try await db.collection("clubs").getDocuments()
        let fetchedClubs = snapshot.documents.compactMap { document -> Club? in
            try? document.data(as: Club.self)
        }
        
        self.saveToLocal(fetchedClubs)
        self.clubs = fetchedClubs
    }
    
    // MARK: - 単一サークルの最新情報を取得 & 更新 (詳細画面用)
    @MainActor
    func fetchSingleClub(clubName: String) async -> Club? {
        do {
            let doc = try await db.collection("clubs").document(clubName).getDocument()
            if let latestClub = try? doc.data(as: Club.self) {
                print("🔄 サークル情報を更新: \(latestClub.clubName)")
                self.updateLocalClub(latestClub)
                return latestClub
            }
        } catch {
            print("❌ サークル詳細取得エラー: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - ローカルデータの個別更新
    private func updateLocalClub(_ newClub: Club) {
        if let index = clubs.firstIndex(where: { $0.clubName == newClub.clubName }) {
            clubs[index] = newClub
        } else {
            clubs.append(newClub)
        }
        saveToLocal(clubs)
    }
    
    // MARK: - ローカルへ保存
    private func saveToLocal(_ data: [Club]) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: localKey)
        }
    }
    
    // MARK: - ローカルから読み込み
    func loadClubsFromLocal() {
        if let data = UserDefaults.standard.data(forKey: localKey),
           let decoded = try? JSONDecoder().decode([Club].self, from: data) {
            self.clubs = decoded
        }
    }
    
    // MARK: - 検索
    func searchClubs(text: String) -> [Club] {
        if text.isEmpty { return clubs }
        return clubs.filter { club in
            club.clubName.contains(text) ||
            club.genre.contains(text) ||
            club.keywords.contains { $0.contains(text) }
        }
    }
}
