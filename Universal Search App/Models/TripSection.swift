//
//  TripSection.swift
//  Universal Search App
//
//  Trip-overview view model (useResponses.buildTripSections): one section per
//  thread, each listing its activity entries (search results + comparisons +
//  conversations).
//

import Foundation

struct TripEntry: Identifiable, Hashable {
    enum EntryType { case results, compare, map, conversation }
    let id: String
    var type: EntryType
    var title: String
    var label: String
    var images: [String]
    /// The `images` are airline-logo chips (flights) rather than photos.
    var isLogo: Bool = false
}

struct TripSection: Identifiable, Hashable {
    let id: String
    var threadId: String
    var kind: Kind
    var title: String
    var entries: [TripEntry]
}

struct TripOverviewClusterItem: Hashable, Sendable {
    var id: String
    var title: String
    var label: String
    var kind: String
    var parentTitle: String
    var entryType: String
    /// Zero is the newest item on the overview.
    var recencyIndex: Int
}

struct TripOverviewCluster: Identifiable, Hashable, Sendable {
    var id: String
    var heading: String
    var description: String
    var itemIDs: [String]
}

protocol TripOverviewClustering: Sendable {
    var configured: Bool { get }
    func cluster(_ items: [TripOverviewClusterItem]) async throws -> [TripOverviewCluster]
}

struct DeterministicTripOverviewClusterer: TripOverviewClustering {
    let configured = true

    func cluster(_ items: [TripOverviewClusterItem]) async throws -> [TripOverviewCluster] {
        Self.clusters(for: items)
    }

    static func clusters(for items: [TripOverviewClusterItem]) -> [TripOverviewCluster] {
        guard items.count > 3 else { return [] }

        let grouped = Dictionary(grouping: items) { item in
            item.entryType == "results" ? "results-\(item.kind)" : item.entryType
        }
        var groups = grouped.map { key, values in
            (key: key, items: values.sorted { $0.recencyIndex < $1.recencyIndex })
        }.sorted {
            ($0.items.first?.recencyIndex ?? .max) < ($1.items.first?.recencyIndex ?? .max)
        }

        if groups.count == 1, let only = groups.first?.items {
            let split = max(2, Int(ceil(Double(only.count) / 2)))
            groups = [
                (key: "recent", items: Array(only.prefix(split))),
                (key: "earlier", items: Array(only.dropFirst(split))),
            ].filter { !$0.items.isEmpty }
        } else if groups.count > 4 {
            let overflow = groups.dropFirst(3).flatMap(\.items)
                .sorted { $0.recencyIndex < $1.recencyIndex }
            groups = Array(groups.prefix(3)) + [(key: "activity", items: overflow)]
        }

        return groups.enumerated().map { index, group in
            let copy = copy(for: group.key)
            return TripOverviewCluster(
                id: "trip-overview-cluster-\(index)",
                heading: copy.heading,
                description: copy.description,
                itemIDs: group.items.map(\.id)
            )
        }
    }

    private static func copy(for key: String) -> (heading: String, description: String) {
        let group: String
        switch key {
        case "results-lodging":    group = "lodging"
        case "results-flights":    group = "flights"
        case "results-cars":       group = "cars"
        case "results-activities": group = "activities"
        case "compare":            group = "compare"
        case "map":                group = "map"
        case "conversation":       group = "conversation"
        case "results-other":      group = "other"
        case "recent":             group = "recent"
        case "earlier":            group = "earlier"
        default:                   group = "related"
        }
        return (Copy["clusters.\(group).heading"], Copy["clusters.\(group).description"])
    }
}

struct FallbackTripOverviewClusterer: TripOverviewClustering {
    var primary: any TripOverviewClustering
    var fallback: any TripOverviewClustering

    var configured: Bool { primary.configured || fallback.configured }

    func cluster(_ items: [TripOverviewClusterItem]) async throws -> [TripOverviewCluster] {
        guard primary.configured else { return try await fallback.cluster(items) }
        do {
            return try await primary.cluster(items)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await fallback.cluster(items)
        }
    }
}

func buildTripSections(_ threads: [ThreadNode]) -> [TripSection] {
    threads.map { thread in
        let images = thread.fanAssets
        let isLogo = thread.fanIsLogo
        // Row hierarchy: the heading (`title`) mirrors the canvas/results header
        // (the thread title) so the overview entry and the open view read the
        // same; the activity TYPE is the subtitle prefix (`label`, later combined
        // with a timestamp).
        var entries: [TripEntry] = thread.conversationOnly ? [] : [
            TripEntry(id: "\(thread.id)-results", type: .results,
                      title: thread.title,
                      label: Copy["overview.searchingLabel"],
                      images: images, isLogo: isLogo)
        ]
        for a in thread.activities {
            let entryType: TripEntry.EntryType
            let label: String
            switch a.type {
            case .compare:
                entryType = .compare
                label = Copy["overview.comparingHeading"]
            case .map:
                entryType = .map
                label = Copy["overview.exploringLabel"]
            case .conversation:
                entryType = .conversation
                label = Copy["overview.conversationLabel"]
            }
            entries.append(TripEntry(
                id: a.id,
                type: entryType,
                title: a.subtitle,
                label: label,
                images: images,
                isLogo: isLogo
            ))
        }
        return TripSection(id: thread.id, threadId: thread.id, kind: thread.kind,
                           title: thread.title, entries: entries)
    }
}

/// Best-effort trip location from the section titles, for the header
/// ("Trip to Miami"). Ported from TripView.jsx `tripLocation`.
func tripLocation(_ sections: [TripSection]) -> String? {
    for s in sections {
        let title = s.title
        if let m = title.range(of: #"\b(?:in|to)\s+[A-Z][a-zA-Z]+"#, options: .regularExpression),
           let word = title[m].split(separator: " ").last {
            return String(word)
        }
        let words = title.split(separator: " ").map(String.init)
        if let w = words.first(where: {
            $0.range(of: #"^[A-Z][a-z]+$"#, options: .regularExpression) != nil &&
            $0.range(of: #"^(?i)(hotels?|flights?|cars?)$"#, options: .regularExpression) == nil
        }) {
            return w
        }
    }
    return nil
}
