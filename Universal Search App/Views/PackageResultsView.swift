//
//  PackageResultsView.swift
//  Universal Search App
//
//  The destination/package result layout from Figma 1655:33044. Broad results
//  are grouped into horizontally scrolling recommendation shelves over a map.
//

import SwiftUI

struct PackageResultsView: View {
    let store: AppStore
    let thread: ThreadNode

    private var sections: [PackageResultSection] {
        var result: [PackageResultSection] = []
        var heading: String?
        var bodyText: String?

        for block in thread.activeBlocks {
            guard block.semanticType == nil else { continue }
            switch block.style {
            case .heading:
                heading = block.text
            case .highlight, .cards, .carousel:
                guard !block.cards.isEmpty else { continue }
                let blockText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = heading
                    ?? (!blockText.isEmpty ? blockText : nil)
                    ?? thread.resultSets.last?.label
                    ?? "Results"
                let subtitle = heading != nil && blockText != title ? blockText : ""
                result.append(PackageResultSection(
                    id: block.id,
                    title: title,
                    subtitle: bodyText ?? subtitle,
                    cards: block.cards,
                    style: block.style,
                    presentation: block.cardPresentation
                ))
                heading = nil
                bodyText = nil
            case .text:
                let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { bodyText = text }
            }
        }

        if result.isEmpty, !thread.activeCards.isEmpty {
            result.append(PackageResultSection(
                id: "\(thread.id)-package-results",
                title: thread.resultSets.last?.label ?? "Results",
                subtitle: thread.resultSets.last?.summary ?? "",
                cards: thread.activeCards,
                style: .cards,
                presentation: .generic
            ))
        }
        return result
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 32) {
            ForEach(sections) { section in
                PackageResultShelf(store: store, section: section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct PackageResultSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let cards: [Card]
    let style: ResultBlock.Style
    let presentation: ResultCardPresentation
}

private struct PackageResultShelf: View {
    let store: AppStore
    let section: PackageResultSection

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
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
            .padding(.horizontal, 24)

            if section.presentation == .flight {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(section.cards) { card in
                            FlightResultCard(card: card, compact: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            } else if section.style == .cards {
                LazyVStack(spacing: 16) {
                    ForEach(section.cards) { card in
                        FeaturedPackageCard(store: store, card: card)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(section.cards) { card in
                            CompactResortCard(card: card)
                        }
                    }
                    .padding(.horizontal, 24)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

private struct FeaturedPackageCard: View {
    let store: AppStore
    let card: Card

    @State private var favorited = false
    /// The hero image's rect in "root" space — the morph source for the detail
    /// page. Captured live so a tap flies out of exactly where the image sits.
    @State private var imageFrame: CGRect = .zero

    /// Only the Hyatt Ziva package opens the bespoke detail page for now.
    private var opensDetail: Bool { card.imageURL == "package-cancun-hyatt-ziva" }

    private var description: String {
        if let highlights = card.highlights, !highlights.isEmpty { return highlights }
        return Copy["results.standoutFallback"]
    }

    private var tripCaption: String {
        "for \(card.nights ?? 5) nights and \(card.travelers ?? 3) travelers"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(card.displayTitle)
                    } icon: {
                        EGDSIcon("hotel", size: 16)
                    }
                    Label {
                        Text("\(card.stops ?? Copy["results.flights.nonstop"])\(Copy["results.flights.flightsSuffix"])")
                    } icon: {
                        EGDSIcon("flight", size: 16)
                    }
                }
                .font(.centra(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)

                Text(description)
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom, spacing: 12) {
                    rating
                    Spacer(minLength: 8)
                    price
                }
            }
            .padding(16)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onTapGesture {
            guard opensDetail else { return }
            store.openPackageDetail(card, source: imageFrame)
        }
    }

    private var image: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 230)
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
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.32), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(card.dateRange ?? "Mar 14–20")
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(24)
            }
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
            .captureFrame(enabled: opensDetail) { imageFrame = $0 }
    }

    @ViewBuilder
    private var rating: some View {
        if let score = card.ratingScoreText {
            HStack(spacing: 6) {
                Text(score)
                    .font(.centra(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 16)
                    .background(Color(red: 12 / 255, green: 147 / 255, blue: 0), in: RoundedRectangle(cornerRadius: 4))
                Text(score >= "9" ? "Excellent" : "Very good")
                    .font(.centra(size: 12))
                    .foregroundStyle(Theme.figmaInk)
            }
        }
    }

    private var price: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let discount = card.discountText {
                Text(discount)
                    .font(.centra(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 20)
                    .background(Color(red: 253 / 255, green: 219 / 255, blue: 50 / 255), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let oldPrice = card.crossedOutPrice {
                    Text(oldPrice)
                        .font(.centra(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .strikethrough()
                }
                Text(card.totalPrice ?? card.displayPrice ?? "See price")
                    .font(.centra(size: 20, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            Text(tripCaption)
                .font(.centra(size: 12))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
    }
}

private struct CompactResortCard: View {
    let card: Card
    @State private var favorited = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteOrLocalImage(urlString: card.imageURL)
                .frame(width: 230, height: 230)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
                .overlay(alignment: .topLeading) {
                    Text(card.dateRange ?? "Mar 14–20")
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(20)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(Theme.springSoft) { favorited.toggle() }
                    } label: {
                        EGDSIcon(favorited ? "heart.fill" : "heart", size: 18)
                            .foregroundStyle(favorited ? Color.red : Color.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.18), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text(card.displayTitle)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(card.highlights ?? "")
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.totalPrice ?? card.displayPrice ?? "See price")
                        .font(.centra(size: 20, weight: .medium))
                    Text("for \(card.nights ?? 5) nights and \(card.travelers ?? 3) travelers")
                        .font(.centra(size: 12))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            .padding(16)
        }
        .frame(width: 230, alignment: .leading)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
