import SwiftUI

enum GhostMenuCategory: String {
    case destination = "Destination"
    case dates = "Dates"
    case guests = "Guests"
    case none = ""
}

@MainActor
@Observable
final class GhostMenuState {
    var anchorY: CGFloat = 0
    var category: GhostMenuCategory = .none
    var selectedCalendarDates: Set<DateComponents> = []
    var selectedCheckIn: Date? = nil
    var selectedCheckOut: Date? = nil
    var adultCount: Int = 0
    var childrenCount: Int = 0
    var infantCount: Int = 0
    var onSelectDestination: ((String) -> Void)?
    var onDismiss: (() -> Void)?
}

struct GhostContextMenuWindow: View {
    var state: GhostMenuState
    let filteredDestinations: [DestinationSuggestion]

    @State private var menuHeight: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let menuTop = max(8, state.anchorY - menuHeight - 8)

            Color.black.opacity(appeared ? 0.2 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                menuContent
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: geo.size.width - 40)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                menuHeight = height
            }
            .glassEffect(in: .rect(cornerRadius: 20))
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(y: menuTop)
            .scaleEffect(appeared ? 1 : 0.7, anchor: .bottom)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            state.onDismiss?()
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        switch state.category {
        case .destination:
            destinationContent
        case .dates:
            datesContent
        case .guests:
            guestsContent
        case .none:
            EmptyView()
        }
    }

    // MARK: - Destination

    private var destinationContent: some View {
        VStack(spacing: 12) {
            menuHeader(title: "Destination")

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredDestinations.prefix(4)) { suggestion in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                appeared = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                state.onSelectDestination?(suggestion.name)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: suggestion.imageURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color(hex: "0c0e1c").opacity(0.08)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.name)
                                        .font(.centra(size: 15, weight: .medium))
                                        .foregroundStyle(Color(hex: "1b1b1f"))
                                    Text(suggestion.subtitle)
                                        .font(.centra(size: 12, weight: .regular))
                                        .foregroundStyle(Color(hex: "1b1b1f").opacity(0.6))
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Dates

    private var datesContent: some View {
        VStack(spacing: 12) {
            menuHeader(title: "Dates")

            MultiDatePicker("", selection: Bindable(state).selectedCalendarDates, in: Date()...)
                .tint(Color(hex: "0c0e1c"))
                .padding(.horizontal, 12)
                .onChange(of: state.selectedCalendarDates) { _, dates in
                    let calendar = Calendar.current
                    let sorted = dates.compactMap { calendar.date(from: $0) }.sorted()
                    state.selectedCheckIn = sorted.first
                    state.selectedCheckOut = sorted.count > 1 ? sorted.last : nil
                }

            confirmButton
        }
        .padding(.top, 16)
    }

    // MARK: - Guests

    private var guestsContent: some View {
        VStack(spacing: 12) {
            menuHeader(title: "Guests")

            VStack(spacing: 8) {
                stepperRow(icon: "person.2", label: "Adults", subtitle: "18+ years", count: Bindable(state).adultCount)
                stepperRow(icon: "face.smiling", label: "Children", subtitle: "2-18 years", count: Bindable(state).childrenCount)
                stepperRow(icon: "bed.double", label: "Infants", subtitle: "0-2 years", count: Bindable(state).infantCount)
            }
            .padding(.horizontal, 16)

            confirmButton
        }
        .padding(.top, 16)
    }

    // MARK: - Shared

    private var confirmButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            dismiss()
        } label: {
            Text("Confirm")
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "0c0e1c"), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func menuHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.centra(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "0c0e1c").opacity(0.8))
                .tracking(-0.13)

            Spacer()

            Button { dismiss() } label: {
                EGDSIcon("xmark", size: 11)
                    .font(.centra(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "0c0e1c").opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: "0c0e1c").opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func stepperRow(icon: String, label: String, subtitle: String, count: Binding<Int>) -> some View {
        HStack {
            EGDSIcon(icon, size: 22)
                .foregroundStyle(Color(hex: "1b1b1f"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "1b1b1f"))
                Text(subtitle)
                    .font(.centra(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "1b1b1f").opacity(0.75))
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    if count.wrappedValue > 0 { count.wrappedValue -= 1 }
                } label: {
                    EGDSIcon("minus", size: 15)
                        .foregroundStyle(Color(hex: "0c0e1c").opacity(count.wrappedValue > 0 ? 0.9 : 0.25))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "0c0e1c").opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(count.wrappedValue == 0)

                Text("\(count.wrappedValue)")
                    .font(.centra(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "1b1b1f"))
                    .frame(minWidth: 20)

                Button {
                    count.wrappedValue += 1
                } label: {
                    EGDSIcon("plus", size: 15)
                        .foregroundStyle(Color(hex: "0c0e1c").opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "0c0e1c").opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
