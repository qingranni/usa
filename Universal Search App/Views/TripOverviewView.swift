import SwiftUI

struct TripOverviewView: View {
    @Bindable var store: AppStore
    let metrics: Metrics
    @State private var generatedClusters: [TripOverviewCluster] = []

    private var b: CGFloat {
        store.revealingThreadID != nil ? clamp(store.reveal - 1, 0, 1) : 1
    }

    private var activityRows: [ActivityHistoryRow] {
        store.tripSections.reversed()
            .flatMap { section in section.entries.map { (section, $0) } }
            .enumerated()
            .map { index, pair in
                ActivityHistoryRow(
                    entry: pair.1,
                    threadID: pair.0.threadId,
                    parentTitle: pair.0.title,
                    kind: pair.0.kind.rawValue,
                    recencyIndex: index
                )
            }
    }

    private var clusterItems: [TripOverviewClusterItem] {
        activityRows.enumerated().map { index, row in
            TripOverviewClusterItem(
                id: row.id,
                title: row.title,
                label: row.entry.label,
                kind: row.kind,
                parentTitle: row.parentTitle,
                entryType: row.entryType,
                recencyIndex: index
            )
        }
    }

    private var clusterSignature: String {
        clusterItems.map {
            "\($0.id)|\($0.title)|\($0.label)|\($0.kind)|\($0.entryType)"
        }.joined(separator: "\n")
    }

