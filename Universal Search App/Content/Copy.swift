//
//  Copy.swift
//  Universal Search App
//
//  The content source of truth for static UI copy — separate from narrative,
//  mock, and Gen-UI result content.
//
//  All copywriter-facing strings live in the bundled `CopyStrings.json`, which is
//  the ONLY place strings are defined. Access is key-based via dotted paths, so
//  the JSON is the single source of truth: adding a new string is one JSON edit
//  plus a `Copy["group.key"]` reference in a view — there is no parallel Swift
//  model to keep in sync. A copywriter edits the JSON and relaunches; every wired
//  string updates. Missing keys are surfaced in-app (the key is shown) and logged
//  in DEBUG so gaps are obvious rather than silent.
//

import Foundation

enum Copy {
    /// The decoded JSON tree. Loaded once at first access. Empty if the bundled
    /// file is missing or malformed, in which case lookups echo their key so the
    /// UI never renders blank and the gap is visible.
    private static let root: [String: Any] = load()

    private static func load() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "CopyStrings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            #if DEBUG
            print("⚠️ [Copy] CopyStrings.json missing or unreadable — keys will echo.")
            #endif
            return [:]
        }
        return obj
    }

    /// Walk the tree following a dotted key path (e.g. "sections.lodging.name").
    private static func value(at path: String) -> Any? {
        var node: Any? = root
        for part in path.split(separator: ".") {
            node = (node as? [String: Any])?[String(part)]
        }
        return node
    }

    /// Look up a string by dotted key path (e.g. `Copy["search.placeholder"]`).
    /// If the key is missing, returns the path itself so the gap is visible in the
    /// UI (and logged in DEBUG).
    static subscript(_ path: String) -> String {
        if let s = value(at: path) as? String { return s }
        #if DEBUG
        print("⚠️ [Copy] missing string for key: \(path)")
        #endif
        return path
    }

    /// Look up a string array by dotted key path (e.g. `Copy.list("refineSuggestions")`).
    static func list(_ path: String) -> [String] {
        if let arr = value(at: path) as? [String] { return arr }
        #if DEBUG
        print("⚠️ [Copy] missing list for key: \(path)")
        #endif
        return []
    }

    /// Section heading for a kind (e.g. "Exploring hotels").
    static func sectionName(_ kind: Kind) -> String { Copy["sections.\(kind.rawValue).name"] }

    /// Section blurb for a kind.
    static func sectionBlurb(_ kind: Kind) -> String { Copy["sections.\(kind.rawValue).blurb"] }
}
