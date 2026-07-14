import Foundation

struct ParsedMatch {
    enum MatchType { case destination, dates, guests }
    let type: MatchType
    let matchedText: String
    let range: Range<String.Index>
    let highlightRange: Range<String.Index>
    let resolvedDestination: String?
    let resolvedCheckIn: Date?
    let resolvedCheckOut: Date?
    let resolvedAdults: Int?
    let resolvedChildren: Int?
    let resolvedInfants: Int?
    var displayLabel: String? = nil
}

struct SearchInputParser {

    static func parse(
        _ text: String,
        existingDestination: String?,
        existingDates: Date?,
        existingGuests: Int
    ) -> ParsedMatch? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if existingDestination == nil, let match = matchDestination(in: text) {
            return match
        }
        if existingDates == nil, let match = matchDates(in: text) {
            return match
        }
        if existingGuests == 0, let match = matchGuests(in: text) {
            return match
        }
        return nil
    }

    static func parseAll(
        _ text: String,
        existingDestination: String?,
        existingDates: Date?,
        existingGuests: Int
    ) -> [ParsedMatch] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        if existingDestination == nil {
            let matches = matchAllDestinations(in: text, limit: 4)
            if !matches.isEmpty { return matches }
        }
        if existingDates == nil, let match = matchDates(in: text) {
            return [match] + fabricateDateAlternates(from: match, text: text)
        }
        if existingGuests == 0, let match = matchGuests(in: text) {
            return [match]
        }
        return []
    }

    // MARK: - Destination

    static func normalize(_ string: String) -> String {
        string.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    }

    private struct ScoredDestinationMatch {
        let suggestion: DestinationSuggestion
        let matchRange: Range<String.Index>
        let score: Double
    }

    private static func scoreDestinations(in text: String) -> [ScoredDestinationMatch] {
        let normalized = normalize(text)
        var candidates: [ScoredDestinationMatch] = []

        for suggestion in ChipComposerCatalog.destinationSuggestions {
            let cityName = suggestion.name.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? suggestion.name
            let countryName = suggestion.name.components(separatedBy: ",").last?
                .trimmingCharacters(in: .whitespaces)

            var bestForSuggestion: ScoredDestinationMatch? = nil

            var candidateNames: [(name: String, isCountry: Bool)] = [
                (cityName, false),
            ]
            if let countryName {
                candidateNames.append((countryName, true))
            }

            for candidateEntry in candidateNames {
                let candidate = candidateEntry.name
                let candidateNorm = normalize(candidate)

                if let matchRange = normalized.range(of: candidateNorm) {
                    let afterMatch = text[matchRange.upperBound...]
                    guard afterMatch.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                    let scored = ScoredDestinationMatch(suggestion: suggestion, matchRange: matchRange, score: 1.0)
                    if bestForSuggestion == nil || scored.score > bestForSuggestion!.score {
                        bestForSuggestion = scored
                    }
                } else {
                    // Country prefixes are too ambiguous for incremental
                    // prediction ("spa" should remain a spa query, not Spain).
                    // A country is still recognized once its full name is typed.
                    guard !candidateEntry.isCountry else { continue }
                    let trailingWord = extractTrailingWord(from: normalized)
                    guard trailingWord.count >= 3 else { continue }
                    guard candidateNorm.hasPrefix(trailingWord) else { continue }

                    let ratio = Double(trailingWord.count) / Double(candidateNorm.count)
                    guard let wordRange = normalized.range(of: trailingWord, options: .backwards) else { continue }
                    let afterMatch = normalized[wordRange.upperBound...]
                    guard afterMatch.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

                    let scored = ScoredDestinationMatch(suggestion: suggestion, matchRange: wordRange, score: ratio)
                    if bestForSuggestion == nil || scored.score > bestForSuggestion!.score {
                        bestForSuggestion = scored
                    }
                }
            }

            if let best = bestForSuggestion {
                candidates.append(best)
            }
        }

        return candidates.sorted { $0.score > $1.score }
    }

    private static func matchDestination(in text: String) -> ParsedMatch? {
        guard let best = scoreDestinations(in: text).first else { return nil }
        let expandedRange = expandToFillerWords(in: text, around: best.matchRange)
        return ParsedMatch(
            type: .destination,
            matchedText: String(text[best.matchRange]),
            range: expandedRange,
            highlightRange: best.matchRange,
            resolvedDestination: best.suggestion.name,
            resolvedCheckIn: nil,
            resolvedCheckOut: nil,
            resolvedAdults: nil,
            resolvedChildren: nil,
            resolvedInfants: nil
        )
    }

    private static func matchAllDestinations(in text: String, limit: Int) -> [ParsedMatch] {
        let ranked = scoreDestinations(in: text).prefix(limit)
        return ranked.map { scored in
            let expandedRange = expandToFillerWords(in: text, around: scored.matchRange)
            return ParsedMatch(
                type: .destination,
                matchedText: String(text[scored.matchRange]),
                range: expandedRange,
                highlightRange: scored.matchRange,
                resolvedDestination: scored.suggestion.name,
                resolvedCheckIn: nil,
                resolvedCheckOut: nil,
                resolvedAdults: nil,
                resolvedChildren: nil,
                resolvedInfants: nil
            )
        }
    }

    static func extractTrailingWord(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let components = trimmed.components(separatedBy: .whitespaces)
        return components.last ?? ""
    }

    // MARK: - Dates

    private static let relativeDatePatterns: [(pattern: String, resolver: () -> (Date, Date?))] = {
        [
            ("next month", {
                let cal = Calendar.current
                guard let nextMonth = cal.date(byAdding: .month, value: 1, to: Date()),
                      let start = cal.date(from: cal.dateComponents([.year, .month], from: nextMonth)),
                      let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
                else { return (Date(), nil) }
                return (start, end)
            }),
            ("next week", {
                let cal = Calendar.current
                let today = Date()
                let weekday = cal.component(.weekday, from: today)
                let daysToMonday = (9 - weekday) % 7
                let monday = cal.date(byAdding: .day, value: max(daysToMonday, 1), to: today)!
                let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
                return (monday, sunday)
            }),
            ("next weekend", {
                let cal = Calendar.current
                let today = Date()
                let weekday = cal.component(.weekday, from: today)
                let daysToSat = (14 - weekday) % 7 + 7
                let saturday = cal.date(byAdding: .day, value: daysToSat, to: today)!
                let sunday = cal.date(byAdding: .day, value: 1, to: saturday)!
                return (saturday, sunday)
            }),
            ("this weekend", {
                let cal = Calendar.current
                let today = Date()
                let weekday = cal.component(.weekday, from: today)
                let daysToSat = (7 - weekday) % 7
                let saturday = cal.date(byAdding: .day, value: max(daysToSat, 1), to: today)!
                let sunday = cal.date(byAdding: .day, value: 1, to: saturday)!
                return (saturday, sunday)
            }),
            ("tomorrow", {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                return (tomorrow, nil)
            }),
            ("today", {
                return (Date(), nil)
            }),
        ]
    }()

    private static let monthNames: [String: Int] = [
        "jan": 1, "january": 1,
        "feb": 2, "february": 2,
        "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "jun": 6, "june": 6,
        "jul": 7, "july": 7,
        "aug": 8, "august": 8,
        "sep": 9, "september": 9,
        "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "december": 12,
    ]

    private static func matchDates(in text: String) -> ParsedMatch? {
        let lower = text.lowercased()

        for (pattern, resolver) in relativeDatePatterns {
            guard let matchRange = lower.range(of: pattern) else { continue }
            let afterMatch = text[matchRange.upperBound...]
            guard afterMatch.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let (checkIn, checkOut) = resolver()
            let expandedRange = expandToFillerWords(in: text, around: matchRange)

            return ParsedMatch(
                type: .dates,
                matchedText: String(text[matchRange]),
                range: expandedRange,
                highlightRange: matchRange,
                resolvedDestination: nil,
                resolvedCheckIn: checkIn,
                resolvedCheckOut: checkOut,
                resolvedAdults: nil,
                resolvedChildren: nil,
                resolvedInfants: nil
            )
        }

        if let match = matchAbsoluteDate(in: text) {
            return match
        }

        return nil
    }

    private static func matchAbsoluteDate(in text: String) -> ParsedMatch? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)

        // "Feb 14-15", "Feb 14 - 15", "February 14-15"
        let rangePattern = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})\s*[-–]\s*(\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: rangePattern, options: .caseInsensitive),
           let nsMatch = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {

            let monthStr = (lower as NSString).substring(with: nsMatch.range(at: 1))
            let day1Str = (lower as NSString).substring(with: nsMatch.range(at: 2))
            let day2Str = (lower as NSString).substring(with: nsMatch.range(at: 3))

            if let month = monthNames[monthStr],
               let day1 = Int(day1Str),
               let day2 = Int(day2Str) {
                let (checkIn, checkOut) = resolveDates(month: month, day1: day1, day2: day2)
                let matchedRange = Range(nsMatch.range, in: lower)!
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.lowerBound))
                    ..< text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.upperBound))
                let expandedRange = expandToFillerWords(in: text, around: originalRange)

                return ParsedMatch(
                    type: .dates,
                    matchedText: String(text[originalRange]),
                    range: expandedRange,
                    highlightRange: originalRange,
                    resolvedDestination: nil,
                    resolvedCheckIn: checkIn,
                    resolvedCheckOut: checkOut,
                    resolvedAdults: nil,
                    resolvedChildren: nil,
                    resolvedInfants: nil
                )
            }
        }

        // "Feb 14", "February 14"
        let singlePattern = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})\b"#
        if let regex = try? NSRegularExpression(pattern: singlePattern, options: .caseInsensitive),
           let nsMatch = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {

            let afterEnd = lower.index(lower.startIndex, offsetBy: nsMatch.range.location + nsMatch.range.length)
            let trailing = lower[afterEnd...].trimmingCharacters(in: .whitespaces)
            guard trailing.isEmpty else { return nil }

            let monthStr = (lower as NSString).substring(with: nsMatch.range(at: 1))
            let dayStr = (lower as NSString).substring(with: nsMatch.range(at: 2))

            if let month = monthNames[monthStr], let day = Int(dayStr) {
                let (checkIn, _) = resolveDates(month: month, day1: day, day2: nil)
                let matchedRange = Range(nsMatch.range, in: lower)!
                let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.lowerBound))
                    ..< text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.upperBound))
                let expandedRange = expandToFillerWords(in: text, around: originalRange)

                return ParsedMatch(
                    type: .dates,
                    matchedText: String(text[originalRange]),
                    range: expandedRange,
                    highlightRange: originalRange,
                    resolvedDestination: nil,
                    resolvedCheckIn: checkIn,
                    resolvedCheckOut: nil,
                    resolvedAdults: nil,
                    resolvedChildren: nil,
                    resolvedInfants: nil
                )
            }
        }

        return nil
    }

    private static func resolveDates(month: Int, day1: Int, day2: Int?) -> (Date, Date?) {
        let cal = Calendar.current
        var year = cal.component(.year, from: Date())
        var comps = DateComponents(year: year, month: month, day: day1)
        var date1 = cal.date(from: comps) ?? Date()

        if date1 < Date() {
            year += 1
            comps.year = year
            date1 = cal.date(from: comps) ?? Date()
        }

        var date2: Date? = nil
        if let d2 = day2 {
            var comps2 = DateComponents(year: year, month: month, day: d2)
            date2 = cal.date(from: comps2)
            if let d = date2, d < date1 {
                comps2.month = month + 1
                date2 = cal.date(from: comps2)
            }
        }

        return (date1, date2)
    }

    // MARK: - Date Alternates

    static func monthName(for month: Int, short: Bool = false) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return short ? fmt.shortMonthSymbols[month - 1] : fmt.monthSymbols[month - 1]
    }

    private static func fabricateDateAlternates(from match: ParsedMatch, text: String) -> [ParsedMatch] {
        guard let checkIn = match.resolvedCheckIn else { return [] }
        let cal = Calendar.current
        let targetMonth = cal.component(.month, from: checkIn)
        let monthFull = monthName(for: targetMonth)

        var alternates: [ParsedMatch] = []

        let isRange = match.resolvedCheckOut != nil
        let spansMonth: Bool = {
            guard let checkOut = match.resolvedCheckOut else { return false }
            let start = cal.component(.day, from: checkIn)
            let end = cal.component(.day, from: checkOut)
            guard let range = cal.range(of: .day, in: .month, for: checkIn) else { return false }
            return start == 1 && end == range.count
        }()

        if !spansMonth {
            if let (flexStart, flexEnd) = monthRange(month: targetMonth, from: checkIn) {
                alternates.append(alternateMatch(
                    match: match,
                    label: "Flexible in \(monthFull)",
                    checkIn: flexStart,
                    checkOut: flexEnd
                ))
            }
        }

        if let (satStart, sunEnd) = firstWeekendInMonth(from: checkIn) {
            let weekendLabel = isRange ? "\(monthFull) weekend" : "\(monthFull) weekend"
            alternates.append(alternateMatch(
                match: match,
                label: weekendLabel,
                checkIn: satStart,
                checkOut: sunEnd
            ))
        }

        return alternates
    }

    private static func monthRange(month: Int, from reference: Date) -> (Date, Date)? {
        let cal = Calendar.current
        let year = cal.component(.year, from: reference)
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let start = cal.date(from: comps) else { return nil }
        guard let range = cal.range(of: .day, in: .month, for: start) else { return nil }
        comps.day = range.count
        guard let end = cal.date(from: comps) else { return nil }
        return (start, end)
    }

    private static func firstWeekendInMonth(from reference: Date) -> (Date, Date)? {
        let cal = Calendar.current
        let year = cal.component(.year, from: reference)
        let month = cal.component(.month, from: reference)
        for day in 1...7 {
            var comps = DateComponents(year: year, month: month, day: day)
            guard let candidate = cal.date(from: comps) else { continue }
            if cal.component(.weekday, from: candidate) == 7 {
                comps.day = day + 1
                guard let sunday = cal.date(from: comps) else { return nil }
                return (candidate, sunday)
            }
        }
        return nil
    }

    private static func alternateMatch(
        match: ParsedMatch,
        label: String,
        checkIn: Date,
        checkOut: Date?
    ) -> ParsedMatch {
        ParsedMatch(
            type: .dates,
            matchedText: match.matchedText,
            range: match.range,
            highlightRange: match.highlightRange,
            resolvedDestination: nil,
            resolvedCheckIn: checkIn,
            resolvedCheckOut: checkOut,
            resolvedAdults: nil,
            resolvedChildren: nil,
            resolvedInfants: nil,
            displayLabel: label
        )
    }

    // MARK: - Guests

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
    ]

    private static func matchGuests(in text: String) -> ParsedMatch? {
        let lower = text.lowercased()

        // "2 adults", "3 children", "1 infant", "2 guests", "4 people", "2 kids", "1 baby"
        let guestPattern = #"(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(guests?|people|adults?|children|child|kids?|infants?|bab(?:y|ies))"#
        if let regex = try? NSRegularExpression(pattern: guestPattern, options: .caseInsensitive),
           let nsMatch = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {

            let afterEnd = lower.index(lower.startIndex, offsetBy: nsMatch.range.location + nsMatch.range.length)
            let trailing = lower[afterEnd...].trimmingCharacters(in: .whitespaces)
            guard trailing.isEmpty else { return nil }

            let numStr = (lower as NSString).substring(with: nsMatch.range(at: 1))
            let typeStr = (lower as NSString).substring(with: nsMatch.range(at: 2))
            let count = Int(numStr) ?? numberWords[numStr] ?? 1

            var adults: Int? = nil
            var children: Int? = nil
            var infants: Int? = nil

            switch typeStr {
            case let s where s.hasPrefix("adult"):
                adults = count
            case let s where s.hasPrefix("child"), let s where s.hasPrefix("kid"):
                children = count
            case let s where s.hasPrefix("infant"), let s where s.hasPrefix("bab"):
                infants = count
            default:
                adults = count
            }

            let matchedRange = Range(nsMatch.range, in: lower)!
            let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.lowerBound))
                ..< text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.upperBound))
            let expandedRange = expandToFillerWords(in: text, around: originalRange)

            return ParsedMatch(
                type: .guests,
                matchedText: String(text[originalRange]),
                range: expandedRange,
                highlightRange: originalRange,
                resolvedDestination: nil,
                resolvedCheckIn: nil,
                resolvedCheckOut: nil,
                resolvedAdults: adults,
                resolvedChildren: children,
                resolvedInfants: infants
            )
        }

        // "for 2" at end of text
        let forPattern = #"for\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b"#
        if let regex = try? NSRegularExpression(pattern: forPattern, options: .caseInsensitive),
           let nsMatch = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {

            let afterEnd = lower.index(lower.startIndex, offsetBy: nsMatch.range.location + nsMatch.range.length)
            let trailing = lower[afterEnd...].trimmingCharacters(in: .whitespaces)
            guard trailing.isEmpty else { return nil }

            let numStr = (lower as NSString).substring(with: nsMatch.range(at: 1))
            let count = Int(numStr) ?? numberWords[numStr] ?? 1

            let matchedRange = Range(nsMatch.range, in: lower)!
            let originalRange = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.lowerBound))
                ..< text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: matchedRange.upperBound))

            return ParsedMatch(
                type: .guests,
                matchedText: String(text[originalRange]),
                range: originalRange,
                highlightRange: originalRange,
                resolvedDestination: nil,
                resolvedCheckIn: nil,
                resolvedCheckOut: nil,
                resolvedAdults: count,
                resolvedChildren: nil,
                resolvedInfants: nil
            )
        }

        return nil
    }

    // MARK: - Helpers

    private static let fillerWords: Set<String> = ["for", "in", "to", "on", "at", "the", "around", "near"]

    private static func expandToFillerWords(in text: String, around range: Range<String.Index>) -> Range<String.Index> {
        return range
    }
}
