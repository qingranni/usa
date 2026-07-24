//
//  QueryChipsView.swift
//  Universal Search App
//
//  The normalized query replay shared by every results canvas.
//

import SwiftUI

struct QueryChipsView: View {
    let query: String

    var body: some View {
        Text(query)
            .font(.centra(size: 16, weight: .medium))
            .foregroundStyle(Theme.figmaInk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Search query: \(query)")
    }
}
