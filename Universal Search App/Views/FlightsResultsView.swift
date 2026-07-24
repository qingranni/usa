//
//  FlightsResultsView.swift
//  Universal Search App
//
//  The flights results canvas (Figma "iPhone 16 & 17 Pro – 96"): a map hero with
//  the route arc and redesigned flight cards (times · route · airlines · price).
//  Rendered by CurtainSheet for `.flights` threads in place of the generic block
//  layout. Shared query replay and filters are owned by ResultsCanvasContent.
//

import SwiftUI

// MARK: - Airport code → city

enum Airports {
    private static let names: [String: String] = [
        "IAH": "Houston", "HOU": "Houston",
        "JFK": "New York", "EWR": "Newark", "NYC": "New York",
        "CUN": "Cancún", "SJD": "Los Cabos", "PVR": "Puerto Vallarta",
        "TQO": "Tulum", "LAX": "Los Angeles", "TPA": "Tampa",
    ]
    static func city(_ code: String) -> String { names[code.uppercased()] ?? code }
}

/// A parsed "IAH → TPA" route.
struct FlightRoute {
    var originCode: String
    var destCode: String
    var originCity: String { Airports.city(originCode) }
    var destCity: String { Airports.city(destCode) }

    /// Parse a card title like "IAH → TPA" (also tolerates "-"/"to").
    init?(_ title: String?) {
        guard let title else { return nil }
        let parts = title.split(whereSeparator: { "→-".contains($0) })
            .flatMap { $0.split(separator: " ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count == 3 && $0.allSatisfy(\.isLetter) }
        guard parts.count >= 2 else { return nil }
        originCode = parts[0].uppercased()
        destCode = parts[1].uppercased()
    }
}

struct FlightsResultsView: View {
    let thread: ThreadNode

    /// The main hero flight cards.
    private var flights: [Card] {
        thread.activeBlocks.first { $0.style == .cards }?.cards ?? thread.activeCards
    }
    /// "More flights" carousel + its heading.
    private var moreHeading: String? {
        thread.activeBlocks.first { $0.style == .heading }?.text
    }
    private var moreFlights: [Card] {
        thread.activeBlocks.first { $0.style == .carousel }?.cards ?? []
    }
    private var summary: String {
        thread.activeBlocks.first { $0.style == .text && $0.semanticType == nil }?.text ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Copy["results.flights.heading"])
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.figmaInk)
                if !summary.isEmpty {
                    (Text(summary + " ")
                        .foregroundStyle(Theme.figmaInk.opacity(0.5))
                     + Text(Copy["results.flights.sortByPrice"])
                        .foregroundStyle(Theme.figmaInk.opacity(0.75))
                        .underline())
                        .font(.centra(size: 16))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(Copy["results.flights.lapInfantFare"])
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.figmaInk.opacity(0.5))
            }

            VStack(spacing: 16) {
                ForEach(Array(flights.enumerated()), id: \.element.id) { i, card in
                    FlightResultCard(card: card)
                }
            }

            if !moreFlights.isEmpty {
                Text(moreHeading ?? "More options")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.figmaInk)
                    .padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(moreFlights) { FlightResultCard(card: $0, compact: true) }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Flight card

struct FlightResultCard: View {
    let card: Card
    var compact: Bool = false

    @State private var saved = false

