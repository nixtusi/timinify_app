//
//  SearchDataModel.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/01.
//

import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - 検索スコープ
enum SearchScope: String, CaseIterable, Identifiable {
    case all = "すべて"
    case `class` = "授業"
    case account = "アカウント"
    case map = "地図"
    
    var id: String { self.rawValue }
}

// MARK: - マップデータモデル
struct MapLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - ユーザー（フレンド）モデル（ダミー）
struct UserAccount: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
}

// MARK: - 授業モデル（検索結果用）
struct ClassSearchResult: Identifiable {
    let id: String
    let title: String
    let teacher: String
    let rawData: [String: Any] // Firestoreの生データ（シラバス変換用）
    
    init(document: QueryDocumentSnapshot) {
        self.id = document.documentID
        let data = document.data()
        self.rawData = data
        
        // ✅ 修正: ユーザー提示のフィールド名に対応
        self.title = data["開講科目名"] as? String ?? "名称未設定"
        
        // "担当" があればそれを、なければ "成績入力担当" を使用、それもなければ不明とする
        if let t = data["担当"] as? String, !t.isEmpty {
            self.teacher = t
        } else {
            self.teacher = data["成績入力担当"] as? String ?? "担当不明"
        }
    }
    
    // Syllabusモデルへ変換
    var toSyllabus: Syllabus {
        let data = self.rawData
        
        // 教科書データのデコード処理（簡易版）
        let textbooks = decodeTextbookContent(from: data["教科書"])
        
        return Syllabus(
            title: data["開講科目名"] as? String ?? "",
            teacher: data["担当"] as? String ?? "",
            credits: data["単位数"] as? String,
            evaluation: data["成績評価基準"] as? String,
            textbooks: textbooks,
            summary: data["授業の概要と計画"] as? String,
            goals: data["授業の到達目標"] as? String,
            language: data["授業における使用言語"] as? String,
            method: data["授業形態"] as? String,
            schedule: data["開講期間"] as? String,
            remarks: data["履修上の注意"] as? String,
            contact: data["オフィスアワー・連絡先"] as? String,
            message: data["学生へのメッセージ"] as? String,
            keywords: data["キーワード"] as? String,
            preparationReview: data["事前・事後学修"] as? String,
            improvements: data["今年度の工夫"] as? String,
            referenceURL: data["参考URL"] as? String,
            evaluationTeacher: data["成績入力担当"] as? String,
            evaluationMethod: data["成績評価方法"] as? String,
            theme: data["授業のテーマ"] as? String,
            references: data["参考書・参考資料等"] as? String,
            code: data["時間割コード"] as? String ?? ""
        )
    }
    
    // 教科書データのデコードヘルパー
    private func decodeTextbookContent(from raw: Any?) -> [TextbookContent] {
        guard let raw = raw else { return [] }
        
        // 文字列の場合
        if let str = raw as? String, !str.isEmpty {
            return [.string(str)]
        }
        
        // 辞書の場合
        if let dict = raw as? [String: Any],
           let text = dict["text"] as? String ?? dict["title"] as? String {
            let link = dict["link"] as? String ?? ""
            if !link.isEmpty {
                return [.object(text: text, link: link)]
            }
            return [.string(text)]
        }
        
        // 配列の場合（再帰的に処理）
        if let array = raw as? [Any] {
            return array.flatMap { decodeTextbookContent(from: $0) }
        }
        
        return []
    }
}

// MARK: - データ提供クラス
class SearchDataProvider {
    static let shared = SearchDataProvider()
    private let db = Firestore.firestore()
    
    // マップデータ（固定）
    let locations: [MapLocation] = [
        MapLocation(name: "人間発達環境学研究科実習観察園、管理棟", latitude: 34.7315583, longitude: 135.2328907),
        MapLocation(name: "武道場（艱貞堂）", latitude: 34.7312839, longitude: 135.2329364),
        MapLocation(name: "第二研究室", latitude: 34.729844, longitude: 135.2344277),
        MapLocation(name: "社会科学系フロンティア館（計算社会科学研究センター）", latitude: 34.7297426, longitude: 135.2338698),
        MapLocation(name: "ラ・クール（模擬法廷棟）", latitude: 34.7292768, longitude: 135.2336583),
        MapLocation(name: "第二学舎（法学研究科）", latitude: 34.7291052, longitude: 135.2333145),
        MapLocation(name: "社会科学系図書館", latitude: 34.729193, longitude: 135.2340875),
        MapLocation(name: "経済経営研究所新館", latitude: 34.7296295, longitude: 135.2346495),
        MapLocation(name: "兼松記念館 （経済経営研究所）", latitude: 34.7293209, longitude: 135.2347568),
        MapLocation(name: "三木記念同窓会館", latitude: 34.7289461, longitude: 135.235363),
        MapLocation(name: "法科大学院自習棟", latitude: 34.728561, longitude: 135.235388),
        MapLocation(name: "本館（経済学研究科、経営学研究科、社会システムイノベーションセンター）", latitude: 34.7282587, longitude: 135.2347466),
        MapLocation(name: "第三学舎", latitude: 34.7285056, longitude: 135.234398),
        MapLocation(name: "第四学舎（企業資料総合センター）", latitude: 34.7288671, longitude: 135.2338617),
        MapLocation(name: "第五学舎（国際協力研究科）", latitude: 34.728294, longitude: 135.2334055),
        MapLocation(name: "出光佐三記念六甲台講堂", latitude: 34.7283337, longitude: 135.2339581),
        MapLocation(name: "社会科学系アカデミア館（放送大学兵庫学習センター）", latitude: 34.7273814, longitude: 135.2336738)
    ]
    
    // ダミーフレンドデータ
    let dummyUsers: [UserAccount] = [
        UserAccount(name: "田中 太郎", iconName: "person.circle.fill"),
        UserAccount(name: "神戸 花子", iconName: "person.crop.circle.badge.checkmark"),
        UserAccount(name: "鈴木 一郎", iconName: "person.circle"),
        UserAccount(name: "佐藤 次郎", iconName: "person.fill"),
        UserAccount(name: "山田 三郎", iconName: "person")
    ]
    
    // ✅ Firestoreから授業を検索（前方一致検索）
    func searchClasses(text: String) async -> [ClassSearchResult] {
        guard !text.isEmpty else { return [] }
        
        do {
            // lecturesサブコレクションを横断検索 (Collection Group Query)
            // "開講科目名" フィールドに対して検索を実行
            let snapshot = try await db.collectionGroup("lectures")
                .whereField("開講科目名", isGreaterThanOrEqualTo: text)
                .whereField("開講科目名", isLessThan: text + "\u{f8ff}")
                .limit(to: 20) // 負荷軽減のため件数制限
                .getDocuments()
            
            return snapshot.documents.map { ClassSearchResult(document: $0) }
        } catch {
            print("❌ Firestore Search Error: \(error.localizedDescription)")
            return []
        }
    }
}
