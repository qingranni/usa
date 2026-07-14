//
//  ChipComposerField.swift
//  Universal Search App
//
//  The inline-chip composer ported from TravelAI's `ConversationalBarView`
//  search overview. You type a natural-language query and the parser turns
//  recognized destinations / dates / guests into active chips embedded inline in
//  the text. Ghost-text autocomplete previews completions (tab / swipe-right to
//  accept, tap to open a context menu), animated filter pills surface parser
//  predictions and open filter sheets, and accepted matches morph the source
//  text into a chip.
//
//  It owns the chip state internally and publishes a `chipSummary` (the chip
//  labels folded into a string) so the host composer can append it to the sent
//  query. No `matchedGeometryEffect` / `navigationTransition` (see MORPHS.md);
//  filter detail is presented as plain sheets.
//

import SwiftUI

struct ChipComposerField: View {
    /// Raw typed text (chips are tracked separately).
    @Binding var text: String
    /// Chip labels folded into a string, published for the host to append to the
    /// submitted query.
    @Binding var chipSummary: String
    /// Fired on return / submit from the editor.
    var onSubmit: () -> Void = {}
    /// Autofocus the field when it appears.
    var autoFocus: Bool = true
    /// Delay before requesting first responder. Kept long enough that the field
    /// is on-screen and laid out (focusing mid-mount silently fails), but short
    /// enough that the keyboard rises *during* the composer's entrance morph so
    /// the two read as one motion rather than a morph followed by a slide.
    var focusDelay: TimeInterval = 0.4
    /// Vertical space inserted between the input and the filter pills. The host
    /// composer drives this so the pills ride the top of the keyboard while the
    /// gap grows the docked sheet toward the full takeover.
    var middleGap: CGFloat = 12
    /// Lets a bounded host use the middle region as flexible space. As the
    /// keyboard grows, this space condenses while the controls remain anchored
    /// just above it.
    var flexesMiddleGap: Bool = false
    /// When true (the home entrance), the filter pills play a one-shot staggered
    /// rise/fade-in after the composer's grow morph settles. Off elsewhere.
    var playEntrance: Bool = false
    /// Uses the homepage empty state from Figma: a fixed destination prompt and
    /// a centered, horizontally scrollable trip-starter carousel. Once the user
    /// enters text, the normal parser and filter controls take over.
    var showsHomeSuggestions: Bool = false
    /// 0 keeps the docked/medium composer exactly as-is. 1 applies the full
    /// takeover treatment from Figma; fractional values support the drag scrub.
    var fullViewProgress: CGFloat = 0

    private let searchCategory = "Stays"
    private let ink = Color(hex: "0c0e1c")

    private var fullProgress: CGFloat {
        clamp(fullViewProgress, 0, 1)
    }

    private var pillForeground: Color {
        Color.mix(ink.opacity(0.9), Theme.figmaInk, fullProgress)
    }

    private var pillBackground: Color {
        Color.mix(ink.opacity(0.03), Theme.figmaChipFill, fullProgress)
    }

    private var pillHorizontalPadding: CGFloat {
        lerp(24, 16, fullProgress)
    }

    private var pillFontWeight: Font.Weight {
        fullProgress > 0.5 ? .regular : .medium
    }

    // MARK: - Chip state

    @State private var selectedDestination: String? = nil
    @State private var selectedCheckIn: Date? = nil
    @State private var selectedCheckOut: Date? = nil
    @State private var selectedCalendarDates: Set<DateComponents> = []
    @State private var adultCount: Int = 0
    @State private var childrenCount: Int = 0
    @State private var infantCount: Int = 0

    // MARK: - Editor / parser state

    /// Drives the staggered filter-pill entrance (see `playEntrance`). Starts
    /// false so the pills are hidden, then flips true to rise/fade them in.
    @State private var pillsRevealed = false
    @State private var isInputFocused = false
    @State private var destinationQuery = ""
    @State private var activeFilterChip: String? = nil
    @State private var shouldChainFilters = false

    @State private var pendingMatch: ParsedMatch? = nil
    @State private var pendingPredictions: [ParsedMatch] = []
    @State private var highlightNSRange: NSRange? = nil
    @State private var parserDebounce: DispatchWorkItem? = nil
    @State private var chipTransition: ChipTransitionInfo? = nil

    @State private var ghostSuggestion = ""
    @State private var rotatingGhostIndex = 0
    @State private var rotatingGhostTask: Task<Void, Never>? = nil
    @State private var activeGhostCategory: GhostMenuCategory = .none
    @State private var ghostOverlayController = WindowOverlayController()
    @State private var ghostMenuState = GhostMenuState()
    @State private var showGhostContextMenu = false
    @State private var selectedHomeSuggestion: Int? = 1

    private let homeSuggestionCount = 3
    private let homeSuggestionSpacing: CGFloat = 8
    private let homeSuggestionCarouselBleed: CGFloat = 32.5
    private let homeSuggestionRotationDelay: Duration = .seconds(3)

    // MARK: - Derived

