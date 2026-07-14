//
//  SettingsPanelView.swift
//  Universal Search App
//
//  Developer settings reached from the account button on the home navigation.
//

import SwiftUI

struct SettingsPanelView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Experience") {
                    NavigationLink {
                        DotGridPlaygroundView(showsDismissButton: false)
                            .navigationTitle("Shader settings")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        settingsRow(
                            icon: "sparkles",
                            title: "Shader settings",
                            subtitle: "Tune the dot-grid renderer"
                        )
                    }

                    NavigationLink {
                        NavStructureSettingsView(store: store)
                    } label: {
                        settingsRow(
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            title: "Nav structure",
                            subtitle: store.canvasNavigationStructure.title
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cardItem)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact(.light)
                        dismiss()
                    } label: {
                        EGDSIcon("xmark", size: 14)
                            .font(.centra(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.figmaInk)
                            .frame(width: 32, height: 32)
                            .background(Theme.figmaChipFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close settings")
                }
            }
        }
        .tint(Theme.figmaInk)
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            EGDSIcon(icon, size: 18)
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 36, height: 36)
                .background(Theme.figmaChipFill, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                Text(subtitle)
                    .font(.centra(size: 13))
                    .foregroundStyle(Theme.figmaInkMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NavStructureSettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        List {
            Section {
                option(
                    .bottomDock,
                    icon: "rectangle.bottomthird.inset.filled",
                    description: "Home and Journeys sit beside the follow-up field. No back control appears over the canvas."
                )

                option(
                    .topBar,
                    icon: "rectangle.topthird.inset.filled",
                    description: "Back and Journeys sit at the top. The follow-up field stays on its own at the bottom."
                )
            } footer: {
                Text("Changes apply immediately to the canvas and results view.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Nav structure")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.cardItem)
    }

    private func option(
        _ structure: CanvasNavigationStructure,
        icon: String,
        description: String
    ) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(Theme.fade) {
                store.canvasNavigationStructure = structure
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                EGDSIcon(icon, size: 20)
                    .foregroundStyle(Theme.figmaInk)
                    .frame(width: 36, height: 36)
                    .background(Theme.figmaChipFill, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(structure.title)
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                    Text(description)
                        .font(.centra(size: 13))
                        .foregroundStyle(Theme.figmaInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                EGDSIcon(store.canvasNavigationStructure == structure
                         ? "checkmark.circle.fill"
                         : "circle", size: 22)
                    .foregroundStyle(Theme.figmaInk)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            store.canvasNavigationStructure == structure ? .isSelected : []
        )
    }
}

#Preview {
    SettingsPanelView(store: AppStore())
}
