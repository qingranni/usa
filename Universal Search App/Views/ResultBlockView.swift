//
//  ResultBlockView.swift
//  Universal Search App
//
//  Renders one server-driven `ResultBlock` in the results canvas: an intro
//  paragraph, a section heading, a stack of hero cards, or a horizontal carousel.
//  The LLM (or the mock) decides which blocks appear and in what order; this view
//  just hydrates each into a native layout.
//

import SwiftUI

struct ResultBlockView: View {
    let block: ResultBlock

    var body: some View {
        switch block.style {
        case .text:
            Text(.init(block.text))   // basic markdown
                .font(.centra(size: 16))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

        case .heading:
            Text(block.text)
                .font(.centra(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

        case .cards:
            VStack(spacing: 24) {
                ForEach(Array(block.cards.enumerated()), id: \.element.id) { i, card in
                    ResultCardView(card: card, index: i)
                }
            }
            .padding(.horizontal, 44)

        case .carousel:
            VStack(alignment: .leading, spacing: 12) {
                if !block.text.isEmpty {
                    Text(block.text)
                        .font(.centra(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.horizontal, 28)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(block.cards) { card in
                            CarouselCard(card: card)
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
    }
}

/// Compact card used inside a carousel row.
private struct CarouselCard: View {
    let card: Card

    @State private var favorited = false

    private var isLodging: Bool { card.rating != nil }

    var body: some View {
        if isLodging { hotelCard } else { genericCard }
    }

    /// Compact take on the redesigned lodging card (Figma 1539-5566).
    private var hotelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .frame(width: 158, height: 118)
                .overlay { image(placeholderSize: 34) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusHotelImage))
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(Theme.springSoft) { favorited.toggle() }
                    } label: {
                        EGDSIcon(favorited ? "heart.fill" : "heart", size: 13)
                            .font(.centra(size: 12, weight: .semibold))
                            .foregroundStyle(favorited ? Color.red : Color.white)
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.28), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }

            Text(card.displayTitle)
                .font(.centra(size: 14, weight: .semibold))
                .foregroundStyle(Theme.figmaInk)
                .lineLimit(1)

            if let score = card.ratingScoreText {
                (Text(score).font(.centra(size: 12, weight: .semibold)).foregroundStyle(Theme.figmaInk)
                 + Text(card.ratingDetailText).font(.centra(size: 12)).foregroundStyle(Theme.onSurfaceVariant))
                    .lineLimit(1)
            }

            Text(card.totalPrice ?? card.displayPrice ?? "")
                .font(.centra(size: 15, weight: .semibold))
                .foregroundStyle(Theme.figmaInk)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 178, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.radiusHotelCard))
        .shadow(color: Theme.hotelCardShadow, radius: 12, y: 4)
    }

    private var genericCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .frame(width: 150, height: 150)
                .overlay { image(placeholderSize: 34) }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.cardShadow, radius: 10, y: 2)
                .overlay(alignment: .topLeading) {
                    if let logo = card.logoURLs.first {
                        LogoBadge(logo: logo, size: 30, cornerRadius: 8, inset: 6,
                                  shadowRadius: 4, shadowY: 1)
                            .padding(8)
                    }
                }

            Text(card.displayTitle)
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if let price = card.displayPrice {
                Text(price)
                    .font(.centra(size: 13))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    @ViewBuilder
    private func image(placeholderSize: CGFloat) -> some View {
        if card.imageURL != nil {
            RemoteOrLocalImage(urlString: card.imageURL)
        } else {
            ZStack {
                Rectangle().fill(Color(white: 0.93))
                EGDSIcon(card.icon ?? "hotel", size: placeholderSize)
                    .font(.centra(size: placeholderSize))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }
}
