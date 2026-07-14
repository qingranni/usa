//
//  DotGridPlaygroundView.swift
//  Universal Search App
//
//  A live tuning surface for the dot-grid shader. The full grid renders behind
//  a translucent control panel of sliders; every knob updates the shader in
//  real time. "Copy" puts the current values on the clipboard as ready-to-paste
//  Swift so a look can be dialed in here and hard-coded later.
//
//  Opened from the home screen's "Discover itineraries" chip. Debug/design tool.
//

import SwiftUI

struct DotGridPlaygroundView: View {
    @Environment(\.dismiss) private var dismiss

    var showsDismissButton = true

    @State private var params = DotGridParams.default
    @State private var controller = DotGridController()
    @State private var showControls = true
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.02, green: 0.015, blue: 0.0).ignoresSafeArea()

            DotGridView(params: params, controller: controller)
                .ignoresSafeArea()

            topBar

            if showControls { controlPanel }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            if showsDismissButton {
                iconButton("xmark") { dismiss() }
            }
            Spacer()
            Button {
                copyValues()
            } label: {
                Label {
                    Text(copied ? "Copied!" : "Copy")
                } icon: {
                    EGDSIcon(copied ? "checkmark" : "doc.on.doc", size: 15)
                }
                    .font(.centra(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            iconButton("slider.horizontal.3") { withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() } }
            iconButton("arrow.counterclockwise") { withAnimation { params = .default } }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }

    private func iconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            EGDSIcon(system, size: 18)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - control panel

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                group("Mode") {
                    Picker("Mode", selection: $controller.mode) {
                        ForEach(DotGridMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                group("Events") {
                    FlowButtons(events: DotGridEvent.allCases) { controller.fire($0) }
                }
                group("Grid") {
                    stepperRow("Grid count", value: Binding(
                        get: { Float(params.gridCount) },
                        set: { params.gridCount = Int($0) }), 8...160, step: 1, fmt: "%.0f")
                    slider("Dot sprite size", $params.pointSize, 20...260)
                    slider("Wave amplitude", $params.amplitude, 0...1.2)
                    slider("Speed", $params.speed, 0...0.6)
                }
                group("Wave shape") {
                    slider("Frequency (primary)", $params.waveFreq, 0.4...6)
                    slider("Frequency (secondary)", $params.waveFreq2, 0.4...10)
                    slider("Secondary amount", $params.wave2Amp, 0...1)
                }
                group("Glow") {
                    slider("Core sharpness", $params.coreSharp, 4...120)
                    slider("Core strength", $params.coreStrength, 0...2)
                    slider("Halo spread (lower = wider)", $params.haloSpread, 0.5...12)
                    slider("Halo strength", $params.haloStrength, 0...1.2)
                }
                group("Bloom vs. wave height") {
                    slider("Sprite scale · trough", $params.bloomMin, 0...2)
                    slider("Sprite scale · crest", $params.bloomMax, 0...4)
                    slider("Brightness · trough", $params.shadeMin, 0...1.5)
                    slider("Brightness · crest", $params.shadeMax, 0...2.5)
                }
                group("Hue drift") {
                    slider("Warm push (crest)", $params.hueWarm, 0...1)
                    slider("Cool push (trough)", $params.hueCool, 0...1)
                }
                group("Ripple reveal") {
                    slider("Resting visibility", $params.ambientVis, 0...1)
                    slider("Reveal strength", $params.revealGain, 0...4)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 420)
        .background(.ultraThinMaterial)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .transition(.move(edge: .bottom))
    }

    private func group<Content: View>(_ title: String,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.centra(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 12)
            content()
        }
    }

    private func slider(_ label: String, _ value: Binding<Float>,
                        _ range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.centra(size: 13)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.centra(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range)
                .tint(.orange)
        }
    }

    private func stepperRow(_ label: String, value: Binding<Float>,
                           _ range: ClosedRange<Float>, step: Float, fmt: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.centra(size: 13)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(String(format: fmt, value.wrappedValue))
                    .font(.centra(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: step)
                .tint(.orange)
        }
    }

    // MARK: - copy

    private func copyValues() {
        UIPasteboard.general.string = swiftSnippet
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { copied = false }
        }
    }

    /// Emits both a `DotGridView(...)` call for the three headline knobs and a
    /// full `DotGridParams` block for everything else.
    private var swiftSnippet: String {
        func f(_ v: Float) -> String { String(format: "%g", v) }
        return """
        // DotGridView call (headline knobs):
        DotGridView(gridCount: \(params.gridCount), pointSize: \(f(params.pointSize)), amplitude: \(f(params.amplitude)))

        // Full params (paste into DotGridParams defaults):
        var params = DotGridParams()
        params.gridCount    = \(params.gridCount)
        params.pointSize    = \(f(params.pointSize))
        params.amplitude    = \(f(params.amplitude))
        params.speed        = \(f(params.speed))
        params.waveFreq     = \(f(params.waveFreq))
        params.waveFreq2    = \(f(params.waveFreq2))
        params.wave2Amp     = \(f(params.wave2Amp))
        params.coreSharp    = \(f(params.coreSharp))
        params.coreStrength = \(f(params.coreStrength))
        params.haloSpread   = \(f(params.haloSpread))
        params.haloStrength = \(f(params.haloStrength))
        params.bloomMin     = \(f(params.bloomMin))
        params.bloomMax     = \(f(params.bloomMax))
        params.shadeMin     = \(f(params.shadeMin))
        params.shadeMax     = \(f(params.shadeMax))
        params.hueWarm      = \(f(params.hueWarm))
        params.hueCool      = \(f(params.hueCool))
        params.ambientVis   = \(f(params.ambientVis))
        params.revealGain   = \(f(params.revealGain))
        """
    }
}

/// A wrapping row of tappable event buttons.
private struct FlowButtons: View {
    let events: [DotGridEvent]
    let fire: (DotGridEvent) -> Void

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(events) { event in
                Button { fire(event) } label: {
                    Text(event.label)
                        .font(.centra(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    DotGridPlaygroundView()
}
