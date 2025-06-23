//
//  UIApplication+Extension.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/06/23.
//

import UIKit

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
