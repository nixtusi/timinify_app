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
    private let barcodeImageFileName = "barcode.png"
    
    private init() {}

    func fetchAndSaveBarcode(completion: @escaping (UIImage?) -> Void) {
        guard let studentNumber = UserDefaults.standard.string(forKey: "studentNumber") else {
            print("⚠️ 学籍番号が取得できませんでした")
            completion(nil)
            return
        }
        
        // 学籍番号（例: 2437109t -> 2437109）数字部分のみ抽出
        let numericPart = studentNumber.filter { "0123456789".contains($0) }
        
        guard numericPart.count == 7 else {
            print("⚠️ 学籍番号の形式が不正です（7桁の数字が必要です）")
            completion(nil)
            return
        }
        
        // アルゴリズムに基づくバーコード番号生成
        let barcodeNumber = generateBarcodeNumber(from: numericPart)
        print("generated barcode: \(barcodeNumber)")
        
        guard let imageURL = URL(string: "https://lib.kobe-u.ac.jp/files/pngcode.php?no=\(barcodeNumber)") else {
            completion(nil)
            return
        }

        self.downloadImage(from: imageURL) { image in
            if let image = image {
                self.saveImage(image)
            }
            completion(image)
        }
    }
    
    // 指定アルゴリズム
    // 入力: ABCDEFG (7桁)
    // 重み: G*2 + F*1 + E*2 + D*1 + C*2 + B*1 + A*2 ...
    // S = sum, X = S % 11
    // 出力: 0 + ABC + 3 + D + 3 + E + FG + X
    private func generateBarcodeNumber(from id: String) -> String {
        let digits = id.compactMap { Int(String($0)) }
        guard digits.count == 7 else { return "" }
        
        let a = digits[0], b = digits[1], c = digits[2]
        let d = digits[3]
        let e = digits[4]
        let f = digits[5], g = digits[6]
        
        // 重み付け計算 (右端Gから2,1,2,1...)
        // G(2), F(1), E(2), D(1), C(2), B(1), A(2)
        let s = (g * 2) + (f * 1) + (e * 2) + (d * 1) + (c * 2) + (b * 1) + (a * 2)
        let x = s % 11
        
        // フォーマット: 0ABC3D3EFGX
        // 例: 0 + 243 + 3 + 7 + 3 + 1 + 09 + X
        let result = "0\(a)\(b)\(c)3\(d)3\(e)\(f)\(g)\(x)"
        return result
    }

    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }

    private func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        try? data.write(to: imageFilePath())
    }

    func loadSavedBarcodeImage() -> UIImage? {
        return UIImage(contentsOfFile: imageFilePath().path)
    }
    
    private func imageFilePath() -> URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yuta.beefapp")!
        return container.appendingPathComponent(barcodeImageFileName)
    }
    
    func deleteSavedBarcode() {
        try? FileManager.default.removeItem(at: imageFilePath())
    }
}
