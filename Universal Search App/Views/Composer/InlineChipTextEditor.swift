import SwiftUI
import UIKit

struct ChipToken: Equatable {
    enum Style: Equatable {
        case standard
        case accent
        case imageAccent(String)
    }

    let id: String
    let icon: String
    let label: String
    var style: Style = .standard

    static func == (lhs: ChipToken, rhs: ChipToken) -> Bool {
        lhs.id == rhs.id && lhs.icon == rhs.icon && lhs.label == rhs.label && lhs.style == rhs.style
    }
}

enum ChipRenderMode {
    case leading
    case inline
}

struct ChipTransitionInfo: Equatable {
    let id: UUID
    let chipId: String
    let sourceText: String

    init(chipId: String, sourceText: String) {
        self.id = UUID()
        self.chipId = chipId
        self.sourceText = sourceText
    }
}

private let chipSpaceAttrKey = NSAttributedString.Key("chipTrailingSpace")
private let ghostTextAttrKey = NSAttributedString.Key("ghostText")

private class ChipTextAttachment: NSTextAttachment {
    var chipId: String = ""
    var spacerSize: CGSize = .zero

    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        UIGraphicsImageRenderer(size: imageBounds.size).image { _ in }
    }
}

private let chipIconSize: CGFloat = 18
private let chipHPad: CGFloat = 8
private let chipVPad: CGFloat = 6
private let chipSpacing: CGFloat = 4
private let chipLineHeight: CGFloat = 30

private func chipSize(for chip: ChipToken, font: UIFont) -> CGSize {
    let textSize = (chip.label as NSString).size(withAttributes: [.font: font])
    return CGSize(
        width: chipHPad + chipIconSize + chipSpacing + textSize.width + chipHPad,
        height: chipLineHeight
    )
}

private class ChipUIView: UIView {
    let chipId: String
    var onTap: ((String) -> Void)?

    private let iconView = UIImageView()
    private let labelView = UILabel()
    private var coverImageView: UIImageView?

