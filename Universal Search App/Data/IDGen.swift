//
//  IDGen.swift
//  Universal Search App
//
//  Session-stable unique ids (ported from data.js `uid`). The ids drive the
//  matched-geometry morph identities, so they only need to be unique + stable
//  within a run.
//

import Foundation

enum IDGen {
    static func uid(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8))"
    }
}
