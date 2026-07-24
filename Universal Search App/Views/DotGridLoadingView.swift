//
//  DotGridLoadingView.swift
//  Universal Search App
//
//  Full-screen loading state shown while a query is in flight. The flat dot
//  grid fades in, pulses out repeating shockwaves from the centre, then fades
//  away as the real results reveal beneath it. (No globe morph.)
//

import AVFoundation
import SwiftUI

/// The animated dot grid used as the launch-sequence backdrop: it fades in and
/// scales down from 1.04, then pulses repeating shockwaves — the same entry
/// treatment the full-screen loading curtain uses, but with no dark background
/// or label of its own (the launch chrome supplies those).
struct LaunchDotGrid: View {
    @State private var appeared = false
    @State private var controller = DotGridController()
    @State private var pulseTask: Task<Void, Never>?

    private let interval: Duration = .seconds(2)

    var body: some View {
        DotGridView(params: .default, controller: controller)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 1.04)
            .onAppear {
                controller.mode = .flat
                withAnimation(.easeOut(duration: 0.6)) { appeared = true }
                pulseTask = Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    while !Task.isCancelled {
                        controller.fire(.shockwave)
                        try? await Task.sleep(for: interval)
                    }
                }
            }
            .onDisappear {
                pulseTask?.cancel()
                pulseTask = nil
            }
    }
}

struct DotGridLoadingView: View {
    /// Phase 1 opacity fade-in of the grid.
    @State private var appeared = false
    /// Controls the flat grid and fires the shockwave events.
    @State private var controller = DotGridController()
    /// The repeating shockwave loop; cancelled when the overlay is removed.
    @State private var pulseTask: Task<Void, Never>?

    /// Seconds between shockwaves.
    private let interval: Duration = .seconds(2)

    var body: some View {
        ZStack {
            // Match the shader's dark clear color so the glow reads.
            Color(red: 0.02, green: 0.015, blue: 0.0)
                .ignoresSafeArea()

            DotGridView(params: .default, controller: controller)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 1.04)

            Text(Copy["search.searching"])
                .font(.centra(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 120)
                .allowsHitTesting(false)
        }
        // Black background appears instantly on insert (so the screen goes
        // black first); only the dot grid fades in via `appeared`. Removal
        // fades the whole overlay out to the results — the grid "disappears".
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        .onAppear {
            controller.mode = .flat
            Task {
                // Hold black for a beat, then fade the dot grid in.
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            }
            // Repeating shockwaves radiating from the centre while loading.
            pulseTask = Task {
                try? await Task.sleep(for: .seconds(0.5))
                while !Task.isCancelled {
                    controller.fire(.shockwave)
                    try? await Task.sleep(for: interval)
                }
            }
        }
        .onDisappear {
            pulseTask?.cancel()
            pulseTask = nil
        }
    }
}

/// Homepage-only loading cover from Figma 1780:17687. The source video is
/// portrait, so it aspect-fills the centered 402×450 pt band and crops its top
/// and bottom. A soft mask blends the band into the warm full-screen surface.
struct HomeLoadingVideoView: View {
    private let background = Theme.cardItem

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / Theme.frameWidth
            let videoHeight = 450.477 * widthScale
            let labelY = proxy.size.height * (602 / Theme.frameHeight)

            ZStack {
                background

                LoopingVideoView(
                    resource: "loading_suitcase",
                    gravity: .resizeAspectFill,
                    backgroundColor: background
                )
                .frame(width: proxy.size.width, height: videoHeight)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                Text(Copy["results.loadingResults"])
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.ink)
                    .position(x: proxy.size.width / 2, y: labelY)
            }
        }
        .background(background)
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
    }
}
