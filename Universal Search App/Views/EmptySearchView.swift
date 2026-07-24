//
//  EmptySearchView.swift
//  Universal Search App
//
//  Homepage matching Figma frame 1655:32315. The composer presentation remains
//  shared with the rest of the app; this view owns the personalized home feed.
//

import SwiftUI

private extension Color {
    static let homeInk = Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)
    static let homeInkMuted = Color.homeInk.opacity(0.6)
    static let homeOffWhite = Color(red: 247 / 255, green: 244 / 255, blue: 243 / 255)
    static let homeChip = Color.homeOffWhite.opacity(0.75)
    static let homePromo = Color(red: 236 / 255, green: 131 / 255, blue: 11 / 255)
}

struct EmptySearchView: View {
    let store: AppStore
    let metrics: Metrics

    @State private var showComposer = false
    @State private var showFlightComposer = false
    @State private var showSettings = false
    @State private var showSearchPillShadow = true
    @Namespace private var composerZoom
    @Namespace private var flightComposerZoom

    private let searchPillHeight: CGFloat = 66

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    searchPill
                        .padding(.horizontal, 32)
                        // The Figma frame started at y = 0 without an iOS safe
                        // area. Keep a small visual gap below the real status bar.
                        .padding(.top, metrics.safeTop + 16)

                    lineOfBusinessChips
                        .padding(.top, 22)

                    greeting
                        .padding(.horizontal, 32)
                        .padding(.vertical, 32)

