//
//  QueryChipsAndFilters.swift
//  Universal Search App
//
//  Applied filters emitted by the selected data source. Empty output renders
//  nothing; this view never invents defaults.
//

import SwiftUI

struct QueryChipsAndFilters: View {
    @Bindable var store: AppStore
    let filters: [String]
    let refinements: [RefinementAction]
    var canvasLayout: ResultsCanvasLayout = .standard
    /// Leading/trailing inset for the chips. Applied as a scroll *content*
    /// margin so the row scrolls edge-to-edge instead of the viewport being
    /// clipped 28pt in from the screen edge.
    var horizontalInset: CGFloat = 28

    // Filter-chip height is aligned across all canvas layouts to match the
    // Mexico (narrative+mock) orientation rather than shrinking for others.
    private let controlHeight: CGFloat = 48

    var body: some View {
        if !filters.isEmpty || !refinements.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    EGDSIcon("slider.horizontal.3", size: 15)
                        .foregroundStyle(Theme.figmaInk)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Theme.canvasFilterChipFill, in: Circle())
                        .overlay(alignment: .topTrailing) {
                            if !filters.isEmpty {
                                Text("\(filters.count)")
                                    .font(.centra(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Theme.ink, in: Circle())
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.15))
                                    }
                                    .offset(x: 2, y: -2)
                            }
                        }

                    ForEach(filters, id: \.self) { filter in
                        HStack(spacing: 4) {
                            EGDSIcon(FilterChipIconName.forLabel(filter), size: 14)
                            Text(filter)
                        }
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk)
                        .padding(.horizontal, 16)
                        .frame(height: controlHeight)
                        .background(Theme.canvasFilterChipFill, in: Capsule())
                    }
                    ForEach(refinements) { refinement in
                        Button {
                            Task { await store.submit(refinement) }
                        } label: {
                            HStack(spacing: 4) {
                                EGDSIcon("plus", size: 14)
                                Text(refinement.label)
                            }
                                .font(.centra(size: 14))
                                .foregroundStyle(Theme.figmaInk)
                                .padding(.horizontal, 16)
                                .frame(height: controlHeight)
                                .background(Theme.canvasFilterChipFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                // The filter count badge is offset above the chip row; without
                // vertical breathing room the ScrollView clips its top edge.
                .padding(.vertical, 6)
            }
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
        }
    }

}