    init(chip: ChipToken, font: UIFont) {
        self.chipId = chip.id
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        clipsToBounds = true

        let bgColor: UIColor
        let fgColor: UIColor
        var bgImageName: String? = nil

        switch chip.style {
        case .standard:
            bgColor = UIColor(Color(hex: "0c0e1c").opacity(0.07))
            fgColor = UIColor(Color(hex: "0c0e1c").opacity(0.9))
        case .accent:
            bgColor = UIColor(Color(hex: "1543EE"))
            fgColor = .white
        case .imageAccent(let imageName):
            bgColor = UIColor.darkGray
            fgColor = .white
            bgImageName = imageName
        }

        backgroundColor = bgColor

        if let bgImageName, let coverImage = UIImage(named: bgImageName) {
            let iv = UIImageView(image: coverImage)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            insertSubview(iv, at: 0)
            coverImageView = iv

            let dimView = UIView()
            dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            insertSubview(dimView, aboveSubview: iv)
        }

        iconView.image = UIImage.egds(chip.icon)?
            .withTintColor(fgColor, renderingMode: .alwaysOriginal)
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        labelView.text = chip.label
        labelView.font = font
        labelView.textColor = fgColor
        addSubview(labelView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        layer.cornerRadius = h / 2

        coverImageView?.frame = bounds

        iconView.frame = CGRect(
            x: chipHPad,
            y: (h - chipIconSize) / 2,
            width: chipIconSize,
            height: chipIconSize
        )

        let labelX = chipHPad + chipIconSize + chipSpacing
        let labelSize = labelView.sizeThatFits(bounds.size)
        labelView.frame = CGRect(
            x: labelX,
            y: (h - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    func updateLabel(_ text: String) {
        labelView.text = text
        setNeedsLayout()
    }

    @objc private func tapped() {
        onTap?(chipId)
    }
}

private class WrappingTextView: UITextView {
    var onLayoutSubviews: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        guard bounds.width > 0 else { return super.intrinsicContentSize }
        let size = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
        onLayoutSubviews?()
    }
}

struct InlineChipTextEditor: UIViewRepresentable {
    @Binding var text: String
    var chips: [ChipToken] = []
    var chipRenderMode: ChipRenderMode = .leading
    var placeholder: String = "Follow up"
    /// When false the built-in UIKit placeholder is suppressed — the host draws its
    /// own (e.g. a SwiftUI placeholder that scales continuously across composer
    /// states). Typed text and the cursor are unaffected.
    var showsPlaceholder: Bool = true
    var isFocused: Binding<Bool>? = nil
    var highlightRange: NSRange? = nil
    var fontName: String = "CentraNo2-Book"
    var fontSize: CGFloat = 18
    var lineHeight: CGFloat = 28
    var lineSpacing: CGFloat = 8
    var ghostText: String = ""
    var onAcceptGhostText: (() -> Void)? = nil
    var onGhostTextTap: ((CGPoint) -> Void)? = nil
    var onChipTap: ((String) -> Void)? = nil
    var onChipDelete: ((String) -> Void)? = nil
    var onSubmit: (() -> Void)? = nil
    var chipTransition: ChipTransitionInfo? = nil
    var onChipFramesChanged: (([String: CGRect]) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = WrappingTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textView.textContainer.maximumNumberOfLines = 6
        textView.tintColor = UIColor(Color(hex: "0c0e1c"))
        textView.textDragInteraction?.isEnabled = false

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        textView.addGestureRecognizer(tapGesture)

        let swipeGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeRight(_:)))
        swipeGesture.direction = .right
        textView.addGestureRecognizer(swipeGesture)

        let font = bodyFont
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: UIColor(Color(hex: "0c0e1c")),
            .paragraphStyle: bodyParagraphStyle
        ]

        let coordinator = context.coordinator
        coordinator.setupPlaceholder(in: textView)
        textView.onLayoutSubviews = { [weak coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.layoutChipViews(in: textView, chips: coordinator.lastChips, font: coordinator.parent.chipFont)
        }
        rebuildAttributedString(in: textView, context: context)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let chipsChanged = coordinator.lastChips != chips
        let textChanged = coordinator.lastText != text
        let highlightChanged = coordinator.lastHighlightRange != highlightRange
        let ghostChanged = coordinator.lastGhostText != ghostText

        let hasNewTransition = chipTransition != nil
            && chipTransition != coordinator.lastChipTransition

        var textFragmentSnapshot: (view: UIView, frame: CGRect)?
        if hasNewTransition, let transition = chipTransition {
            coordinator.stopHighlightAnimation()
            coordinator.lastChipTransition = chipTransition
            textFragmentSnapshot = coordinator.captureSourceTextFragment(
                in: textView, sourceText: transition.sourceText
            )
        }

        if chipsChanged || textChanged || highlightChanged || ghostChanged {
            coordinator.lastGhostText = ghostText
            let isNewHighlight = highlightChanged && highlightRange != nil && coordinator.lastHighlightRange == nil

            let selectedRange = textView.selectedRange
            rebuildAttributedString(in: textView, context: context)
            coordinator.lastHighlightRange = highlightRange

            if hasNewTransition {
                // highlight already stopped above
            } else if isNewHighlight, let hl = highlightRange, hl.length > 0 {
                let attrRange: NSRange
                if chipRenderMode == .inline {
                    let attrStart = coordinator.textOffsetToAttrOffset(hl.location)
                    let attrEnd = coordinator.textOffsetToAttrOffset(hl.location + hl.length)
                    attrRange = NSRange(location: attrStart, length: attrEnd - attrStart)
                } else {
                    attrRange = hl
                }
                coordinator.startHighlightAnimation(in: textView, range: attrRange)
                rebuildAttributedString(in: textView, context: context)
            } else if highlightRange == nil {
                coordinator.stopHighlightAnimation()
            } else if coordinator.highlightOverlayActive, let hl = highlightRange, hl.length > 0 {
                let attrRange: NSRange
                if chipRenderMode == .inline {
                    let attrStart = coordinator.textOffsetToAttrOffset(hl.location)
                    let attrEnd = coordinator.textOffsetToAttrOffset(hl.location + hl.length)
                    attrRange = NSRange(location: attrStart, length: attrEnd - attrStart)
                } else {
                    attrRange = hl
                }
                coordinator.animatingHighlightRange = attrRange
                coordinator.updateOverlayPosition(in: textView)
            }

            let totalLen = textView.attributedText.length
            let ghostLen = ghostText.count
            let maxPos = max(0, totalLen - ghostLen)
            let safeLoc = min(selectedRange.location, maxPos)
            let safeLen = min(selectedRange.length, maxPos - safeLoc)

            let moveToEnd = chipRenderMode == .inline
                ? (textChanged || chipsChanged) && !coordinator.isEditing
                : textChanged && !coordinator.isEditing

            if moveToEnd {
                textView.selectedRange = NSRange(location: maxPos, length: 0)
            } else {
                textView.selectedRange = NSRange(location: safeLoc, length: safeLen)
            }

            if hasNewTransition, let fragment = textFragmentSnapshot {
                coordinator.startChipTransition(in: textView, fragment: fragment.view, at: fragment.frame)
            }
        }

        textView.textContainer.maximumNumberOfLines = 6

        if let focusBinding = isFocused {
            let wantsFocus = focusBinding.wrappedValue
            if wantsFocus && !textView.isFirstResponder {
                DispatchQueue.main.async { textView.becomeFirstResponder() }
            } else if !wantsFocus && textView.isFirstResponder {
                DispatchQueue.main.async { textView.resignFirstResponder() }
            }
        }

        DispatchQueue.main.async {
            coordinator.updatePlaceholder(in: textView)
        }
    }

    // MARK: - Fonts

    private var bodyFont: UIFont {
        UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    private var bodyParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineSpacing = lineSpacing
        return style
    }

    private var chipFont: UIFont {
        UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    // MARK: - Rebuild Attributed String

    private func rebuildAttributedString(in textView: UITextView, context: Context) {
        if chipRenderMode == .inline {
            rebuildInline(in: textView, context: context)
        } else {
            rebuildLeading(in: textView, context: context)
        }
    }

    private func rebuildLeading(in textView: UITextView, context: Context) {
        let result = NSMutableAttributedString()
        let font = bodyFont

        for (index, chip) in chips.enumerated() {
            let size = chipSize(for: chip, font: chipFont)
            let attachment = ChipTextAttachment()
            attachment.chipId = chip.id
            attachment.spacerSize = size
            let yOffset = font.descender
            attachment.bounds = CGRect(x: 0, y: yOffset, width: size.width, height: lineHeight)

            let attachStr = NSAttributedString(attachment: attachment)
            result.append(attachStr)

            if index < chips.count - 1 || !text.isEmpty || text.isEmpty {
                let space = NSAttributedString(string: " ", attributes: [
                    .font: font,
                    .foregroundColor: UIColor(Color(hex: "0c0e1c")),
                    .paragraphStyle: bodyParagraphStyle
                ])
                result.append(space)
            }
        }

        let textColor = UIColor(Color(hex: "0c0e1c"))
        let paragraphStyle = bodyParagraphStyle
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        let userText = NSMutableAttributedString(string: text, attributes: textAttrs)

        if let highlight = highlightRange {
            let color: UIColor = context.coordinator.highlightOverlayActive
                ? .clear
                : UIColor(Color(hex: "0C0E1C"))
            let clampedLoc = max(0, min(highlight.location, userText.length))
            let clampedLen = min(highlight.length, userText.length - clampedLoc)
            let safeRange = NSRange(location: clampedLoc, length: clampedLen)
            if safeRange.length > 0 {
                userText.addAttribute(.foregroundColor, value: color, range: safeRange)
            }
        }

        result.append(userText)

        if !ghostText.isEmpty {
            let ghostAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(Color(hex: "0c0e1c").opacity(0.25)),
                .paragraphStyle: paragraphStyle,
                ghostTextAttrKey: true
            ]
            result.append(NSAttributedString(string: ghostText, attributes: ghostAttrs))
        }

        textView.attributedText = result
        textView.typingAttributes = textAttrs

        context.coordinator.lastChips = chips
        context.coordinator.lastText = text
        context.coordinator.chipCharacterCount = chips.isEmpty ? 0 : chips.count * 2

        textView.invalidateIntrinsicContentSize()
        context.coordinator.layoutChipViews(in: textView, chips: chips, font: chipFont)
    }

    private func rebuildInline(in textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        let font = bodyFont
        let textColor = UIColor(Color(hex: "0c0e1c"))
        let paragraphStyle = bodyParagraphStyle
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let existingIds = Set(coordinator.chipPositions.map(\.chipId))
        let currentIds = Set(chips.map(\.id))
        let newChipIds = currentIds.subtracting(existingIds)
        let removedIds = existingIds.subtracting(currentIds)

        coordinator.chipPositions.removeAll { removedIds.contains($0.chipId) }

        if !newChipIds.isEmpty {
            let cursorAttr = textView.selectedRange.location
            let cursorText = coordinator.attrOffsetToTextOffset(cursorAttr)
            let clampedCursor = min(cursorText, text.count)

            for chip in chips where newChipIds.contains(chip.id) {
                coordinator.chipPositions.append((chipId: chip.id, textOffset: clampedCursor))
            }
        }

        coordinator.chipPositions = coordinator.chipPositions.map { pos in
            (chipId: pos.chipId, textOffset: min(pos.textOffset, text.count))
        }
        coordinator.chipPositions.sort { $0.textOffset < $1.textOffset }

        let result = NSMutableAttributedString()
        var currentTextOffset = 0

        for pos in coordinator.chipPositions {
            guard let chip = chips.first(where: { $0.id == pos.chipId }) else { continue }
            let chipTextOffset = pos.textOffset

            if chipTextOffset > currentTextOffset && currentTextOffset < text.count {
                let start = text.index(text.startIndex, offsetBy: currentTextOffset)
                let end = text.index(text.startIndex, offsetBy: min(chipTextOffset, text.count))
                result.append(NSAttributedString(string: String(text[start..<end]), attributes: textAttrs))
            }

            let size = chipSize(for: chip, font: chipFont)
            let attachment = ChipTextAttachment()
            attachment.chipId = chip.id
            attachment.spacerSize = size
            let yOffset = font.descender
            attachment.bounds = CGRect(x: 0, y: yOffset, width: size.width, height: lineHeight)
            result.append(NSAttributedString(attachment: attachment))

            var spaceAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
            spaceAttrs[chipSpaceAttrKey] = chip.id
            result.append(NSAttributedString(string: " ", attributes: spaceAttrs))

            currentTextOffset = chipTextOffset
        }

        if currentTextOffset < text.count {
            let start = text.index(text.startIndex, offsetBy: currentTextOffset)
            result.append(NSAttributedString(string: String(text[start...]), attributes: textAttrs))
        }

        if let highlight = highlightRange, highlight.length > 0 {
            let attrStart = coordinator.textOffsetToAttrOffset(highlight.location)
            let attrEnd = coordinator.textOffsetToAttrOffset(highlight.location + highlight.length)
            let color: UIColor = coordinator.highlightOverlayActive
                ? .clear
                : UIColor(Color(hex: "0C0E1C"))
            let safeStart = max(0, min(attrStart, result.length))
            let safeEnd = max(safeStart, min(attrEnd, result.length))
            if safeEnd > safeStart {
                result.addAttribute(.foregroundColor, value: color, range: NSRange(location: safeStart, length: safeEnd - safeStart))
            }
        }

        if !ghostText.isEmpty {
            let ghostAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(Color(hex: "0c0e1c").opacity(0.25)),
                .paragraphStyle: paragraphStyle,
                ghostTextAttrKey: true
            ]
            result.append(NSAttributedString(string: ghostText, attributes: ghostAttrs))
        }

        textView.attributedText = result
        textView.typingAttributes = textAttrs

        coordinator.lastChips = chips
        coordinator.lastText = text

        textView.invalidateIntrinsicContentSize()
        coordinator.layoutChipViews(in: textView, chips: chips, font: chipFont)
    }

