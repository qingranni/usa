//
//  TripHero.swift
//  Universal Search App
//
//  The trip overview's hero banner: a flat dark header with a floating back
//  button, a history / distance toggle, the trip title, and date / people chips.
//  Trip content overlaps the lower edge so the morph geometry stays stable.
//

import SwiftUI

struct TripHero: View {
    let title: String
    let safeTop: CGFloat

    var body: some View {
        let h = safeTop + 290

        ZStack(alignment: .topLeading) {
            Theme.darkBG

            VStack(alignment: .leading, spacing: 0) {
                // Space for the global NavHeader (back + history/distance toggle),
                // which floats above this hero.
                Spacer().frame(height: safeTop + 68)

                Text(title)
                    .font(.centra(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)

                HStack(spacing: 6) {
                    chip(Copy["trip.dateChip"])
                    chip(Copy["trip.peopleChip"])
                }
                .padding(.top, 12)
                .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
        }
        .frame(height: h)
        .frame(maxWidth: .infinity)
    }

    // MARK: - chips

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.centra(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(.white.opacity(0.05))
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
    }
}