    private var searchInputBarChips: [ChipToken] {
        var tokens: [ChipToken] = []
        if selectedDestination != nil {
            tokens.append(ChipToken(id: "Destination", icon: "mappin", label: shortDestinationName))
        }
        if selectedCheckIn != nil {
            tokens.append(ChipToken(id: "Dates", icon: "calendar", label: shortDateLabel))
        }
        if totalGuests > 0 {
            tokens.append(ChipToken(id: "Guests", icon: "person", label: shortGuestLabel))
        }
        return tokens
    }

    private var searchHasChips: Bool {
        selectedDestination != nil || selectedCheckIn != nil || totalGuests > 0
    }

    private var searchInputIsEmpty: Bool {
        text.isEmpty && searchInputBarChips.isEmpty
    }

    private var showsHomeDefaultState: Bool {
        showsHomeSuggestions && searchInputIsEmpty
    }

    private var composedSummary: String {
        searchInputBarChips.map(\.label).joined(separator: " ")
    }

    private var shortDestinationName: String {
        selectedDestination?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private var totalGuests: Int { adultCount + childrenCount + infantCount }

    private var shortGuestLabel: String {
        totalGuests == 1 ? "1 guest" : "\(totalGuests) guests"
    }

    private var shortDateLabel: String {
        guard let checkIn = selectedCheckIn else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        if let checkOut = selectedCheckOut {
            return "\(fmt.string(from: checkIn)) – \(fmt.string(from: checkOut))"
        }
        return fmt.string(from: checkIn)
    }

    private var currentFilterChips: [String] {
        ChipComposerCatalog.quickActionFilterChips[searchCategory] ?? ["Destination", "Dates", "Guests"]
    }

    private var predictionState: ComposerPredictionState {
        ComposerPredictionEngine.state(
            for: ComposerPredictionContext(
                text: text,
                hasDestination: selectedDestination != nil,
                hasDates: selectedCheckIn != nil,
                hasGuests: totalGuests > 0,
                hasStructuredMatches: !pendingPredictions.isEmpty
            )
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputArea
                // The shared full composer keeps the query at x=36. The newer
                // home frame uses the card's 32.5pt gutter directly.
                .padding(.leading, showsHomeSuggestions ? 0 : 8 * fullProgress)

            if showsHomeDefaultState {
                Color.clear.frame(height: 174.5)
                homeSuggestionCarousel
                    .transition(.opacity)
                Color.clear.frame(height: 30.5)
            } else if flexesMiddleGap {
                Spacer(minLength: 12)
            } else {
                Color.clear.frame(height: max(12, middleGap))
            }

            // Keep one stable action row across both states. Removing the home
            // carousel shortens the content above it by 89pt, so the mic/submit
            // control lifts in lockstep with the white card instead of being
            // replaced at a new position.
            HStack {
                Spacer(minLength: 0)
                trailingActionButton
            }
            .padding(.trailing, showsHomeSuggestions ? 0 : 8 * fullProgress)
            .padding(.bottom, showsHomeDefaultState ? 0 : lerp(12, 56, fullProgress))

            if !showsHomeDefaultState {
                filterPills
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.42, dampingFraction: 0.9),
            value: showsHomeDefaultState
        )
        .onAppear {
            // Focus AFTER the composer's entrance morph settles. Requesting first
            // responder during the grow (while the field is still transparent /
            // mid-layout) silently fails and the keyboard never comes up, so we
            // wait for the field to be on-screen and stable.
            if autoFocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) {
                    isInputFocused = true
                }
            }
            // Home entrance: hold the pills hidden until the grow morph and the
            // sheet-wide fade have settled, then flip `pillsRevealed` to run the
            // per-index staggered rise/fade below. Elsewhere show them at once.
            if playEntrance {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                    pillsRevealed = true
                }
            } else {
                pillsRevealed = true
            }
            startRotatingGhostText()
        }
        .onDisappear {
            stopRotatingGhostText()
        }
        .onChange(of: text) { _, newValue in
            updateGhostText()
            handleInputTextChange(newValue)
        }
        .onChange(of: composedSummary) { _, newValue in
            chipSummary = newValue
            updateGhostText()
        }
        .sheet(isPresented: filterSheetPresented) {
            filterOverlayContent
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(.white)
        }
    }

    // MARK: - Input area

    private var inputArea: some View {
        // Just the inline-chip editor; the mic/send button and the smart filter
        // pills sit together at the bottom of the sheet (see `body`), so the
        // input is free to fill the width up top.
        editor
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = true }
        .frame(minHeight: 50)
    }

    private var editor: some View {
        InlineChipTextEditor(
            text: $text,
            chips: searchInputBarChips,
            chipRenderMode: .inline,
            placeholder: showsHomeSuggestions ? "Where do you want to go?" : "",
            isFocused: $isInputFocused,
            highlightRange: highlightNSRange,
            fontName: "CentraNo2-Medium",
            fontSize: 20,
            lineHeight: lerp(30, 40, fullProgress),
            lineSpacing: 8,
            ghostText: ghostSuggestion,
            onAcceptGhostText: acceptGhostText,
            onGhostTextTap: handleGhostTextTap,
            onChipTap: { chipId in
                shouldChainFilters = false
                openFilter(chipId)
            },
            onChipDelete: deleteChip,
            onSubmit: onSubmit,
            chipTransition: chipTransition
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var trailingActionButton: some View {
        let size = lerp(50, 52, fullProgress)

        if searchInputIsEmpty {
            Button {
                Haptics.impact(.light)
                isInputFocused = true
            } label: {
                EGDSIcon(showsHomeSuggestions ? "mic" : "mic.fill", size: 20)
                    .foregroundStyle(showsHomeSuggestions ? Theme.figmaInk : ink.opacity(0.6))
                    .frame(width: size, height: size)
                    .background {
                        Circle()
                            .fill(
                                showsHomeSuggestions
                                    ? Theme.cardItem.opacity(0.75)
                                    : Color(red: 241 / 255, green: 241 / 255, blue: 241 / 255)
                                        .opacity(0.5 * Double(fullProgress))
                            )
                    }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.impact(.medium)
                onSubmit()
            } label: {
                EGDSIcon("arrow.right", size: 20)
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background {
                        ZStack {
                            Circle()
                                .fill(ink)
                                .glassEffect(in: .circle)
                                .opacity(Double(1 - fullProgress))
                            Circle()
                                .fill(Theme.figmaInk)
                                .opacity(Double(fullProgress))
                        }
                    }
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    private func deleteChip(_ chipId: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            switch chipId {
            case "Destination":
                selectedDestination = nil
            case "Dates":
                selectedCheckIn = nil
                selectedCheckOut = nil
                selectedCalendarDates = []
            case "Guests":
                adultCount = 0
                childrenCount = 0
                infantCount = 0
            default:
                break
            }
        }
    }

    // MARK: - Home trip starters

    private var homeSuggestionCarousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: homeSuggestionSpacing) {
                homeSuggestionCard(
                    id: 0,
                    asset: "composer-building-suggestion",
                    artworkSize: CGSize(width: 128, height: 128),
                    artworkOffset: CGSize(width: 241, height: -1)
                )
                homeSuggestionCard(
                    id: 1,
                    asset: "composer-trip-suggestion",
                    artworkSize: CGSize(width: 211, height: 170),
                    artworkOffset: CGSize(width: 210.36, height: -25.92)
                )
                homeSuggestionCard(
                    id: 2,
                    asset: "composer-trip-suggestion",
                    artworkSize: CGSize(width: 211, height: 170),
                    artworkOffset: CGSize(width: 211, height: -25)
                )
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: $selectedHomeSuggestion, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        // The field itself sits inside the home card's 32.5pt gutter. Let only
        // the carousel bleed back across that gutter, then restore it as scroll
        // content margin. A centered 337pt card therefore leaves 24.5pt of each
        // neighboring card visible as a swipe affordance.
        .contentMargins(.horizontal, homeSuggestionCarouselBleed, for: .scrollContent)
        .padding(.horizontal, -homeSuggestionCarouselBleed)
        .frame(height: 106)
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: homeSuggestionRotationDelay)
                } catch {
                    return
                }

                guard showsHomeDefaultState else { return }
                withAnimation(.easeInOut(duration: 0.55)) {
                    let currentSuggestion = selectedHomeSuggestion ?? 0
                    selectedHomeSuggestion = (currentSuggestion + 1) % homeSuggestionCount
                }
            }
        }
    }

    private func homeSuggestionCard(
        id: Int,
        asset: String,
        artworkSize: CGSize,
        artworkOffset: CGSize
    ) -> some View {
        Button {
            Haptics.impact(.light)
            text = "Weekend getaway near me"
            isInputFocused = true
        } label: {
            ZStack(alignment: .topLeading) {
                Theme.cardItem

                homeSuggestionArtwork(
                    asset,
                    size: artworkSize,
                    offset: artworkOffset
                )
            }
            .frame(width: 337, height: 106)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("“Weekend getaway near me”")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(ink)
                    Text("Plan a new trip")
                        .font(.centra(size: 16))
                        .foregroundStyle(ink.opacity(0.5))
                }
                .lineLimit(1)
                .padding(.leading, 32)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .id(id)
    }

    @ViewBuilder
    private func homeSuggestionArtwork(
        _ asset: String,
        size: CGSize,
        offset: CGSize
    ) -> some View {
        if asset == "composer-trip-suggestion" {
            // Match Figma's crop: a 252pt square image inside a 211×170 window.
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 252, height: 250)
                .offset(x: -18.4, y: -41.4)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .offset(x: offset.width, y: offset.height)
        } else {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .offset(x: offset.width, y: offset.height)
        }
    }

    // MARK: - Filter pills

    private var filterPills: some View {
        let chips = currentFilterChips.filter { chip in
            if (chip == "Destination" || chip == "From"), selectedDestination != nil { return false }
            if chip == "Dates", selectedCheckIn != nil { return false }
            if chip == "Guests", totalGuests > 0 { return false }
            return true
        }
        let predictionsActive = !pendingPredictions.isEmpty
        let predictiveInputs = predictionState.actions

        return ScrollView(.horizontal) {
            HStack(spacing: lerp(12, 10, fullProgress)) {
                addPillButton(predictionsActive: predictionsActive)
                    .modifier(PillEntrance(revealed: pillsRevealed, index: 0))

                if predictionsActive {
                    ForEach(Array(pendingPredictions.enumerated()), id: \.offset) { index, prediction in
                        let preview = pendingMatchPreview(prediction)
                        Button {
                            applyParsedMatch(prediction)
                        } label: {
                            BlurTransitionText(text: preview.label)
                                .font(.centra(size: 14, weight: pillFontWeight))
                                .tracking(-0.14)
                                .foregroundStyle(
                                    Color.mix(ink, Theme.figmaInk, fullProgress)
                                )
                                .padding(.horizontal, pillHorizontalPadding)
                                .padding(.vertical, 16)
                                .background(
                                    Color.mix(
                                        Color(hex: "2F80ED").opacity(0.12),
                                        Theme.figmaChipFill,
                                        fullProgress
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.90).combined(with: .opacity)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.85).delay(0.1 * Double(index + 1))),
                                removal: .scale(scale: 0.90).combined(with: .opacity)
                            )
                        )
                    }
                } else if !predictiveInputs.isEmpty {
                    ForEach(predictiveInputs) { action in
                        Button {
                            Haptics.impact(.light)
                            applyPredictiveInput(action)
                        } label: {
                            BlurTransitionText(text: action.label)
                                .font(.centra(size: 14, weight: pillFontWeight))
                                .tracking(-0.14)
                                .foregroundStyle(pillForeground)
                                .padding(.horizontal, pillHorizontalPadding)
                                .padding(.vertical, 16)
                                .background(pillBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.90).combined(with: .opacity))
                        .modifier(PillEntrance(revealed: pillsRevealed, index: action.slot + 1))
                    }
                } else {
                    ForEach(Array(chips.enumerated()), id: \.element) { index, chip in
                        Button {
                            Haptics.impact(.light)
                            if !searchHasChips && text.isEmpty {
                                shouldChainFilters = true
                            }
                            openFilter(chip)
                        } label: {
                            HStack(spacing: lerp(12, 10, fullProgress)) {
                                filterIcon(filterChipIcon(chip))
                                    .font(.centra(size: 14, weight: .medium))
                                Text(chip)
                                    .font(.centra(size: 14, weight: pillFontWeight))
                                    .tracking(-0.14)
                            }
                            .foregroundStyle(pillForeground)
                            .padding(.horizontal, pillHorizontalPadding)
                            .padding(.vertical, 16)
                            .background(pillBackground)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.90).combined(with: .opacity))
                        .modifier(PillEntrance(revealed: pillsRevealed, index: index + 1))
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pendingMatch != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pendingPredictions.count)
    }

    private func applyPredictiveInput(_ action: ComposerPredictionAction) {
        switch action.kind {
        case .filter(let filter):
            shouldChainFilters = false
            openFilter(filter)
        case .append:
            text = ComposerPredictionEngine.applying(action, to: text)
            isInputFocused = true
        }
    }

    @ViewBuilder
    private func addPillButton(predictionsActive: Bool) -> some View {
        if predictionsActive, let match = pendingMatch {
            let entryPoint = predictionEntryPoint(for: match)
            Button {
                Haptics.impact(.light)
                shouldChainFilters = false
                openFilter(entryPoint.filter)
            } label: {
                Text(entryPoint.label)
                    .font(.centra(size: 14, weight: pillFontWeight))
                    .tracking(-0.14)
                    .foregroundStyle(pillForeground)
                    .padding(.horizontal, pillHorizontalPadding)
                    .padding(.vertical, 16)
                    .background {
                        ZStack {
                            GeometryReader { geo in
                                WaveGradientView(
                                    color1: Color(hex: "2F80ED"),
                                    color2: Color(hex: "0037D0"),
                                    color3: Color(hex: "D6E4FA"),
                                    opacity: 0.15
                                )
                                .distortionEffect(
                                    ShaderLibrary.pillRefraction(
                                        .float2(geo.size),
                                        .float(0.4)
                                    ),
                                    maxSampleOffset: CGSize(width: 30, height: 30)
                                )
                            }
                            .opacity(Double(1 - fullProgress))
                            pillBackground.opacity(Double(fullProgress))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32))
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.90).combined(with: .opacity))
        } else {
            EGDSIcon("plus", size: 15)
                .foregroundStyle(pillForeground)
                .padding(16)
                .background(pillBackground)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .transition(.scale(scale: 0.90).combined(with: .opacity))
        }
    }

    private func predictionEntryPoint(for match: ParsedMatch) -> (label: String, filter: String) {
        switch match.type {
        case .destination:
            return ("Add destination", "Destination")
        case .dates:
            return ("Add dates", "Dates")
        case .guests:
            return ("Add guests", "Guests")
        }
    }

    @ViewBuilder
    private func filterIcon(_ name: String) -> some View {
        switch name {
        case "mappin": Image("location-pin").renderingMode(.template)
        case "calendar": Image("calendar-icon").renderingMode(.template)
        case "person", "person.2": Image("guests-icon").renderingMode(.template)
        default: EGDSIcon(name, size: 17)
        }
    }

    private func filterChipIcon(_ chip: String) -> String {
        switch chip {
        case "Destination", "From", "To", "Pick-up", "Drop-off": return "mappin"
        case "Dates": return "calendar"
        case "Guests", "Travelers": return "person.2"
        default: return "plus"
        }
    }

    // MARK: - Filter sheets

    private var filterSheetPresented: Binding<Bool> {
        Binding(get: { activeFilterChip != nil }, set: { if !$0 { activeFilterChip = nil } })
    }

    private var filterOverlayContent: some View {
        VStack(spacing: 0) {
            searchFilterHeader(title: activeFilterChip ?? "")
                .padding(.top, 24)
                .padding(.bottom, 24)

            Group {
                if activeFilterChip == "Destination" || activeFilterChip == "From"
                    || activeFilterChip == "To" || activeFilterChip == "Pick-up"
                    || activeFilterChip == "Drop-off" {
                    searchDestinationBody
                } else if activeFilterChip == "Dates" {
                    searchDatesBody
                } else if activeFilterChip == "Guests" || activeFilterChip == "Travelers" {
                    searchGuestsBody
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: activeFilterChip)
        }
    }

    @State private var filterScrubberExpanded = false

    private func searchFilterHeader(title: String) -> some View {
        ZStack {
            FilterScrubberPill(
                currentFilter: title,
                filters: currentFilterChips,
                onSwitch: { newFilter in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        activeFilterChip = newFilter
                    }
                },
                isExpanded: $filterScrubberExpanded
            )

            if !filterScrubberExpanded {
                HStack {
                    Button { activeFilterChip = nil } label: {
                        headerActionIcon("xmark")
                    }
                    Spacer()
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: filterScrubberExpanded)
        .padding(.horizontal, 20)
    }

    private func headerActionIcon(_ system: String) -> some View {
        EGDSIcon(system, size: 14)
            .foregroundStyle(ink.opacity(0.6))
            .frame(width: 44, height: 44)
            .glassEffect(in: .circle)
    }

    private var filteredDestinations: [DestinationSuggestion] {
        let query = destinationQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return ChipComposerCatalog.destinationSuggestions }
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let matches = ChipComposerCatalog.destinationSuggestions.filter { suggestion in
            let n = suggestion.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let s = suggestion.subtitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return n.contains(normalizedQuery) || s.contains(normalizedQuery)
        }
        return matches.sorted { a, b in
            let cityA = a.name.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? a.name
            let cityB = b.name.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? b.name
            let normA = cityA.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normB = cityB.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let aPrefixed = normA.hasPrefix(normalizedQuery)
            let bPrefixed = normB.hasPrefix(normalizedQuery)
            if aPrefixed != bPrefixed { return aPrefixed }
            return a.name < b.name
        }
    }

    private var searchDestinationBody: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(filteredDestinations) { suggestion in
                        Button {
                            Haptics.impact(.heavy)
                            selectedDestination = suggestion.name
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                activeFilterChip = shouldChainFilters ? "Dates" : nil
                            }
                        } label: {
                            HStack(spacing: 16) {
                                AsyncImage(url: URL(string: suggestion.imageURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        ink.opacity(0.08)
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.name)
                                        .font(.centra(size: 16, weight: .medium))
                                        .foregroundStyle(Color(hex: "1b1b1f"))
                                    Text(suggestion.subtitle)
                                        .font(.centra(size: 14, weight: .regular))
                                        .foregroundStyle(Color(hex: "1b1b1f").opacity(0.75))
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) { destinationSearchBar }
    }

    private var destinationSearchBar: some View {
        HStack(spacing: 12) {
            EGDSIcon("magnifyingglass", size: 18)
                .foregroundStyle(ink.opacity(0.5))
            TextField("Search destinations...", text: $destinationQuery)
                .font(.centra(size: 18, weight: .regular))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(minHeight: 56)
        .glassEffect(in: .rect(cornerRadius: 42))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var searchDatesBody: some View {
        VStack(spacing: 16) {
            MultiDatePicker("", selection: $selectedCalendarDates, in: Date()...)
                .tint(ink)
                .padding(.horizontal, 20)
                .onChange(of: selectedCalendarDates) { _, dates in
                    let calendar = Calendar.current
                    let sorted = dates.compactMap { calendar.date(from: $0) }.sorted()
                    selectedCheckIn = sorted.first
                    selectedCheckOut = sorted.count > 1 ? sorted.last : nil
                }
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            filterConfirmButton {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    activeFilterChip = shouldChainFilters ? "Guests" : nil
                }
            }
        }
    }

    private var searchGuestsBody: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                guestStepperRow(icon: "person.2", label: "Adults", subtitle: "18+ years", count: $adultCount)
                guestStepperRow(icon: "face.smiling", label: "Children", subtitle: "2-18 years", count: $childrenCount)
                guestStepperRow(icon: "bed.double", label: "Infants", subtitle: "0-2 years", count: $infantCount)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            filterConfirmButton { activeFilterChip = nil }
        }
    }

    private func guestStepperRow(icon: String, label: String, subtitle: String, count: Binding<Int>) -> some View {
        HStack {
            EGDSIcon(icon, size: 22)
                .foregroundStyle(Color(hex: "1b1b1f"))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "1b1b1f"))
                Text(subtitle)
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "1b1b1f").opacity(0.75))
            }
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if count.wrappedValue > 0 { count.wrappedValue -= 1 }
                } label: {
                    EGDSIcon("minus", size: 15)
                        .foregroundStyle(ink.opacity(count.wrappedValue > 0 ? 0.9 : 0.25))
                        .frame(width: 38, height: 38)
                        .background(ink.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(count.wrappedValue == 0)

                Text("\(count.wrappedValue)")
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "1b1b1f"))
                    .frame(minWidth: 20)

                Button {
                    count.wrappedValue += 1
                } label: {
                    EGDSIcon("plus", size: 15)
                        .foregroundStyle(ink.opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(ink.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func filterConfirmButton(action: @escaping () -> Void = {}) -> some View {
        Button {
            Haptics.impact(.heavy)
            action()
        } label: {
            Text("Confirm")
                .font(.centra(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func openFilter(_ chip: String) {
        activeFilterChip = chip
    }

    // MARK: - Parser

    private func handleInputTextChange(_ newValue: String) {
        parserDebounce?.cancel()

        if let pending = pendingMatch, stillMatchesPending(newValue, pending: pending) {
            if newValue.hasSuffix(" ") {
                highlightNSRange = nil
            } else {
                let trailingWord = SearchInputParser.extractTrailingWord(from: newValue)
                if let wordRange = newValue.range(of: trailingWord, options: .backwards) {
                    let startOffset = newValue.distance(from: newValue.startIndex, to: wordRange.lowerBound)
                    highlightNSRange = NSRange(location: startOffset, length: trailingWord.count)
                }
            }
            let refreshed = SearchInputParser.parseAll(
                newValue,
                existingDestination: selectedDestination,
                existingDates: selectedCheckIn,
                existingGuests: totalGuests
            )
            if !refreshed.isEmpty { pendingPredictions = refreshed }
            return
        }

        pendingMatch = nil
        pendingPredictions = []
        highlightNSRange = nil

        guard ghostSuggestion.isEmpty else { return }

        let work = DispatchWorkItem {
            let predictions = SearchInputParser.parseAll(
                newValue,
                existingDestination: selectedDestination,
                existingDates: selectedCheckIn,
                existingGuests: totalGuests
            )
            if let match = predictions.first {
                let startOffset = newValue.distance(from: newValue.startIndex, to: match.highlightRange.lowerBound)
                let length = newValue.distance(from: match.highlightRange.lowerBound, to: match.highlightRange.upperBound)
                highlightNSRange = NSRange(location: startOffset, length: length)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    pendingMatch = match
                    pendingPredictions = predictions
                }
                Haptics.impact(.soft)
            }
        }
        parserDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func stillMatchesPending(_ text: String, pending: ParsedMatch) -> Bool {
        let textNorm = SearchInputParser.normalize(text)
        switch pending.type {
        case .destination:
            guard let dest = pending.resolvedDestination else { return false }
            let cityName = dest.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? dest
            let countryName = dest.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces)
            let trailingWord = SearchInputParser.extractTrailingWord(from: text)
            guard !trailingWord.isEmpty else { return false }
            let wordNorm = SearchInputParser.normalize(trailingWord)
            for candidate in [cityName, countryName].compactMap({ $0 }) {
                let candidateNorm = SearchInputParser.normalize(candidate)
                if candidateNorm.hasPrefix(wordNorm) || candidateNorm == wordNorm { return true }
            }
            return false
        case .dates, .guests:
            let matchedNorm = SearchInputParser.normalize(pending.matchedText)
            return textNorm.contains(matchedNorm)
        }
    }

    private func applyParsedMatch(_ match: ParsedMatch) {
        shouldChainFilters = false
        Haptics.impact(.medium)
        let chipId: String
        switch match.type {
        case .destination: chipId = "Destination"
        case .dates: chipId = "Dates"
        case .guests: chipId = "Guests"
        }
        let sourceText = String(text[match.highlightRange])
        chipTransition = ChipTransitionInfo(chipId: chipId, sourceText: sourceText)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            switch match.type {
            case .destination:
                if let dest = match.resolvedDestination { selectedDestination = dest }
            case .dates:
                selectedCheckIn = match.resolvedCheckIn
                selectedCheckOut = match.resolvedCheckOut
                if let checkIn = match.resolvedCheckIn {
                    var comps = Set<DateComponents>()
                    let cal = Calendar.current
                    comps.insert(cal.dateComponents([.year, .month, .day], from: checkIn))
                    if let checkOut = match.resolvedCheckOut {
                        var d = checkIn
                        while d <= checkOut {
                            comps.insert(cal.dateComponents([.year, .month, .day], from: d))
                            d = cal.date(byAdding: .day, value: 1, to: d)!
                        }
                    }
                    selectedCalendarDates = comps
                }
            case .guests:
                if let a = match.resolvedAdults { adultCount = a }
                if let c = match.resolvedChildren { childrenCount = c }
                if let i = match.resolvedInfants { infantCount = i }
            }

            text = String(text[text.startIndex..<match.range.lowerBound])
                .trimmingCharacters(in: .whitespaces)

            pendingMatch = nil
            pendingPredictions = []
            highlightNSRange = nil
        }
    }

    private func pendingMatchPreview(_ match: ParsedMatch) -> (icon: String, label: String) {
        if let override = match.displayLabel {
            return (predictionCategoryIcon(match), override)
        }
        switch match.type {
        case .destination:
            return ("mappin", match.resolvedDestination ?? match.matchedText)
        case .dates:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            if let checkIn = match.resolvedCheckIn {
                if let checkOut = match.resolvedCheckOut {
                    return ("calendar", "\(fmt.string(from: checkIn))-\(fmt.string(from: checkOut))")
                }
                return ("calendar", fmt.string(from: checkIn))
            }
            return ("calendar", match.matchedText)
        case .guests:
            let total = (match.resolvedAdults ?? 0) + (match.resolvedChildren ?? 0) + (match.resolvedInfants ?? 0)
            return ("person", total == 1 ? "1 guest" : "\(total) guests")
        }
    }

    private func predictionCategoryIcon(_ match: ParsedMatch) -> String {
        switch match.type {
        case .destination: return "mappin"
        case .dates: return "calendar"
        case .guests: return "person"
        }
    }

    // MARK: - Ghost text

    private typealias GhostCategory = GhostMenuCategory

    private static let ghostRotationInterval: UInt64 = 3_000_000_000

    private static let ghostPredictions: [(prefix: String, completion: String, category: GhostMenuCategory)] = [
        ("hotels in ", "Barcelona", .destination),
        ("flights to ", "Tokyo", .destination),
        ("vacation in ", "Santorini", .destination),
        ("getaway to ", "Bali", .destination),
        ("escape to ", "Lisbon", .destination),
        ("traveling to ", "Rome", .destination),
        ("road trip to ", "Cape Town", .destination),
        ("honeymoon in ", "Santorini", .destination),
        ("fly to ", "Tokyo", .destination),
        ("trip to ", "Rome", .destination),
        ("stay in ", "Miami", .destination),
        ("going to ", "Lisbon", .destination),
        ("heading to ", "Bali", .destination),
        ("weekend in ", "Amsterdam", .destination),
        ("visit ", "London", .destination),
        ("explore ", "Marrakech", .destination),
        ("near ", "Barcelona", .destination),
        ("in ", "Barcelona", .destination),
        ("to ", "Paris", .destination),
        ("checking in ", "Friday", .dates),
        ("starting ", "Monday", .dates),
        ("departing ", "Friday", .dates),
        ("leaving ", "Thursday", .dates),
        ("arriving ", "Monday", .dates),
        ("beginning of ", "July", .dates),
        ("next ", "weekend", .dates),
        ("this ", "weekend", .dates),
        ("from ", "Friday", .dates),
        ("for ", "week", .dates),
        ("over ", "weekend", .dates),
        ("late ", "August", .dates),
        ("early ", "September", .dates),
        ("mid ", "October", .dates),
        ("until ", "Sunday", .dates),
        ("group of ", "6", .guests),
        ("couple ", "getaway", .guests),
        ("family ", "trip", .guests),
        ("solo ", "traveler", .guests),
        ("with ", "kids", .guests),
        ("just ", "me", .guests),
        ("1 ", "guest", .guests),
        ("2 ", "adults", .guests),
        ("two ", "adults", .guests),
        ("3 ", "guests", .guests),
        ("three ", "adults", .guests),
        ("4 ", "people", .guests),
        ("5 ", "guests", .guests),
    ]

    private static let rotatingGhostSuggestions: [String] = ghostPredictions.map {
        $0.prefix + $0.completion
    }

    private var currentRotatingGhostSuggestion: String {
        guard !Self.rotatingGhostSuggestions.isEmpty else { return "" }
        return Self.rotatingGhostSuggestions[rotatingGhostIndex % Self.rotatingGhostSuggestions.count]
    }

    private func updateGhostText() {
        let lower = text.lowercased()
        guard !lower.isEmpty || !searchInputBarChips.isEmpty else {
            ghostSuggestion = showsHomeSuggestions ? "" : currentRotatingGhostSuggestion
            activeGhostCategory = .none
            return
        }
        guard searchInputBarChips.isEmpty else {
            ghostSuggestion = ""
            activeGhostCategory = .none
            return
        }
        guard lower.last == " " else {
            ghostSuggestion = ""
            activeGhostCategory = .none
            return
        }
        for prediction in Self.ghostPredictions {
            if lower.hasSuffix(prediction.prefix.lowercased()) {
                ghostSuggestion = prediction.completion
                activeGhostCategory = prediction.category
                return
            }
        }
        ghostSuggestion = ""
        activeGhostCategory = .none
    }

    private func startRotatingGhostText() {
        stopRotatingGhostText()
        updateGhostText()
        guard !showsHomeSuggestions else { return }

        rotatingGhostTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.ghostRotationInterval)
                guard !Task.isCancelled else { return }
                guard searchInputIsEmpty else { continue }

                withAnimation(.easeInOut(duration: 0.25)) {
                    rotatingGhostIndex = (rotatingGhostIndex + 1) % max(Self.rotatingGhostSuggestions.count, 1)
                    updateGhostText()
                }
            }
        }
    }

    private func stopRotatingGhostText() {
        rotatingGhostTask?.cancel()
        rotatingGhostTask = nil
    }

    private func handleGhostTextTap(_ windowPoint: CGPoint) {
        guard activeGhostCategory != .none else { return }
        ghostMenuState.category = activeGhostCategory
        ghostMenuState.anchorY = windowPoint.y
        showGhostContextMenu = true
        isInputFocused = false
        presentGhostOverlay()
    }

    private func acceptGhostText() {
        guard !ghostSuggestion.isEmpty else { return }
        let category = activeGhostCategory
        text += ghostSuggestion
        ghostSuggestion = ""
        activeGhostCategory = .none

        if category != .none {
            parserDebounce?.cancel()
            let fullText = text
            let predictions = SearchInputParser.parseAll(
                fullText,
                existingDestination: selectedDestination,
                existingDates: selectedCheckIn,
                existingGuests: totalGuests
            )
            if let match = predictions.first {
                withAnimation(.easeOut(duration: 0.3)) {
                    pendingMatch = match
                    pendingPredictions = predictions
                }
                let startOffset = fullText.distance(from: fullText.startIndex, to: match.highlightRange.lowerBound)
                let length = fullText.distance(from: match.highlightRange.lowerBound, to: match.highlightRange.upperBound)
                highlightNSRange = NSRange(location: startOffset, length: length)
                Haptics.impact(.soft)
            }
        }
    }

    // MARK: - Ghost overlay

    private func dismissGhostContextMenu() {
        showGhostContextMenu = false
        ghostMenuState.category = .none
        ghostOverlayController.dismiss()
        syncGhostMenuStateBack()
    }

    private func syncGhostMenuStateBack() {
        selectedCalendarDates = ghostMenuState.selectedCalendarDates
        selectedCheckIn = ghostMenuState.selectedCheckIn
        selectedCheckOut = ghostMenuState.selectedCheckOut
        adultCount = ghostMenuState.adultCount
        childrenCount = ghostMenuState.childrenCount
        infantCount = ghostMenuState.infantCount
    }

    private func presentGhostOverlay() {
        ghostMenuState.selectedCalendarDates = selectedCalendarDates
        ghostMenuState.selectedCheckIn = selectedCheckIn
        ghostMenuState.selectedCheckOut = selectedCheckOut
        ghostMenuState.adultCount = adultCount
        ghostMenuState.childrenCount = childrenCount
        ghostMenuState.infantCount = infantCount
        ghostMenuState.onSelectDestination = { name in
            shouldChainFilters = false
            selectedDestination = name
            dismissGhostContextMenu()
        }
        ghostMenuState.onDismiss = { dismissGhostContextMenu() }

        let destinations = filteredDestinations
        ghostOverlayController.show {
            GhostContextMenuWindow(state: ghostMenuState, filteredDestinations: destinations)
        }
    }
}

// MARK: - Staggered pill entrance

/// One-shot staggered rise/fade for the filter pills on the home entrance. Each
/// pill starts 10pt low and transparent, then springs to place on a per-index
/// delay so they cascade in left-to-right.
private struct PillEntrance: ViewModifier {
    let revealed: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 10)
            .animation(.spring(response: 0.38, dampingFraction: 0.85)
                .delay(Double(index) * 0.06), value: revealed)
    }
}

// MARK: - Blur transition text (prediction pill label swap)

private struct BlurTransitionText: View {
    let text: String
    @State private var displayedText: String = ""
    @State private var blurRadius: CGFloat = 0

    var body: some View {
        Text(text)
            .hidden()
            .overlay(alignment: .leading) {
                Text(displayedText)
                    .blur(radius: blurRadius)
                    .fixedSize()
            }
            .clipped()
            .onChange(of: text) { _, newValue in
                if displayedText.isEmpty {
                    displayedText = newValue
                    blurRadius = 6
                    withAnimation(.easeOut(duration: 0.35)) { blurRadius = 0 }
                } else {
                    withAnimation(.easeIn(duration: 0.15)) { blurRadius = 6 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        displayedText = newValue
                        withAnimation(.easeOut(duration: 0.25)) { blurRadius = 0 }
                    }
                }
            }
            .onAppear {
                displayedText = text
                blurRadius = 6
                withAnimation(.easeOut(duration: 0.35)) { blurRadius = 0 }
            }
    }
}
