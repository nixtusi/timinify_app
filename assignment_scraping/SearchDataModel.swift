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
    case circle = "サークル"
    
    var id: String { self.rawValue }
}

// MARK: - マップデータモデル
struct MapLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let campus: String // キャンパス名
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - ユーザーモデル（ダミー）
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
    let place: String
    let rawData: [String: Any]
    
    init(document: QueryDocumentSnapshot) {
        self.id = document.documentID
        let data = document.data()
        self.rawData = data
        
        self.title = data["開講科目名"] as? String ?? "名称未設定"
        
        if let t = data["担当"] as? String, !t.isEmpty {
            self.teacher = t
        } else {
            self.teacher = data["成績入力担当"] as? String ?? "担当不明"
        }
        
        self.place = data["開講場所"] as? String ?? data["教室"] as? String ?? ""
    }
    
    var toSyllabus: Syllabus {
        let data = self.rawData
        let textbooks = decodeTextbookContent(from: data["教科書"])
        
        return Syllabus(
            title: data["開講科目名"] as? String ?? "",
            teacher: self.teacher,
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
    
    // ✅ 修正: エラーの原因箇所（nilではなくStringを渡すように修正）
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
            // 修正: linkがString型を期待しているため、nilではなくそのまま渡す
            return [.object(text: text, link: link)]
        }
        
        // 配列の場合
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
    
    // 全キャンパスの地図データ
    let locations: [MapLocation] = [
        // 六甲台第1キャンパス
        MapLocation(name: "人間発達環境学研究科実習観察園、管理棟", latitude: 34.7315583, longitude: 135.2328907, campus: "六甲台第1"),
        MapLocation(name: "武道場（艱貞堂）", latitude: 34.7312839, longitude: 135.2329364, campus: "六甲台第1"),
        MapLocation(name: "第二研究室", latitude: 34.729844, longitude: 135.2344277, campus: "六甲台第1"),
        MapLocation(name: "社会科学系フロンティア館", latitude: 34.7297426, longitude: 135.2338698, campus: "六甲台第1"),
        MapLocation(name: "ラ・クール（模擬法廷棟）", latitude: 34.7292768, longitude: 135.2336583, campus: "六甲台第1"),
        MapLocation(name: "第二学舎（法学研究科）", latitude: 34.7291052, longitude: 135.2333145, campus: "六甲台第1"),
        MapLocation(name: "社会科学系図書館", latitude: 34.729193, longitude: 135.2340875, campus: "六甲台第1"),
        MapLocation(name: "経済経営研究所新館", latitude: 34.7296295, longitude: 135.2346495, campus: "六甲台第1"),
        MapLocation(name: "兼松記念館", latitude: 34.7293209, longitude: 135.2347568, campus: "六甲台第1"),
        MapLocation(name: "三木記念同窓会館", latitude: 34.7289461, longitude: 135.235363, campus: "六甲台第1"),
        MapLocation(name: "法科大学院自習棟", latitude: 34.728561, longitude: 135.235388, campus: "六甲台第1"),
        MapLocation(name: "本館（経済・経営・社シス）", latitude: 34.7282587, longitude: 135.2347466, campus: "六甲台第1"),
        MapLocation(name: "第三学舎", latitude: 34.7285056, longitude: 135.234398, campus: "六甲台第1"),
        MapLocation(name: "第四学舎", latitude: 34.7288671, longitude: 135.2338617, campus: "六甲台第1"),
        MapLocation(name: "第五学舎（国際協力研究科）", latitude: 34.728294, longitude: 135.2334055, campus: "六甲台第1"),
        MapLocation(name: "出光佐三記念六甲台講堂", latitude: 34.7283337, longitude: 135.2339581, campus: "六甲台第1"),
        MapLocation(name: "社会科学系アカデミア館", latitude: 34.7273814, longitude: 135.2336738, campus: "六甲台第1"),

        // 六甲台第2キャンパス
        MapLocation(name: "都市安全研究センター(実験棟)", latitude: 34.7282465, longitude: 135.2377072, campus: "六甲台第2"),
        MapLocation(name: "都市安全研究センター(研究棟)", latitude: 34.727583, longitude: 135.2383, campus: "六甲台第2"),
        MapLocation(name: "研究基盤センター(機器分析部門)", latitude: 34.7280334, longitude: 135.2371483, campus: "六甲台第2"),
        MapLocation(name: "情報基盤センター(分館)", latitude: 34.7278483, longitude: 135.2367192, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・5E,5W,C4棟", latitude: 34.7276887, longitude: 135.2371414, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・LR棟", latitude: 34.7275044, longitude: 135.2368372, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・4E,4W,C3棟", latitude: 34.727358, longitude: 135.2373131, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・3E,3W,C2棟", latitude: 34.7270538, longitude: 135.2374794, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・D1,D2棟", latitude: 34.7268466, longitude: 135.2371897, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・2E,2W,C1棟", latitude: 34.726754, longitude: 135.2376564, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・B棟", latitude: 34.7268548, longitude: 135.2383921, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・1E,1W棟", latitude: 34.726458, longitude: 135.2379093, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・A棟", latitude: 34.726652, longitude: 135.2384887, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・環境防災実験室棟", latitude: 34.7264668, longitude: 135.2384779, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・構造物実験室", latitude: 34.7265065, longitude: 135.2385852, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・建築システム実験室棟", latitude: 34.7264447, longitude: 135.2382526, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・風洞実験室棟", latitude: 34.7263369, longitude: 135.2387686, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・音響実験室棟", latitude: 34.7259619, longitude: 135.2377218, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・音響心理実験室棟", latitude: 34.7258429, longitude: 135.2378827, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・工作技術センター", latitude: 34.7274096, longitude: 135.2364349, campus: "六甲台第2"),
        MapLocation(name: "先端バイオ工学研究センター", latitude: 34.7272333, longitude: 135.2364617, campus: "六甲台第2"),
        MapLocation(name: "先端膜工学研究拠点", latitude: 34.7269952, longitude: 135.23651, campus: "六甲台第2"),
        MapLocation(name: "自然科学総合研究棟3号館", latitude: 34.7266781, longitude: 135.2367975, campus: "六甲台第2"),
        MapLocation(name: "スカイ ダイニング（工学部食堂）", latitude: 34.7264401, longitude: 135.2369048, campus: "六甲台第2"),
        MapLocation(name: "工学研究科・工学会館", latitude: 34.7262328, longitude: 135.2371516, campus: "六甲台第2"),
        MapLocation(name: "産官学連携本部", latitude: 34.726373, longitude: 135.2340471, campus: "六甲台第2"),
        MapLocation(name: "バイオメディカルメンブレン研究", latitude: 34.7265537, longitude: 135.233929, campus: "六甲台第2"),
        MapLocation(name: "自然科学総合研究棟2号館", latitude: 34.7261957, longitude: 135.2345532, campus: "六甲台第2"),
        MapLocation(name: "自然科学総合研究棟1号館", latitude: 34.726081, longitude: 135.2342045, campus: "六甲台第2"),
        MapLocation(name: "自然科学総合研究棟4号館", latitude: 34.7258429, longitude: 135.2337807, campus: "六甲台第2"),
        MapLocation(name: "ライフサイエンスラボラトリー", latitude: 34.7257327, longitude: 135.2334642, campus: "六甲台第2"),
        MapLocation(name: "研究基盤センター（アイソトープ部門）", latitude: 34.7256622, longitude: 135.2332014, campus: "六甲台第2"),
        MapLocation(name: "本部（事務局、保健管理センター）", latitude: 34.7263713, longitude: 135.2354054, campus: "六甲台第2"),
        MapLocation(name: "自然科学系図書館", latitude: 34.7260054, longitude: 135.23566, campus: "六甲台第2"),
        MapLocation(name: "情報基盤センター（本館）", latitude: 34.725829, longitude: 135.235897, campus: "六甲台第2"),
        MapLocation(name: "システム情報学研究科（本館）", latitude: 34.7256615, longitude: 135.2361062, campus: "六甲台第2"),
        MapLocation(name: "バイオシグナル総合研究センター棟", latitude: 34.7255514, longitude: 135.2343652, campus: "六甲台第2"),
        MapLocation(name: "理学研究科・C棟", latitude: 34.7257498, longitude: 135.2346602, campus: "六甲台第2"),
        MapLocation(name: "環境保全推進センター", latitude: 34.7259615, longitude: 135.2348694, campus: "六甲台第2"),
        MapLocation(name: "共同実験室", latitude: 34.7258261, longitude: 135.2352181, campus: "六甲台第2"),
        MapLocation(name: "理学研究科・Y,Z棟", latitude: 34.7256453, longitude: 135.2351484, campus: "六甲台第2"),
        MapLocation(name: "理学研究科・B棟", latitude: 34.7254028, longitude: 135.2351484, campus: "六甲台第2"),
        MapLocation(name: "理学研究科・X棟", latitude: 34.7251471, longitude: 135.235143, campus: "六甲台第2"),
        MapLocation(name: "理学研究科・A棟", latitude: 34.7250413, longitude: 135.2354863, campus: "六甲台第2"),
        MapLocation(name: "研究基盤センター（極低温部門）", latitude: 34.7248208, longitude: 135.2356794, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・農業生産機械工場", latitude: 34.7257636, longitude: 135.2326121, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・畜産加工工場", latitude: 34.725477, longitude: 135.2325584, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・A棟", latitude: 34.7254682, longitude: 135.2336785, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・B棟", latitude: 34.7251448, longitude: 135.2334854, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・C棟", latitude: 34.7250654, longitude: 135.2337429, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・D棟", latitude: 34.7249111, longitude: 135.2332815, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・E棟", latitude: 34.7246333, longitude: 135.2333405, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・F棟", latitude: 34.7245936, longitude: 135.2328256, campus: "六甲台第2"),
        MapLocation(name: "農学研究科・動物飼育舎", latitude: 34.7246268, longitude: 135.2321623, campus: "六甲台第2"),
        MapLocation(name: "人文学研究科・A棟", latitude: 34.7246431, longitude: 135.2343306, campus: "六甲台第2"),
        MapLocation(name: "人文学研究科・C棟、人文科学図書館", latitude: 34.7247533, longitude: 135.2349637, campus: "六甲台第2"),
        MapLocation(name: "人文学研究科・B棟", latitude: 34.7244226, longitude: 135.234733, campus: "六甲台第2"),
        MapLocation(name: "眺望館（男女共同参画推進室）", latitude: 34.7239663, longitude: 135.2338116, campus: "六甲台第2"),
        MapLocation(name: "瀧川記念学術交流会館", latitude: 34.7239928, longitude: 135.2341174, campus: "六甲台第2"),
        MapLocation(name: "六甲台南食堂LANS BOX", latitude: 34.7242, longitude: 135.235192, campus: "六甲台第2"),
        MapLocation(name: "神戸大学百年記念館（神大会館）", latitude: 34.7245351, longitude: 135.2359608, campus: "六甲台第2"),
        MapLocation(name: "山口誓子記念館", latitude: 34.7246652, longitude: 135.2364732, campus: "六甲台第2"),

        // 鶴甲第1キャンパス
        MapLocation(name: "武道場（養心館）", latitude: 34.73216801, longitude: 135.2381131, campus: "鶴甲第1"),
        MapLocation(name: "第二体育館", latitude: 34.73206661, longitude: 135.2377698, campus: "鶴甲第1"),
        MapLocation(name: "第一体育館", latitude: 34.7318946, longitude: 135.2372494, campus: "鶴甲第1"),
        MapLocation(name: "D棟（国際コミュニケーションセンター）", latitude: 34.73162134, longitude: 135.2363904, campus: "鶴甲第1"),
        MapLocation(name: "N棟", latitude: 34.73131274, longitude: 135.2362133, campus: "鶴甲第1"),
        MapLocation(name: "K棟", latitude: 34.73112757, longitude: 135.2359344, campus: "鶴甲第1"),
        MapLocation(name: "化学実験室", latitude: 34.73095123, longitude: 135.23609, campus: "鶴甲第1"),
        MapLocation(name: "C棟", latitude: 34.73110553, longitude: 135.2365352, campus: "鶴甲第1"),
        MapLocation(name: "F棟", latitude: 34.73107848, longitude: 135.2368445, campus: "鶴甲第1"),
        MapLocation(name: "M棟", latitude: 34.73084042, longitude: 135.2364261, campus: "鶴甲第1"),
        MapLocation(name: "B棟（学生センター）", latitude: 34.73066848, longitude: 135.2367318, campus: "鶴甲第1"),
        MapLocation(name: "大、中講義室", latitude: 34.73049654, longitude: 135.2361471, campus: "鶴甲第1"),
        MapLocation(name: "L棟（キャンパスライフ支援センター）", latitude: 34.730426, longitude: 135.2366514, campus: "鶴甲第1"),
        MapLocation(name: "E棟", latitude: 34.73035987, longitude: 135.2370016, campus: "鶴甲第1"),
        MapLocation(name: "A棟（図書館、ラーニングコモンズ）", latitude: 34.73009535, longitude: 135.2367602, campus: "鶴甲第1"),
        MapLocation(name: "学生会館", latitude: 34.72923564, longitude: 135.2361808, campus: "鶴甲第1"),

        // 鶴甲第2キャンパス
        MapLocation(name: "体育館", latitude: 34.73413554, longitude: 135.234655, campus: "鶴甲第2"),
        MapLocation(name: "食堂", latitude: 34.73375653, longitude: 135.2339639, campus: "鶴甲第2"),
        MapLocation(name: "G棟", latitude: 34.73339063, longitude: 135.2334597, campus: "鶴甲第2"),
        MapLocation(name: "D棟", latitude: 34.73389952, longitude: 135.2349074, campus: "鶴甲第2"),
        MapLocation(name: "A棟（人間科学図書館）", latitude: 34.73348953, longitude: 135.2346016, campus: "鶴甲第2"),
        MapLocation(name: "E棟", latitude: 34.73332641, longitude: 135.233915, campus: "鶴甲第2"),
        MapLocation(name: "B棟", latitude: 34.73307954, longitude: 135.2340062, campus: "鶴甲第2"),
        MapLocation(name: "F棟", latitude: 34.7329605, longitude: 135.2333517, campus: "鶴甲第2"),
        MapLocation(name: "C棟", latitude: 34.73256373, longitude: 135.2334804, campus: "鶴甲第2"),

        // 楠キャンパス
        MapLocation(name: "医学部会館", latitude: 34.68557627, longitude: 135.1699142, campus: "楠"),
        MapLocation(name: "立体駐車場", latitude: 34.68585501, longitude: 135.1702713, campus: "楠"),
        MapLocation(name: "第二病棟（清明寮）", latitude: 34.68641311, longitude: 135.1711067, campus: "楠"),
        MapLocation(name: "中央診療棟", latitude: 34.68585082, longitude: 135.171055, campus: "楠"),
        MapLocation(name: "外来診療棟", latitude: 34.68518738, longitude: 135.1708245, campus: "楠"),
        MapLocation(name: "第一病棟", latitude: 34.68534925, longitude: 135.171642, campus: "楠"),
        MapLocation(name: "研究棟E", latitude: 34.68485192, longitude: 135.1719726, campus: "楠"),
        MapLocation(name: "研究棟A", latitude: 34.68473699, longitude: 135.1713505, campus: "楠"),
        MapLocation(name: "医学部管理棟", latitude: 34.68460725, longitude: 135.1706045, campus: "楠"),
        MapLocation(name: "Medical C3 commons", latitude: 34.68470112, longitude: 135.1702296, campus: "楠"),
        MapLocation(name: "研究棟B", latitude: 34.68417297, longitude: 135.1708609, campus: "楠"),
        MapLocation(name: "研究棟C", latitude: 34.68381863, longitude: 135.1709295, campus: "楠"),
        MapLocation(name: "研究棟D", latitude: 34.6835521, longitude: 135.1710731, campus: "楠"),
        MapLocation(name: "医学部附属地域医療活性化センター", latitude: 34.68298679, longitude: 135.1700517, campus: "楠"),

        // 名谷キャンパス
        MapLocation(name: "体育館", latitude: 34.67234135, longitude: 135.098042, campus: "名谷"),
        MapLocation(name: "教育・研究棟（E,F棟）", latitude: 34.67259282, longitude: 135.0986268, campus: "名谷"),
        MapLocation(name: "事務・研究棟（C棟）", latitude: 34.67216488, longitude: 135.0986268, campus: "名谷"),
        MapLocation(name: "教育・研究棟（B棟）", latitude: 34.67193987, longitude: 135.0989701, campus: "名谷"),
        MapLocation(name: "講義棟（D棟）", latitude: 34.67185605, longitude: 135.0986911, campus: "名谷"),
        MapLocation(name: "教育・研究棟（A棟）", latitude: 34.67160458, longitude: 135.098836, campus: "名谷"),
        MapLocation(name: "保健科学図書室", latitude: 34.67163546, longitude: 135.099131, campus: "名谷"),

        // 深江キャンパス
        MapLocation(name: "機関実験実習センター", latitude: 34.7202716, longitude: 135.2913246, campus: "深江"),
        MapLocation(name: "エネルギー工学実験棟", latitude: 34.7200643, longitude: 135.2909276, campus: "深江"),
        MapLocation(name: "先端ものづくり工房技術部センター", latitude: 34.7199952, longitude: 135.2914104, campus: "深江"),
        MapLocation(name: "海事科学研究科・4号館", latitude: 34.7196072, longitude: 135.2913836, campus: "深江"),
        MapLocation(name: "水素実験棟", latitude: 34.7198321, longitude: 135.291625, campus: "深江"),
        MapLocation(name: "熱工学実験棟", latitude: 34.7196866, longitude: 135.2917001, campus: "深江"),
        MapLocation(name: "総合水槽実験棟", latitude: 34.7198986, longitude: 135.2919086, campus: "深江"),
        MapLocation(name: "極低温実験棟", latitude: 34.7194317, longitude: 135.2922437, campus: "深江"),
        MapLocation(name: "RI・加速器実験棟", latitude: 34.7193807, longitude: 135.2918891, campus: "深江"),
        MapLocation(name: "海事科学研究科・3号館", latitude: 34.7193587, longitude: 135.2913795, campus: "深江"),
        MapLocation(name: "海事科学研究科・5号館", latitude: 34.7195889, longitude: 135.2909074, campus: "深江"),
        MapLocation(name: "海事科学研究科・2号館", latitude: 34.7196727, longitude: 135.2902905, campus: "深江"),
        MapLocation(name: "総合学術交流棟", latitude: 34.718976, longitude: 135.2905748, campus: "深江"),
        MapLocation(name: "門衛所(守衛室)", latitude: 34.7194213, longitude: 135.2893893, campus: "深江"),
        MapLocation(name: "講堂・海事博物館", latitude: 34.7190912, longitude: 135.2892953, campus: "深江"),
        MapLocation(name: "体育館・課外活動共用施設", latitude: 34.7189589, longitude: 135.2889305, campus: "深江"),
        MapLocation(name: "保健管理センター深江分室", latitude: 34.7187958, longitude: 135.2890861, campus: "深江"),
        MapLocation(name: "水先教育研究棟", latitude: 34.7187958, longitude: 135.2885067, campus: "深江"),
        MapLocation(name: "屋内プール", latitude: 34.7185845, longitude: 135.2885921, campus: "深江"),
        MapLocation(name: "大学会館・食堂", latitude: 34.7183197, longitude: 135.2887317, campus: "深江"),
        MapLocation(name: "海事科学研究科・6号館", latitude: 34.7181326, longitude: 135.2889756, campus: "深江"),
        MapLocation(name: "海事科学研究科事務棟", latitude: 34.7184721, longitude: 135.2890675, campus: "深江"),
        MapLocation(name: "附属図書館海事科学分館", latitude: 34.718429, longitude: 135.2894983, campus: "深江"),
        MapLocation(name: "海事科学研究科・1号館", latitude: 34.7186359, longitude: 135.2898744, campus: "深江"),
        MapLocation(name: "海事基盤センター", latitude: 34.7175968, longitude: 135.291076, campus: "深江"),
        MapLocation(name: "艇庫", latitude: 34.7173807, longitude: 135.2911994, campus: "深江"),
        MapLocation(name: "附属練習船「海神丸」", latitude: 34.7179075, longitude: 135.2924812, campus: "深江"),
        MapLocation(name: "進徳丸メモリアル", latitude: 34.7182998, longitude: 135.2927278, campus: "深江"),

        // その他の地区
        MapLocation(name: "東京オフィス", latitude: 35.67489647, longitude: 139.7644022, campus: "その他"),
        MapLocation(name: "インターナショナル・レジデンス", latitude: 34.670724, longitude: 135.2145143, campus: "その他"),
        MapLocation(name: "住吉寮・住吉国際学生宿舎", latitude: 34.7348288, longitude: 135.2541217, campus: "その他"),
        MapLocation(name: "国維寮", latitude: 34.7202263, longitude: 135.2177357, campus: "その他"),
        MapLocation(name: "白鴎寮", latitude: 34.7229356, longitude: 135.2878897, campus: "その他"),
        MapLocation(name: "国際交流会館", latitude: 34.7229356, longitude: 135.2878897, campus: "その他"),
        MapLocation(name: "学而荘", latitude: 34.7161781, longitude: 135.2423325, campus: "その他")
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
