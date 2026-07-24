//
//  EGDSIcon.swift
//  Universal Search App
//
//  Custom (non-native) icon system backed by the EGDS glyph set imported from
//  the egds-prototype-kit-template repo. SVGs live in Assets.xcassets/EGDSIcons
//  as template-rendered vector imagesets ("egds-<slug>").
//
//  `EGDSIcon` is a drop-in replacement for `Image(systemName:)`. It accepts the
//  same SF Symbol / Material icon name strings the app already used and resolves
//  them to an EGDS glyph, then renders it as a tintable, explicitly sized image.
//  Callers pass `size:` to match the point size the SF Symbol used to derive from
//  its surrounding `.font(...)`; any trailing `.foregroundStyle` still tints it.
//

import SwiftUI
import UIKit

enum EGDSIcons {
    /// Maps every SF Symbol / Material icon name used in the app to an EGDS glyph
    /// slug. Unknown names fall back to a neutral place marker.
    private static let table: [String: String] = [
        // Material icon names (mirrors the old IconMap table).
        "arrow_back": "chevron-left",
        "arrow_forward": "arrow-forward",
        "home": "home",
        "favorite_border": "favorite-outline",
        "favorite": "favorite",
        "edit": "mode-edit",
        "hotel": "lob-hotels",
        "flight": "flight",
        "directions_car": "directions-car",
        "local_activity": "local-activity",
        "place": "place",
        "map": "map",
        "forum": "chat",
        "add": "add",
        "close": "close",
        "history": "history",
        "distance": "trips",
        "more_vert": "more-vert",

        // SF Symbol names used directly across the views.
        "chevron.left": "chevron-left",
        "arrow.forward": "arrow-forward",
        "arrow.right": "arrow-forward",
        "arrow.counterclockwise": "refresh",
        "house": "home",
        "heart": "favorite-outline",
        "heart.fill": "favorite",
        "pencil": "mode-edit",
        "bed.double": "bed",
        "airplane": "flight",
        "airplane.departure": "flight-takeoff",
        "airplane.arrival": "flight-land",
        "car": "directions-car",
        "ticket": "local-activity",
        "mappin": "place",
        "bubble.left.and.bubble.right": "chat",
        "plus": "add",
        "minus": "remove",
        "xmark": "close",
        "clock.arrow.circlepath": "history",
        "magnifyingglass": "search",
        "slider.horizontal.3": "tune",
        "building.columns.fill": "attractions",
        "sparkles": "ai",
        "point.topleft.down.to.point.bottomright.curvepath": "trips",
        "person.crop.circle": "account-circle",
        "person": "person",
        "person.2": "group",
        "face.smiling": "child",
        "calendar": "calendar",
        "checkmark": "check",
        "checkmark.circle.fill": "check-circle",
        "circle": "circle-outlined",
        "doc.on.doc": "copy-content",
        "mic": "mic",
        "mic.fill": "mic",
        "trash": "delete",
        "rectangle.bottomthird.inset.filled": "arrow-downward",
        "rectangle.topthird.inset.filled": "arrow-upward",
    ]

    /// EGDS asset-catalog name for any SF Symbol / Material icon name.
    static func asset(for name: String?) -> String {
        guard let name else { return "egds-place" }
        return "egds-" + (table[name] ?? "place")
    }
}

/// Shared semantic glyph selection for every filter-chip treatment. Keeping the
/// mapping beside the EGDS resolver prevents composer, results, and scrubber
/// variants from drifting back to SF Symbols or legacy one-off assets.
enum FilterChipIconName {
    static func forLabel(_ label: String) -> String {
        let value = label.lowercased()
        if value.contains("date") || value.contains("week") || value.contains("mar ") {
            return "calendar"
        }
        if value.contains("guest") || value.contains("traveler")
            || value.contains("adult") || value.contains("child") || value.contains("teen") {
            return "person.2"
        }
        if value.contains("flight") || value.contains("nonstop")
            || value.contains("seat") || value.contains("bag") {
            return "flight"
        }
        if value.contains("$") || value.contains("budget") || value.contains("price") {
            return "local_activity"
        }
        if value.contains("destination") || value.contains("from") || value.contains("to")
            || value.contains("pick-up") || value.contains("drop-off")
            || value.contains("mexico") || value.contains("cancun") {
            return "mappin"
        }
        if value.contains("beach") || value.contains("activity") {
            return "local_activity"
        }
        return "slider.horizontal.3"
    }
}

/// Custom EGDS glyph rendered as a tintable, square, explicitly sized image.
/// Drop-in for `Image(systemName:)`; pass the point size the symbol used.
struct EGDSIcon: View {
    let name: String
    var size: CGFloat = 17

    init(_ name: String, size: CGFloat = 17) {
        self.name = name
        self.size = size
    }

    @ViewBuilder
    var body: some View {
        Image(EGDSIcons.asset(for: name))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

extension UIImage {
    /// UIKit counterpart used by the inline chip text editor. Returns a
    /// template EGDS glyph for an SF Symbol / Material icon name.
    static func egds(_ name: String?) -> UIImage? {
        UIImage(named: EGDSIcons.asset(for: name))?
            .withRenderingMode(.alwaysTemplate)
    }
}
