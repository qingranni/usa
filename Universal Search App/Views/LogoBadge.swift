//
//  LogoBadge.swift
//  Universal Search App
//
//  Shared airline/brand logo rendering. `LogoImage` is the raw bitmap (remote
//  URL or asset name); `LogoBadge` wraps it in the white rounded chip used on
//  result cards and carousel tiles.
//

import SwiftUI

/// The raw logo: a remote "http…" URL (AsyncImage) or a local asset name.
struct LogoImage: View {
    let logo: String

    var body: some View {
        if logo.hasPrefix("http"), let url = URL(string: logo) {
            AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
        } else {
            Image(logo).resizable().scaledToFit()
        }
    }
}

/// A small white rounded chip carrying a logo, pinned to a card's image corner.
struct LogoBadge: View {
    let logo: String
    var size: CGFloat = 38
    var cornerRadius: CGFloat = 10
    var inset: CGFloat = 7
    var shadowRadius: CGFloat = 5
    var shadowY: CGFloat = 2

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size)
            .overlay {
                LogoImage(logo: logo)
                    .padding(inset)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(0.18), radius: shadowRadius, y: shadowY)
    }
}
