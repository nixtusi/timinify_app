//
//  SettingsViewModel.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/10.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
    // デバイス内に永続保存されるデータ
    @AppStorage("studentID") var studentID: String = ""         // 学籍番号
    @AppStorage("libraryBarcode") var libraryBarcode: String = "" // バーコード番号
    
    // MARK: - 1. 設定画面が開いたときに呼ばれる処理
    func checkAndGenerateBarcode() {
        // 学籍番号が空なら何もしない
        guard !studentID.isEmpty else { return }
        
        // すでにバーコードがあるなら何もしない（ここが重要）
        if !libraryBarcode.isEmpty {
            return
        }
        
        // バーコードがない場合のみ生成して保存
        print("バーコードがないため、自動生成します")
        libraryBarcode = generateBarcode(from: studentID)
    }
    
    // MARK: - 2. データ更新ボタンが押されたときの処理
    func updateTimeTableData() {
        // ★ここからはバーコード生成処理を削除し、時間割の更新だけを行う
        print("時間割データのスクレイピング・更新を開始します...")
        
        // ここに既存のスクレイピングやAPI通信のコードを書く
    }
    
    // MARK: - 内部処理: バーコード計算ロジック
    private func generateBarcode(from id: String) -> String {
        // ★ここに、以前作成した「学籍番号からバーコードを作る計算式」を入れてください
        // 例: "2435109t" -> 図書館用の番号
        return "生成された番号" // 仮の戻り値
    }
}
