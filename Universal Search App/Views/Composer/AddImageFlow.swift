//
//  AddImageFlow.swift
//  Universal Search App
//
//  The "attach images" flow launched from the composer's `+` button. Tapping
//  `+` closes the keyboard and presents this sheet in the keyboard's place:
//    1. `AddImageMenuView`  — Photos / Attach / Recent / Trips  (node 2641-18418)
//    2. `AddImagePhotoGridView` — a selectable curated photo grid (node 2583-17101)
//  Tapping "Add N images" hands the selection back so `ChipComposerField` can
//  render `AttachedImagesChip` above the composer text (node 2583-17114).
//
//  Curated (mock) source: the app's existing travel imagery in `ImageLibrary`,
//  so the grid shows the same stock travel photos as the design without any
//  photo-library permission.
//

import SwiftUI

// MARK: - Page

enum AddImageSheetPage: Equatable {
    case menu
    case photos
}

// MARK: - Curated catalog

enum AddImageCatalog {
    /// The travel photos from the design (Figma node 2583-17101), bundled as
    /// local assets (`Assets.xcassets/AddImagePhotos`) so the grid renders
    /// instantly and offline — no photo-library permission, no network fetch.
    static let photos: [String] = (1...11).map { "addimg\($0)" }
}

// MARK: - Inline drawer

/// Rendered by the composer host directly in the beige area below the retracted
/// input card (NOT a modal sheet), switching between the menu and the photo grid
/// in place. The host owns the page + in-progress selection (`draft`).
/// The photo grid presented as an overlay sheet over the composer (the menu is
/// rendered inline by the host; only this page is a modal sheet).
struct AddImagePhotoSheet: View {
    let catalog: [String]
    @Binding var draft: [String]
    var onBack: () -> Void
    var onAdd: () -> Void

    var body: some View {
        AddImagePhotoGridView(
            catalog: catalog,
            draft: $draft,
            onBack: onBack,
            onAdd: onAdd
        )
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.cardItem)
    }
}

// MARK: - Menu (node 2641-18418)

struct AddImageMenuView: View {
    var onPhotos: () -> Void
    var onClose: () -> Void

    /// Drives the +→× morph: the close glyph is a `plus` that rotates 45° into an
    /// × when the menu appears, and rotates back as it closes.
    @State private var morphed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                withAnimation(Theme.springSoft) { morphed = false }
                onClose()
            } label: {
                EGDSIcon("plus", size: 18)
                    .foregroundStyle(Theme.figmaInk)
                    .rotationEffect(.degrees(morphed ? 45 : 0))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.figmaChipFill))
            }
            .buttonStyle(.plain)
            .onAppear { withAnimation(Theme.springSoft) { morphed = true } }

            VStack(spacing: 8) {
                // No EGDS photo/link glyph exists yet, so these two fall back to
                // SF Symbols; Recent/Trips use the design-system glyphs.
                menuRow(label: "Photos", action: onPhotos) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .regular))
                }
                menuRow(label: "Attach", enabled: false, action: {}) {
                    Image(systemName: "link")
                        .font(.system(size: 20, weight: .regular))
                }
                menuRow(label: "Recent", enabled: false, action: {}) {
                    EGDSIcon("history", size: 22)
                }
                menuRow(label: "Trips", enabled: false, action: {}) {
                    EGDSIcon("point.topleft.down.to.point.bottomright.curvepath", size: 22)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    @ViewBuilder
    private func menuRow<Icon: View>(
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 16) {
                icon()
                    .foregroundStyle(Theme.figmaInk)
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.centra(size: 16))
                    .foregroundStyle(Theme.figmaInk)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Theme.figmaChipFill, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }
}

// MARK: - Photo grid (node 2583-17101)

struct AddImagePhotoGridView: View {
    let catalog: [String]
    @Binding var draft: [String]
    var onBack: () -> Void
    var onAdd: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(catalog, id: \.self) { key in
                        cell(key)
                    }
                }
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
    }

    private func cell(_ key: String) -> some View {
        let order = draft.firstIndex(of: key)
        let selected = order != nil
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { RemoteOrLocalImage(urlString: key) }
            .clipped()
            .overlay { if selected { Color.black.opacity(0.18) } }
            .overlay(alignment: .bottomTrailing) {
                if let order { badge(order + 1).padding(6) }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.easeOut(duration: 0.15)) { toggle(key) }
            }
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.centra(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Theme.ink))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }

    private var bottomBar: some View {
        HStack {
            Button(action: onBack) {
                EGDSIcon("chevron.left", size: 20)
                    .foregroundStyle(Theme.figmaInk)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.figmaChipFill))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !draft.isEmpty {
                Button(action: onAdd) {
                    Text(draft.count == 1 ? "Add 1 image" : "Add \(draft.count) images")
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                        .padding(.horizontal, 24)
                        .frame(height: 52)
                        .background(Capsule().fill(.white))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: draft.isEmpty)
    }

    private func toggle(_ key: String) {
        if let i = draft.firstIndex(of: key) {
            draft.remove(at: i)
        } else {
            draft.append(key)
        }
    }
}

// MARK: - Attached-images chip (node 2583-17114)

/// The pill rendered above the composer text once images are attached: a
/// stacked-thumbnail preview + "N images" + a trailing X to clear.
struct AttachedImagesChip: View {
    let images: [String]
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            thumbnails
            Text(label)
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(Theme.figmaInk)
            Button(action: onRemove) {
                EGDSIcon("xmark", size: 14)
                    .foregroundStyle(Theme.figmaInkMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Theme.figmaChipFill, in: Capsule())
    }

    private var label: String {
        images.count == 1 ? "1 image" : "\(images.count) images"
    }

    private var thumbnails: some View {
        ZStack {
            if images.count > 1 {
                thumb(images[1])
                    .rotationEffect(.degrees(8))
                    .offset(x: 7)
            }
            if let first = images.first {
                thumb(first)
                    .rotationEffect(.degrees(-5))
                    .offset(x: -2)
            }
        }
        .frame(width: 36, height: 26)
    }

    private func thumb(_ key: String) -> some View {
        RemoteOrLocalImage(urlString: key)
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1.5))
    }
}
