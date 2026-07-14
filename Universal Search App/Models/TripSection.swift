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
    enum EntryType { case results, compare, map }
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

func buildTripSections(_ threads: [ThreadNode]) -> [TripSection] {
    threads.map { thread in
        let images = thread.fanAssets
        let isLogo = thread.fanIsLogo
        var entries: [TripEntry] = [
            TripEntry(id: "\(thread.id)-results", type: .results,
                      title: thread.title, label: Copy["overview.resultsHeading"],
                      images: images, isLogo: isLogo)
        ]
        for a in thread.activities {
            entries.append(TripEntry(
                id: a.id,
                type: a.type == .compare ? .compare : .map,
                title: a.subtitle,
                label: a.type == .compare ? Copy["overview.comparingHeading"] : Copy["overview.conversationLabel"],
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
