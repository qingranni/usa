//
//  DestinationDiscoveryPill.swift
//  Universal Search App
//
//  The one-time "destination discovery" prompt the composer pill morphs into
//  when a narrative results thread opens. A piece of leading artwork sits beside
//  a two-line prompt on the shared fauxGlass surface; it retires back to the
//  "Ask anything" pill once the results have been scrolled a bit (see
//  AppStore.showsDestinationDiscovery).
//
//  Two variants share the surface:
//   • .cancunPackages — a fanned cluster of location photos, "Cancun at a
//     glance" (Figma 2583:17562).
//   • .mexicoVacations — a single globe illustration, "Can't decide?"
//     (Figma 2913:42338).
//

import SwiftUI

struct DestinationDiscoveryPill: View {
    /// Which narrative flow the prompt is closing out — picks the artwork and copy.
    enum Variant {
        case cancunPackages
        case mexicoVacations

        var titleKey: String {
            switch self {
            case .cancunPackages: return "results.packages.discoveryTitle"
            case .mexicoVacations: return "results.vacations.discoveryTitle"
            }
        }

        var subtitleKey: String {
            switch self {
            case .cancunPackages: return "results.packages.discoverySubtitle"
            case .mexicoVacations: return "results.vacations.discoverySubtitle"
            }
        }
    }

    var variant: Variant = .cancunPackages
    var onTap: () -> Void

    private let cancunImages = [
        "package-cancun-hero-1",
        "package-cancun-hero-2",
        "package-cancun-hero-3",
    ]

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy[variant.titleKey])
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                    Text(Copy[variant.subtitleKey])
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk.opacity(0.5))
                }
                .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fauxGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Copy[variant.titleKey]). \(Copy[variant.subtitleKey])"
        )
    }

    @ViewBuilder
    private var artwork: some View {
        switch variant {
        case .cancunPackages: photoCluster
        case .mexicoVacations: globe
        }
    }

    /// Three overlapping photos — a 46pt centre card flanked by two 32pt cards
    /// rotated ±15°, matching the fanned cluster in Figma.
    private var photoCluster: some View {
        ZStack {
            thumb(cancunImages[0], size: 32, radius: 6.3)
                .rotationEffect(.degrees(-15))
                .offset(x: -22, y: 4)
            thumb(cancunImages[2], size: 32, radius: 6.3)
                .rotationEffect(.degrees(15))
                .offset(x: 22, y: 4)
            thumb(cancunImages[1], size: 46, radius: 8)
        }
        .frame(width: 83, height: 49)
    }

    /// A single globe illustration that overflows its 49pt slot — the artwork
    /// box is 76×85 and sits slightly up-and-left, matching Figma 2913:42376.
    private var globe: some View {
        Color.clear
            .frame(width: 49, height: 49)
            .overlay {
                Image("discovery-globe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 85)
                    .offset(x: 1.5, y: 0)
            }
    }

    private func thumb(_ asset: String, size: CGFloat, radius: CGFloat) -> some View {
        RemoteOrLocalImage(urlString: asset)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.black.opacity(0.05))
            }
            .shadow(color: .black.opacity(0.15), radius: size >= 46 ? 5 : 4, y: size >= 46 ? 5 : 4)
    }
}
