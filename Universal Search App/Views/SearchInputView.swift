//
//  SearchInputView.swift
//  Universal Search App
//
//  Home search now uses the shared inline-chip composer (see ComposerView /
//  ChipComposerField), opened expanded from EmptySearchView. What remains here is
//  `SearchMorphSurface` — the geometric white page the launch "Searching…" dock
//  grows out of (mounted by RootView during a homepage launch).
//

import SwiftUI

// MARK: - Morphing surface

/// The white page the home search pill grows into. Purely geometric: it morphs
/// the pill's rounded rect up to the full-screen rect and back, sampling every
/// interpolated frame via `AnimatableMorph` so the spring reads as one fluid
/// grow instead of a jump. Reference example for the surface-morph recipe in
/// MORPHS.md.
///
/// While collapsed it wears the pill's warm off-white fill, white gloss, hairline
/// stroke, and drop shadow; all of those dissolve into a flat white page as it
/// opens. A centred placeholder rides along and fades out as the real input's
/// leading placeholder fades in on top.
struct SearchMorphSurface: View {
    var progress: CGFloat
    let pill: CGRect
    let full: CGRect
    var placeholder: String = Copy["search.placeholder"]

    /// home pill off-white — #F7F4F3
    private let offWhite = Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xF3 / 255)
    /// navy ink used in the pill label — #191E3B
    private let navy = Color(red: 25 / 255, green: 30 / 255, blue: 59 / 255)

    var body: some View {
        AnimatableMorph(progress: progress) { p in
            let shape = RoundedRectangle(cornerRadius: p.lerp(33, 46), style: .continuous)

            shape
                .fill(Color.mix(offWhite, .white, p.eased))
                .overlay {
                    // Pill gloss — top-to-bottom white sheen, only while collapsed.
                    shape.fill(
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(p.inverted.eased)
                }
                .overlay {
                    // Centred pill label fading out as the page opens.
                    Text(placeholder)
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(navy)
                        .opacity(p.window(0...0.35).fadeOut)
                }
                .overlay(shape.strokeBorder(.white, lineWidth: 1).opacity(p.inverted.eased))
                .shadow(color: .black.opacity(0.12 * Double(p.inverted.eased)), radius: 16, x: 0, y: 12)
                .morphFrame(from: pill, to: full, progress: p)
        }
        .allowsHitTesting(false)
    }
}