    // MARK: - Shimmer Overlay

    class ShimmerOverlay: UIView {
        private var hostingController: UIHostingController<ShimmerSweepView>?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            clipsToBounds = true
        }

        required init?(coder: NSCoder) { fatalError() }

        func startAnimating() {
            stopAnimating()
            let shimmer = ShimmerSweepView(
                baseColor: Color(hex: "0C0E1C"),
                highlightColor: Color(hex: "85868D")
            )
            let hc = UIHostingController(rootView: shimmer)
            hc.view.backgroundColor = .clear
            hc.view.frame = bounds
            hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(hc.view)
            hostingController = hc
        }

        func stopAnimating() {
            hostingController?.view.removeFromSuperview()
            hostingController = nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostingController?.view.frame = bounds
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: InlineChipTextEditor
        var lastChips: [ChipToken] = []
        var lastText: String = ""
        var lastHighlightRange: NSRange? = nil
        var lastGhostText: String = ""
        var chipCharacterCount: Int = 0
        var isEditing = false
        var chipHighlighted = false
        var chipPositions: [(chipId: String, textOffset: Int)] = []
        private var placeholderLabel: UILabel?

        private var gradientOverlay: ShimmerOverlay?
        fileprivate(set) var animatingHighlightRange: NSRange?
        var highlightOverlayActive: Bool { gradientOverlay != nil }

        private var chipTransitionOverlay: UIView?
        var lastChipTransition: ChipTransitionInfo?
        private var chipViews: [String: ChipUIView] = [:]

        init(_ parent: InlineChipTextEditor) {
            self.parent = parent
        }

        func layoutChipViews(in textView: UITextView, chips: [ChipToken], font: UIFont) {
            let attrText = textView.attributedText ?? NSAttributedString()
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let inset = textView.textContainerInset

            var activeIds = Set<String>()

            attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, range, _ in
                guard let attach = value as? ChipTextAttachment else { return }
                guard let chip = chips.first(where: { $0.id == attach.chipId }) else { return }
                activeIds.insert(chip.id)

                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: range, actualCharacterRange: nil
                )
                let glyphRect = layoutManager.boundingRect(
                    forGlyphRange: glyphRange, in: textContainer
                )
                let frame = CGRect(
                    x: glyphRect.origin.x + inset.left,
                    y: glyphRect.origin.y + inset.top,
                    width: glyphRect.width,
                    height: glyphRect.height
                )

                let view: ChipUIView
                if let existing = chipViews[chip.id] {
                    view = existing
                    view.updateLabel(chip.label)
                } else {
                    view = ChipUIView(chip: chip, font: font)
                    view.onTap = { [weak self] chipId in
                        self?.parent.onChipTap?(chipId)
                    }
                    textView.addSubview(view)
                    chipViews[chip.id] = view

                    view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                    view.alpha = 0

                    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                    blur.frame = view.bounds
                    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    blur.isUserInteractionEnabled = false
                    view.addSubview(blur)

                    UIView.animate(
                        withDuration: 0.4,
                        delay: 0,
                        usingSpringWithDamping: 0.7,
                        initialSpringVelocity: 0.5,
                        options: .curveEaseOut
                    ) {
                        view.transform = .identity
                        view.alpha = 1
                        blur.effect = nil
                    } completion: { _ in
                        blur.removeFromSuperview()
                    }
                }
                let chipH = attach.spacerSize.height
                view.frame = CGRect(
                    x: frame.origin.x,
                    y: frame.midY - chipH / 2,
                    width: frame.width,
                    height: chipH
                )
            }