    private var route: FlightRoute? { FlightRoute(card.title) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            timesRow
            bottomRow
        }
        .padding(20)
        .frame(width: compact ? 320 : nil, alignment: .leading)
        .background(Color(red: 0xF8 / 255, green: 0xF8 / 255, blue: 0xF8 / 255),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Header (avatar · name · aircraft line · save)

    private var header: some View {
        HStack(spacing: 12) {
            if let logo = card.logoURLs.first {
                LogoImage(logo: logo)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(airlineName)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.centra(size: 13))
                        .foregroundStyle(Theme.figmaInk.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                Haptics.impact(.light)
                withAnimation(Theme.fade) { saved.toggle() }
            } label: {
                EGDSIcon(saved ? "favorite" : "favorite_border", size: 22)
                    .foregroundStyle(saved ? Theme.figmaInk : Theme.figmaInk.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(saved ? "Saved" : "Save flight")
        }
    }

    private var airlineName: String {
        guard let a = card.airlines.first else { return "Flight" }
        switch a {
        case "United":    return "United Airlines"
        case "Delta":     return "Delta Air Lines"
        case "American":  return "American Airlines"
        case "JetBlue":   return "JetBlue Airways"
        case "Spirit":    return "Spirit Airlines"
        case "Alaska":    return "Alaska Airlines"
        case "Southwest": return "Southwest Airlines"
        default:          return a.localizedCaseInsensitiveContains("air") ? a : "\(a) Airlines"
        }
    }

    /// "Economy • Boeing 777 • UA 507" — omits any missing piece.
    private var metaLine: String {
        [card.cabin, card.aircraft, card.flightNumber]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    // MARK: - Times / route

    private var timesRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text(card.departTime ?? "")
                    .font(.centra(size: 24, weight: .medium))
                    .tracking(-0.72)
                connector
                Text(card.arriveTime ?? "")
                    .font(.centra(size: 24, weight: .medium))
                    .tracking(-0.72)
            }
            .foregroundStyle(Theme.figmaInk)

            HStack(spacing: 12) {
                Text(route?.originCode ?? "")
                    .font(.centra(size: 14, weight: .medium))
                Spacer()
                if let dur = card.duration {
                    Text(dur)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk.opacity(0.6))
                }
                Spacer()
                Text(route?.destCode ?? "")
                    .font(.centra(size: 14, weight: .medium))
            }
            .foregroundStyle(Theme.figmaInk)
        }
    }

    private var connector: some View {
        ZStack {
            Rectangle()
                .fill(Theme.figmaInk.opacity(0.25))
                .frame(height: 1)
            Circle()
                .fill(Theme.figmaInk)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stops · amenities · price

    private var bottomRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if let stops = card.stops {
                    Text(stops)
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                }
                if let layover = layoverText {
                    Text(layover)
                        .font(.centra(size: 13))
                        .foregroundStyle(Theme.figmaInk.opacity(0.6))
                }
                amenityStrip
            }
            Spacer(minLength: 0)
            priceColumn
        }
    }

    /// Layover detail only when the flight isn't nonstop; sourced from the
    /// option's highlights (fixtures carry no structured layover today).
    private var layoverText: String? {
        guard let stops = card.stops,
              !stops.localizedCaseInsensitiveContains("nonstop") else { return nil }
        return card.highlights
    }

    private var amenityStrip: some View {
        HStack(spacing: 12) {
            ForEach(["suitcase.fill", "wifi", "powerplug.fill", "play.rectangle.fill"], id: \.self) { name in
                Image(systemName: name)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.figmaInk.opacity(0.55))
            }
        }
    }

    private var priceColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let discount = card.discountText {
                Text(discount)
                    .font(.centra(size: 12, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                    .padding(.horizontal, 10)
                    .frame(height: 20)
                    .background(Color(red: 253 / 255, green: 219 / 255, blue: 50 / 255), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let old = card.crossedOutPrice {
                    Text(old)
                        .font(.centra(size: 15))
                        .foregroundStyle(Theme.figmaInk.opacity(0.5))
                        .strikethrough()
                }
                if let price = card.price {
                    Text(price)
                        .font(.centra(size: 24, weight: .medium))
                        .tracking(-0.48)
                        .foregroundStyle(Theme.figmaInk)
                }
            }
            Text("\(card.tripType ?? Copy["results.flights.roundTrip"])\(Copy["results.flights.perTravelerSuffix"])")
                .font(.centra(size: 13))
                .foregroundStyle(Theme.figmaInk.opacity(0.6))
        }
    }
}
