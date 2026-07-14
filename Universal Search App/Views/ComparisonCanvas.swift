//
//  ComparisonCanvas.swift
//  Universal Search App
//
//  Compare presentation for the results (white sheet) stage: two hotel options
//  side by side, then the A-vs-B rows for the attributes selected via the
//  details panel's "Compare on" chips (store.compareAttributes). Content-only —
//  the parent CurtainSheet hosts the ScrollView.
//

import SwiftUI

struct ComparisonCanvas: View {
    @Bindable var store: AppStore
    let comparison: Comparison

    private var selectedCategories: [CompareCategory] {
        comparison.categories.filter { store.compareAttributes.contains($0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 14) {
                optionColumn(title: comparison.titleA, image: comparison.imageA, price: comparison.priceA)
                optionColumn(title: comparison.titleB, image: comparison.imageB, price: comparison.priceB)
            }

            if selectedCategories.isEmpty {
                Text(Copy["compare.emptyPrompt"])
                    .font(.centra(size: 14))
                    .foregroundStyle(Theme.inkMuted)
            } else {
                ForEach(selectedCategories) { cat in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(cat.name)
                            .font(.centra(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.bottom, 4)
                        ForEach(Array(cat.rows.enumerated()), id: \.element.id) { i, h in
                            if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)) }
                            highlightRow(h)
                        }
                    }
                }
            }
        }
    }

    private func optionColumn(title: String, image: String?, price: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteOrLocalImage(urlString: image)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.cardShadow, radius: 14, y: 2)
            Text(title)
                .font(.centra(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            if let price {
                Text(price)
                    .font(.centra(size: 15))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightRow(_ h: CompareHighlight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(h.label)
                .font(.centra(size: 13))
                .foregroundStyle(Theme.inkMuted)
            HStack(spacing: 14) {
                Text(h.a)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(h.b)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.centra(size: 15, weight: .medium))
            .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 12)
    }
}
