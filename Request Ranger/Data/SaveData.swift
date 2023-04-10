//
//  SaveData.swift
//  Request Ranger
//
//  Created by Lukas Reschke on 10.04.23.
//

import Foundation

/** Serialized HTTP requests and responses. The other entries will be manually recreated on the import to ensure maximum compatibility. */
struct HttpRequestForSaving: Codable {
    let id: Int
    let rawRequest: String
    let rawResponse: String?
    let date: Date
    let hostName: String
}

struct ComparisonStringForSaving: Codable {
    let id: Int
    let string: String
}
