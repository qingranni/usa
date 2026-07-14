//
//  IconMap.swift
//  Universal Search App
//
//  Legacy shim. Icon rendering now goes through `EGDSIcon` / `EGDSIcons`, which
//  resolve Material/SF names to the custom EGDS glyph set. Kept only so any
//  remaining reference resolves to an EGDS asset name.
//

import Foundation

enum IconMap {
    /// EGDS asset-catalog name for a Material/SF icon name.
    static func sf(_ material: String?) -> String {
        EGDSIcons.asset(for: material)
    }
}
