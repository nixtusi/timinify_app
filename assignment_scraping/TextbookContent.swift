//
//  TextbookContent.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/01.
//

import Foundation

enum TextbookContent: Codable, Identifiable {
    case string(String)
    case object(text: String, link: String)

    var id: String {
        switch self {
        case .string(let str):
            return str
        case .object(let text, let link):
            return text + link
        }
    }

    var displayText: String {
        switch self {
        case .string(let str):
            return str
        case .object(let text, _):
            return text
        }
    }

    var url: URL? {
        switch self {
        case .string:
            return nil
        case .object(_, let link):
            return URL(string: link)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let dict = try? container.decode([String: String].self),
                  let text = dict["text"],
                  let link = dict["link"] {
            self = .object(text: text, link: link)
        } else {
            throw DecodingError.typeMismatch(
                TextbookContent.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "教科書の形式が正しくありません")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .object(let text, let link):
            try container.encode(["text": text, "link": link])
        }
    }
}
