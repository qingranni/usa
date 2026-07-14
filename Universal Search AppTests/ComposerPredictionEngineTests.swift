import Testing
@testable import Universal_Search_App

struct ComposerPredictionEngineTests {
    @Test
    func emptyAndEarlyInputUseMissingDetailDefaults() {
        for text in ["", "L", "Lo"] {
            let state = ComposerPredictionEngine.state(for: context(text: text))
            guard case .defaults(let actions) = state else {
                Issue.record("Expected default actions for '\(text)'")
                continue
            }
            #expect(actions.map(\.label) == ["Add dates", "Add people"])
        }
    }

    @Test
    func londonPredictsShortContinuations() {
        let state = ComposerPredictionEngine.state(for: context(text: "London"))
        guard case .nextWords(let actions) = state else {
            Issue.record("Expected next-word actions")
            return
        }
        #expect(actions.map(\.label) == ["For next week", "Hotels"])
    }

    @Test
    func nextWordActionsAppendWithSentenceSpacing() {
        let state = ComposerPredictionEngine.state(for: context(text: "London"))
        guard case .nextWords(let actions) = state,
              let hotels = actions.first(where: { $0.label == "Hotels" })
        else {
            Issue.record("Expected a Hotels continuation")
            return
        }
        #expect(ComposerPredictionEngine.applying(hotels, to: "London  ") == "London hotels")
    }

    @Test
    func structuredMatchesSupersedeNextWords() {
        let state = ComposerPredictionEngine.state(
            for: context(text: "London", hasStructuredMatches: true)
        )
        guard case .confirmations = state else {
            Issue.record("Expected structured confirmations")
            return
        }
    }

    @Test
    func parserRecognizesDateAndGuestConcepts() {
        let dateMatches = SearchInputParser.parseAll(
            "today",
            existingDestination: nil,
            existingDates: nil,
            existingGuests: 0
        )
        #expect(dateMatches.first?.resolvedCheckIn != nil)

        let guestMatches = SearchInputParser.parseAll(
            "3 people",
            existingDestination: nil,
            existingDates: nil,
            existingGuests: 0
        )
        #expect(guestMatches.first?.resolvedAdults == 3)
    }

    @Test
    func countryRequiresItsFullName() {
        let partial = SearchInputParser.parseAll(
            "spa",
            existingDestination: nil,
            existingDates: nil,
            existingGuests: 0
        )
        #expect(partial.isEmpty)

        let exact = SearchInputParser.parseAll(
            "Spain",
            existingDestination: nil,
            existingDates: nil,
            existingGuests: 0
        )
        #expect(!exact.isEmpty)
        #expect(exact.allSatisfy { $0.resolvedDestination?.contains("Spain") == true })
    }

    private func context(
        text: String,
        hasDestination: Bool = false,
        hasDates: Bool = false,
        hasGuests: Bool = false,
        hasStructuredMatches: Bool = false
    ) -> ComposerPredictionContext {
        ComposerPredictionContext(
            text: text,
            hasDestination: hasDestination,
            hasDates: hasDates,
            hasGuests: hasGuests,
            hasStructuredMatches: hasStructuredMatches
        )
    }
}
