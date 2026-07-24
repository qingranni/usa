import Testing
import Foundation
@testable import Universal_Search_App

struct FlightScopedComposerTests {
    @Test
    func narrativeMockDraftStartsAtHobbyWithTampaPrefilled() {
        let draft = FlightScopedComposerDraft(prefillsMockDestination: true)

        #expect(draft.step == .origin)
        #expect(draft.origin?.code == "HOU")
        #expect(draft.destination?.code == "TPA")
        #expect(draft.selectedAirport?.code == "HOU")
    }

    @Test
    func advanceStepsThroughDatesAndTravelersBeforeCompleting() {
        var draft = FlightScopedComposerDraft(prefillsMockDestination: true)

        #expect(draft.advance() == false)
        #expect(draft.step == .destination)
        #expect(draft.selectedAirport?.code == "TPA")

        #expect(draft.advance() == false)
        #expect(draft.step == .dates)

        #expect(draft.advance() == false)
        #expect(draft.step == .travelers)

        #expect(draft.advance() == true)
    }

    @Test
    func submissionQueryIncludesTravelersAndDates() {
        var draft = FlightScopedComposerDraft(prefillsMockDestination: true)

        // Defaults: 2 adults + 1 child = 3 travelers, no dates yet.
        #expect(draft.travelerLabel == "3 travelers")
        #expect(draft.submissionQuery == "Roundtrip flights from Houston (HOU) to Tampa (TPA), 3 travelers")

        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 25
        draft.departureDate = Calendar.current.date(from: comps)
        comps.day = 28
        draft.returnDate = Calendar.current.date(from: comps)

        #expect(draft.dateRangeLabel == "Aug 25–28")
        #expect(draft.submissionQuery == "Roundtrip flights from Houston (HOU) to Tampa (TPA), Aug 25–28, 3 travelers")
    }

    @Test
    func setChildrenKeepsChildAgesInSync() {
        var draft = FlightScopedComposerDraft(prefillsMockDestination: true)

        #expect(draft.children == 1)
        #expect(draft.childAges.count == 1)

        draft.setChildren(3)
        #expect(draft.children == 3)
        #expect(draft.childAges.count == 3)

        draft.setChildren(0)
        #expect(draft.children == 0)
        #expect(draft.childAges.isEmpty)
        #expect(draft.travelerLabel == "2 travelers")
    }

    @Test
    func liveDraftDoesNotInventDestination() {
        var draft = FlightScopedComposerDraft(prefillsMockDestination: false)

        #expect(draft.destination == nil)
        #expect(draft.advance() == false)
        #expect(draft.step == .destination)
        #expect(draft.canAdvance == false)
    }

    @Test
    func tampaMockPreservesExplicitHobbyOrigin() throws {
        let thread = try #require(
            DestinationData.response(
                text: "Flights from Houston (HOU) to Tampa (TPA)"
            )?.prebuiltThread
        )
        let routes = thread.activeCards.compactMap(\.title)

        #expect(thread.kind == .flights)
        #expect(!routes.isEmpty)
        #expect(routes.allSatisfy { $0 == "HOU → TPA" })
    }
}
