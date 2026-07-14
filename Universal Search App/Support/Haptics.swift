//
//  Haptics.swift
//  Universal Search App
//
//  Thin wrapper over UIKit feedback generators so composer interactions can fire
//  TravelAI-style haptics without scattering generator instantiations. The chip
//  editor / filter pill / ghost menu carry their own feedback; this covers the
//  composer chrome (open, dismiss, action taps, submit).
//

import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
