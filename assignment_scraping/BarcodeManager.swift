//
//  BarcodeManager.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/11.
//

import Foundation
import UIKit

class BarcodeManager {
    static let shared = BarcodeManager()

    private let apiURL = URL(string: "https://api.timinify.com/library")!
    private let barcodeImageFileName = "barcode.png"
    
    private init() {}

    //呼び出し元用：バーコード取得＆保存（Completionで画像を返す）
    func fetchAndSaveBarcode(completion: @escaping (UIImage?) -> Void) {
        guard let studentNumber = UserDefaults.standard.string(forKey: "studentNumber"),
              let password = UserDefaults.standard.string(forKey: "loginPassword") else {
            print("⚠️ ログイン情報が取得できませんでした")
            completion(nil)
            return
        }

        let body: [String: String] = [
            "student_number": studentNumber,
            "password": password
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ ユーザー情報取得失敗: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let info = json["user_info"] as? String,
                  let base = info.components(separatedBy: "(").first else {
                print("⚠️ user_infoの解析に失敗しました")
                completion(nil)
                return
            }

            let barcodeNumber = base.replacingOccurrences(of: " ", with: "") + "1"
            let imageURL = URL(string: "https://lib.kobe-u.ac.jp/files/pngcode.php?no=\(barcodeNumber)")!

            self.downloadImage(from: imageURL) { image in
                if let image = image {
                    self.saveImage(image)
                }
                completion(image)
            }
        }.resume()
    }

    //画像取得
    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ バーコード画像の取得に失敗しました")
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }

    //デバイス内に保存
    private func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        let path = imageFilePath()
        try? data.write(to: path)
    }

    //デバイス内から読み込み
    func loadSavedBarcodeImage() -> UIImage? {
        let path = imageFilePath()
        return UIImage(contentsOfFile: path.path)
    }

    //ファイル保存先（非表示領域）
//    private func imageFilePath() -> URL {
//        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.yuta-nishimatsu.assignment-scraping")!
//            return container.appendingPathComponent(barcodeImageFileName)
//    }
    
    private func imageFilePath() -> URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yuta.beefapp")!
            return container.appendingPathComponent(barcodeImageFileName)
    }
    
    // デバイス内から削除
    func deleteSavedBarcode() {
        let path = imageFilePath()
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                try FileManager.default.removeItem(at: path)
                print("🗑️ バーコード画像を削除しました")
            } catch {
                print("⚠️ バーコード削除エラー: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ 削除対象のバーコード画像は存在しません")
        }
    }

}
