//
//  RemoteOrLocalImage.swift
//  Universal Search App
//
//  Loads a card image from either a remote "http…" URL (AsyncImage) or a local
//  asset-catalog name derived from a path like "/v1/hotel-1.jpg" → "hotel-1".
//

import SwiftUI

struct RemoteOrLocalImage: View {
    let urlString: String?

    var body: some View {
        if let s = urlString, !s.isEmpty {
            if s.hasPrefix("http"), let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                Image(assetName(from: s)).resizable().scaledToFill()
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle().fill(Color(white: 0.93))
    }

    private func assetName(from path: String) -> String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        if let dot = last.lastIndex(of: ".") { return String(last[..<dot]) }
        return last
    }
}
