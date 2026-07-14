//
//  PhotoFan.swift
//  Universal Search App
//
//  Small rotated thumbnail stack for activity cards (ported from PhotoFan.jsx).
//

import SwiftUI

/// One tile in a fan — a full-bleed photo, or an airline-logo chip (a white
/// rounded card with the logo padded inside, matching the flight card badges).
/// Used by `PhotoFan`; callers add rotation / shadow / position.
struct FanTile: View {
    let asset: String
    let size: CGFloat
    var isLogo: Bool = false
    var cornerRadius: CGFloat = 6

    var body: some View {
        if isLogo {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white)
                .overlay {
                    logoImage
                        .padding(size * 0.18)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06))
                )
                .frame(width: size, height: size)
        } else {
            RemoteOrLocalImage(urlString: asset)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    private var logoImage: some View {
        if asset.hasPrefix("http"), let url = URL(string: asset) {
            AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
        } else {
            Image(asset).resizable().scaledToFit()
        }
    }
}

/// One slot in a fanned thumbnail stack: x offset, rotation, z order.
struct FanSlot {
    let x: CGFloat
    let rot: Double
    let z: Double

    static let fan1 = [FanSlot(x: 0, rot: 0, z: 1)]
    static let fan2 = [FanSlot(x: 8, rot: -15, z: 2), FanSlot(x: -4, rot: 15, z: 1)]
}

struct PhotoFan: View {
    let images: [String]
    var size: CGFloat = 36
    /// Render the tiles as airline-logo chips (flights) rather than photos.
    var isLogo: Bool = false
    /// 0 = stacked; 1 = fully fanned. Normal trip rows stay fully fanned; the
    /// floating collapse card can drive this for a quick fan-out as it lands.
    var fanProgress: CGFloat = 1

    var body: some View {
        let shown = Array(images.filter { !$0.isEmpty }.prefix(2))
        if shown.isEmpty {
            Color.clear.frame(width: size + 16, height: size + 8)
        } else {
            let slots = shown.count <= 1 ? FanSlot.fan1 : FanSlot.fan2
            let radius: CGFloat = isLogo ? size * 0.2 : 6
            let p = smoothstep(fanProgress)
            ZStack {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, src in
                    let slot = slots[i]
                    FanTile(asset: src, size: size, isLogo: isLogo, cornerRadius: radius)
                        .shadow(color: .black.opacity(0.25 * Double(p)), radius: 2.5, y: 2.5)
                        .rotationEffect(.degrees(slot.rot * Double(p)))
                        .offset(x: slot.x * p)
                        .zIndex(slot.z)
                }
            }
            .frame(width: size + 16, height: size + 8)
        }
    }
}
