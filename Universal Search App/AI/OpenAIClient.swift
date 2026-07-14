//
//  OpenAIClient.swift
//  Universal Search App
//
//  URLSession + Codable port of ai.js: a single strict-JSON-schema chat
//  completion that returns { reply, thread? }. Throws on any failure; the
//  store catches and falls back to the mock generator.
//

import Foundation

enum AIError: Error { case notConfigured, badStatus, emptyResponse }

enum OpenAIClient {

    static func requestAssistant(node: ThreadNode?, history: [Message],
                                 userText: String) async throws -> AssistantResponse {
        guard !Secrets.openAIKey.isEmpty else { throw AIError.notConfigured }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt(node)]]
        for m in history { messages.append(["role": m.role.rawValue, "content": m.text]) }
        messages.append(["role": "user", "content": userText])

        let body: [String: Any] = [
            "model": Secrets.model,
            "messages": messages,
            "response_format": responseFormat,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIError.badStatus
        }

        // The model returns a JSON *string* in choices[0].message.content → decode twice.
        let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let content = completion.choices.first?.message.content, !content.isEmpty else {
            throw AIError.emptyResponse
        }
        let parsed = try JSONDecoder().decode(RawAssistant.self, from: Data(content.utf8))
        return parsed.toDomain()
    }

    // MARK: - prompts (ported from ai.js)

    private static func systemPrompt(_ node: ThreadNode?) -> String {
        let context: String
        if let node {
            context = """
            The user is inside the existing "\(node.title)" \(node.kind.rawValue) thread. \
            - REFINEMENT (same topic): if they're refining or asking for an alternative set of THIS topic (e.g. "cheaper", "with a pool", "different times"), return a `thread` with kind="\(node.kind.rawValue)", UPDATE `title` to reflect it (e.g. "\(node.title)" → "Budget \(node.title)"), set `label` to a 2-4 word name, set `chip` to a 1-2 word filter (e.g. "budget"), and compose a fresh rich `blocks` layout for the refined results. \
            - OFF-TOPIC (different bookable resource, e.g. flights when this is a hotels thread): return a `thread` with the appropriate `kind` and a rich layout; the app opens it as a new thread. \
            For pure chit-chat with no travel intent, set `thread` to null and just answer.
            """
        } else {
            context = """
            The user is at the trip root. Return a `thread` for ANY travel intent — a specific resource ("hotels in Miami", "flights to Lisbon", "rental car"), OR an open-ended idea ("I want to go surfing in Portugal", "a relaxing beach week", "where should I go for food"). Only set `thread` to null for pure chit-chat/greetings with no travel intent.
            """
        }
        return [
            "You are a travel-planning assistant inside a mobile trip planner. You answer with a RICH, DYNAMIC result view — never just a plain paragraph.",
            "When you return a `thread`: set a short `title`, a one-line `summary`, a 2-4 word `label`, `chip` (\"\" unless it's a refinement filter), and 2-4 `options` (the primary picks; used for the trip summary). Content is plausible but invented — you do not have live data, so give concrete-sounding names, places, and $ prices.",
            "Compose `blocks` as an ordered, magazine-style layout — aim for 4-7 blocks. Start with a `text` intro (2-3 sentences). Then add multiple SECTIONS, each a `heading` followed by a `cards` block (2-3 hero items) or a `carousel` block (4-6 items). Cover everything relevant to the request:",
            "- For an OPEN-ENDED trip idea: e.g. a \"Top destinations\" carousel, a \"Flights from $X\" carousel, a \"Where to stay\" carousel, and optionally \"Things to do\". ",
            "- For a SPECIFIC search (e.g. hotels): a top-picks `cards` block, then themed carousels like \"Near the beach\", \"Budget-friendly\", \"Luxury stays\".",
            "Set each cards/carousel block's `kind` so imagery fits: `flights` for flights, `lodging` for stays, `activities` for destinations & things to do, `cars` for rentals. Use `null` kind for `text`/`heading`. Each item is {title, detail}; put a $price in `detail` where it makes sense. `text` on a `carousel` is an optional row subtitle.",
            "Keep `reply` to 1-2 sentences — a brief follow-up shown near the input, NOT the main content.",
            context,
        ].joined(separator: " ")
    }

    // MARK: - strict response schema (mirrors RESPONSE_SCHEMA in ai.js)

    private static let responseFormat: [String: Any] = [
        "type": "json_schema",
        "json_schema": [
            "name": "assistant_response",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "reply": [
                        "type": "string",
                        "description": "A short, friendly reply to the user (1-2 sentences).",
                    ],
                    "thread": [
                        "type": ["object", "null"],
                        "additionalProperties": false,
                        "properties": [
                            "kind": ["type": "string", "enum": ["flights", "lodging", "cars", "activities", "other"]],
                            "title": ["type": "string", "description": "Short thread title, e.g. \"Flights\". On a refinement, UPDATE it to reflect the new constraint, e.g. \"Budget Miami Hotels\"."],
                            "summary": ["type": "string", "description": "One-line intro shown above the result cards."],
                            "label": ["type": "string", "description": "A short 2-4 word label naming THIS specific result set, e.g. \"Budget friendly options\", \"Closest to beach\"."],
                            "chip": ["type": "string", "description": "On a REFINEMENT only: a single 1-2 word filter to ADD to the query chips. Empty string if base search or no new filter."],
                            "options": [
                                "type": "array",
                                "description": "2-4 result options.",
                                "items": [
                                    "type": "object",
                                    "additionalProperties": false,
                                    "properties": [
                                        "title": ["type": "string", "description": "Option name, e.g. \"Nonstop · 7h 45m\"."],
                                        "detail": ["type": "string", "description": "Short detail, e.g. \"$420 · KLM\"."],
                                    ],
                                    "required": ["title", "detail"],
                                ],
                            ],
                            "blocks": [
                                "type": "array",
                                "description": "Ordered UI blocks laying out the result view: a text intro, a cards block of 2-3 picks, then optionally a heading + carousel of 4-6 alternatives.",
                                "items": [
                                    "type": "object",
                                    "additionalProperties": false,
                                    "properties": [
                                        "type": ["type": "string", "enum": ["text", "heading", "cards", "carousel"]],
                                        "kind": ["type": ["string", "null"], "enum": ["flights", "lodging", "cars", "activities", "other", NSNull()], "description": "Image domain for this section's cards so imagery fits: `flights` for flight rows, `lodging` for stays, `activities` for destinations / things to do, `cars` for rentals. Null for `text`/`heading`."],
                                        "text": ["type": ["string", "null"], "description": "Body for `text`, heading for `heading`, optional row title for `carousel`. Null for `cards`."],
                                        "items": [
                                            "type": ["array", "null"],
                                            "description": "Cards for `cards`/`carousel` (null for `text`/`heading`). 3-6 for a carousel, 2-3 for cards.",
                                            "items": [
                                                "type": "object",
                                                "additionalProperties": false,
                                                "properties": [
                                                    "title": ["type": "string"],
                                                    "detail": ["type": "string", "description": "Short detail, may include a $price."],
                                                ],
                                                "required": ["title", "detail"],
                                            ],
                                        ],
                                    ],
                                    "required": ["type", "kind", "text", "items"],
                                ],
                            ],
                        ],
                        "required": ["kind", "title", "summary", "label", "chip", "options", "blocks"],
                    ],
                ],
                "required": ["reply", "thread"],
            ],
        ],
    ]

    // MARK: - decoding DTOs

    private struct ChatCompletion: Decodable {
        struct Choice: Decodable { let message: Msg }
        struct Msg: Decodable { let content: String? }
        let choices: [Choice]
    }

    private struct RawAssistant: Decodable {
        let reply: String
        let thread: RawThread?

        struct RawThread: Decodable {
            let kind: String
            let title: String
            let summary: String
            let label: String
            let chip: String
            let options: [RawOption]
            let blocks: [RawBlock]?
        }
        struct RawOption: Decodable {
            let title: String
            let detail: String
        }
        struct RawBlock: Decodable {
            let type: String
            let kind: String?
            let text: String?
            let items: [RawOption]?
        }

        func toDomain() -> AssistantResponse {
            guard let t = thread else { return AssistantResponse(reply: reply) }
            let blocks: [BlockSpec] = (t.blocks ?? []).compactMap { rb in
                guard let style = ResultBlock.Style(rawValue: rb.type) else { return nil }
                return BlockSpec(
                    style: style,
                    text: rb.text ?? "",
                    items: (rb.items ?? []).map { Option(title: $0.title, detail: $0.detail) },
                    kind: rb.kind.flatMap { Kind(rawValue: $0) }
                )
            }
            let payload = ThreadPayload(
                kind: Kind(rawValue: t.kind) ?? .other,
                title: t.title, summary: t.summary, label: t.label, chip: t.chip,
                options: t.options.map { Option(title: $0.title, detail: $0.detail) },
                blocks: blocks
            )
            return AssistantResponse(reply: reply, thread: payload)
        }
    }
}
