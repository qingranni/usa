import SwiftUI

/// ONE surface for the whole quick-answer → conversation life: the floating quick
/// answer, the composer expand, and every streamed reply all render here, so there
/// is never a view swap (which used to flash on the trip-entry promote). `presence`
/// morphs the frame from a resting bottom card (0) to the full conversation (1);
/// the content is the same `ConversationCanvasView` throughout, backed by
/// `store.quickConversation` (draft first, then the promoted activity).
struct QuickConversationView: View {
    @Bindable var store: AppStore
    let metrics: Metrics
    /// 0 = resting quick-answer card · 1 = full conversation surface.
    var presence: CGFloat

    /// The in-flight reply's stream, scoped to this conversation.
    private var streamingTurn: StreamingTurn? {
        store.streamingActivityID != nil && store.streamingActivityID == store.openActivityID
            ? store.streamingTurn : nil
    }

    var body: some View {
        let p = max(0, min(1, presence))
        let cardHeight = lerp(metrics.H * 0.55, metrics.H, p)
        let corner = lerp(48, 0, p)
        let topPad = lerp(40, metrics.safeTop + 96, p)
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.white)
                .frame(height: cardHeight)
                .shadow(color: .black.opacity(lerp(0.12, 0, p)), radius: 32, y: lerp(-12, 0, p))
                .overlay {
                    ScrollViewReader { proxy in
                        ScrollView {
                            if let conversation = store.quickConversation {
                                ConversationCanvasView(
                                    conversation: conversation,
                                    topPadding: topPad,
                                    streamingTurn: streamingTurn,
                                    reservedBottom: metrics.size.height * 0.9
                                )
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                        // Resting card is a static peek; only the expanded surface scrolls.
                        .scrollDisabled(p < 0.5)
                        .scrollDismissesKeyboard(.interactively)
                        // A fresh reply pins its question below the header, answer in view.
                        .onChange(of: store.conversationScrollToken) { _, _ in
                            guard let target = store.conversationScrollTarget else { return }
                            let headerFraction = min(0.32, (metrics.safeTop + 150) / metrics.H)
                            withAnimation(Theme.springMorph) {
                                proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: headerFraction))
                            }
                        }
                    }
                    .frame(height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
        }
        .frame(width: metrics.size.width, height: metrics.H, alignment: .bottom)
        // A white scrim + soft blur from the top down to ~24pt below the title and
        // controls, so scrolling copy dissolves into the header area instead of
        // colliding with it. Fades in with the expand (irrelevant on the card).
        .overlay(alignment: .top) {
            topScrim(height: metrics.safeTop + 76).opacity(p)
        }
        // Card at rest doesn't intercept touches (the dock pill drives compose);
        // the expanded surface takes over scrolling.
        .allowsHitTesting(p > 0.5)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
        .animation(Theme.springMorph, value: presence)
    }

    /// White scrim (100% → 0%) with a blur that fades on the same curve, so the
    /// title + controls stay crisp while the copy scrolling beneath melts into the
    /// header area (mirrors the homepage nav scrim).
    private func topScrim(height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.55),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            LinearGradient(
                colors: [.white, .white.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

struct ConversationCanvasView: View {
    let conversation: Conversation
    let topPadding: CGFloat
    /// A reply mid-arrival: the thinking shim, then the answer revealed word by
    /// word, shown below the persisted turns until it commits.
    var streamingTurn: StreamingTurn? = nil
    /// Trailing space reserved below the last turn so a freshly submitted turn can
    /// scroll all the way to the top (ChatGPT-style) even when its answer is short
    /// — without it, a brief reply can't reach the top and stops mid-screen.
    var reservedBottom: CGFloat = 140
    /// Shared namespace: the first assistant message is the matchedGeometry target
    /// the resting inline-answer card flies into when the composer opens over it.
    var morphNS: Namespace.ID? = nil

    /// Scroll anchor for the streaming bubble (distinct from the Int message ids).
    static let streamingBubbleID = "conversation-streaming-bubble"
    /// matchedGeometry id shared with `InlineAnswerView` for the answer hand-off.
    static let answerMorphID = "conversation-answer-morph"

    /// Index of the first assistant message — the one that morphs from the inline
    /// answer card (its text is the same string, so the hand-off reads as one move).
    private var morphAnchorIndex: Int? {
        conversation.messages.firstIndex { $0.role == .assistant }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(Array(conversation.messages.enumerated()), id: \.offset) { index, message in
                if !(index == 0 && message.role == .user) {
                    messageView(message)
                        .modifier(AnswerMorph(active: morphNS != nil && index == morphAnchorIndex,
                                              id: Self.answerMorphID, ns: morphNS))
                        .id(index)
                }
            }
            if let stream = streamingTurn {
                streamingView(stream)
                    .id(Self.streamingBubbleID)
            }
        }
        .padding(.horizontal, 39)
        .padding(.top, topPadding)
        .padding(.bottom, max(140, reservedBottom))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func streamingView(_ stream: StreamingTurn) -> some View {
        if stream.thinking {
            ThinkingShimmer()
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        } else {
            // No transition here: at commit this streamed text is replaced by the
            // identical committed message at the same spot, so an opacity transition
            // would cross-fade two identical layers and read as a flash.
            Text(stream.revealed)
                .font(.centra(size: 16))
                .foregroundStyle(Theme.figmaInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func messageView(_ message: Message) -> some View {
        switch message.role {
        case .assistant:
            Text(.init(message.text))
                .font(.centra(size: 16))
                .foregroundStyle(Theme.figmaInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            Text(message.text)
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(Theme.figmaInkMuted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Applies the answer `matchedGeometryEffect` only to the single anchor message,
/// so the inline-answer card flies its text into that message's slot without
/// tagging every turn (and only when a namespace is supplied).
private struct AnswerMorph: ViewModifier {
    let active: Bool
    let id: String
    let ns: Namespace.ID?
    func body(content: Content) -> some View {
        if active, let ns {
            content.matchedGeometryEffect(id: id, in: ns, anchor: .topLeading)
        } else {
            content
        }
    }
}

/// The "Thinking…" shim shown while a reply resolves — the app's AI-reasoning
/// shimmer (see `ShimmerSweepView`) masked to the label, so the word glows as it
/// sweeps left to right.
struct ThinkingShimmer: View {
    private let label = Copy["search.thinking"]
    private let font = Font.centra(size: 16)

    var body: some View {
        Text(label)
            .font(font)
            .opacity(0)
            .overlay {
                ShimmerSweepView(baseColor: Theme.figmaInkMuted, highlightColor: Theme.figmaInk)
                    .mask(Text(label).font(font))
            }
            .fixedSize()
    }
}
