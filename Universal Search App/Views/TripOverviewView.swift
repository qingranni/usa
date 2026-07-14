import SwiftUI

struct TripOverviewView: View {
    @Bindable var store: AppStore
    let metrics: Metrics

    private var b: CGFloat {
        store.revealingThreadID != nil ? clamp(store.reveal - 1, 0, 1) : 1
    }

    private var entries: [(entry: TripEntry, threadID: String)] {
        store.tripSections.flatMap { section in
            section.entries.map { ($0, section.threadId) }
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Journeys")
                        .font(.centra(size: 32, weight: .medium))
                        .tracking(-0.32)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 32)

                    journeyCarousel
                        .padding(.top, 24)

                    Text("Spring break planning")
                        .font(.centra(size: 20, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 32)
                        .padding(.top, 30)
                        .opacity(smoothstep(ramp(b, 0.82, 1)))

                    VStack(spacing: 6) {
                        ForEach(entries.indices, id: \.self) { index in
                            let item = entries[index]
                            entryCard(item.entry, threadId: item.threadID, index: index)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 21)
                }
                // Match the homepage: begin below the real status-bar safe area,
                // while preserving the Figma spacing beneath the floating nav.
                .padding(.top, metrics.safeTop + 96)
                .padding(.bottom, 120)
            }
            .scrollDisabled(store.revealingThreadID != nil)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var journeyCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                JourneyCard(
                    image: "journey-mallorca",
                    title: "Mallorca trip",
                    badge: "In 12 days",
                    avatars: ["journey-avatar-1", "journey-avatar-2"]
                )
                JourneyCard(image: "journey-denver", title: "Denver")
            }
            .padding(.horizontal, 31)
        }
        .scrollClipDisabled()
    }

    private func isOpenEntry(_ entry: TripEntry, _ threadId: String) -> Bool {
        guard store.revealingThreadID == threadId else { return false }
        if let aid = store.openActivityID { return entry.id == aid }
        return entry.type == .results
    }

    private func entryCard(_ entry: TripEntry, threadId: String, index: Int) -> some View {
        let isConvo = entry.type == .map
        let curtain = store.revealingThreadID != nil
        let isOpen = isOpenEntry(entry, threadId)
        let appear = curtain ? Double(ramp(store.reveal, 1.55, 2.0)) : 1
        let opacity = (curtain && isOpen) ? 0 : appear
        let scale = (curtain && isOpen) ? 1 : lerp(0.97, 1, CGFloat(appear))
        let fallback = index == 0 ? "activity-mexico" : "activity-cancun"

        return Button {
            if entry.type == .compare {
                store.openActivity(entry.id, in: threadId)
            } else {
                store.open(threadId)
            }
        } label: {
            OverviewCardRow(heading: entry.label, title: entry.title,
                            images: entry.images, isConvo: isConvo, isLogo: entry.isLogo,
                            fallbackAsset: fallback)
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .scaleEffect(scale)
        .allowsHitTesting(!curtain)
        .captureFrame { rect in
            if store.slotFrames[entry.id] != rect { store.slotFrames[entry.id] = rect }
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteThread(threadId)
            } label: {
                Label {
                    Text(Copy["actions.removeFromTrip"])
                } icon: {
                    EGDSIcon("trash", size: 16)
                }
            }
        }
    }
}

private struct JourneyCard: View {
    let image: String
    let title: String
    var badge: String? = nil
    var avatars: [String] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 260, height: 260)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.48),
                    .init(color: Theme.ink.opacity(0.75), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let badge {
                Text(badge)
                    .font(.centra(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                    .padding(.top, 27)
                    .padding(.leading, 27)
            }

            if !avatars.isEmpty {
                HStack(spacing: -5) {
                    ForEach(avatars, id: \.self) { avatar in
                        Image(avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.75))
                            .shadow(color: .black.opacity(0.5), radius: 5)
                    }
                }
                .padding(.leading, 29)
                .padding(.top, 173)
            }

            Text(title)
                .font(.centra(size: 32, weight: .medium))
                .tracking(-1.5)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, 28)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 22)
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.black.opacity(0.05))
        }
    }
}

struct OverviewCardRow: View {
    let heading: String
    let title: String
    let images: [String]
    var isConvo: Bool = false
    var isLogo: Bool = false
    var fallbackAsset: String = "activity-mexico"

    var body: some View {
        HStack(spacing: 20) {
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
                    .font(.centra(size: 16))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(height: 118)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardItem, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct TripRowArtwork: View {
    let images: [String]
    let isConversation: Bool
    let isLogo: Bool
    let fallbackAsset: String

    var body: some View {
        Group {
            if isConversation {
                ZStack {
                    Image("activity-conversation")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)

                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Theme.ink)
                                .frame(width: 4.5, height: 4.5)
                                .shadow(color: Theme.ink.opacity(0.25), radius: 2.5)
                        }
                    }
                }
            } else if isLogo {
                PhotoFan(images: images, size: 42, isLogo: true)
            } else {
                RemoteOrLocalImage(urlString: images.first ?? fallbackAsset)
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.black.opacity(0.05))
                    }
            }
        }
        .frame(width: 86, height: 86)
    }
}
