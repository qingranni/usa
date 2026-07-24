//
//  FlightDatesCalendar.swift
//  Universal Search App
//
//  Custom vertically-scrolling multi-month calendar with date-range selection,
//  matching the Figma flight "When?" screen. Built by hand rather than the native
//  `MultiDatePicker` (used by ChipComposerField) so the grid, range band, and
//  filled endpoints match the design. Sunday-first, endpoints as filled dark
//  circles, in-range days as a light band.
//

import SwiftUI

struct FlightDatesCalendar: View {
    @Binding var departureDate: Date?
    @Binding var returnDate: Date?

    /// Number of months to render starting from the current month.
    var monthCount: Int = 12

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let cellHeight: CGFloat = 46
    private let circleSize: CGFloat = 40

    private var band: Color { Theme.figmaInk.opacity(0.06) }

    private var months: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) else { return [] }
        return (0..<monthCount).compactMap {
            calendar.date(byAdding: .month, value: $0, to: startOfMonth)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(months, id: \.self) { month in
                    monthSection(month)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 140)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthTitle(month))
                .font(.centra(size: 16, weight: .medium))
                .foregroundStyle(Theme.figmaInk)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leadingBlanks(month), id: \.self) { index in
                    Color.clear
                        .frame(height: cellHeight)
                        .id("blank-\(month)-\(index)")
                }
                ForEach(daysInMonth(month), id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let today = calendar.startOfDay(for: Date())
        let isPast = date < today
        let isStart = departureDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isEnd = returnDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isEndpoint = isStart || isEnd
        let hasRange = departureDate != nil && returnDate != nil
        let inRange: Bool = {
            guard let dep = departureDate, let ret = returnDate else { return false }
            return date > dep && date < ret
        }()
        let singleDay = isStart && isEnd
        let showBand = !singleDay && (inRange || (isEndpoint && hasRange))
        let bandLeading = inRange || isEnd
        let bandTrailing = inRange || isStart

        return Button {
            Haptics.impact(.light)
            withAnimation(Theme.fade) { handleTap(date) }
        } label: {
            ZStack {
                if showBand {
                    HStack(spacing: 0) {
                        Rectangle().fill(band).opacity(bandLeading ? 1 : 0)
                        Rectangle().fill(band).opacity(bandTrailing ? 1 : 0)
                    }
                    .frame(height: circleSize)
                }
                if isEndpoint {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: circleSize, height: circleSize)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.centra(size: 16))
                    .foregroundStyle(dayColor(isEndpoint: isEndpoint, isPast: isPast))
            }
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .accessibilityLabel(accessibilityLabel(date))
        .accessibilityAddTraits(isEndpoint ? .isSelected : [])
    }

    private func dayColor(isEndpoint: Bool, isPast: Bool) -> Color {
        if isEndpoint { return .white }
        return isPast ? Theme.figmaInk.opacity(0.25) : Theme.figmaInk
    }

    // MARK: - Selection

    private func handleTap(_ date: Date) {
        if let dep = departureDate, returnDate == nil {
            if date < dep {
                returnDate = dep
                departureDate = date
            } else {
                returnDate = date
            }
        } else {
            departureDate = date
            returnDate = nil
        }
    }

    // MARK: - Calendar math

    private func monthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }

    private func firstOfMonth(_ month: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    /// Empty leading cells before the 1st, Sunday-first.
    private func leadingBlanks(_ month: Date) -> Int {
        let weekday = calendar.component(.weekday, from: firstOfMonth(month)) // 1 = Sunday
        return weekday - 1
    }

    private func daysInMonth(_ month: Date) -> [Date] {
        let first = firstOfMonth(month)
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private func accessibilityLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}