            for (id, view) in chipViews where !activeIds.contains(id) {
                view.removeFromSuperview()
                chipViews.removeValue(forKey: id)
            }

            var frames: [String: CGRect] = [:]
            for (id, view) in chipViews {
                frames[id] = view.frame
            }
            parent.onChipFramesChanged?(frames)
        }

        func startHighlightAnimation(in textView: UITextView, range: NSRange) {
            stopHighlightAnimation()
            animatingHighlightRange = range

            let overlay = ShimmerOverlay()
            overlay.isUserInteractionEnabled = false
            textView.addSubview(overlay)
            gradientOverlay = overlay

            updateOverlayMask(in: textView, range: range)
            overlay.startAnimating()
        }

        func stopHighlightAnimation() {
            gradientOverlay?.stopAnimating()
            gradientOverlay?.removeFromSuperview()
            gradientOverlay = nil
            animatingHighlightRange = nil
        }

        func updateOverlayPosition(in textView: UITextView) {
            guard let range = animatingHighlightRange, let overlay = gradientOverlay else { return }
            updateOverlayMask(in: textView, range: range)
            overlay.setNeedsDisplay()
        }

        private func updateOverlayMask(in textView: UITextView, range: NSRange) {
            guard let overlay = gradientOverlay else { return }
            textView.layoutIfNeeded()

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let inset = textView.textContainerInset

            let safeStart = max(0, min(range.location, textView.attributedText.length))
            let safeLen = min(range.length, textView.attributedText.length - safeStart)
            guard safeLen > 0 else { return }
            let safeRange = NSRange(location: safeStart, length: safeLen)

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: safeRange, actualCharacterRange: nil
            )

            var rects: [CGRect] = []
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                rects.append(rect)
            }

            guard !rects.isEmpty else { return }

            var unionRect = rects[0]
            for r in rects.dropFirst() { unionRect = unionRect.union(r) }

            let clipPad: CGFloat = 4
            let overlayFrame = CGRect(
                x: unionRect.origin.x + inset.left - clipPad,
                y: unionRect.origin.y + inset.top - clipPad,
                width: unionRect.width + clipPad * 2,
                height: unionRect.height + clipPad * 2
            )
            overlay.frame = overlayFrame

            let maskImage = renderTextMask(
                size: overlay.bounds.size,
                unionRect: unionRect,
                rects: rects,
                safeRange: safeRange,
                textView: textView,
                drawOffset: CGPoint(x: clipPad, y: clipPad)
            )
            applyMask(to: overlay, maskImage: maskImage)
        }

        private func renderTextMask(
            size: CGSize,
            unionRect: CGRect,
            rects: [CGRect],
            safeRange: NSRange,
            textView: UITextView,
            drawOffset: CGPoint = .zero
        ) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let drawOrigin = CGPoint(
                    x: -unionRect.origin.x + drawOffset.x,
                    y: -unionRect.origin.y + drawOffset.y
                )
                let maskText = NSMutableAttributedString(attributedString: textView.attributedText)
                let fullRange = NSRange(location: 0, length: maskText.length)
                maskText.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRange)
                maskText.addAttribute(.foregroundColor, value: UIColor.white, range: safeRange)

                maskText.draw(
                    with: CGRect(
                        origin: drawOrigin,
                        size: textView.textContainer.size
                    ),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                )
            }
        }

        private func applyMask(to view: UIView, maskImage: UIImage) {
            let maskLayer = CALayer()
            maskLayer.frame = view.bounds
            maskLayer.contentsScale = UIScreen.main.scale
            maskLayer.contents = maskImage.cgImage
            view.layer.mask = maskLayer
        }

        // MARK: - Chip Transition Animation

        func stopChipTransition() {
            chipTransitionOverlay?.layer.removeAllAnimations()
            chipTransitionOverlay?.removeFromSuperview()
            chipTransitionOverlay = nil
        }

        func captureSourceTextFragment(in textView: UITextView, sourceText: String) -> (view: UIView, frame: CGRect)? {
            let attrStr = textView.attributedText ?? NSAttributedString()
            let fullString = attrStr.string as NSString
            let range = fullString.range(of: sourceText, options: .backwards)
            guard range.location != NSNotFound else { return nil }

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let inset = textView.textContainerInset

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var unionRect = CGRect.zero
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                unionRect = unionRect == .zero ? rect : unionRect.union(rect)
            }
            guard unionRect != .zero else { return nil }

            let frame = CGRect(
                x: unionRect.origin.x + inset.left,
                y: unionRect.origin.y + inset.top,
                width: unionRect.width,
                height: unionRect.height
            )

            let renderer = UIGraphicsImageRenderer(size: frame.size)
            let image = renderer.image { _ in
                let drawOrigin = CGPoint(x: -unionRect.origin.x, y: -unionRect.origin.y)
                let maskText = NSMutableAttributedString(attributedString: attrStr)
                let fullRange = NSRange(location: 0, length: maskText.length)
                maskText.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRange)
                maskText.addAttribute(
                    .foregroundColor,
                    value: UIColor(Color(hex: "0c0e1c")),
                    range: range
                )
                maskText.draw(
                    with: CGRect(origin: drawOrigin, size: textContainer.size),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                )
            }

            let imageView = UIImageView(image: image)
            imageView.frame = frame
            return (view: imageView, frame: frame)
        }

        func startChipTransition(in textView: UITextView, fragment: UIView, at frame: CGRect) {
            stopChipTransition()

            fragment.frame = frame
            fragment.isUserInteractionEnabled = false
            textView.addSubview(fragment)
            chipTransitionOverlay = fragment

            let blur = UIVisualEffectView(effect: nil)
            blur.frame = fragment.bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            fragment.addSubview(blur)

            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                fragment.alpha = 0
                fragment.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                blur.effect = UIBlurEffect(style: .regular)
            } completion: { _ in
                fragment.removeFromSuperview()
                self.chipTransitionOverlay = nil
            }
        }

        // MARK: - Offset Conversion

        func textOffsetToAttrOffset(_ textOffset: Int) -> Int {
            var count = 0
            for pos in chipPositions {
                if pos.textOffset <= textOffset { count += 1 }
            }
            return textOffset + count * 2
        }

        func attrOffsetToTextOffset(_ attrOffset: Int) -> Int {
            var tOffset = 0
            var aOffset = 0
            let sorted = chipPositions.sorted { $0.textOffset < $1.textOffset }

            for pos in sorted {
                let segLen = pos.textOffset - tOffset
                if attrOffset < aOffset + segLen {
                    return tOffset + (attrOffset - aOffset)
                }
                aOffset += segLen
                if attrOffset < aOffset + 2 {
                    return pos.textOffset
                }
                aOffset += 2
                tOffset = pos.textOffset
            }

            return tOffset + max(0, attrOffset - aOffset)
        }

        // MARK: - Placeholder

        func setupPlaceholder(in textView: UITextView) {
            // Idempotent: a reused coordinator can see `makeUIView` run again, and
            // adding a second label would stack it over the first (overlapping,
            // slightly offset placeholder text). Drop any existing one first.
            placeholderLabel?.removeFromSuperview()
            let font = parent.bodyFont
            let label = UILabel()
            label.text = parent.placeholder
            label.font = font
            label.textColor = UIColor(Color(hex: "0c0e1c").opacity(0.5))
            label.numberOfLines = 1
            textView.addSubview(label)
            placeholderLabel = label
        }

        func updatePlaceholder(in textView: UITextView) {
            let showPlaceholder = parent.showsPlaceholder && parent.text.isEmpty && parent.chips.isEmpty
            placeholderLabel?.isHidden = !showPlaceholder

            guard showPlaceholder, let label = placeholderLabel else { return }
            let lineHeight = parent.lineHeight
            label.frame = CGRect(
                x: 0,
                y: textView.textContainerInset.top + (lineHeight - label.font.lineHeight) / 2,
                width: textView.bounds.width,
                height: lineHeight
            )
        }

        // MARK: - UITextViewDelegate

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            parent.isFocused?.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            parent.isFocused?.wrappedValue = false
        }

        func textViewDidChange(_ textView: UITextView) {
            chipHighlighted = false

            if parent.chipRenderMode == .inline {
                textViewDidChangeInline(textView)
            } else {
                textViewDidChangeLeading(textView)
            }

            updatePlaceholder(in: textView)
            textView.invalidateIntrinsicContentSize()
        }

        private func textViewDidChangeLeading(_ textView: UITextView) {
            let attrStr = textView.attributedText ?? NSAttributedString()
            var endOfUser = attrStr.length
            if endOfUser > 0 {
                let lastAttrs = attrStr.attributes(at: endOfUser - 1, effectiveRange: nil)
                if lastAttrs[ghostTextAttrKey] != nil {
                    var ghostStart = endOfUser - 1
                    while ghostStart > 0 {
                        let a = attrStr.attributes(at: ghostStart - 1, effectiveRange: nil)
                        if a[ghostTextAttrKey] != nil { ghostStart -= 1 } else { break }
                    }
                    endOfUser = ghostStart
                }
            }

            let fullText = (attrStr.string as NSString).substring(to: endOfUser)
            let userText: String
            if chipCharacterCount > 0 && fullText.count >= chipCharacterCount {
                let startIndex = fullText.index(fullText.startIndex, offsetBy: chipCharacterCount)
                userText = String(fullText[startIndex...])
            } else if parent.chips.isEmpty {
                userText = fullText
            } else {
                userText = ""
            }

            isEditing = true
            parent.text = userText
            lastText = userText
            isEditing = false
        }

        private func textViewDidChangeInline(_ textView: UITextView) {
            guard let attrStr = textView.attributedText else { return }

            var userText = ""
            var newPositions: [(chipId: String, textOffset: Int)] = []
            var i = 0
            let length = attrStr.length

            while i < length {
                let attrs = attrStr.attributes(at: i, effectiveRange: nil)

                if attrs[ghostTextAttrKey] != nil {
                    i += 1
                } else if let chipAttach = attrs[.attachment] as? ChipTextAttachment {
                    newPositions.append((chipId: chipAttach.chipId, textOffset: userText.count))
                    i += 1
                } else if attrs[chipSpaceAttrKey] != nil {
                    i += 1
                } else {
                    let char = (attrStr.string as NSString).substring(with: NSRange(location: i, length: 1))
                    if char != "\u{FFFC}" {
                        userText += char
                    }
                    i += 1
                }
            }

            chipPositions = newPositions

            isEditing = true
            parent.text = userText
            lastText = userText
            isEditing = false
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if parent.chipRenderMode == .inline {
                return shouldChangeTextInline(textView, range: range, text: text)
            } else {
                return shouldChangeTextLeading(textView, range: range, text: text)
            }
        }

        private func shouldChangeTextLeading(_ textView: UITextView, range: NSRange, text: String) -> Bool {
            if text == "\t" && !parent.ghostText.isEmpty {
                parent.onAcceptGhostText?()
                return false
            }
            if text == "\n" {
                parent.onSubmit?()
                return false
            }

            let isBackspace = text.isEmpty && range.length > 0

            if isBackspace && range.location < chipCharacterCount && chipCharacterCount > 0 {
                if chipHighlighted {
                    let lastChip = parent.chips.last
                    chipHighlighted = false
                    if let chip = lastChip {
                        parent.onChipDelete?(chip.id)
                    }
                }
                return false
            }

            if isBackspace && range.location == chipCharacterCount && range.length == 1 && chipCharacterCount > 0 {
                if !chipHighlighted {
                    let lastChipStart = chipCharacterCount - 2
                    textView.selectedRange = NSRange(location: lastChipStart, length: 2)
                    chipHighlighted = true
                    return false
                }
            }

            if range.location < chipCharacterCount {
                return false
            }

            return true
        }

        private func shouldChangeTextInline(_ textView: UITextView, range: NSRange, text: String) -> Bool {
            if text == "\t" && !parent.ghostText.isEmpty {
                parent.onAcceptGhostText?()
                return false
            }
            if text == "\n" {
                parent.onSubmit?()
                return false
            }

            let isBackspace = text.isEmpty && range.length > 0

            if isBackspace, let attrStr = textView.attributedText {
                for i in range.location..<min(range.location + range.length, attrStr.length) {
                    let attrs = attrStr.attributes(at: i, effectiveRange: nil)

                    if let chipAttach = attrs[.attachment] as? ChipTextAttachment {
                        parent.onChipDelete?(chipAttach.chipId)
                        return false
                    }

                    if let chipId = attrs[chipSpaceAttrKey] as? String {
                        parent.onChipDelete?(chipId)
                        return false
                    }
                }
            }

            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let font = parent.bodyFont
            let textColor = UIColor(Color(hex: "0c0e1c"))
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: parent.bodyParagraphStyle
            ]

            let ghostLen = parent.ghostText.count
            if ghostLen > 0 {
                let totalLen = textView.attributedText.length
                let editableEnd = max(0, totalLen - ghostLen)
                let sel = textView.selectedRange
                let selEnd = sel.location + sel.length
                if selEnd > editableEnd {
                    let clampedLoc = min(sel.location, editableEnd)
                    textView.selectedRange = NSRange(location: clampedLoc, length: 0)
                }
            }

            if parent.chipRenderMode == .inline { return }

            guard chipCharacterCount > 0 else { return }
            let sel = textView.selectedRange

            if chipHighlighted {
                let expectedRange = NSRange(location: chipCharacterCount - 2, length: 2)
                if sel != expectedRange {
                    chipHighlighted = false
                }
                return
            }

            if sel.location < chipCharacterCount {
                let newLoc = chipCharacterCount
                let newLen = max(0, sel.location + sel.length - newLoc)
                textView.selectedRange = NSRange(location: newLoc, length: newLen)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let point = gesture.location(in: textView)
            let textContainerOffset = CGPoint(
                x: point.x - textView.textContainerInset.left,
                y: point.y - textView.textContainerInset.top
            )

            let charIndex = textView.layoutManager.characterIndex(
                for: textContainerOffset,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            if charIndex < textView.attributedText.length {
                let attrs = textView.attributedText.attributes(at: charIndex, effectiveRange: nil)
                if attrs[ghostTextAttrKey] != nil {
                    let windowPoint = textView.convert(point, to: nil)
                    parent.onGhostTextTap?(windowPoint)
                    return
                }
            }
        }

        @objc func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
            guard !parent.ghostText.isEmpty else { return }
            parent.onAcceptGhostText?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
