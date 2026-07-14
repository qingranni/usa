//
//  QueryChipsView.swift
//  Universal Search App
//
//  The query rendered as an inline sentence with chip pills, e.g.
//  "Hotels in [Miami 📍] with a [pool] and a [spa]" (QueryChips.jsx).
//

import SwiftUI

struct QueryChipsView: View {
    let chips: [QueryChip]

    private static let defaults = [
        QueryChip(label: "Miami", icon: "place"),
        QueryChip(label: "pool"),
        QueryChip(label: "spa"),
    ]

    /// Connective word before chip i (QueryChips.jsx `connective`).
    private func connective(_ i: Int) -> String? {
        switch i {
        case 0: return nil
        case 1: return " with a "
        case 2: return " and a "
        default: return " and "
        }
    }

    var body: some View {
        let items = chips.isEmpty ? Self.defaults : chips
        FlowLayout(hSpacing: 0, vSpacing: 6) {
            lead("Hotels in ")
            ForEach(Array(items.enumerated()), id: \.element.id) { i, chip in
                if i > 0, let c = connective(i) { lead(c) }
                chipPill(chip)
            }
        }
    }

    private func lead(_ s: String) -> some View {
        Text(s)
            .font(.centra(size: 18, weight: .medium))
            .foregroundStyle(Theme.darkText)
    }

    private func chipPill(_ chip: QueryChip) -> some View {
        HStack(spacing: 6) {
            if let icon = chip.icon {
                EGDSIcon(icon, size: 18).font(.centra(size: 18))
            }
            Text(chip.label)
        }
        .font(.centra(size: 18, weight: .medium))
        .foregroundStyle(Theme.darkText)
        .padding(8)
        .background(Theme.darkSurface, in: Capsule())
    }
}
