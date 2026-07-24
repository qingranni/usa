//
//  ResultCardView.swift
//  Universal Search App
//
//  A single hotel/flight/car result card (ResultCard.jsx): 1:1 rounded image,
//  title, optional price. Fades + slides up on appear with a per-index stagger.
//

import SwiftUI

struct ResultCardView: View {
    let card: Card
    var index: Int = 0

    @State private var favorited = false

    /// Lodging cards carry a guest rating (real or synthesized) and render the
    /// redesigned white card; everything else keeps the generic layout.
    private var isLodging: Bool { card.rating != nil }

    var body: some View {
        Group {
            if isLodging { hotelCard } else { genericCard }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggeredAppear(index: index)
    }

    // MARK: Redesigned lodging card (Figma 1539-5566)

    private var hotelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            hotelImage

            Text(card.displayTitle)
                .font(.centra(size: 17, weight: .semibold))
                .foregroundStyle(Theme.figmaInk)
                .padding(.top, 14)

            if let score = card.ratingScoreText {
                (Text(score).font(.centra(size: 14, weight: .semibold)).foregroundStyle(Theme.figmaInk)
                 + Text(card.ratingDetailText).font(.centra(size: 14)).foregroundStyle(Theme.onSurfaceVariant))
                    .padding(.top, 4)
            }

            Text(Copy["results.includesTaxesAndFees"])
                .font(.centra(size: 13))
                .foregroundStyle(Theme.onSurfaceVariant)
                .padding(.top, 10)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.totalPrice ?? card.displayPrice ?? "")
                    .font(.centra(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.figmaInk)
                if card.totalPrice != nil, let nightly = card.displayPrice {
                    Text("\(nightly)\(Copy["results.perNightSuffix"])")
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.onSurfaceVariant)
                }
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.radiusHotelCard))
        .shadow(color: Theme.hotelCardShadow,
                radius: Theme.hotelCardShadowRadius, y: Theme.hotelCardShadowY)
    }

    private var hotelImage: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay { imageContent }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusHotelImage))
            .overlay(alignment: .topTrailing) { favoriteButton.padding(10) }
    }

    private var favoriteButton: some View {
        Button {
            withAnimation(Theme.springSoft) { favorited.toggle() }
        } label: {
            EGDSIcon(favorited ? "heart.fill" : "heart", size: 16)
                .font(.centra(size: 15, weight: .semibold))
                .foregroundStyle(favorited ? Color.red : Color.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.28), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Generic card (flights in mixed layouts, cars, activities)

    private var genericCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { imageContent }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
                .shadow(color: Theme.cardShadow, radius: Theme.cardShadowRadius, y: Theme.cardShadowY)
                .overlay(alignment: .topLeading) {
                    if !card.logoURLs.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(card.logoURLs.prefix(2), id: \.self) { LogoBadge(logo: $0) }
                        }
                        .padding(12)
                    }
                }

            Text(card.displayTitle)
                .font(.centra(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            if card.departTime != nil { flightInfo.padding(.top, 6) }

            if let price = card.displayPrice {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(price)
                        .font(.centra(size: 16))
                        .foregroundStyle(Theme.inkMuted)
                    if card.departTime != nil, let trip = card.tripType {
                        Text(trip)
                            .font(.centra(size: 13))
                            .foregroundStyle(Theme.inkMuted.opacity(0.8))
                    }
                }
                .padding(.top, 3)
            }

            // Reserved highlights slot (hotels) — stub copy for now.
            if let hl = card.highlights, !hl.isEmpty {
                Text(hl)
                    .font(.centra(size: 13))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 6)
            }
        }
    }

    /// The card photo (remote/local) or a kind glyph placeholder.
    @ViewBuilder
    private var imageContent: some View {
        if card.imageURL != nil {
            RemoteOrLocalImage(urlString: card.imageURL)
        } else {
            ZStack {
                Rectangle().fill(Color(white: 0.93))
                EGDSIcon(card.icon ?? "hotel", size: 56)
                    .font(.centra(size: 56))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }

    /// Structured flight detail: times, stops/duration, cabin + carriers.
    @ViewBuilder
    private var flightInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let dep = card.departTime, let arr = card.arriveTime {
                Text("\(dep) → \(arr)")
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            let line = [card.stops, card.duration].compactMap { $0 }.joined(separator: " · ")
            if !line.isEmpty {
                Text(line)
                    .font(.centra(size: 13))
                    .foregroundStyle(Theme.inkMuted)
            }
            if let cabin = card.cabin {
                let carriers = card.airlines.isEmpty ? "" : " · " + card.airlines.joined(separator: ", ")
                Text(cabin + carriers)
                    .font(.centra(size: 13))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
