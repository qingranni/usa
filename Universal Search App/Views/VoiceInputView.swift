//
//  VoiceInputView.swift
//  Universal Search App
//
//  Reusable pieces of the mock voice-input "Listening…" state. This is NOT a
//  standalone screen — the composer morphs into the listening state in place
//  (see `ChipComposerField.isListening` and `HomeComposerCover`), so these are
//  just the visual parts it composes:
//
//    • VoiceListeningLabel — the shimmering "Listening…" text that replaces the
//      composer placeholder.
//    • VoiceGoldGlow — the warm gold mesh gradient that morphs behind the sheet
//      and fills the gap above the keyboard when the sheet retracts.
//    • VoiceWaveformView — a dark audio meter that scrolls right→left and builds
//      as the mock "records".
//
//  Audio + recognition are mocked. Nothing parses while listening; the composer
//  hands its canned transcript to the real `SearchInputParser` only on confirm.
//

import SwiftUI

/// The shimmering "Listening…" label shown where the composer placeholder sits.
struct VoiceListeningLabel: View {
    var body: some View {
        Text(Copy["voice.listening"])
            .font(.centra(size: 20, weight: .medium))
            .kerning(-0.32)
            .foregroundStyle(.clear)
            .overlay {
                ShimmerSweepView(
                    baseColor: Theme.figmaInk.opacity(0.5),
                    highlightColor: Theme.figmaInk
                )
                .mask(
                    Text(Copy["voice.listening"])
                        .font(.centra(size: 20, weight: .medium))
                        .kerning(-0.32)
                )
            }
            .fixedSize()
    }
}

/// The warm gold mesh that morphs (mock "voice") behind the sheet and fills the
/// gap above the keyboard. Softens into the keyboard at the bottom.
struct VoiceGoldGlow: View {
    var body: some View {
        WaveGradientView(
            color1: Color(red: 247 / 255, green: 197 / 255, blue: 37 / 255),
            color2: Color(red: 255 / 255, green: 214 / 255, blue: 90 / 255),
            color3: Color(red: 250 / 255, green: 237 / 255, blue: 175 / 255),
            timeSpeed: 3.5,
            opacity: 1,
            scale: 1.3
        )
        .mask(
            // A long, multi-stop fade so the gold dissolves gently into the warm
            // white rather than cutting off with a hard edge.
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.45),
                    .init(color: .black.opacity(0.85), location: 0.62),
                    .init(color: .black.opacity(0.5), location: 0.78),
                    .init(color: .black.opacity(0.2), location: 0.9),
                    .init(color: .black.opacity(0), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

/// A dark audio meter that scrolls right → left and builds as it records, à la a
/// live voice waveform. The newest sample enters at the right; older samples flow
/// left and fade out. Purely time-driven (no real mic) so it reads as lively
/// "listening" motion. Quiet stretches collapse to dim dots, matching the Figma.
struct VoiceWaveformView: View {
    private let barCount = 44
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 4
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 24
    /// Seconds of "audio" represented by one bar of horizontal travel.
    private let step: Double = 0.05

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            // Divided down so the wave scrolls ~3× slower than raw wall-clock.
            let elapsed = timeline.date.timeIntervalSince(start) / 3.0
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let bar = bar(index: index, elapsed: elapsed)
                    Capsule(style: .continuous)
                        .fill(Theme.figmaInk.opacity(bar.recorded ? 1 : 0.5))
                        .frame(width: barWidth, height: bar.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// `index` 0 = leftmost (oldest), `barCount - 1` = rightmost (newest).
    private func bar(index: Int, elapsed: Double) -> (height: CGFloat, recorded: Bool) {
        let age = Double(barCount - 1 - index) * step
        let sampleTime = elapsed - age
        // Nothing recorded here yet → resting dot. This makes the wave build in
        // from the right as recording gets underway.
        guard sampleTime >= 0 else { return (minHeight, false) }

        // Older samples fade as they scroll off the left edge.
        let leftFade = min(1, Double(index) / 6.0)
        // Ramp in from all grey dots at the very start, then let the wave grow.
        let onset = min(1, elapsed / 1.0)
        let amplitude = noise(sampleTime) * silenceGate(sampleTime) * leftFade * onset
        let height = minHeight + (maxHeight - minHeight) * amplitude
        return (max(minHeight, height), amplitude > 0.12)
    }

    /// Layered sines → a smooth, non-uniform 0…1 envelope standing in for voice.
    private func noise(_ t: Double) -> Double {
        let a = sin(t * 7.3)
        let b = sin(t * 4.1 + 1.7)
        let c = sin(t * 12.9 + 0.5)
        return min(1, abs(0.45 * a + 0.35 * b + 0.2 * c) * 1.3)
    }

    /// A slow swell that dips to zero, so quiet gaps render as grey dots between
    /// bursts — the meter breathes instead of being a constant wall of bars.
    private func silenceGate(_ t: Double) -> Double {
        let g = sin(t * 4.5) * 0.6 + sin(t * 2.3 + 1.1) * 0.4
        return max(0, g)
    }
}
