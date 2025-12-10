//
//  SettingsViewModel.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
    // ユーザー設定として保存される値
    @AppStorage("studentID") var studentID: String = "" // 学籍番号
    @AppStorage("libraryBarcode") var libraryBarcode: String = "" // 図書館バーコード番号
    
    // データ更新処理（ここからはバーコード生成を削除する）
    func updateData() {
        // 課題のスクレイピングなどの処理のみを行う
        print("データを更新しました")
    }
    
    // 【新規作成】設定画面が開かれたときに呼ぶ関数
    func initializeLibraryBarcode() {
        // 1. 学籍番号が設定されているか確認
        guard !studentID.isEmpty else { return }
        
        // 2. すでにバーコードが生成済みなら何もしない（ここが重要）
        if !libraryBarcode.isEmpty {
            return
        }
        
        // 3. まだ生成されていない場合のみ生成ロジックを実行
        print("バーコードを初回生成します")
        libraryBarcode = generateBarcodeFromID(studentID)
    }
    
    // バーコード生成の計算ロジック（以前のアルゴリズム）
    private func generateBarcodeFromID(_ id: String) -> String {
        // ここに以前作成した変換アルゴリズムを入れる
        // 例: 学籍番号 "2435109t" -> 図書館番号
        return "変換後の番号"
    }
}