                    feed
                }
            }
            .background(Color.white)

            homeNavigation
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["OPEN_COMPOSER"] != nil {
                store.composerText = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showComposer = true }
            }
        }
        .fullScreenCover(isPresented: $showComposer) {
            HomeComposerCover(store: store, metrics: metrics)
                .navigationTransition(.zoom(sourceID: "composer", in: composerZoom))
        }
        .fullScreenCover(isPresented: $showFlightComposer) {
            FlightScopedComposerView(store: store)
                .navigationTransition(
                    .zoom(sourceID: "flightScopedComposer", in: flightComposerZoom)
                )
        }
        .sheet(isPresented: $showSettings) {
            SettingsPanelView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .onChange(of: showComposer) { _, isPresented in
            if !isPresented {
                withAnimation(.easeOut(duration: 0.12)) {
                    showSearchPillShadow = true
                }
            }
        }
    }

    // MARK: - Search

    private var searchPill: some View {
        ZStack {
            searchPillChrome
                .shadow(color: Color.homeInk.opacity(0.08), radius: 16, y: 12)
                .opacity(showSearchPillShadow ? 1 : 0)

            Button { present("") } label: {
                Text(Copy["search.placeholder"])
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(Color.homeInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(searchPillChrome)
                    .overlay(Capsule().strokeBorder(Color.homeInk.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .matchedTransitionSource(id: "composer", in: composerZoom)
        }
        .frame(height: searchPillHeight)
    }

    private var searchPillChrome: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0), Color.white.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(Color.homeOffWhite.opacity(0.5), in: Capsule())
    }

    private func present(_ seed: String) {
        Haptics.impact(.light)
        store.composerText = seed
        withAnimation(.easeOut(duration: 0.08)) {
            showSearchPillShadow = false
        }
        showComposer = true
    }

    // MARK: - Line of business chips

    private var lineOfBusinessChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                lineOfBusinessChip("Stays", asset: "home-lob-stays") {
                    present("Stays")
                }
                lineOfBusinessChip("Flights", asset: "home-lob-flights") {
                    Haptics.impact(.light)
                    store.composerText = ""
                    showFlightComposer = true
                }
                .matchedTransitionSource(
                    id: "flightScopedComposer",
                    in: flightComposerZoom
                )
                lineOfBusinessChip("Cars", asset: "home-lob-cars") {
                    present("Cars")
                }
                lineOfBusinessChip("Activities", asset: "home-lob-activities") {
                    present("Activities")
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private func lineOfBusinessChip(
        _ title: String,
        asset: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.centra(size: 14))
                    .foregroundStyle(Color.homeInk)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Color.homeChip, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy["home.greetingName"])
                .foregroundStyle(Color.homeInkMuted)
            Text(Copy["home.greetingPrompt"])
                .foregroundStyle(Color.homeInk)
        }
        .font(.centra(size: 28, weight: .medium))
        .tracking(-0.5)
        .lineSpacing(0)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Feed

    private var feed: some View {
        ZStack(alignment: .top) {
            Color.homeOffWhite

            cancunHero

            VStack(alignment: .leading, spacing: 24) {
                recentActivity
                travelGuide
                    .padding(.horizontal, 32)
                inspiration
                    .padding(.leading, 32)
            }
            .padding(.top, 300)
            .padding(.bottom, 96)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var cancunHero: some View {
        ZStack(alignment: .topLeading) {
            Image("home-cancun-hero")
                .resizable()
                .scaledToFill()
                .frame(height: 500)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color(red: 0, green: 70 / 255, blue: 149 / 255).opacity(0.75), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 190)

            VStack(alignment: .leading, spacing: 12) {
                Text("2025 Spring Break recap")
                    .font(.centra(size: 32, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 15)

                HStack(spacing: 8) {
                    heroChip("5 nights")
                    heroChip("3 people")
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 36)

            LinearGradient(
                stops: [
                    .init(color: Color.homeOffWhite.opacity(0), location: 0),
                    .init(color: Color.homeOffWhite.opacity(0.25), location: 0.45),
                    .init(color: Color.homeOffWhite.opacity(0.76), location: 0.72),
                    .init(color: Color.homeOffWhite, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 277)
            .frame(maxWidth: .infinity)
            .offset(y: 223)
        }
        .frame(height: 500)
    }

    private func heroChip(_ title: String) -> some View {
        Text(title)
            .font(.centra(size: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var recentActivity: some View {
        VStack(spacing: 8) {
            hotelActivityCard
            flightActivityCard
        }
        .padding(.horizontal, 32)
    }

    private var hotelActivityCard: some View {
        Button { present("Hard Rock Hotel Cancun") } label: {
            HStack(spacing: 20) {
                recentActivityArtwork("home-cancun-hotel")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hard Rock Hotel Cancun - All Inclusive")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Color.homeInk)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text("9.2")
                            .font(.centra(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 16)
                            .background(
                                Color(red: 12 / 255, green: 147 / 255, blue: 0),
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                            )
                        Text("Excellent")
                            .font(.centra(size: 12))
                            .foregroundStyle(Color(red: 25 / 255, green: 30 / 255, blue: 59 / 255))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var flightActivityCard: some View {
        Button { present("HOUS → CUN") } label: {
            HStack(spacing: 20) {
                Image("home-expedia-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(width: 86, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("HOUS → CUN")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Color.homeInk)
                        .lineLimit(1)
                    Text("Conversation")
                        .font(.centra(size: 16))
                        .foregroundStyle(Color.homeInk.opacity(0.5))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recentActivityArtwork(_ image: String) -> some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(width: 86, height: 86)
            .clipped()
            .background(Color.homeOffWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.homeInk.opacity(0.05), lineWidth: 1)
            )
    }

    // MARK: - Below-the-fold content

    private var travelGuide: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan your itinerary with our\nRome Travel Guide")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Color.homeInk)
                Text("From neighborhood cafés to seaside dinners. Taste the Rome locals love.")
                    .font(.centra(size: 15))
                    .foregroundStyle(Color.homeInkMuted)
            }

            ZStack(alignment: .bottom) {
                Color.homePromo
                EGDSIcon("building.columns.fill", size: 96)
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
                Text("Rome")
                    .font(.centra(size: 70, weight: .bold))
                    .tracking(-1.4)
                    .foregroundStyle(Color.homeInk)
                    .padding(.bottom, 20)
            }
            .aspectRatio(338.0 / 246.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var inspiration: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get inspired for your trip")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Color.homeInk)
                Text("Handpicked stays, tips, and itineraries from featured creators for your trip to Rome.")
                    .font(.centra(size: 15))
                    .foregroundStyle(Color.homeInkMuted)
                    .padding(.trailing, 32)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    inspirationCard(
                        image: "la-1",
                        title: "Hidden Gems\naround Trevi",
                        ideas: "14 ideas",
                        avatar: "la-2",
                        creator: "frankvinyl"
                    )
                    inspirationCard(
                        image: "cancun-1",
                        title: "Family Friendly\nRome",
                        ideas: "7 ideas",
                        avatar: "cancun-2",
                        creator: "Renee’s Favorites"
                    )
                }
                .padding(.trailing, 32)
            }
        }
    }

    private func inspirationCard(
        image: String,
        title: String,
        ideas: String,
        avatar: String,
        creator: String
    ) -> some View {
        ZStack {
            Image(image)
                .resizable()
                .scaledToFill()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.centra(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                    Text(ideas)
                        .font(.centra(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    Text(creator)
                        .font(.centra(size: 15))
                        .foregroundStyle(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(width: 241, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Floating navigation

    private var homeNavigation: some View {
        ZStack(alignment: .top) {
            // Progressive blur so content dissolves as it scrolls under the bar.
            // The material is masked to fade in toward the bottom, with only a
            // light white tint over it (0 → 0.15) so the blur stays visible.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            HStack(spacing: 4) {
                navigationButton("house", selected: true)
                navigationButton("point.topleft.down.to.point.bottomright.curvepath", selected: false)
                navigationButton("person.crop.circle", selected: false)
            }
            .padding(4)
            .background(
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .background(Color.homeOffWhite.opacity(0.9), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
            .shadow(color: Color.homeInk.opacity(0.08), radius: 32, y: 12)
            .padding(.top, 44)
        }
        .frame(height: 133)
        .allowsHitTesting(true)
    }

    private func navigationButton(_ systemName: String, selected: Bool) -> some View {
        Button {
            Haptics.impact(.light)
            if systemName == "person.crop.circle" {
                showSettings = true
            }
        } label: {
            EGDSIcon(systemName, size: 22)
                .foregroundStyle(selected ? Color.white : Color.homeInk)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(selected ? Color.homeInk : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            systemName == "house" ? "Home" :
                (systemName == "person.crop.circle" ? "Account" : "Trips")
        )
    }
}
