//
//  CompareChips.swift
//  Universal Search App
//
//  The multi-select category chips for the shared light query-playback card's
//  compare variant. The selection drives which A-vs-B rows the comparison canvas
//  shows (shared via store.compareAttributes). The "Compare on" label and title
//  are owned by the shared scaffold in OverviewCard.
//

import SwiftUI

struct CompareChips: View {
    @Bindable var store: AppStore
    let comparison: Comparison

    var body: some View {
        FlowLayout(hSpacing: 6, vSpacing: 6) {
            ForEach(comparison.categories) { cat in
                chip(cat.name)
            }
        }
    }

    private func chip(_ label: String) -> some View {
        let on = store.compareAttributes.contains(label)
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                if on { store.compareAttributes.remove(label) } else { store.compareAttributes.insert(label) }
            }
        } label: {
            Text(label)
                .font(.centra(size: 16))
                .foregroundStyle(on ? Color.white : Theme.figmaInk)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(on ? Theme.figmaInk : Theme.figmaChipFill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
