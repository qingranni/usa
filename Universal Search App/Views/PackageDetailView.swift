//
//  PackageDetailView.swift
//  Universal Search App
//
//  Full-screen package detail for the Hyatt Ziva Cancun + Flight card, rebuilt
//  1:1 from Figma 2291-33520. Opens with a slow, cinematic shared-element morph:
//  the tapped card's image glides + scales into the hero (beat 1) while the white
//  sheet materialises; the on-image chrome fades/blurs in (beat 1.5–2); the rest
//  of the page fades/blurs/rises in last (beat 3). All beats are windowed slices
//  of `store.detailReveal`, evaluated per-frame inside AnimatableMorph on the
//  long `Theme.springDetailMorph` timeline.
//

import SwiftUI

struct PackageDetailView: View {
    let store: AppStore
    let metrics: Metrics

    @State private var favorited = false

    // MARK: exact design tokens (Figma 2291-33520)

    private let cInk = Color(red: 0x0C / 255, green: 0x0E / 255, blue: 0x1C / 255)       // #0c0e1c
    private let cSurface2 = Color(red: 0xF6 / 255, green: 0xF5 / 255, blue: 0xF4 / 255)  // #f6f5f4
    private let cCard = Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xF3 / 255)      // #f7f4f3
    private let cArchiveMax = Color(red: 0x24 / 255, green: 0x22 / 255, blue: 0x20 / 255) // #242220
    private let cHeroGrad = Color(red: 0x69 / 255, green: 0x67 / 255, blue: 0x90 / 255)  // #696790
    private let cOnSurfaceVar = Color(red: 0x67 / 255, green: 0x6A / 255, blue: 0x7D / 255) // #676a7d
    private let cTextSecondary = Color(red: 0x67 / 255, green: 0x60 / 255, blue: 0x5C / 255) // #67605c
    private let cTextTertiary = Color(red: 0xB0 / 255, green: 0xAA / 255, blue: 0xA6 / 255)  // #b0aaa6
    private let cArchiveMin = Color(red: 0x8F / 255, green: 0x88 / 255, blue: 0x83 / 255)    // #8f8883
    private let cFgMax = Color(red: 0x1A / 255, green: 0x17 / 255, blue: 0x16 / 255)     // #1a1716
    private let cFgMin = Color(red: 0x75 / 255, green: 0x6C / 255, blue: 0x67 / 255)     // #756c67
    private let cTeal = Color(red: 0x00 / 255, green: 0x74 / 255, blue: 0x99 / 255)      // #007499
    private let cGlass = Color(red: 0x0C / 255, green: 0x0E / 255, blue: 0x1C / 255).opacity(0.5)

    private let cardImage = "package-cancun-hyatt-ziva"

    // MARK: geometry

    private var W: CGFloat { metrics.size.width }
    private var heroH: CGFloat { metrics.safeTop + 428 }
    private var restingHero: CGRect { CGRect(x: 0, y: 0, width: W, height: heroH) }
    private var source: CGRect {
        store.detailHeroSource == .zero
            ? CGRect(x: W / 2 - 150, y: metrics.size.height * 0.42, width: 300, height: 230)
            : store.detailHeroSource
    }

    var body: some View {
        AnimatableMorph(progress: store.detailReveal) { p in
            content(p)
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(Theme.springDetailMorph) { store.detailReveal = 1 }
            }
        }
    }

    // MARK: beat compositing

    @ViewBuilder
    private func content(_ p: MorphProgress) -> some View {
        let morphGeo = p.window(0...0.58)      // beat 1  — image flies into place
        let morphFade = p.window(0.5...0.62)   //          — hand off to resting hero
        let heroImgIn = p.window(0.46...0.6)   //          — resting hero receives it
        let bgIn = p.window(0...0.42)          // beat 1  — white sheet materialises
        let chromeIn = p.window(0.5...0.78)    // beat 1.5–2 — on-image content
        let restIn = p.window(0.66...1.0)      // beat 3  — the rest of the page

        ZStack(alignment: .top) {
            Color.white.opacity(bgIn.fadeIn).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroBlock(heroImgIn: heroImgIn, chromeIn: chromeIn)

                    VStack(spacing: 32) {
                        chipsRow
                        reviewHighlightsSection
                        mapSection
                        roomsSection
                        flightSection
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 150)
                    .beatIn(restIn, rise: 24)
                }
            }
            .ignoresSafeArea(edges: .top)

            flyingHero(morphGeo: morphGeo, morphFade: morphFade)
            bottomAsk(restIn)
        }
    }

    // MARK: - Hero

    private var heroGradient: some View {
        // Solid #696790 at the very top fading to transparent by ~41% down.
        LinearGradient(
            stops: [
                .init(color: cHeroGrad, location: 0),
                .init(color: cHeroGrad.opacity(0), location: 0.41)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func flyingHero(morphGeo: MorphProgress, morphFade: MorphProgress) -> some View {
        let r = morphGeo.rect(source, restingHero)
        return RemoteOrLocalImage(urlString: cardImage)
            .frame(width: r.width, height: r.height)
            .overlay(heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: lerp(26, 0, morphGeo.eased), style: .continuous))
            .blur(radius: Theme.morphBlurRadius * morphGeo.midPeak)
            .position(x: r.midX, y: r.midY)
            .opacity(morphFade.fadeOut)
            .allowsHitTesting(false)
    }

    private func heroBlock(heroImgIn: MorphProgress, chromeIn: MorphProgress) -> some View {
        ZStack(alignment: .top) {
            RemoteOrLocalImage(urlString: cardImage)
                .frame(width: W, height: heroH)
                .clipped()
                .overlay(heroGradient)
                .opacity(heroImgIn.fadeIn)

            VStack(spacing: 6) {
                Text("Hyatt Ziva + Flight")
                    .font(.centra(size: 32, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                ratingRow
            }
            .frame(width: 339)
            .frame(maxWidth: .infinity)
            .padding(.top, metrics.safeTop + 40)
            .beatIn(chromeIn)
        }
        .frame(width: W, height: heroH)
        .overlay(alignment: .top) {
            navButtons
                .padding(.horizontal, 32)
                .padding(.top, metrics.safeTop + 6)
                .beatIn(chromeIn)
        }
        .overlay(alignment: .bottom) {
            overlayCards
                .padding(.bottom, 22)
                .beatIn(chromeIn)
        }
    }

    private var navButtons: some View {
        HStack {
            circleButton("chevron.left") { store.closePackageDetail() }
                .accessibilityLabel("Back")
            Spacer()
            circleButton(favorited ? "heart.fill" : "heart") {
                withAnimation(Theme.springSoft) { favorited.toggle() }
            }
            .accessibilityLabel(favorited ? "Remove from favorites" : "Add to favorites")
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
            }
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(width: 1, height: 11)
            HStack(spacing: 6) {
                Text(scoreText)
                    .font(.centra(size: 12, weight: .medium))
                    .tracking(-0.18)
                    .foregroundStyle(cInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(cSurface2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(.white, lineWidth: 1))
                Text("\(store.detailCard?.reviewCount ?? 3560)")
                    .font(.centra(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private var scoreText: String {
        store.detailCard?.ratingScoreText ?? "9.2"
    }

    // MARK: - Hero overlay cards (flight + rooms)

    private var overlayCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                glassCard(thumb: "detail-flight-logo", thumbFit: false) {
                    HStack(spacing: 5) {
                        Text("HOU").fixedSize()
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                        Text("CAN").fixedSize()
                    }
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    Text("Non-stop • 5h 30m")
                        .font(.centra(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("$230")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                glassCard(thumb: "detail-rooms-thumb", thumbFit: true) {
                    Text("2 rooms")
                        .font(.centra(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Deluxe double + suite")
                        .font(.centra(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("$930")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 23)
        }
    }

    @ViewBuilder
    private func glassCard<Info: View>(thumb: String, thumbFit: Bool, @ViewBuilder info: () -> Info) -> some View {
        HStack(spacing: 16) {
            RemoteOrLocalImage(urlString: thumb)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6, content: info)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 256, alignment: .leading)
        .background(cGlass, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Chips

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("calendar", "Mar 15–21")
                chip("person.2", "3 travelers")
                chip(nil, "Seats together")
            }
            .padding(.horizontal, 32)
        }
    }

    private func chip(_ icon: String?, _ label: String) -> some View {
        HStack(spacing: 10) {
            if let icon {
                EGDSIcon(icon, size: 16).foregroundStyle(cInk)
            }
            Text(label)
                .font(.centra(size: 14, weight: .regular))
                .foregroundStyle(cInk)
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(cSurface2, in: Capsule())
    }

    // MARK: - Review + Highlights

    private var reviewHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                Text("What families with teens say")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(cInk)
                Text("Teens loved the waterslide and stayed entertained while we relaxed. Beach is calm — no big waves to worry about. Rooms are spacious enough that the kids had their own space.")
                    .font(.centra(size: 16, weight: .regular))
                    .foregroundStyle(cInk.opacity(0.5))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    highlightTile("detail-illus-bed", "Spacious\nfamily rooms",
                                  "Extra space for everyone to relax after a day at the beach")
                    highlightTile("detail-illus-controller", "Arcade room\nfor teens",
                                  "Let the kids play in the arcade room while you relax")
                }
                .padding(.horizontal, 32)
            }

            insiderRow
                .padding(.horizontal, 32)
        }
    }

    private func highlightTile(_ image: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RemoteOrLocalImage(urlString: image)
                .aspectRatio(contentMode: .fit)
                .frame(height: 104)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(cInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(cOnSurfaceVar)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 217, height: 271, alignment: .topLeading)
        .background(cSurface2, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var insiderRow: some View {
        HStack(spacing: 16) {
            RemoteOrLocalImage(urlString: "detail-illus-insider")
                .aspectRatio(contentMode: .fit)
                .frame(width: 86, height: 86)
            VStack(alignment: .leading, spacing: 4) {
                Text("Insider tip")
                    .font(.centra(size: 16, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(cInk)
                Text("Pool area can get loud at night. Request a room on the quiet side if your teens are early sleepers.")
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(cOnSurfaceVar)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Map / Activities nearby

    private var mapSection: some View {
        ZStack(alignment: .top) {
            RemoteOrLocalImage(urlString: "detail-map")
                .frame(height: 430)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: cTeal.opacity(0), location: 0.5),
                            .init(color: cTeal.opacity(0.5), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Center hotel pin
            Image(systemName: "bed.double.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(cInk, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: cInk.opacity(0.24), radius: 6, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -20)

            HStack {
                Text("Activities nearby")
                    .font(.centra(size: 16, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(cGlass, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(cGlass, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            recentActivityRow
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
        }
        .frame(height: 430)
    }

    private var recentActivityRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                activityCard("detail-activity-1", "Snorkeling", "Mar 3 — Mar 13", "Starting at $30")
                activityCard("detail-activity-2", "Water park day", "Mar 3 — Mar 13", "Starting at $95")
            }
            .padding(.horizontal, 32)
        }
    }

    private func activityCard(_ image: String, _ title: String, _ date: String, _ price: String) -> some View {
        HStack(spacing: 8) {
            RemoteOrLocalImage(urlString: image)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.centra(size: 15, weight: .medium))
                    .tracking(-0.15)
                    .foregroundStyle(cFgMax)
                Text(date)
                    .font(.centra(size: 13, weight: .regular))
                    .foregroundStyle(cFgMin)
                Text(price)
                    .font(.centra(size: 13, weight: .medium))
                    .foregroundStyle(cFgMax)
            }
            .padding(8)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: 302, alignment: .leading)
        .background(cCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Rooms + price + Reserve

    private var roomsSection: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("We think you'll love this setup")
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.32)
                    .foregroundStyle(cInk)
                Text("Two connected rooms give everyone a little more space while keeping the family close together.")
                    .font(.centra(size: 16, weight: .regular))
                    .foregroundStyle(cInk.opacity(0.5))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                roomRow("detail-room-1", "Deluxe Double", "1 Adult, 2 Children",
                        "Sleeps 4  •  2 Double Beds", "$500", "$250 per night")
                roomRow("detail-rooms-thumb", "Suite, King", "1 Adult",
                        "Sleeps 2  •  1 King Bed", "$430", "$215 per night")
            }

            HStack(alignment: .top) {
                Text("Total")
                    .font(.centra(size: 17, weight: .medium))
                    .foregroundStyle(cArchiveMax)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$930")
                        .font(.centra(size: 20, weight: .medium))
                        .tracking(-0.5)
                        .foregroundStyle(cArchiveMax)
                    Text("for 2 nights")
                        .font(.centra(size: 13, weight: .regular))
                        .foregroundStyle(cArchiveMin)
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 20) {
                Button {} label: {
                    Text("Select these rooms")
                        .font(.centra(size: 15, weight: .medium))
                        .tracking(-0.15)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(cArchiveMax, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("Choose your own rooms")
                    .font(.centra(size: 15, weight: .medium))
                    .tracking(-0.15)
                    .foregroundStyle(cArchiveMax)
            }
        }
        .padding(.horizontal, 32)
    }

    private func roomRow(_ image: String, _ title: String, _ occ1: String, _ occ2: String,
                         _ price: String, _ perNight: String) -> some View {
        HStack(spacing: 0) {
            RemoteOrLocalImage(urlString: image)
                .frame(width: 128, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(8)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.centra(size: 17, weight: .medium))
                        .foregroundStyle(cArchiveMax)
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(occ1)
                            .font(.centra(size: 13, weight: .regular))
                            .foregroundStyle(cTextSecondary)
                        Text(occ2)
                            .font(.centra(size: 13, weight: .regular))
                            .foregroundStyle(cTextTertiary)
                    }
                }
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(price)
                            .font(.centra(size: 20, weight: .medium))
                            .tracking(-0.5)
                            .foregroundStyle(cArchiveMax)
                        Text(perNight)
                            .font(.centra(size: 13, weight: .regular))
                            .foregroundStyle(cArchiveMin)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Flight options (arc + cards)

    private var flightSection: some View {
        VStack(spacing: 24) {
            arcGraphic
            VStack(spacing: 8) {
                flightDetailCard(origin: "HOU", dest: "CUN", depart: "8:10 am", arrive: "1:40 pm",
                                 stops: "Nonstop", duration: "5h 30m", airline: "United",
                                 price: "$230", cta: "Select")
                flightDetailCard(origin: "CUN", dest: "HOU", depart: "3:20 pm", arrive: "6:55 pm",
                                 stops: "Nonstop", duration: "5h 35m", airline: "United",
                                 price: "$230", cta: "Details")
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(cCard)
    }

    private var arcGraphic: some View {
        ZStack {
            // Dashed flight arc
            ArcShape()
                .stroke(cInk.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7]))
                .frame(height: 150)
                .padding(.horizontal, 40)
            RemoteOrLocalImage(urlString: "detail-airplane")
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(28))
                .offset(x: 40, y: -34)
            VStack(spacing: 2) {
                Text("Houston → Cancun")
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(cInk.opacity(0.75))
                HStack(spacing: 6) {
                    Text("Direct flights")
                        .foregroundStyle(cInk.opacity(0.6))
                    Text("3h 18m")
                        .foregroundStyle(cInk)
                }
                .font(.centra(size: 20, weight: .medium))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 150)
    }

    private func flightDetailCard(origin: String, dest: String, depart: String, arrive: String,
                                  stops: String, duration: String, airline: String,
                                  price: String, cta: String) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Text(origin).frame(width: 72, alignment: .center)
                        ZStack {
                            Rectangle().fill(cInk.opacity(0.25)).frame(height: 1)
                            Circle().fill(cInk).frame(width: 6, height: 6)
                        }
                        Text(dest).frame(width: 72, alignment: .center)
                    }
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(cInk)

                    HStack(alignment: .top, spacing: 12) {
                        Text(depart).frame(width: 72, alignment: .center)
                            .font(.centra(size: 14, weight: .medium))
                        VStack(spacing: 2) {
                            Text(duration)
                            Text(stops)
                        }
                        .font(.centra(size: 14, weight: .regular))
                        .foregroundStyle(cInk.opacity(0.7))
                        Text(arrive).frame(width: 72, alignment: .center)
                            .font(.centra(size: 14, weight: .medium))
                    }
                    .foregroundStyle(cInk)
                }

                HStack {
                    Text(airline)
                        .font(.centra(size: 14, weight: .regular))
                        .foregroundStyle(cInk.opacity(0.7))
                    Spacer()
                    RemoteOrLocalImage(urlString: "detail-flight-logo")
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Rectangle().fill(cInk.opacity(0.08)).frame(height: 1)

            HStack(spacing: 12) {
                Text(price)
                    .font(.centra(size: 20, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(cInk)
                Text("Round trip")
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(cInk.opacity(0.7))
                Spacer()
                Text(cta)
                    .font(.centra(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(cInk, in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(cInk.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Fixed chrome

    private func circleButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            EGDSIcon(icon, size: 20)
                .foregroundStyle(icon == "heart.fill" ? Color.red : cInk)
                .frame(width: 44, height: 44)
                .background(cCard, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .shadow(color: cInk.opacity(0.08), radius: 12, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func bottomAsk(_ restIn: MorphProgress) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom)
                .frame(height: 133)
                .allowsHitTesting(false)
            Text("Ask anything")
                .font(.centra(size: 14, weight: .regular))
                .foregroundStyle(cInk.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(cCard.opacity(0.9), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 1))
                .shadow(color: cInk.opacity(0.08), radius: 32, y: 12)
                .padding(.horizontal, 31)
                .padding(.bottom, metrics.safeBottom + 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .beatIn(restIn)
    }
}

/// Quarter-circle-ish flight arc: a shallow upward curve across the width.
private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.1)
        )
        return p
    }
}

private extension View {
    /// Windowed "load in" beat: fade + resolve from a soft blur (and optional
    /// upward rise) as `p` crosses its window. Endpoints are sharp.
    func beatIn(_ p: MorphProgress, blur: CGFloat = 9, rise: CGFloat = 0) -> some View {
        opacity(p.fadeIn)
            .blur(radius: blur * (1 - p.eased))
            .offset(y: rise * (1 - p.eased))
    }
}