    private var resolvedClusters: [ResolvedActivityCluster] {
        let items = clusterItems
        guard items.count > 3 else { return [] }
        let expectedIDs = Set(items.map(\.id))
        let generatedIDs = generatedClusters.flatMap(\.itemIDs)
        let validGenerated = (2...4).contains(generatedClusters.count)
            && generatedIDs.count == expectedIDs.count
            && Set(generatedIDs) == expectedIDs
        let clusters = validGenerated
            ? generatedClusters
            : DeterministicTripOverviewClusterer.clusters(for: items)
        let rowsByID = Dictionary(activityRows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resolved = clusters.compactMap { cluster -> ResolvedActivityCluster? in
            let rows = cluster.itemIDs.compactMap { rowsByID[$0] }
            guard !rows.isEmpty else { return nil }
            return ResolvedActivityCluster(
                id: cluster.id,
                heading: cluster.heading,
                description: cluster.description,
                rows: rows
            )
        }
        // Pin the cluster holding the active view to the top, preserving the
        // recency order of the rest.
        guard let currentID = currentEntryID else { return resolved }
        let active = resolved.filter { $0.rows.contains { $0.entry.id == currentID } }
        let rest = resolved.filter { cluster in !active.contains { $0.id == cluster.id } }
        return active + rest
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy["trip.overviewHeading"])
                        .font(.centra(size: 32, weight: .medium))
                        .tracking(-0.32)
                        .foregroundStyle(Theme.ink)

                    if activityRows.count <= 3 {
                        flatActivityList
                            .padding(.top, 32)
                    } else {
                        VStack(alignment: .leading, spacing: 32) {
                            ForEach(resolvedClusters) { cluster in
                                activitySection(
                                    title: cluster.heading,
                                    description: cluster.description,
                                    rows: cluster.rows
                                )
                            }
                        }
                        .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, metrics.safeTop + 96)
                .padding(.bottom, 120)
            }
            .scrollDisabled(store.revealingThreadID != nil)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
        }
        .task(id: clusterSignature) {
            await refreshClusters()
        }
    }

    private var flatActivityList: some View {
        VStack(spacing: 8) {
            ForEach(activityRows) { row in
                historyRow(row)
                    .background(
                        Theme.cardItem,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
            }
        }
        .opacity(smoothstep(ramp(b, 0.82, 1)))
    }

    private func activitySection(
        title: String,
        description: String,
        rows: [ActivityHistoryRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.figmaInk)

                Text(description)
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.figmaInkMuted)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    historyRow(row)

                    if index < rows.count - 1 {
                        Divider()
                            .overlay(Theme.ink.opacity(0.08))
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                Theme.cardItem,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
        .opacity(smoothstep(ramp(b, 0.82, 1)))
    }

    private func refreshClusters() async {
        let items = clusterItems
        guard items.count > 3 else {
            generatedClusters = []
            return
        }
        generatedClusters = DeterministicTripOverviewClusterer.clusters(for: items)
        do {
            generatedClusters = try await EmbeddedLiveProviderFactory.tripOverviewClusterer()
                .cluster(items)
        } catch is CancellationError {
            return
        } catch {
            generatedClusters = DeterministicTripOverviewClusterer.clusters(for: items)
        }
    }

    private func historyRow(_ row: ActivityHistoryRow) -> some View {
        Button {
            if row.entry.type == .compare || row.entry.type == .conversation {
                store.openActivity(row.entry.id, in: row.threadID)
            } else {
                store.open(row.threadID)
            }
        } label: {
            historyRowContent(row)
        }
        .buttonStyle(.plain)
        .opacity(rowOpacity(row.entry, threadID: row.threadID))
        .scaleEffect(rowScale(row.entry, threadID: row.threadID))
        .allowsHitTesting(store.revealingThreadID == nil)
        .captureFrame { rect in
            if store.slotFrames[row.entry.id] != rect {
                store.slotFrames[row.entry.id] = rect
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteThread(row.threadID)
            } label: {
                Label {
                    Text(Copy["actions.removeFromTrip"])
                } icon: {
                    EGDSIcon("trash", size: 16)
                }
            }
        }
    }

    private func historyRowContent(_ row: ActivityHistoryRow) -> some View {
        HStack(spacing: 16) {
            TripRowArtwork(
                images: row.entry.images,
                isConversation: row.isConversation,
                isLogo: row.isLogo,
                fallbackAsset: "activity-mexico",
                // The current-view checkmark rides on the artwork (scrim + glyph)
                // rather than the trailing edge, so the title runs the full card.
                checkmarkSettled: isCurrentView(row) ? store.revealingThreadID == nil : nil
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(rowSubtitle(row))
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .contentShape(Rectangle())
    }

    /// The entry that is the active view: the one open behind the overview, or —
    /// once fully collapsed to the trip list (`teardown` clears `openThreadID`) —
    /// the last-viewed entry that "back" returns to.
    private var currentEntryID: String? {
        if let open = store.openEntryID { return open }
        guard let tid = store.lastOpenThreadID else { return nil }
        return store.lastOpenActivityID ?? "\(tid)-results"
    }

    /// The checkmark marks the active view — not every completed search.
    private func isCurrentView(_ row: ActivityHistoryRow) -> Bool {
        row.entry.id == currentEntryID
    }

    /// The active row is the canvas's morph destination, so its subtitle mirrors
    /// the collapsing card's heading ("Results" / "Comparing" / …) rather than
    /// the "Searching • time" cadence — otherwise the label pops on hand-off.
    private func rowSubtitle(_ row: ActivityHistoryRow) -> String {
        isCurrentView(row) ? entryHeading(row.entry) : row.subtitle
    }

    /// The heading the open canvas/card shows for an entry, mirrored by
    /// `OverviewCard`/`OverviewCardRow` during the morph.
    private func entryHeading(_ entry: TripEntry) -> String {
        switch entry.type {
        case .results: return Copy["overview.resultsHeading"]
        case .compare: return Copy["overview.comparingHeading"]
        case .map: return Copy["overview.exploringLabel"]
        case .conversation: return Copy["overview.conversationLabel"]
        }
    }

    private func isOpenEntry(_ entry: TripEntry, _ threadID: String) -> Bool {
        guard store.revealingThreadID == threadID else { return false }
        if let activityID = store.openActivityID {
            return entry.id == activityID
        }
        return entry.type == .results
    }

    private func rowOpacity(_ entry: TripEntry, threadID: String) -> Double {
        let curtain = store.revealingThreadID != nil
        if curtain && isOpenEntry(entry, threadID) { return 0 }
        return curtain ? Double(ramp(store.reveal, 1.55, 2.0)) : 1
    }

    private func rowScale(_ entry: TripEntry, threadID: String) -> CGFloat {
        let curtain = store.revealingThreadID != nil
        if curtain && isOpenEntry(entry, threadID) { return 1 }
        let appear = curtain ? Double(ramp(store.reveal, 1.55, 2.0)) : 1
        return lerp(0.97, 1, CGFloat(appear))
    }
}

/// Placeholder relative-time for a row, keyed off its recency position. The
/// narrative-mock data carries no real timestamps, so this synthesizes the
/// design's "5 mins ago / 3 hours ago / …" cadence deterministically.
private func relativeActivityTime(_ recencyIndex: Int) -> String {
    switch recencyIndex {
    case 0: return "Just now"
    case 1: return "5 mins ago"
    case 2: return "3 hours ago"
    case 3: return "Yesterday"
    case 4: return "2 days ago"
    case 5: return "Last week"
    default: return "A month ago"
    }
}

private struct ActivityHistoryRow: Identifiable {
    let entry: TripEntry
    let threadID: String
    let parentTitle: String
    let kind: String
    /// Zero is the newest row on the overview; drives the placeholder timestamp.
    let recencyIndex: Int

    var id: String { entry.id }
    var title: String { entry.title }
    /// "{activity type} • {relative time}", e.g. "Searching • 5 mins ago".
    var subtitle: String {
        let time = relativeActivityTime(recencyIndex)
        return time.isEmpty ? entry.label : "\(entry.label)  •  \(time)"
    }
    var image: String? { entry.images.first }
    var entryType: String {
        switch entry.type {
        case .results: return "results"
        case .compare: return "compare"
        case .map: return "map"
        case .conversation: return "conversation"
        }
    }
    var isConversation: Bool { entry.type == .map || entry.type == .conversation }
    var isLogo: Bool { entry.isLogo }
}

/// The "current view" checkmark, overlaid on the row's artwork: a 75% dark scrim
/// with a centered check. The morph-in card carries no checkmark, so on hand-off
/// the scrim would otherwise hard-cut in; it fades in (glyph scales up) once the
/// row settles onto the trip list (`settled` flips true when the curtain tears
/// down). Clipped to the artwork's rounded rect.
private struct CheckmarkOverlay: View {
    let settled: Bool
    @State private var shown = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.black.opacity(0.75))
            .overlay {
                EGDSIcon("checkmark", size: 20)
                    .foregroundStyle(.white)
                    .scaleEffect(shown ? 1 : 0.5)
            }
            .opacity(shown ? 1 : 0)
            .onAppear { shown = settled }
            .onChange(of: settled) { _, now in
                withAnimation(now ? .spring(response: 0.4, dampingFraction: 0.6) : nil) {
                    shown = now
                }
            }
    }
}

