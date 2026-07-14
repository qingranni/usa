//
//  FlightsResultsView.swift
//  Universal Search App
//
//  The flights results canvas (Figma "iPhone 16 & 17 Pro – 96"): a map hero with
//  the route arc, a centered route title, filter chips, a "Picked for you"
//  section, and the redesigned flight cards (times · route · airlines · price).
//  Rendered by CurtainSheet for `.flights` threads in place of the generic block
//  layout.
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
    let metrics: Metrics

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
    private var route: FlightRoute? { FlightRoute(flights.first?.title) }
    private var summary: String {
        thread.activeBlocks.first { $0.style == .text }?.text ?? ""
    }
    private var routeTitle: String {
        if let r = route { return "Flexible flights \(r.originCity) to \(r.destCity)" }
        return thread.title
    }

    var body: some View {
        // The live Apple Map now sits behind the sheet (RootView), revealed by
        // dragging the detent sheet down — so this view is just the white sheet
        // content. The sheet starts at the detent top, so the top padding only has
        // to clear the drag grabber (owned by CurtainSheet).
        VStack(alignment: .leading, spacing: 24) {
            Text(routeTitle)
                .font(.centra(size: 16, weight: .medium))
                .foregroundStyle(Theme.figmaInk)
                .frame(maxWidth: .infinity, alignment: .center)

            chips

            VStack(alignment: .leading, spacing: 4) {
                Text("Picked for you")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.figmaInk)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.centra(size: 16))
                        .foregroundStyle(Theme.figmaInk.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 16) {
                ForEach(Array(flights.enumerated()), id: \.element.id) { i, card in
                    FlightResultCard(card: card)
                }
            }

            if !moreFlights.isEmpty {
                Text(moreHeading ?? "More flights")
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
        .padding(.top, 28)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(red: 243 / 255, green: 242 / 255, blue: 242 / 255).opacity(0.8))
                    EGDSIcon("slider.horizontal.3", size: 18)
                        .foregroundStyle(Theme.figmaInk)
                }
                .frame(width: 40, height: 40)

                ForEach(chipLabels, id: \.self) { label in
                    Text(label)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Color(red: 243 / 255, green: 242 / 255, blue: 242 / 255).opacity(0.8),
                                    in: Capsule())
                }
            }
        }
    }

    private var chipLabels: [String] {
        if !thread.preferences.isEmpty { return thread.preferences }
        var labels: [String] = ["Seats together"]
        if let trip = flights.first?.tripType { labels.append(trip) }
        if let cabin = flights.first?.cabin { labels.append(cabin) }
        labels.append("2 adults, 1 infant")
        return labels
    }
}

// MARK: - Flight card

struct FlightResultCard: View {
    let card: Card
    var compact: Bool = false

    private var route: FlightRoute? { FlightRoute(card.title) }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 24) {
                topRow
                metaRow
            }
            Divider().overlay(Theme.figmaInk.opacity(0.1))
            priceRow
        }
        .padding(16)
        .frame(width: compact ? 320 : nil)
        .background(Color(red: 0xF8 / 255, green: 0xF8 / 255, blue: 0xF8 / 255),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private var topRow: some View {
        VStack(spacing: 4) {
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

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(route.map { "\($0.originCity) (\($0.originCode))" } ?? "")
                    .font(.centra(size: 14, weight: .medium))
                VStack(alignment: .leading, spacing: 2) {
                    if let dur = card.duration {
                        Text(dur).font(.centra(size: 14)).opacity(0.7)
                    }
                    if let stops = card.stops {
                        Text(stops).font(.centra(size: 14)).opacity(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(route.map { "\($0.destCity) (\($0.destCode))" } ?? "")
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

    private var metaRow: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                if !card.airlines.isEmpty {
                    Text(card.airlines.joined(separator: ", "))
                }
                if let cabin = card.cabin {
                    Text(cabin)
                }
            }
            .font(.centra(size: 14))
            .foregroundStyle(Theme.figmaInk.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach(card.logoURLs.prefix(2), id: \.self) { logo in
                    LogoImage(logo: logo)
                        .frame(width: 40, height: 40)
                }
            }
        }
    }

    private var priceRow: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let price = card.price {
                    Text(price)
                        .font(.centra(size: 24, weight: .medium))
                        .tracking(-0.48)
                        .foregroundStyle(Theme.figmaInk)
                }
                if let trip = card.tripType {
                    Text(trip)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Details")
                .font(.centra(size: 14, weight: .medium))
                .tracking(-0.25)
                .foregroundStyle(Theme.figmaInk)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Color(white: 0.83).opacity(0.5), in: Capsule())
        }
    }
}
