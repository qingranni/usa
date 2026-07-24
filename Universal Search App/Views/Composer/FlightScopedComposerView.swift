//
//  FlightScopedComposerView.swift
//  Universal Search App
//
//  Flights-only sister of the universal composer. It starts as a structured
//  airport picker (not a text editor), so the keyboard remains closed.
//

import SwiftUI

struct FlightAirport: Identifiable, Equatable {
    enum Artwork: Equatable {
        case icon(String)
        case asset(String)
    }

    let code: String
    let name: String
    let city: String
    let subtitle: String
    let artwork: Artwork

    var id: String { code }
    var displayName: String { "\(city) (\(code) - \(name))" }

    static let hobby = FlightAirport(
        code: "HOU",
        name: "William P. Hobby",
        city: "Houston",
        subtitle: "Airport in Texas, US",
        artwork: .icon("airplane")
    )
    static let tampa = FlightAirport(
        code: "TPA",
        name: "Tampa International",
        city: "Tampa",
        subtitle: "Airport in Florida, US",
        artwork: .icon("airplane")
    )
}

struct FlightScopedComposerDraft: Equatable {
    enum Step: Equatable {
        case origin
        case destination
        case dates
        case travelers
    }

    enum TripType: String, CaseIterable, Identifiable {
        case roundtrip = "Roundtrip"
        case oneWay = "One-way"
        case multiCity = "Multi-city"

        var id: Self { self }
    }

    var step: Step = .origin
    var tripType: TripType = .roundtrip
    var origin: FlightAirport? = .hobby
    var destination: FlightAirport?

    // Dates
    var departureDate: Date?
    var returnDate: Date?
    /// The "Exact dates / +2 day" chip pair — cosmetic ± flexibility label.
    var datesFlexible: Bool = false

    // Travelers
    var adults: Int = 2
    var children: Int = 1
    var childAges: [Int] = [1]
    var petsAllowed: Bool = false

    init(prefillsMockDestination: Bool) {
        destination = prefillsMockDestination ? .tampa : nil
    }

    var selectedAirport: FlightAirport? {
        get { step == .origin ? origin : destination }
        set {
            if step == .origin {
                origin = newValue
            } else {
                destination = newValue
            }
        }
    }

    var canAdvance: Bool {
        switch step {
        case .origin: return origin != nil
        case .destination: return destination != nil
        case .dates, .travelers: return true
        }
    }

    /// Advances to the next step; returns `true` only when the whole flow is
    /// complete (on `.travelers` with a full route) and the caller should submit.
    @discardableResult
    mutating func advance() -> Bool {
        switch step {
        case .origin:
            guard origin != nil else { return false }
            step = .destination
            return false
        case .destination:
            guard destination != nil else { return false }
            step = .dates
            return false
        case .dates:
            step = .travelers
            return false
        case .travelers:
            return origin != nil && destination != nil
        }
    }

    /// Keeps `childAges` in sync with the child count (0–6 children, ages 0–17).
    mutating func setChildren(_ count: Int) {
        let clamped = max(0, min(count, 6))
        children = clamped
        if childAges.count < clamped {
            childAges.append(contentsOf: Array(repeating: 10, count: clamped - childAges.count))
        } else if childAges.count > clamped {
            childAges.removeLast(childAges.count - clamped)
        }
    }

    var totalTravelers: Int { adults + children }

    var travelerLabel: String {
        "\(totalTravelers) traveler\(totalTravelers == 1 ? "" : "s")"
    }

    /// "Aug 25–28" (same month) / "Aug 28 – Sep 2" (spanning), with an optional
    /// "(±2)" suffix when flexible. `nil` until a departure date is chosen.
    var dateRangeLabel: String? {
        guard let departureDate else { return nil }
        let cal = Calendar.current
        let monthDay = DateFormatter()
        monthDay.dateFormat = "MMM d"
        let start = monthDay.string(from: departureDate)
        let base: String
        if let returnDate {
            if cal.isDate(departureDate, equalTo: returnDate, toGranularity: .month) {
                base = "\(start)–\(cal.component(.day, from: returnDate))"
            } else {
                base = "\(start) – \(monthDay.string(from: returnDate))"
            }
        } else {
            base = start
        }
        return datesFlexible ? "\(base) (±2)" : base
    }