private struct ResolvedActivityCluster: Identifiable {
    let id: String
    let heading: String
    let description: String
    let rows: [ActivityHistoryRow]
}

struct OverviewCardRow: View {
    let heading: String
    let title: String
    let images: [String]
    var isConvo: Bool = false
    var isLogo: Bool = false
    var fallbackAsset: String = "activity-mexico"

    var body: some View {
        HStack(spacing: 16) {
            TripRowArtwork(
                images: images,
                isConversation: isConvo,
                isLogo: isLogo,
                fallbackAsset: fallbackAsset
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(heading)
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(height: 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct TripRowArtwork: View {
    let images: [String]
    let isConversation: Bool
    let isLogo: Bool
    let fallbackAsset: String
    /// `nil` = no checkmark; otherwise the settle state that drives its fade-in.
    var checkmarkSettled: Bool? = nil

    var body: some View {
        Group {
            if isConversation {
                EGDSIcon("forum", size: 24)
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 56, height: 56)
                    .background(
                        Theme.ink.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            } else if isLogo {
                PhotoFan(images: images, size: 42, isLogo: true)
            } else {
                RemoteOrLocalImage(urlString: images.first ?? fallbackAsset)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.black.opacity(0.05))
                    }
            }
        }
        .frame(width: 56, height: 56)
        .overlay {
            if let settled = checkmarkSettled {
                CheckmarkOverlay(settled: settled)
            }
        }
    }
}
