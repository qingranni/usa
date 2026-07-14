//
//  PackageResultsView.swift
//  Universal Search App
//
//  The destination/package result layout from Figma 1655:33044. Broad results
//  are grouped into horizontally scrolling recommendation shelves over a map.
//

import SwiftUI

struct PackageResultsView: View {
    let thread: ThreadNode

    private var sections: [PackageResultSection] {
        var result: [PackageResultSection] = []
        var heading: String?

        for block in thread.activeBlocks {
            switch block.style {
            case .heading:
                heading = block.text
            case .cards, .carousel:
                guard !block.cards.isEmpty else { continue }
                let title = heading ?? block.text
                result.append(PackageResultSection(
                    id: block.id,
                    title: title.isEmpty ? "Top destinations" : title,
                    subtitle: subtitle(for: title),
                    cards: block.cards
                ))
                heading = nil
            case .text:
                continue
            }
        }

        if result.isEmpty, !thread.activeCards.isEmpty {
            result.append(PackageResultSection(
                id: "\(thread.id)-package-results",
                title: "Top destinations",
                subtitle: thread.resultSets.last?.summary ?? "",
                cards: thread.activeCards
            ))
        }
        return result
    }

    private var displayTitle: String {
        if thread.title.localizedCaseInsensitiveContains("mexico") {
            return "Mexico beach destinations"
        }
        return thread.title
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 32) {
            VStack(spacing: 24) {
                Text(displayTitle)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                filterRow
            }
            .padding(.horizontal, 32)

            ForEach(sections) { section in
                PackageResultShelf(section: section)
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            packageFilterButton(systemImage: "slider.horizontal.3", label: nil)
            packageFilterButton(systemImage: "calendar", label: "Add dates")
            packageFilterButton(systemImage: "person", label: "Travelers")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func packageFilterButton(systemImage: String, label: String?) -> some View {
        Button {
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 10) {
                EGDSIcon(systemImage, size: 16)
                    .font(.centra(size: 15, weight: .medium))
                if let label {
                    Text(label)
                        .font(.centra(size: 14))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, label == nil ? 16 : 18)
            .frame(height: 50)
            .background(Theme.cardItem.opacity(0.75), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for heading: String) -> String {
        switch heading.lowercased() {
        case let value where value.contains("stay"):
            return "Popular stays and package-ready destinations."
        case let value where value.contains("flight"):
            return "Flexible flight options to pair with your stay."
        case let value where value.contains("getting"), let value where value.contains("car"):
            return "Easy ways to explore once you arrive."
        case let value where value.contains("thing"), let value where value.contains("activit"):
            return "Memorable experiences to add to your trip."
        default:
            return "Handpicked options for your trip."
        }
    }
}

private struct PackageResultSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let cards: [Card]
}

private struct PackageResultShelf: View {
    let section: PackageResultSection

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(.centra(size: 20, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                if !section.subtitle.isEmpty {
                    Text(section.subtitle)
                        .font(.centra(size: 16))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(section.cards) { card in
                        PackageRecommendationCard(card: card)
                    }
                }
                .padding(.horizontal, 32)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct PackageRecommendationCard: View {
    let card: Card

    @State private var favorited = false

    private var description: String {
        let components = card.sublabel.components(separatedBy: " · ")
        let detail = components.dropFirst().joined(separator: " · ")
        if !detail.isEmpty { return detail }
        if let highlights = card.highlights, !highlights.isEmpty { return highlights }
        return "A standout option for this trip"
    }

    private var primaryPrice: String {
        card.departTime == nil ? "Flights available" : (card.displayPrice ?? "See fares")
    }

    private var stayPrice: String {
        if card.rating != nil {
            return "\(card.totalPrice ?? card.displayPrice ?? "See price") avg."
        }
        return card.departTime == nil ? (card.displayPrice ?? "See options") : "Stays available"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            image

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.displayTitle)
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Text(description)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    priceLine(systemImage: "airplane", text: primaryPrice)
                    priceLine(systemImage: "bed.double", text: stayPrice)
                }
            }
            .padding(10)
        }
        .padding(8)
        .frame(width: 216, alignment: .leading)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var image: some View {
        Color.clear
            .frame(width: 200, height: 200)
            .overlay {
                if card.imageURL != nil {
                    RemoteOrLocalImage(urlString: card.imageURL)
                } else {
                    ZStack {
                        Theme.cardItem.opacity(0.55)
                        EGDSIcon(card.icon ?? "", size: 44)
                            .font(.centra(size: 44, weight: .light))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(Theme.springSoft) { favorited.toggle() }
                } label: {
                    EGDSIcon(favorited ? "heart.fill" : "heart", size: 18)
                        .font(.centra(size: 17, weight: .medium))
                        .foregroundStyle(favorited ? Color.red : Color.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.22), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(favorited ? "Remove from favorites" : "Add to favorites")
            }
    }

    private func priceLine(systemImage: String, text: String) -> some View {
        HStack(spacing: 8) {
        EGDSIcon(systemImage, size: 14)
            .font(.centra(size: 13, weight: .medium))
            .frame(width: 16)
            Text(text)
                .font(.centra(size: 14))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.inkMuted)
    }
}
