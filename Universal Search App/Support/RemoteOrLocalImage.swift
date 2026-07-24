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
            if s.hasPrefix("http"), let url = optimizedURL(from: s) {
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
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.88), Color(white: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "building.2")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color(white: 0.66))
        }
    }

    /// Expedia's source lodging images can approach a megabyte. Ask its image
    /// service for the display-sized crop so the first card does not look blank
    /// while a full-resolution asset downloads.
    private func optimizedURL(from rawValue: String) -> URL? {
        guard var components = URLComponents(string: rawValue) else { return nil }
        guard components.host?.hasSuffix("expedia.com") == true else {
            return components.url
        }

        var items = components.queryItems ?? []
        let existingNames = Set(items.map(\.name))
        let resizeItems = [
            URLQueryItem(name: "impolicy", value: "resizecrop"),
            URLQueryItem(name: "ra", value: "fill"),
            URLQueryItem(name: "rw", value: "800"),
            URLQueryItem(name: "rh", value: "600"),
        ]
        items.append(contentsOf: resizeItems.filter { !existingNames.contains($0.name) })
        components.queryItems = items
        return components.url
    }

    private func assetName(from path: String) -> String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        if let dot = last.lastIndex(of: ".") { return String(last[..<dot]) }
        return last
    }
}
