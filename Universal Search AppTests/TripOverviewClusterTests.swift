import Testing
@testable import Universal_Search_App

struct TripOverviewClusterTests {
    @Test
    func threeOrFewerOverviewItemsDoNotCluster() {
        #expect(DeterministicTripOverviewClusterer.clusters(for: items(count: 1)).isEmpty)
        #expect(DeterministicTripOverviewClusterer.clusters(for: items(count: 3)).isEmpty)
    }

    @Test
    func fourOrMoreOverviewItemsAreClusteredExactlyOnce() {
        let input = [
            item("stay-1", kind: "lodging", index: 0),
            item("stay-2", kind: "lodging", index: 1),
            item("flight-1", kind: "flights", index: 2),
            item("compare-1", kind: "other", type: "compare", index: 3),
        ]

        let clusters = DeterministicTripOverviewClusterer.clusters(for: input)
        let clusteredIDs = clusters.flatMap(\.itemIDs)

        #expect((2...4).contains(clusters.count))
        #expect(clusteredIDs.count == input.count)
        #expect(Set(clusteredIDs) == Set(input.map(\.id)))
    }

    private func items(count: Int) -> [TripOverviewClusterItem] {
        (0..<count).map { item("item-\($0)", kind: "other", index: $0) }
    }

    private func item(
        _ id: String,
        kind: String,
        type: String = "results",
        index: Int
    ) -> TripOverviewClusterItem {
        TripOverviewClusterItem(
            id: id,
            title: id,
            label: "Results",
            kind: kind,
            parentTitle: "Trip",
            entryType: type,
            recencyIndex: index
        )
    }
}
