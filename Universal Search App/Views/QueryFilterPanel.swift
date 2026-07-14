//
//  QueryChipsAndFilters.swift
//  Universal Search App
//
//  Suggested-filter chips for the shared light query-playback card's results
//  variant. Tapping a filter sends it as a follow-up. The query title and the
//  "Refine" label are owned by the shared scaffold in OverviewCard.
//

import SwiftUI

struct QueryChipsAndFilters: View {
    @Bindable var store: AppStore
    let thread: ThreadNode

    private let suggested = Copy.list("refineSuggestions")

    var body: some View {
        FlowLayout(hSpacing: 6, vSpacing: 6) {
            ForEach(suggested, id: \.self) { f in
                Button { Task { await store.send(f, refine: true) } } label: {
                    Text(f)
                        .font(.centra(size: 16))
                        .foregroundStyle(Theme.figmaInk)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Theme.figmaChipFill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            EGDSIcon("add", size: 18)
                .font(.centra(size: 18))
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 38, height: 38)
                .background(Theme.figmaChipFill, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
