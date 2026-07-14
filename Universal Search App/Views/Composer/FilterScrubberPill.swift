import SwiftUI

private struct SegmentWidthKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct FilterScrubberPill: View {
    let currentFilter: String
    let filters: [String]
    let onSwitch: (String) -> Void
    @Binding var isExpanded: Bool

    @State private var activeIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var segmentWidths: [Int: CGFloat] = [:]
    @State private var containerWidth: CGFloat = 0
    @State private var isScrubbing = false
    @State private var pressStart: Date? = nil
    @State private var longPressTimer: Timer? = nil
    @State private var scrubAnchorX: CGFloat? = nil
    @State private var scrubFocusedIndex: Int? = nil

    private let segmentHeight: CGFloat = 44
    private let segmentHPad: CGFloat = 22
    private let slotInset: CGFloat = 4
    private let longPressDuration: TimeInterval = 0.3

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2

            Capsule()
                .fill(.clear)
                .frame(
                    width: isExpanded ? activeSegmentWidth + slotInset * 2 : 0,
                    height: segmentHeight
                )
                .glassEffect(in: .capsule)
                .opacity(isExpanded ? 1 : 0)
                .position(x: cx, y: cy)

            HStack(spacing: 0) {
                ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                    Text(filter)
                        .font(.centra(size: 14, weight: .medium))
                        .tracking(-0.14)
                        .foregroundStyle(
                            Color(hex: "0c0e1c")
                                .opacity(labelOpacity(for: index))
                        )
                        .padding(.horizontal, segmentHPad)
                        .frame(height: segmentHeight)
                        .contentShape(Rectangle())
                        .background {
                            GeometryReader { seg in
                                Color.clear.preference(
                                    key: SegmentWidthKey.self,
                                    value: [index: seg.size.width]
                                )
                            }
                        }
                }
            }
            .onPreferenceChange(SegmentWidthKey.self) { segmentWidths = $0 }
            .fixedSize()
            .position(
                x: cx + (totalWidth / 2 - centerX(of: activeIndex)) + dragOffset,
                y: cy
            )
        }
        .frame(height: segmentHeight)
        .padding(slotInset)
        .clipShape(Capsule())
        .glassEffect(in: .capsule)
        .frame(
            width: isExpanded ? nil : collapsedWidth,
            height: segmentHeight + slotInset * 2
        )
        .contentShape(Capsule())
        .highPriorityGesture(unifiedGesture)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: activeSegmentWidth)
        .animation(.spring(response: 1.0, dampingFraction: 0.82), value: activeIndex)
        .onAppear { syncIndex() }
        .onChange(of: currentFilter) { _, _ in syncIndex() }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }

    // MARK: - Sizing

    private var activeSegmentWidth: CGFloat {
        widthOf(activeIndex)
    }

    private var collapsedWidth: CGFloat {
        activeSegmentWidth + slotInset * 2
    }

    private func labelOpacity(for index: Int) -> Double {
        if !isExpanded {
            return index == activeIndex ? 0.9 : 0
        }
        let distance = abs(index - activeIndex)
        switch distance {
        case 0: return 0.9
        case 1: return 0.35
        default: return 0.2
        }
    }

    // MARK: - Unified Gesture

    private var unifiedGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    pressStart = Date()
                    startLongPressTimer()
                }

                if isScrubbing {
                    if scrubAnchorX == nil {
                        scrubAnchorX = value.location.x
                    }
                    dragOffset = value.location.x - scrubAnchorX!
                    let nearest = nearestSegment()
                    if nearest != scrubFocusedIndex {
                        scrubFocusedIndex = nearest
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
            }
            .onEnded { value in
                cancelLongPressTimer()
                let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? 0
                pressStart = nil
                scrubAnchorX = nil
                scrubFocusedIndex = nil

                if isScrubbing {
                    isScrubbing = false
                    let velocity = value.predictedEndTranslation.width - value.translation.width
                    snapAfterDrag(velocity: velocity)
                } else if elapsed < longPressDuration {
                    handleTap(at: value.location)
                }
            }
    }

    private func startLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                if !isExpanded {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        isExpanded = true
                    }
                }
                isScrubbing = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func handleTap(at location: CGPoint) {
        if isExpanded {
            let tappedIndex = segmentAt(x: location.x)
            tapSegment(at: tappedIndex)
        } else {
            syncIndex()
            dragOffset = 0
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isExpanded = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Layout Math

    private func widthOf(_ index: Int) -> CGFloat {
        segmentWidths[index] ?? 80
    }

    private var totalWidth: CGFloat {
        (0..<filters.count).reduce(0) { $0 + widthOf($1) }
    }

    private func centerX(of targetIndex: Int) -> CGFloat {
        var x: CGFloat = 0
        for i in 0..<filters.count {
            let w = widthOf(i)
            if i == targetIndex { return x + w / 2 }
            x += w
        }
        return x
    }

    private func segmentAt(x: CGFloat) -> Int {
        let cx = containerWidth / 2
        let touchInHStack = x - cx + centerX(of: activeIndex) - dragOffset

        var accumulated: CGFloat = 0
        for i in 0..<filters.count {
            let w = widthOf(i)
            if touchInHStack < accumulated + w {
                return i
            }
            accumulated += w
        }
        return filters.count - 1
    }

    // MARK: - Actions

    private func nearestSegment() -> Int {
        let displaced = centerX(of: activeIndex) - dragOffset
        var bestIndex = activeIndex
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<filters.count {
            let dist = abs(centerX(of: i) - displaced)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func syncIndex() {
        activeIndex = filters.firstIndex(of: currentFilter) ?? 0
    }

    private func tapSegment(at index: Int) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            isExpanded = false
        }
        if index != activeIndex {
            activeIndex = index
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onSwitch(filters[index])
        }
    }

    private func snapAfterDrag(velocity: CGFloat) {
        let displaced = centerX(of: activeIndex) - dragOffset - velocity * 0.15

        var bestIndex = activeIndex
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<filters.count {
            let dist = abs(centerX(of: i) - displaced)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            dragOffset = 0
            activeIndex = bestIndex
            isExpanded = false
        }

        if bestIndex != filters.firstIndex(of: currentFilter) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onSwitch(filters[bestIndex])
        }
    }
}
