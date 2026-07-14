//
//  ImageLibrary.swift
//  Universal Search App
//
//  Tagged image library + pickImage scoring, ported verbatim from data.js.
//  Each card's photo is chosen by scoring library entries against the option
//  text so a "beach villa" gets a beachfront photo, an "EV compact" the EV one.
//

import Foundation

enum ImageLibrary {

    struct Entry { let kind: Kind; let url: String; let tags: [String] }

    static let entries: [Entry] = [
        // ---- lodging ----
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80", tags: ["beach", "resort", "pool", "beachfront", "tropical"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1551776235-dde6d482980b?w=600&q=80", tags: ["boutique", "city", "modern", "rooftop", "urban"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&q=80", tags: ["cabin", "mountain", "rustic", "cozy", "lodge"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600&q=80", tags: ["hotel", "luxury", "suite", "premium"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600&q=80", tags: ["hotel", "lobby", "bedroom", "standard", "budget"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&q=80", tags: ["boutique", "design", "apartment", "studio"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1535827841776-24afc1e255ac?w=600&q=80", tags: ["villa", "pool", "private", "luxury", "estate"]),
        Entry(kind: .lodging, url: "https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=600&q=80", tags: ["bedroom", "standard", "simple", "budget", "hostel"]),

        // ---- flights ----
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=600&q=80", tags: ["plane", "wing", "window", "flight", "sky"]),
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=600&q=80", tags: ["airport", "terminal", "departure", "gate"]),
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1542296332-2e4473faf563?w=600&q=80", tags: ["plane", "runway", "takeoff", "landing", "tarmac"]),
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1583446942153-fb04a35aa1d8?w=600&q=80", tags: ["cabin", "business", "first-class", "seat", "premium"]),
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1503220317375-aaad61436b1b?w=600&q=80", tags: ["sunset", "plane", "sky", "flight", "evening"]),
        Entry(kind: .flights, url: "https://images.unsplash.com/photo-1556388158-158ea5ccacbd?w=600&q=80", tags: ["airline", "plane", "jet", "commercial", "economy"]),

        // ---- cars ----
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600&q=80", tags: ["compact", "sedan", "small", "budget", "economy"]),
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=600&q=80", tags: ["sports", "sport", "luxury", "fast", "performance"]),
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1493238792000-8113da705763?w=600&q=80", tags: ["suv", "crossover", "family", "large", "4wd"]),
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1502877338535-766e1452684a?w=600&q=80", tags: ["convertible", "cabrio", "roadster", "open-top"]),
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=600&q=80", tags: ["truck", "pickup", "hauling", "utility"]),
        Entry(kind: .cars, url: "https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?w=600&q=80", tags: ["ev", "electric", "tesla", "modern", "hybrid"]),

        // ---- activities ----
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1543340713-8c2cb6c5cd0e?w=600&q=80", tags: ["museum", "art", "gallery", "culture", "history"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1551632811-561732d1e306?w=600&q=80", tags: ["hike", "hiking", "mountain", "trail", "outdoor", "nature", "cliff", "coast", "scenic", "viewpoint"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=600&q=80", tags: ["snorkel", "snorkeling", "dive", "reef", "underwater", "ocean", "beach", "coast", "surf", "surfing", "waves", "sea"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80", tags: ["food", "tour", "tasting", "restaurant", "dining", "cuisine"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1582033876234-a3c1d4f37fe4?w=600&q=80", tags: ["theme", "park", "rollercoaster", "amusement", "family"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80", tags: ["concert", "music", "festival", "live", "show"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1530549387789-4c1017266635?w=600&q=80", tags: ["boat", "cruise", "sail", "sailing", "yacht", "ocean", "island", "seaside", "coast", "bay"]),
        Entry(kind: .activities, url: "https://images.unsplash.com/photo-1455156218388-5e61b526818b?w=600&q=80", tags: ["city", "walking", "tour", "sightseeing", "urban", "town", "village", "destination", "old-town", "streets"]),
    ]

    /// Tiny stable hash for tiebreaking — same input always picks the same image.
    private static func hashStr(_ s: String) -> Int {
        var h = 0
        for ch in s.unicodeScalars {
            h = (h &* 31 &+ Int(ch.value)) & 0x7fffffff
        }
        return abs(h)
    }

    /// Pick the most relevant image for a card by scoring entries against the
    /// card text. Kind match counts strongly; tag matches stack on top.
    static func pickImage(_ text: String?, kind: Kind) -> String? {
        let lower = (text ?? "").lowercased()
        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let tokenSet = Set(tokens)

        var best: Entry?
        var bestScore = -1
        for entry in entries {
            var score = 0
            if entry.kind == kind { score += 3 }
            for tag in entry.tags {
                if tokenSet.contains(tag) {
                    score += 2
                } else if tokens.contains(where: { $0.contains(tag) || tag.contains($0) }) {
                    score += 1
                }
            }
            if score > bestScore {
                bestScore = score
                best = entry
            }
        }

        // Nothing matched: deterministic per-kind choice from the text hash.
        if bestScore <= 0 {
            let ofKind = entries.filter { $0.kind == kind }
            if !ofKind.isEmpty {
                return ofKind[hashStr(text ?? "") % ofKind.count].url
            }
        }
        return best?.url
    }
}
