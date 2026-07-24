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

    struct Entry {
        let key: String
        let kind: Kind
        let url: String
        let tags: [String]
    }

    static let entries: [Entry] = [
        // ---- lodging ----
        Entry(key: "lodging_beach_resort", kind: .lodging, url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80", tags: ["beach", "resort", "pool", "beachfront", "tropical"]),
        Entry(key: "lodging_city_boutique", kind: .lodging, url: "https://images.unsplash.com/photo-1551776235-dde6d482980b?w=600&q=80", tags: ["boutique", "city", "modern", "rooftop", "urban"]),
        Entry(key: "lodging_mountain_cabin", kind: .lodging, url: "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&q=80", tags: ["cabin", "mountain", "rustic", "cozy", "lodge"]),
        Entry(key: "lodging_luxury_hotel", kind: .lodging, url: "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600&q=80", tags: ["hotel", "luxury", "suite", "premium"]),
        Entry(key: "lodging_budget_hotel", kind: .lodging, url: "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600&q=80", tags: ["hotel", "lobby", "bedroom", "standard", "budget"]),
        Entry(key: "lodging_design_stay", kind: .lodging, url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&q=80", tags: ["boutique", "design", "apartment", "studio"]),
        Entry(key: "lodging_private_villa", kind: .lodging, url: "https://images.unsplash.com/photo-1535827841776-24afc1e255ac?w=600&q=80", tags: ["villa", "pool", "private", "luxury", "estate"]),
        Entry(key: "lodging_simple_room", kind: .lodging, url: "https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=600&q=80", tags: ["bedroom", "standard", "simple", "budget", "hostel"]),

        // ---- flights ----
        Entry(key: "flights_window_view", kind: .flights, url: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=600&q=80", tags: ["plane", "wing", "window", "flight", "sky"]),
        Entry(key: "flights_airport_terminal", kind: .flights, url: "https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=600&q=80", tags: ["airport", "terminal", "departure", "gate"]),
        Entry(key: "flights_runway", kind: .flights, url: "https://images.unsplash.com/photo-1542296332-2e4473faf563?w=600&q=80", tags: ["plane", "runway", "takeoff", "landing", "tarmac"]),
        Entry(key: "flights_premium_cabin", kind: .flights, url: "https://images.unsplash.com/photo-1583446942153-fb04a35aa1d8?w=600&q=80", tags: ["cabin", "business", "first-class", "seat", "premium"]),
        Entry(key: "flights_sunset", kind: .flights, url: "https://images.unsplash.com/photo-1503220317375-aaad61436b1b?w=600&q=80", tags: ["sunset", "plane", "sky", "flight", "evening"]),
        Entry(key: "flights_commercial_jet", kind: .flights, url: "https://images.unsplash.com/photo-1556388158-158ea5ccacbd?w=600&q=80", tags: ["airline", "plane", "jet", "commercial", "economy"]),

        // ---- cars ----
        Entry(key: "cars_compact", kind: .cars, url: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600&q=80", tags: ["compact", "sedan", "small", "budget", "economy"]),
        Entry(key: "cars_sports", kind: .cars, url: "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=600&q=80", tags: ["sports", "sport", "luxury", "fast", "performance"]),
        Entry(key: "cars_suv", kind: .cars, url: "https://images.unsplash.com/photo-1493238792000-8113da705763?w=600&q=80", tags: ["suv", "crossover", "family", "large", "4wd"]),
        Entry(key: "cars_convertible", kind: .cars, url: "https://images.unsplash.com/photo-1502877338535-766e1452684a?w=600&q=80", tags: ["convertible", "cabrio", "roadster", "open-top"]),
        Entry(key: "cars_pickup", kind: .cars, url: "https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=600&q=80", tags: ["truck", "pickup", "hauling", "utility"]),
        Entry(key: "cars_electric", kind: .cars, url: "https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?w=600&q=80", tags: ["ev", "electric", "tesla", "modern", "hybrid"]),

        // ---- activities ----
        Entry(key: "activities_museum", kind: .activities, url: "https://images.unsplash.com/photo-1543340713-8c2cb6c5cd0e?w=600&q=80", tags: ["museum", "art", "gallery", "culture", "history"]),
        Entry(key: "activities_hiking", kind: .activities, url: "https://images.unsplash.com/photo-1551632811-561732d1e306?w=600&q=80", tags: ["hike", "hiking", "mountain", "trail", "outdoor", "nature", "cliff", "coast", "scenic", "viewpoint"]),
        Entry(key: "activities_ocean", kind: .activities, url: "https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=600&q=80", tags: ["snorkel", "snorkeling", "dive", "reef", "underwater", "ocean", "beach", "coast", "surf", "surfing", "waves", "sea"]),
        Entry(key: "activities_food", kind: .activities, url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80", tags: ["food", "tour", "tasting", "restaurant", "dining", "cuisine"]),
        Entry(key: "activities_theme_park", kind: .activities, url: "https://images.unsplash.com/photo-1582033876234-a3c1d4f37fe4?w=600&q=80", tags: ["theme", "park", "rollercoaster", "amusement", "family"]),
        Entry(key: "activities_live_event", kind: .activities, url: "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80", tags: ["concert", "music", "festival", "live", "show"]),
        Entry(key: "activities_boating", kind: .activities, url: "https://images.unsplash.com/photo-1530549387789-4c1017266635?w=600&q=80", tags: ["boat", "cruise", "sail", "sailing", "yacht", "ocean", "island", "seaside", "coast", "bay"]),
        Entry(key: "activities_city_tour", kind: .activities, url: "https://images.unsplash.com/photo-1455156218388-5e61b526818b?w=600&q=80", tags: ["city", "walking", "tour", "sightseeing", "urban", "town", "village", "destination", "old-town", "streets"]),
    ]

    /// Keys accepted by the AI response schema.
    static var keys: [String] { entries.map(\.key) }

    /// Compact descriptions included in the prompt so the model can make a
    /// semantic choice without seeing URLs or making another network request.
    static var promptCatalog: String {
        entries.map { "\($0.key) [\($0.tags.joined(separator: ", "))]" }
            .joined(separator: "; ")
    }

    /// Resolve a model-selected key only when it belongs to the expected kind.
    /// A wrong-kind or unknown key returns nil so hydration can use text scoring.
    static func imageURL(forKey key: String?, kind: Kind) -> String? {
        guard let key else { return nil }
        return entries.first { $0.key == key && $0.kind == kind }?.url
    }

    /// Tiny stable hash for tiebreaking — same input always picks the same image.
    private static func hashStr(_ s: String) -> Int {
        var h = 0
        for ch in s.unicodeScalars {
            h = (h &* 31 &+ Int(ch.value)) & 0x7fffffff
        }
        return abs(h)
    }

    /// Pick the most relevant same-kind image by scoring tags against card text.
    static func pickImage(_ text: String?, kind: Kind) -> String? {
        let lower = (text ?? "").lowercased()
        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let tokenSet = Set(tokens)
        let candidates = entries.filter { $0.kind == kind }

        var best: Entry?
        var bestScore = 0
        for entry in candidates {
            var score = 0
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
            if !candidates.isEmpty {
                return candidates[hashStr(text ?? "") % candidates.count].url
            }
        }
        return best?.url
    }
}
