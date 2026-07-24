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
    /// When false, the field's own placeholder is suppressed — the host draws a
    /// single placeholder that scales continuously across the pill→docked→full
    /// morph, so there's no duplicate/stepped placeholder inside the field.
    var showsFieldPlaceholder: Bool = true

    // MARK: - Voice input

    /// Drives the in-place "Listening…" state: the host retracts the sheet to
    /// reveal the gold + waveform strip, and the field swaps its placeholder for
    /// "Listening…" and its mic for ✕/✓. Owned by the host so the sheet geometry
    /// can morph in lockstep — the editor keeps first responder throughout, so the
    /// keyboard never drops.
    var isListening: Bool = false
    /// Mic tapped in the empty state — the host enters the listening state.
    var onMicTap: () -> Void = {}
    /// ✕ tapped — discard and return to the resting composer.
    var onVoiceCancel: () -> Void = {}
    /// ✓ tapped — commit the mock transcript and return to the composer.
    var onVoiceConfirm: () -> Void = {}

    // MARK: - Add-image flow

    /// Owned by the host so it can render the add-image drawer in the beige area
    /// below the retracted card. nil = closed; `.menu` / `.photos` while open.
    var addImagePage: Binding<AddImageSheetPage?> = .constant(nil)
    /// Committed image selection; renders `AttachedImagesChip` above the input.
    var attachedImages: Binding<[String]> = .constant([])

    private let searchCategory = "Stays"
    private let ink = Color(hex: "0c0e1c")

    private var fullProgress: CGFloat {
        clamp(fullViewProgress, 0, 1)
    }

    /// The docked "Ask anything" bar: a simple single-line input with the plus and
    /// submit on one row and no smart chips. Dragging toward the full takeover
    /// (fullProgress → 1) crosses back into the rich search composer.
    private var isCollapsed: Bool { fullProgress < 0.5 }

    /// Smart chips / parser predictions belong to the expanded search state.
    /// Home mode also shows the chip row (plus + Add …) in the resting/empty
    /// state so the suggestion carousel and quick-add chips sit together by
    /// default (Figma node 1910:20928); elsewhere it stays typing-only.
    private var showsSmartChips: Bool {
        guard !isCollapsed else { return false }
        return showsHomeSuggestions || !showsHomeDefaultState
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

    /// Debounced predictive-input state driving the smart chip row. Recomputed a
    /// beat after typing settles (see `schedulePredictionUpdate`) so the chips
    /// don't reshuffle on every keystroke.
    @State private var predictionState: ComposerPredictionState = .defaults([])
    @State private var predictionDebounce: DispatchWorkItem? = nil

    @State private var ghostSuggestion = ""
    @State private var activeGhostCategory: GhostMenuCategory = .none
    @State private var ghostOverlayController = WindowOverlayController()
    @State private var ghostMenuState = GhostMenuState()
    @State private var showGhostContextMenu = false
    // Rendered as `homeSuggestionCopies` back-to-back copies of the 3 base cards
    // so auto-rotation can always glide *forward* into the next copy and then
    // silently rewind one set — an infinite carousel that never scrolls back to
    // reset. Selection starts on card 1 of the middle copy.
    @State private var selectedHomeSuggestion: Int? = ChipComposerField.homeSuggestionCount + 1

    private static let homeSuggestionCount = 3
    private let homeSuggestionCount = ChipComposerField.homeSuggestionCount
    private let homeSuggestionCopies = 3
    private let homeSuggestionSpacing: CGFloat = 8
    private let homeSuggestionCarouselBleed: CGFloat = 32.5
    private let homeSuggestionRotationDelay: Duration = .seconds(3)
    private let homeSuggestionRotationDuration: TimeInterval = 1.0

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
            tokens.append(ChipToken(id: "Guests", icon: "person.2", label: shortGuestLabel))
        }
        return tokens
    }

    private var searchHasChips: Bool {
        selectedDestination != nil || selectedCheckIn != nil || totalGuests > 0
    }

    private var searchInputIsEmpty: Bool {
        // Attached images count as content: they drop the home carousel and flip
        // the mic to the submit arrow (the composer reads as "filled").
        text.isEmpty && searchInputBarChips.isEmpty && attachedImages.wrappedValue.isEmpty
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

    /// Live (undebounced) predictive state for the current field contents. The
    /// debounced `predictionState` is set from this via `schedulePredictionUpdate`.
    private func currentPredictionState() -> ComposerPredictionState {
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

    /// Recompute the smart-chip row a beat after input settles. Structured
    /// matches (already debounced by the parser) take the row over immediately;
    /// everything else waits out `predictionSettleDelay` so the chips don't
    /// reshuffle on every keystroke.
    private func schedulePredictionUpdate() {
        predictionDebounce?.cancel()

        if !pendingPredictions.isEmpty {
            predictionState = .confirmations
            return
        }

        let work = DispatchWorkItem {
            predictionState = currentPredictionState()
        }
        predictionDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + predictionSettleDelay, execute: work)
    }

    /// Debounce windows. Kept equal so the parser's structured pills and the
    /// predictive chips land on the same beat rather than fighting each other.
    private let parserSettleDelay: TimeInterval = 0.45
    private let predictionSettleDelay: TimeInterval = 0.45

    /// The add-image drawer is open — the host has retracted the card, so the
    /// field shows only its placeholder: no carousel, action row, or filter pills.
    private var addImageActive: Bool { addImagePage.wrappedValue != nil }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !attachedImages.wrappedValue.isEmpty {
                AttachedImagesChip(images: attachedImages.wrappedValue) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        attachedImages.wrappedValue = []
                    }
                }
                .padding(.leading, showsHomeSuggestions ? 0 : 8 * fullProgress)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            inputArea
                // The shared full composer keeps the query at x=36. The newer
                // home frame uses the card's 32.5pt gutter directly.
                .padding(.leading, showsHomeSuggestions ? 0 : 8 * fullProgress)

            if isListening || addImageActive {
                // Listening / add-image both drop the carousel + controls so the
                // card shows only the placeholder above the retracted gap.
                Spacer(minLength: 0)
            } else if showsHomeDefaultState {
                // Flexible gaps spread editor → carousel → mic → chips down the
                // card and shrink to keep the chip row above the keyboard on
                // shorter viewports (Figma node 1910:20928). Fixed heights here
                // overflowed once the chip row was added.
                Spacer(minLength: 24)
                homeSuggestionCarousel
                    .transition(.opacity)
                // Keep the carousel + mic together as a pair; the greedy spacers
                // above and below the pair center it and drop the chip row to the
                // bottom.
                Color.clear.frame(height: 24)
            } else if flexesMiddleGap {
                Spacer(minLength: 12)
            } else {
                Color.clear.frame(height: max(12, middleGap))
            }

            // Keep one stable action row across both states. Removing the home
            // carousel shortens the content above it by 89pt, so the mic/submit
            // control lifts in lockstep with the white card instead of being
            // replaced at a new position.
            if !addImageActive {
                HStack(spacing: 12) {
                    if isListening {
                        Spacer(minLength: 0)
                        voiceCancelButton
                        voiceConfirmButton
                    } else {
                        // Collapsed, the plus rides the same line as submit (the smart
                        // chips row that normally carries the plus is hidden).
                        // Expanded, the plus moves back into the chips row below.
                        if !showsSmartChips && !showsHomeDefaultState { collapsedPlusButton }
                        Spacer(minLength: 0)
                        trailingActionButton
                    }
                }
                .padding(.trailing, showsHomeSuggestions ? 0 : 8 * fullProgress)
                .padding(.bottom, showsHomeDefaultState ? 0 : lerp(12, 56, fullProgress))
            }

            // Home resting state: the greedy top spacer above the carousel now
            // absorbs all the slack, dropping the carousel + mic pair to the
            // bottom of the white card. This fixed gap lands the mic row 32pt
            // above the card's bottom edge — the card ends `chipVerticalSpacing
            // + 2` (22pt) above the filter-pill row that rides the beige gap
            // below it, so 32 + 22 = 54pt sits between the mic row and pills.
            if showsHomeDefaultState && !isListening && !addImageActive {
                Color.clear.frame(height: 54)
            }

            if showsSmartChips && !isListening && !addImageActive {
                filterPills
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.42, dampingFraction: 0.9),
            value: showsHomeDefaultState
        )
        .animation(Theme.springSoft, value: isListening)
        .animation(Theme.springSoft, value: addImageActive)
        .onChange(of: addImagePage.wrappedValue) { _, page in
            // Drawer closed → bring the keyboard back (node 2583-17114).
            if page == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isInputFocused = true
                }
            }
        }
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
            updateGhostText()
            // Seed the resting chips immediately; later changes are debounced.
            predictionState = currentPredictionState()
        }
        .onChange(of: text) { _, newValue in
            updateGhostText()
            handleInputTextChange(newValue)
            schedulePredictionUpdate()
        }
        .onChange(of: composedSummary) { _, newValue in
            chipSummary = newValue
            updateGhostText()
            schedulePredictionUpdate()
        }
        .onChange(of: pendingPredictions.count) { _, _ in
            // Structured matches appearing/clearing flips which branch owns the
            // row; keep the predictive state in step with it.
            schedulePredictionUpdate()
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
        .onTapGesture { if !isListening { isInputFocused = true } }
        .frame(minHeight: 50)
        // While listening, an opaque "Listening…" label covers the editor (which
        // stays first responder underneath, so the keyboard never drops).
        .overlay(alignment: .topLeading) {
            if isListening {
                VoiceListeningLabel()
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white)
                    .transition(.opacity)
            }
        }
    }

    private var editor: some View {
        InlineChipTextEditor(
            text: $text,
            chips: searchInputBarChips,
            chipRenderMode: .inline,
            placeholder: showsHomeSuggestions ? Copy["search.placeholder"] : Copy["search.followUp"],
            showsPlaceholder: showsFieldPlaceholder,
            isFocused: $isInputFocused,
            highlightRange: highlightNSRange,
            fontName: "CentraNo2-Medium",
            fontSize: isCollapsed ? 16 : 20,
            lineHeight: isCollapsed ? 22 : lerp(30, 40, fullProgress),
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

    // Leading plus on the collapsed bar. Matches the trailing control's
    // 50pt circle and the light chip fill. Opens the add-image flow.
    private var collapsedPlusButton: some View {
        Button(action: openAddImageDrawer) {
            EGDSIcon("plus", size: 18)
                .foregroundStyle(ink.opacity(0.9))
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(Color(red: 241 / 255, green: 241 / 255, blue: 241 / 255).opacity(0.6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add-image flow

    /// Tapping `+` closes the keyboard and asks the host to open the add-image
    /// menu in the freed beige space. The host retracts the card and renders
    /// `AddImageMenuView`; the keyboard returns when the flow closes (`.onChange`).
    private func openAddImageDrawer() {
        Haptics.impact(.light)
        isInputFocused = false
        withAnimation(Theme.springSoft) { addImagePage.wrappedValue = .menu }
    }

    @ViewBuilder
    private var trailingActionButton: some View {
        let size = lerp(50, 52, fullProgress)

        if searchInputIsEmpty {
            Button {
                Haptics.impact(.light)
                // Empty composer → morph the composer into the listening state in
                // place. The host retracts the sheet and reveals the gold strip;
                // the editor keeps focus so the keyboard stays up.
                onMicTap()
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

    // Listening-state controls, shown in place of the mic: discard (light) and
    // confirm (dark), 52pt per Figma.
    private var voiceCancelButton: some View {
        Button(action: onVoiceCancel) {
            EGDSIcon("xmark", size: 20)
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 52, height: 52)
                .background(composerControlFill())
                .shadow(color: Theme.ink.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var voiceConfirmButton: some View {
        Button(action: onVoiceConfirm) {
            EGDSIcon("checkmark", size: 20)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.figmaInk))
                .shadow(color: Theme.ink.opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
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
                ForEach(0 ..< homeSuggestionCount * homeSuggestionCopies, id: \.self) { index in
                    let card = homeSuggestionCards[index % homeSuggestionCount]
                    homeSuggestionCard(
                        id: index,
                        asset: card.asset,
                        prompt: card.prompt,
                        subtitle: card.subtitle,
                        artworkSize: card.artworkSize,
                        artworkOffset: card.artworkOffset
                    )
                }
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
                let current = selectedHomeSuggestion ?? homeSuggestionCount
                let next = current + 1
                // Glide one card forward with the requested 0.75, 0, 0, 1 curve.
                withAnimation(.timingCurve(0.75, 0, 0, 1, duration: homeSuggestionRotationDuration)) {
                    selectedHomeSuggestion = next
                }
                // Once the glide lands in the final copy, wait for it to finish,
                // then silently rewind one full set. The rewound card is visually
                // identical, so the carousel keeps advancing forever without ever
                // scrolling backward to reset.
                if next >= homeSuggestionCount * (homeSuggestionCopies - 1) {
                    do {
                        try await Task.sleep(for: .seconds(homeSuggestionRotationDuration))
                    } catch {
                        return
                    }
                    guard showsHomeDefaultState else { return }
                    var silent = Transaction()
                    silent.disablesAnimations = true
                    withTransaction(silent) {
                        selectedHomeSuggestion = next - homeSuggestionCount
                    }
                }
            }
        }
    }

    private struct HomeSuggestionCardModel {
        let asset: String
        let prompt: String
        let subtitle: String
        let artworkSize: CGSize
        let artworkOffset: CGSize
    }

    private var homeSuggestionCards: [HomeSuggestionCardModel] {
        [
            HomeSuggestionCardModel(
                asset: "composer-trip-suggestion",
                prompt: Copy["home.suggestions.trip.prompt"],
                subtitle: Copy["home.suggestions.trip.subtitle"],
                artworkSize: CGSize(width: 155, height: 125),
                artworkOffset: CGSize(width: 216, height: -6)
            ),
            HomeSuggestionCardModel(
                asset: "composer-building-suggestion",
                prompt: Copy["home.suggestions.stay.prompt"],
                subtitle: Copy["home.suggestions.stay.subtitle"],
                artworkSize: CGSize(width: 128, height: 128),
                artworkOffset: CGSize(width: 241, height: -1)
            ),
            HomeSuggestionCardModel(
                asset: "composer-trip-suggestion",
                prompt: Copy["home.suggestions.escape.prompt"],
                subtitle: Copy["home.suggestions.escape.subtitle"],
                artworkSize: CGSize(width: 155, height: 125),
                artworkOffset: CGSize(width: 216, height: -6)
            ),
        ]
    }

    private func homeSuggestionCard(
        id: Int,
        asset: String,
        prompt: String,
        subtitle: String,
        artworkSize: CGSize,
        artworkOffset: CGSize
    ) -> some View {
        Button {
            Haptics.impact(.light)
            text = prompt
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
                    Text(prompt)
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(ink)
                    Text(subtitle)
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
            // Match Figma's crop (node 2358:26146): the ~square trip image is
            // scaled to 119.41%×146.96% of the artwork window and nudged up/left
            // by (-8.72%, -24.29%) so the plane sits centered within the window.
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 1.1941, height: size.height * 1.4696)
                .offset(x: size.width * -0.0872, y: size.height * -0.2429)
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
                            HStack(spacing: 10) {
                                EGDSIcon(preview.icon, size: 17)
                                BlurTransitionText(text: preview.label)
                            }
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
                        .transition(.chipAppear(index: index + 1))
                    }
                } else if !predictiveInputs.isEmpty {
                    ForEach(predictiveInputs) { action in
                        Button {
                            Haptics.impact(.light)
                            applyPredictiveInput(action)
                        } label: {
                            HStack(spacing: 10) {
                                if let icon = predictionActionIcon(action) {
                                    EGDSIcon(icon, size: 17)
                                }
                                BlurTransitionText(text: action.label)
                            }
                                .font(.centra(size: 14, weight: pillFontWeight))
                                .tracking(-0.14)
                                .foregroundStyle(pillForeground)
                                .padding(.horizontal, pillHorizontalPadding)
                                .padding(.vertical, 16)
                                .background(pillBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .transition(.chipAppear(index: action.slot + 1))
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
                                EGDSIcon(FilterChipIconName.forLabel(chip), size: 17)
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
                        .transition(.chipAppear(index: index + 1))
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
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: predictionState)
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
                HStack(spacing: 10) {
                    EGDSIcon(FilterChipIconName.forLabel(entryPoint.filter), size: 17)
                    Text(entryPoint.label)
                }
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
            .transition(.chipAppear(index: 0))
        } else {
            Button(action: openAddImageDrawer) {
                EGDSIcon("plus", size: 15)
                    .foregroundStyle(pillForeground)
                    .padding(16)
                    .background(pillBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
            }
            .buttonStyle(.plain)
            .transition(.chipAppear(index: 0))
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

    private func predictionActionIcon(_ action: ComposerPredictionAction) -> String? {
        guard case .filter(let filter) = action.kind else { return nil }
        return FilterChipIconName.forLabel(filter)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + parserSettleDelay, execute: work)
    }

    private func stillMatchesPending(_ text: String, pending: ParsedMatch) -> Bool {
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
            // The parser only recognizes dates/guests at the trailing edge of
            // the text, so the confirm pill is only relevant while that phrase
            // is still what's being typed. Defer to a re-parse rather than a
            // naive substring check — otherwise "for two" keeps offering
            // "2 guests" long after the user has typed past it
            // ("...for two adults and a place").
            let refreshed = SearchInputParser.parseAll(
                text,
                existingDestination: selectedDestination,
                existingDates: selectedCheckIn,
                existingGuests: totalGuests
            )
            return refreshed.contains { $0.type == pending.type }
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

    private func updateGhostText() {
        let lower = text.lowercased()
        guard !lower.isEmpty || !searchInputBarChips.isEmpty else {
            // Idle input shows the static "Ask anything" placeholder — no rotating
            // ghost suggestion. Typed-prefix autocomplete below still applies.
            ghostSuggestion = ""
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

/// One-shot staggered rise/blur/fade for the filter pills on the home entrance.
/// Each pill starts low, transparent, and softly blurred, then springs to place
/// on a per-index delay so they cascade in left-to-right — the same visual
/// language as `ChipAppear` below, which handles later content swaps.
private struct PillEntrance: ViewModifier {
    let revealed: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .blur(radius: revealed ? 0 : 6)
            .offset(y: revealed ? 0 : 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.88)
                .delay(Double(index) * 0.05), value: revealed)
    }
}

// MARK: - Chip appear transition

/// Blur + fade + slight rise applied to a whole chip as it enters or leaves the
/// row, with a small per-index delay so a fresh set staggers in rather than
/// popping all at once. Used for every smart-chip branch so predictions,
/// predictive inputs, and default filters all share one motion.
private struct ChipAppearModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    let scale: CGFloat
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: offsetY)
    }
}

private extension AnyTransition {
    static func chipAppear(index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ChipAppearModifier(blur: 6, opacity: 0, scale: 0.96, offsetY: 6),
                identity: ChipAppearModifier(blur: 0, opacity: 1, scale: 1, offsetY: 0)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.88).delay(Double(index) * 0.05)),
            removal: .modifier(
                active: ChipAppearModifier(blur: 4, opacity: 0, scale: 0.96, offsetY: 0),
                identity: ChipAppearModifier(blur: 0, opacity: 1, scale: 1, offsetY: 0)
            )
            .animation(.easeOut(duration: 0.16))
        )
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