    var submissionQuery: String? {
        guard let origin, let destination else { return nil }
        var parts = ["\(tripType.rawValue) flights from \(origin.city) (\(origin.code)) to \(destination.city) (\(destination.code))"]
        if let dateRangeLabel { parts.append(dateRangeLabel) }
        parts.append(travelerLabel)
        return parts.joined(separator: ", ")
    }
}

struct FlightScopedComposerView: View {
    @Bindable var store: AppStore

    @Environment(\.dismiss) private var dismiss
    @State private var draft: FlightScopedComposerDraft
    @State private var submitting = false

    init(store: AppStore) {
        self.store = store
        _draft = State(
            initialValue: FlightScopedComposerDraft(
                prefillsMockDestination: store.assistantSourceMode == .narrativeMock
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Theme.cardItem.ignoresSafeArea()

                composerSurface(safeTop: geometry.safeAreaInsets.top)
                    .padding(.bottom, 117)

                quickActions
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .interactiveDismissDisabled(submitting)
    }

    private func composerSurface(safeTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 48,
                bottomLeadingRadius: 48,
                bottomTrailingRadius: 48,
                topTrailingRadius: 48,
                style: .continuous
            )
            .fill(.white)
            .shadow(color: Theme.ink.opacity(0.06), radius: 27)

            VStack(spacing: 0) {
                tripTypePicker
                    .padding(.top, safeTop + 66)

                stepContent
                    .padding(.top, 30)
            }
            .padding(.horizontal, 32)

            HStack {
                closeButton
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, safeTop + 8)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if draft.step == .dates {
                        flexibilityChips
                    }
                    Spacer()
                    forwardButton
                }
                .padding(.leading, 32)
                .padding(.trailing, 28)
                .padding(.bottom, 28)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 48,
                bottomLeadingRadius: 48,
                bottomTrailingRadius: 48,
                topTrailingRadius: 48,
                style: .continuous
            )
        )
    }

    private var tripTypePicker: some View {
        Picker("Trip type", selection: $draft.tripType) {
            ForEach(FlightScopedComposerDraft.TripType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .font(.centra(size: 14, weight: .medium))
        .accessibilityLabel("Trip type")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case .origin, .destination:
            VStack(spacing: 0) {
                selectionHeader
                airportSuggestions
                    .padding(.top, 14)
                Spacer(minLength: 72)
            }
        case .dates:
            datesStep
        case .travelers:
            travelersStep
        }
    }

    // MARK: - Dates step

    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When?")
                .font(.centra(size: 24, weight: .medium))
                .tracking(-0.5)
                .foregroundStyle(Theme.figmaInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            weekdayHeader
                .padding(.top, 20)
                .padding(.bottom, 8)

            Divider().overlay(Theme.figmaInk.opacity(0.08))

            FlightDatesCalendar(
                departureDate: $draft.departureDate,
                returnDate: $draft.returnDate
            )
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var flexibilityChips: some View {
        HStack(spacing: 8) {
            flexChip(title: "Exact dates", isOn: !draft.datesFlexible) {
                draft.datesFlexible = false
            }
            flexChip(title: "+2 day", isOn: draft.datesFlexible) {
                draft.datesFlexible = true
            }
        }
    }

    private func flexChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(Theme.fade) { action() }
        } label: {
            Text(title)
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(isOn ? Theme.figmaInk : Theme.onSurfaceVariant)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(isOn ? Theme.figmaChipFill : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Travelers step

    private var travelersStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Who's going?")
                    .font(.centra(size: 24, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.figmaInk)
                    .frame(maxWidth: .infinity, alignment: .leading)

                stepperRow(label: "Adults", subtitle: nil, count: draft.adults, range: 1...9) { value in
                    draft.adults = value
                }
                Divider().overlay(Theme.figmaInk.opacity(0.08))

                stepperRow(label: "Children", subtitle: "Age 0 to 17", count: draft.children, range: 0...6) { value in
                    withAnimation(Theme.fade) { draft.setChildren(value) }
                }

                if draft.children > 0 {
                    VStack(spacing: 12) {
                        ForEach(0..<draft.children, id: \.self) { index in
                            childAgeRow(index: index)
                        }
                    }
                    .padding(.bottom, 8)
                }
                Divider().overlay(Theme.figmaInk.opacity(0.08))

                petsRow

                Spacer(minLength: 72)
            }
        }
        .scrollClipDisabled()
    }

    private func stepperRow(
        label: String,
        subtitle: String?,
        count: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                if let subtitle {
                    Text(subtitle)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.onSurfaceVariant)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                stepperButton(icon: "minus", disabled: count <= range.lowerBound) {
                    onChange(count - 1)
                }
                Text("\(count)")
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                    .frame(minWidth: 20)
                stepperButton(icon: "plus", disabled: count >= range.upperBound) {
                    onChange(count + 1)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private func stepperButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            EGDSIcon(icon, size: 15)
                .foregroundStyle(disabled ? Theme.figmaInk.opacity(0.3) : Theme.figmaInk)
                .frame(width: 38, height: 38)
                .background(Theme.ink.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(icon == "plus" ? "Increase \(icon)" : "Decrease")
    }

    private func childAgeRow(index: Int) -> some View {
        HStack {
            Text("Child \(index + 1) age")
                .font(.centra(size: 14))
                .foregroundStyle(Theme.onSurfaceVariant)
            Spacer()
            Menu {
                ForEach(0...17, id: \.self) { age in
                    Button("\(age)") {
                        if index < draft.childAges.count { draft.childAges[index] = age }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(index < draft.childAges.count ? "\(draft.childAges[index])" : "1")
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.onSurfaceVariant)
                }
                .padding(.horizontal, 20)
                .frame(minWidth: 96)
                .frame(height: 44)
                .background(Theme.figmaChipFill, in: Capsule())
            }
            .accessibilityLabel("Child \(index + 1) age")
        }
    }

    private var petsRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pets")
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                Text("Only results that allow pets will be shown")
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.onSurfaceVariant)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.impact(.light)
                withAnimation(Theme.fade) { draft.petsAllowed.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(draft.petsAllowed ? Theme.ink : Color.clear)
                        .overlay(
                            Circle().strokeBorder(
                                draft.petsAllowed ? Color.clear : Theme.figmaInk.opacity(0.2),
                                lineWidth: 1
                            )
                        )
                        .frame(width: 28, height: 28)
                    if draft.petsAllowed {
                        EGDSIcon("checkmark", size: 14).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pets allowed")
            .accessibilityAddTraits(draft.petsAllowed ? .isSelected : [])
        }
        .padding(.vertical, 20)
    }

    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(draft.step == .origin ? "Leaving from" : "Going to")
                .font(.centra(size: 14))
                .foregroundStyle(Theme.onSurfaceVariant)

            HStack(spacing: 8) {
                Text(draft.selectedAirport?.displayName ?? "Select an airport")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(Theme.figmaInk)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if draft.selectedAirport != nil {
                    Button {
                        Haptics.impact(.light)
                        withAnimation(Theme.fade) { draft.selectedAirport = nil }
                    } label: {
                        EGDSIcon("xmark", size: 8)
                            .foregroundStyle(Theme.onSurfaceVariant)
                            .frame(width: 18, height: 18)
                            .background(Color(red: 230 / 255, green: 227 / 255, blue: 227 / 255), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear selected airport")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var airportSuggestions: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if draft.step == .origin {
                    sectionTitle("My current location")
                    airportRow(Self.sanAntonio, currentLocation: true)
                        .padding(.vertical, 8)

                    sectionTitle("Suggested")
                        .padding(.top, 20)
                    airportRow(Self.houstonAll, indented: false)
                    airportRow(Self.intercontinental, indented: true)
                    airportRow(.hobby, indented: true)
                    airportRow(Self.collegeStation, indented: false)
                } else {
                    sectionTitle("Suggested")
                    airportRow(Self.tampaAll, indented: false)
                    airportRow(.tampa, indented: true)
                    airportRow(Self.stPete, indented: true)
                    airportRow(Self.orlando, indented: false)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.centra(size: 14))
            .foregroundStyle(Theme.onSurfaceVariant)
            .frame(height: 21)
    }

    private func airportRow(
        _ airport: FlightAirport,
        currentLocation: Bool = false,
        indented: Bool = false
    ) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(Theme.fade) { draft.selectedAirport = airport }
        } label: {
            HStack(spacing: 16) {
                airportArtwork(airport, currentLocation: currentLocation)

                VStack(alignment: .leading, spacing: 4) {
                    Text(airport.displayName)
                        .font(.centra(size: 14, weight: .medium))
                        .tracking(-0.14)
                        .foregroundStyle(Theme.figmaInk)
                        .lineLimit(1)
                    Text(airport.subtitle)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, indented ? 48 : 0)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(airport.displayName), \(airport.subtitle)")
        .accessibilityAddTraits(draft.selectedAirport == airport ? .isSelected : [])
    }

    @ViewBuilder
    private func airportArtwork(_ airport: FlightAirport, currentLocation: Bool) -> some View {
        switch airport.artwork {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .icon(let name):
            EGDSIcon(currentLocation ? "mappin" : name, size: 23)
                .foregroundStyle(Theme.ink)
                .frame(width: 48, height: 48)
                .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var closeButton: some View {
        Button {
            Haptics.impact(.light)
            dismiss()
        } label: {
            EGDSIcon("xmark", size: 18)
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                .shadow(color: Theme.ink.opacity(0.08), radius: 16, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close flight search")
    }

    private var forwardButton: some View {
        Button {
            Haptics.impact(.medium)
            if draft.advance() {
                submit()
            }
        } label: {
            EGDSIcon("arrow.right", size: 20)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.ink, in: Circle())
                .shadow(color: Theme.ink.opacity(0.24), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!draft.canAdvance || submitting)
        .opacity(draft.canAdvance ? 1 : 0.35)
        .accessibilityLabel(draft.step == .origin ? "Continue to destination" : "Search flights")
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickAction(icon: "plus", label: nil, selected: false)
                quickAction(
                    icon: "airplane.departure",
                    label: draft.origin.map { "From \($0.code)" } ?? "Add from",
                    selected: draft.step == .origin
                ) {
                    withAnimation(Theme.fade) { draft.step = .origin }
                }
                quickAction(
                    icon: "airplane.arrival",
                    label: draft.destination.map { "To \($0.code)" } ?? "Add to",
                    selected: draft.step == .destination
                ) {
                    withAnimation(Theme.fade) { draft.step = .destination }
                }
                quickAction(
                    icon: "calendar",
                    label: draft.dateRangeLabel ?? "Add dates",
                    selected: draft.step == .dates
                ) {
                    withAnimation(Theme.fade) { draft.step = .dates }
                }
                quickAction(
                    icon: "person.2",
                    label: draft.travelerLabel,
                    selected: draft.step == .travelers
                ) {
                    withAnimation(Theme.fade) { draft.step = .travelers }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 4)
        }
    }

    private func quickAction(
        icon: String,
        label: String?,
        selected: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 10) {
                EGDSIcon(icon, size: 18)
                if let label {
                    Text(label)
                        .font(.centra(size: 14))
                }
            }
            .foregroundStyle(Theme.figmaInk)
            .padding(.horizontal, label == nil ? 16 : 20)
            .frame(height: 50)
            .background(selected ? Color.white.opacity(0.7) : Theme.figmaChipFill, in: Capsule())
            .overlay {
                if selected {
                    Capsule().strokeBorder(.white, lineWidth: 1)
                }
            }
            .shadow(color: selected ? Theme.ink.opacity(0.08) : .clear, radius: 16, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "Add flight detail")
    }

    private func submit() {
        guard let query = draft.submissionQuery else { return }
        submitting = true
        store.composerText = query
        dismiss()
        Task { await store.submitComposer() }
    }

    private static let sanAntonio = FlightAirport(
        code: "SAT",
        name: "San Antonio Intl.",
        city: "San Antonio",
        subtitle: "Airport in Texas, US",
        artwork: .icon("mappin")
    )
    private static let houstonAll = FlightAirport(
        code: "HOU",
        name: "All airports",
        city: "Houston",
        subtitle: "City in Texas, US",
        artwork: .asset("mexico-houston-home")
    )
    private static let intercontinental = FlightAirport(
        code: "IAH",
        name: "George Bush Intercontinental",
        city: "Houston",
        subtitle: "Airport in Texas, US",
        artwork: .icon("airplane")
    )
    private static let collegeStation = FlightAirport(
        code: "CLL",
        name: "Easterwood",
        city: "College Station",
        subtitle: "Airport in Texas, US",
        artwork: .icon("airplane")
    )
    private static let tampaAll = FlightAirport(
        code: "TPA",
        name: "All airports",
        city: "Tampa",
        subtitle: "City in Florida, US",
        artwork: .asset("tampa-1")
    )
    private static let stPete = FlightAirport(
        code: "PIE",
        name: "St. Pete-Clearwater Intl.",
        city: "St. Petersburg",
        subtitle: "Airport in Florida, US",
        artwork: .icon("airplane")
    )
    private static let orlando = FlightAirport(
        code: "MCO",
        name: "Orlando International",
        city: "Orlando",
        subtitle: "Airport in Florida, US",
        artwork: .icon("airplane")
    )
}
