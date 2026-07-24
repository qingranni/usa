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
    @Bindable var store: AppStore
    let block: ResultBlock
    var canvasLayout: ResultsCanvasLayout = .standard

    private var isMexicoOrientation: Bool {
        canvasLayout == .mexicoOrientation
    }

    @ViewBuilder
    var body: some View {
        if let semanticType = block.semanticType {
            UniversalSemanticBlockView(
                store: store,
                type: semanticType,
                props: block.semanticProps,
                fallback: block.text
            )
                .padding(.horizontal, 28)
        } else {
            standardBody
        }
    }

    @ViewBuilder
    private var standardBody: some View {
        switch block.style {
        case .text:
            Text(.init(block.text))   // basic markdown
                .font(.centra(size: 16))
                .foregroundStyle(isMexicoOrientation ? Theme.inkMuted : Theme.ink)
                .lineSpacing(isMexicoOrientation ? 3 : 0)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

        case .heading:
            Text(block.text)
                .font(.centra(
                    size: isMexicoOrientation ? 20 : 18,
                    weight: isMexicoOrientation ? .medium : .semibold
                ))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

        case .highlight:
            if let card = block.cards.first {
                if block.cardPresentation == .destinationHero {
                    DestinationHeroCard(card: card)
                        .padding(.horizontal, 28)
                } else if block.cardPresentation == .flight {
                    FlightResultCard(card: card)
                        .padding(.horizontal, 24)
                } else {
                    ResultCardView(card: card, index: 0)
                        .padding(.horizontal, 44)
                }
            }

        case .cards:
            VStack(spacing: block.cardPresentation == .destinationHero ? 16 : 24) {
                ForEach(Array(block.cards.enumerated()), id: \.element.id) { i, card in
                    if block.cardPresentation == .destinationHero {
                        DestinationHeroCard(card: card)
                            .staggeredAppear(index: i)
                    } else if block.cardPresentation == .flight {
                        FlightResultCard(card: card)
                            .staggeredAppear(index: i)
                    } else {
                        ResultCardView(card: card, index: i)
                    }
                }
            }
            .padding(.horizontal, block.cardPresentation == .destinationHero ? 28 : 44)

        case .carousel:
            VStack(alignment: .leading, spacing: 12) {
                if !block.text.isEmpty {
                    Text(block.text)
                        .font(.centra(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.horizontal, 28)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: block.cardPresentation == .destinationCarousel ? 8 : 14) {
                        ForEach(block.cards) { card in
                            if block.cardPresentation == .flight {
                                FlightResultCard(card: card, compact: true)
                            } else if block.cardPresentation == .destinationCarousel {
                                DestinationCarouselCard(card: card)
                            } else {
                                CarouselCard(card: card)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
    }
}

/// Full-width authored destination card used by the Mexico Narrative orientation
/// frame. Its chrome is explicit, so generic `.other` results do not inherit it.
private struct DestinationHeroCard: View {
    let card: Card

    @State private var favorited = false

    private var detail: String {
        let parts = card.sublabel.components(separatedBy: " · ")
        return parts.dropFirst().joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 280)
                .overlay {
                    if card.imageURL != nil {
                        RemoteOrLocalImage(urlString: card.imageURL)
                    } else {
                        Theme.cardItem
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.35), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.displayTitle)
                            .font(.centra(size: 28, weight: .medium))
                        Text(card.highlights ?? "Flights + stay")
                            .font(.centra(size: 16, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(Theme.springSoft) { favorited.toggle() }
                    } label: {
                        EGDSIcon(favorited ? "heart.fill" : "heart", size: 18)
                            .foregroundStyle(favorited ? Color.red : Color.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.16), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(18)
                    .accessibilityLabel(favorited ? "Remove from favorites" : "Add to favorites")
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                if !detail.isEmpty {
                    Text(detail)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let price = card.displayPrice {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(Copy["results.pricePrefix"])
                                .font(.centra(size: 15, weight: .medium))
                                .foregroundStyle(Theme.inkMuted)
                            Text(price)
                                .font(.centra(size: 20, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        Text(Copy["results.priceAvgCaption"])
                            .font(.centra(size: 12))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)
        }
        .padding(8)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct DestinationCarouselCard: View {
    let card: Card

    @State private var favorited = false

    private var detail: String {
        let parts = card.sublabel.components(separatedBy: " · ")
        return parts.dropFirst().joined(separator: " · ")
    }

    private var staySummary: String {
        let nights = card.nights ?? 5
        let travelers = card.travelers ?? 3
        return "for \(nights) nights and \(travelers) travelers"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .frame(width: 230, height: 230)
                .overlay {
                    if card.imageURL != nil {
                        RemoteOrLocalImage(urlString: card.imageURL)
                    } else {
                        Theme.cardItem
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(Theme.springSoft) { favorited.toggle() }
                    } label: {
                        EGDSIcon(favorited ? "heart.fill" : "heart", size: 18)
                            .foregroundStyle(favorited ? Color.red : Color.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.16), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .accessibilityLabel(favorited ? "Remove from favorites" : "Add to favorites")
                }

            VStack(alignment: .leading, spacing: 12) {
                Text(card.displayTitle)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let price = card.displayPrice {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(price)
                            .font(.centra(size: 20, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text(staySummary)
                            .font(.centra(size: 12))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 230, alignment: .leading)
    }
}

private struct UniversalSemanticBlockView: View {
    @Bindable var store: AppStore
    let type: String
    let props: [String: JSONValue]
    let fallback: String

    var body: some View {
        switch type {
        case "result-state-summary":
            VStack(alignment: .leading, spacing: 5) {
                Text(string("headline") ?? fallback)
                    .font(.centra(size: 17, weight: .semibold))
                if let detail = string("detail") {
                    Text(detail)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.inkMuted)
                }
                if let source = string("sourceLabel") {
                    Text("Source: \(source)")
                        .font(.centra(size: 12))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardItem.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))

        case "clarification":
            VStack(alignment: .leading, spacing: 10) {
                Text(string("question") ?? fallback)
                    .font(.centra(size: 18, weight: .semibold))
                if let reason = string("reason") {
                    Text(reason)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.inkMuted)
                }
                ForEach(actions) { action in
                    Button {
                        Task { await store.submit(action) }
                    } label: {
                        Text(action.label)
                            .font(.centra(size: 14, weight: .medium))
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(Theme.figmaChipFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 20))

        case "comparison-table":
            comparison

        case "validation-block":
            VStack(alignment: .leading, spacing: 10) {
                Text(string("title") ?? fallback)
                    .font(.centra(size: 16, weight: .semibold))
                ForEach(Array((props["facts"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, value in
                    if let fact = value.objectValue {
                        HStack(alignment: .top) {
                            Text(fact["label"]?.stringValue ?? "")
                                .foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Text(fact["value"]?.stringValue ?? "Unknown")
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.centra(size: 14))
                    }
                }
            }
            .padding(16)
            .background(Theme.cardItem.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))

        case "capability-state":
            ContentUnavailableView {
                Label(string("title") ?? "Unavailable", systemImage: "info.circle")
            } description: {
                Text(string("message") ?? fallback)
            }

        case "explainability-note":
            Label(string("content") ?? fallback, systemImage: "info.circle")
                .font(.centra(size: 14))
                .foregroundStyle(Theme.inkMuted)

        default:
            Text(fallback)
                .font(.centra(size: 16))
                .foregroundStyle(Theme.ink)
        }
    }

    private var comparison: some View {
        let headers = props["headers"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let ids = props["candidateIds"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let rows = props["rows"]?.arrayValue?.compactMap(\.objectValue) ?? []
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                comparisonColumn(
                    title: headers.first ?? "Fact",
                    values: rows.map { $0["fact"]?.stringValue ?? "" }
                )
                ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                    comparisonColumn(
                        title: headers.indices.contains(index + 1) ? headers[index + 1] : id,
                        values: rows.map { suggestionText($0[id] ?? .null) }
                    )
                }
            }
        }
    }

    private func comparisonColumn(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.centra(size: 14, weight: .semibold)).lineLimit(2)
            Divider()
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.centra(size: 13))
                    .frame(minHeight: 34, alignment: .topLeading)
            }
        }
        .padding(12)
        .frame(width: 160, alignment: .leading)
        .background(Theme.cardItem.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    private func string(_ key: String) -> String? {
        props[key]?.stringValue
    }

    private func suggestionText(_ value: JSONValue) -> String {
        switch value {
        case .null: return "Unknown"
        case .bool(let value): return value ? "Yes" : "No"
        case .number(let value): return value.formatted()
        case .string(let value): return value
        case .array(let values): return values.map(suggestionText).joined(separator: ", ")
        case .object(let object):
            return object.keys.sorted().compactMap { key in
                object[key].map(suggestionText)
            }.joined(separator: " – ")
        }
    }

    private var actions: [RefinementAction] {
        (props["mappedActions"]?.arrayValue ?? []).compactMap { value in
            guard let object = value.objectValue,
                  let id = object["id"]?.stringValue,
                  let label = object["label"]?.stringValue,
                  let query = object["query"]?.stringValue,
                  let rawKind = object["kind"]?.stringValue,
                  let kind = RefinementActionKind(rawValue: rawKind)
            else { return nil }
            let field = object["field"]?.stringValue
            let actionValue = object["value"].flatMap { $0 == .null ? nil : $0 }
            return RefinementAction(
                id: id,
                label: label,
                field: field,
                value: actionValue,
                query: query,
                kind: kind,
                required: object["required"]?.boolValue ?? false
            )
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
