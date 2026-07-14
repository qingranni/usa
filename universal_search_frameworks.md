# Universal Search — Frameworks & Content Strategy

**Expedia Group · UX Design Reference**
*Compiled July 2026 · reflects the current (reverted) framework state*

This document consolidates the frameworks, research findings, and design decisions developed for Universal Search — an AI travel-planning system framed internally as *"a shared travel planning system, not a smarter search box."* It is a working reference for the design team, not a spec.

---

## 0. Framing & core principles

Universal Search is a shared travel planning system. The guiding shift is from **query submission** to **goal expression** — the traveler states what they want to accomplish, and the system helps structure it, rather than parsing keywords into filters.

**Four core principles (content strategy):**

1. **Goal expression, not query submission.** The input surface is built for natural, paragraph-length, goal-oriented briefs as the default case — not as an advanced mode.
2. **Design for xLOB (cross-line-of-business) continuity from the start.** A trip brief scopes flights, lodging, and ground together under one budget and one context, and persists across surfaces without re-entry.
3. **Make context visible, editable, and tiered.** Everything the system knows or infers is shown to the traveler and can be changed. Context is organized into layers with distinct persistence rules.
4. **Trust is the constraint — content carries the safety net.** Only ~7–8% of travelers trust AI to book on their behalf, so content must make the system's reasoning legible and keep the traveler in control at the moment of commitment.

---

## 1. Intent spectrum (six levels)

Queries are classified by **structural completeness** along a spectrum from fully specified to fully open:

| Level | Description |
|---|---|
| **High intent** | Two airports, explicit dates, trip shape — often cabin, bags, stops, airline. Proceed immediately, no clarification. |
| **Near-complete** | Destination and dates present; one blocking attribute missing (usually precise origin or return date). One inline ask unlocks results. |
| **Structured fuzzy** | Clear destination and intent, but fuzzy timing ("second week of July") or missing origin. Confirm one or two attributes, then proceed. *Largest cluster in the 10K query analysis.* |
| **Semi-fuzzy** | Destination present but origin, dates, or party often missing. Higher hotel mix. Needs goal-first questions. |
| **Open** | Exploratory — "alternative to," vibe-led, amenity-driven, no fixed destination. Near-even flight/hotel. Inspiration mode. |
| **Fully open** | Emotional register, cross-region comparison, no committed destination/date/origin. Rare (~0.5% of volume) but distinct. |

**10K query analysis distribution** (rule-based classifier over the Jan–May 2026 Anthropic-connector dataset): High 21.9% · Near-complete 18.8% · Structured fuzzy 29.5% · Semi-fuzzy 19.1% · Open 10.2% · Fully open 0.5%. The distribution is **center-weighted, not bimodal** — the core opportunity is the large fuzzy middle, not the extremes.

---

## 2. Blocking vs. narrowing attributes

The central classification that drives all routing.

- **Blocking** — the system cannot return *any* useful/coherent result without it. Origin (for flights), destination, dates (for inventory), structural constraints (e.g. road-trip stop-spacing). Blocking attributes have **no MaxDiff score** — they are technical requirements, not preference signals.
- **Narrowing** — results exist without it; they're just broader or less precise. Budget, party, amenities, cabin, flex cancellation, duration, area. MaxDiff scores apply here: higher score = ask earlier / show more confidently.

**The test:** *"Could we show anything reasonable at all without this?"* No → blocking. Yes → narrowing.

### Current classification notes (reverted framework)

- **Dates:** A holiday or occasion reference ("spring break," "christmas") is a **timing signal, not actual dates** — it remains **blocking** for inventory, resolved with a **lightweight confirm and a pre-filled regional estimate**, framed humbly because school/holiday calendars vary. A fully open/flexible signal with no anchor ("flexible dates") is also blocking → ask lightly, not a gate. Only an explicit date/range is "known."
- **Destination / area:** **Always narrowing** once a region or place is named, regardless of granularity. "Mexico" or "Mexico beach" does **not** require a discovery stage or a forced single-city pick — group results by area and let the traveler navigate within results. This follows the MaxDiff finding that area value is near-zero at Inspire and peaks later at Active Search — do not gate on it upfront.

> **Reversion note:** An earlier exploration treated dates as conditionally-narrowing (inferring a window from "spring break") and area as blocking (triggering a destination discovery stage). The team reverted both: dates return to blocking-with-lightweight-confirm, and destination discovery is de-scoped as a formal routing stage. This document reflects the reverted state.

---

## 3. Missing-attribute routing (decision tree)

When an attribute is missing, route it:

```
Missing attribute
   └─ Can results return without it?
        ├─ No  → BLOCKING → Ask (gate, or lightweight confirm with pre-filled suggestion)
        └─ Yes → NARROWING
                   └─ Can it be inferred from profile/context?
                        ├─ Yes → High comfort?
                        │          ├─ Yes → INFER (apply quietly, editable chip)
                        │          └─ No  → CONFIRM (explicit editable field, never silent)
                        └─ No  → High value?
                                   ├─ Yes → ASK (conversational, turn 1)
                                   └─ No  → SKIP (surface later as results-refinement filter)
```

**Five outcomes:**

- **Ask (blocking)** — gate or lightweight confirm with a pre-filled suggestion. Stage: Inspire → Orient.
- **Ask (conversational)** — high-value narrowing with no inference signal (budget, party). One question, turn 1, results shown in parallel.
- **Infer** — narrowing, inferable, *high comfort*. Apply quietly as a dismissible, editable chip. Stage: any.
- **Confirm** — narrowing, inferable, but *low/medium comfort* (accessibility, past-similar-trips, reason for travel, lap-infant status). Explicit editable field with obvious controls, **never applied silently.**
- **Skip** — low-value narrowing, no signal. Surface as an optional filter in the results-refinement bar. Stage: Orient → Decide.

**Reference-point destination special case:** "Los Cabos alternative" names a place as an *anchor for similarity, not a target*. Route destination to infer and generate a candidate set — the alternatives are the answer.

---

## 4. Context layers (four tiers)

Everything captured is filed into a layer with its own persistence, visibility, and control rules.

| Layer | What belongs here | Persistence | Visible | Editable | Confirmable | Dismissible |
|---|---|---|---|---|---|---|
| **Live moment** | Current phrasing, active modality, comparison state, exploratory signals, recent correction | One turn / session | Yes | Yes | Yes | Yes |
| **Trip-scoped** | Destination/region, dates, party, budget, selected constraints, saved candidates | This trip | Yes | Yes | Selective | Selective |
| **Trip-type pattern** | Recurring trip shape (family beach, solo city, ski) | Sometimes / across trips | Yes | Yes | **No by default** | Yes |
| **Profile** | Hotel tier, accessibility needs, seat preference, loyalty, language | Durable | Yes | Yes | Selective | Yes |

**Rules that matter:**

- **Live moment** fades once distilled into trip-scoped chips.
- **Trip-scoped** is the brief that carries forward across surfaces (the xLOB mechanism).
- **Trip-type pattern** is surfaced only as a *dismissible suggestion* if history confirms it — **never applied silently.** Strengthen only after repeated confirmed behavior.
- **Profile** is *"durable, but never hidden logic."* Accessibility must be **confirmed, never inferred.**

**Collection preferences (research):** 55.6% of travelers want to be asked directly; 36% want a mix of asking and learning; only ~5% prefer pure inference. On persistence, 49.3% want context kept "until I change it."

---

## 5. Journey stage = cognitive state

The journey stage describes **both** where the traveler is in the funnel **and** their cognitive posture — these are one and the same concept (an earlier "mode" layer of Dream/Shape/Weigh/Lock was collapsed into the stage labels).

| Stage | Cognitive posture |
|---|---|
| **Inspire** | Generating possibility, dreaming. Broad guidance over precision. |
| **Orient** | Imposing structure, shaping the trip. Constraints doing real narrowing. |
| **Decide** | Comparing options, weighing. Validation becomes prominent. |
| **Commit** | Finalizing, locking in. Trust matters most; agency handoff is explicit. |
| **Live** | In-trip or post-trip. Orchestration mode, not planning. Post-trip signal writes back to the trip-type pattern layer. |

**Mapping from intent level:** High/Near-complete → Decide→Commit · Structured fuzzy → Orient→Decide · Semi-fuzzy → Orient · Open → Inspire→Orient · Fully open → Inspire.

---

## 6. Emotional register (a separate axis)

**Emotional register (warm ↔ flat) is independent of intent completeness.** Tone comes from register; interaction behavior comes from the journey stage. Never conflate them.

Most queries fall on a diagonal (warm-and-open, or flat-and-complete), but the off-diagonal cases prove the axes are separate:

- **Warm but complete** — a honeymoon query: emotionally rich ("Please help!") *and* fully specified. Match the warmth in copy, but run Decide-stage behavior (reflect the brief, one scoping question). Reading the emotion as low intent would be the failure.
- **Flat but open** — a recurring automated fare check: transactional in register but open-ended in intent (a standing agent task, not a one-time search).

**Rule:** the register sets the *tone/copy*; the completeness sets the *stage/behavior*. On the diagonal you can read one from the other; off the diagonal you must decouple them.

---

## 7. Surface patterns

Three content jobs the surface performs depending on stage:

- **Entry** — reduce intimidation, invite the goal. Scaffolded starters, saved context, prompts that sound like traveler goals not form fields.
- **Working** — refine and compare. Result-state summaries, editable chips, tradeoff language.
- **Transition** — preserve continuity into booking. Carry-forward summaries, brief persistence.

---

## 8. Safety net (three patterns) + xLOB

The trust architecture. Content carries these because trust is the binding constraint.

- **Explainability** — reveal what the system applied, inferred, or ignored, *quietly*. Show inferred values as attributed chips ("from your profile"). Never return results the traveler didn't ask for without saying why. *(Research: travelers couldn't tell whether summaries were personalized or generic; and "zero results without explanation" felt broken.)*
- **Validation** — surface the facts at the moment of commitment: total price with taxes, cancellation/change policy, reviews, and a freshness cue on volatile pricing.
- **Agency** — make the traveler's control explicit. Inferred values are editable and dismissible. AI recommends; the traveler commits. The handoff at booking is unmistakable.
- **xLOB continuity** — the trip brief scopes flights + lodging + ground under one budget and persists across surfaces without re-entry. *"I have to repeat information? That defeats the purpose of having an assistant."*

---

## 9. MaxDiff Signal Capture study (n = 722)

What travelers value the system knowing, by attribute, and how it shifts across journey stages.

| Attribute | Overall score | Notes |
|---|---|---|
| **Budget** | 53.1 (#1) | Reaches 77.2% of travelers alone. High comfort. Stable across all stages. |
| **Must-have amenities** | 25.1 (#2) | Budget + amenities reaches 90%. High comfort. Peaks at Commit (29.5). |
| **Flexible cancellation** | 14.3 (#3) | Peaks at Booking (21.2) and Active Search (19.3); low at Inspire (4.8). |
| **Who is going / party** | 10.6 (#4) | Budget + amenities + party reaches 95.8%. Medium comfort. |
| **Preferred area** | 3.4 (#5) | *Most journey-dependent signal:* 1.2 at Inspire → peak 21.0 at Active Search → −6.2 at Booking. |
| **Saved places / shortlist** | −9.2 | Declines sharply across the journey (−20.1 at booking). |
| **Accessibility** | −19.4 | Low aggregate but high stakes; rises near booking. **Confirm, never infer.** |
| **Past similar trips** | −27.4 | Declines across all stages. Surface as a quiet suggestion only; confirm before use. |

**Reach (TURF):** budget alone 77% → + amenities 90% → + who is going 96% → + any other pref 98%. Foreground in that order; everything past the top four is diminishing returns.

**Key insight:** blocking/narrowing and MaxDiff operate on **different axes.** Budget scores 53.1 not because it's required to return results, but because travelers find it the most useful thing the system can know. Blocking attributes carry no MaxDiff score at all.

---

## 10. 10K query analysis — vision-level patterns

Beyond the intent spectrum, keyword-based prevalence patterns from the 10,000-query dataset (directional, not precise; the dataset over-represents AI-comfortable/conversational travelers):

- **Group/family/party-aware — 28.2%.** The dominant hidden axis. Party composition should be a first-class structuring input, not a filter.
- **Long-form queries (15+ words) — 38.9%.** Conversational, goal-expression briefs are already the norm (avg flight query 16.7 words). Validates Principle 1.
- **Multi-destination / multi-stop — 14.9%.** The trip-as-organizing-layer must handle itineraries, not just single stays.
- **Heavy constraint stacking (3+ filters) — 7.8%.** Where NL precision is the genuine moat over faceted search.
- **Comparison / alternative-seeking — 6.4%.** First-class query type (reference-point behavior).
- **Recurring / monitoring — 4.5%.** An unmet category — a standing agent task, not a search.

**Prioritization stance:** weight toward gap analysis + revealed-behavior premium (what travelers *type* > what MaxDiff says they *value*), bounded by the caveat that this dataset skews conversational. Group-aware packaging, long-form NL precision, persistent monitoring, and multi-destination itineraries are the underserved opportunities.

---

## 11. Evidence base — undifferentiated vs. grouped results

Supporting the "group results by area, don't dump undifferentiated lists" decision (engagement/preference data, not conversion):

- **Multi-City study (n=10):** travelers overwhelmed by ungrouped multi-destination options — "so many options!!!!" — struggle to connect the dots without grouping.
- **Categories study (n=8):** area- and theme-grouped results align with traveler mental models; traveler-backed groupings are trusted over sponsored content.
- **Next Best Click (n=5):** starting with destination discovery beats starting with property-type discovery; travelers prefer destination categories (Beach, Mountains, Urban) as the entry point.
- **Discovery synthesis (BEX):** 56% have a flexible destination; 46% start from location; ~30% change destination within a session.
- **NLS on Vrbo (live May 2026):** grouped Exact/Partial Match bands with explainability, 77% property click-through — grouped + explained outperforms flat lists.

**Honest limit:** *"Searchers with more specific destinations are less likely to convert"* — so resolve area into structure, don't collapse it to a forced single pick. And all of the above is engagement/preference data; there is no conversion delta proving guided discovery beats a smart system-pick for category queries. That A/B test remains the open validation.

---

## 12. Canonical personas & test queries

**Rosa** — 1 adult + 2 teens, spring break Mexico beach, ~5 nights, under $5,000. Open-ended inspiration → package. Flight-and-hotel package framing.

**Emma & Jacob** — 2 adults + Noah (4) + Ada (1, lap infant). Houston → Tampa, ~5 nights, booking 30+ days out. Flight-first, then lodging. Key needs: value, fare clarity, seats together, coordinated logistics.

**The eight test queries** (spanning the intent spectrum):

1. *High intent:* "Nonstop flights from JFK to LAX Aug 25"
2. *Near-complete:* "Cheapest hotel rate in Tucson, Arizona"
3. *Structured fuzzy:* "Spring break beach vacation in Mexico for 1 adult and 2 teenagers for under $5000"
4. *Semi-fuzzy:* "Spring Break beach trip to Mexico"
5. *Fuzzy register but complete:* honeymoon, May 18–25, Caribbean, resorts w/ restaurants, $5–6k, privacy, plunge pool, "Please help!"
6. *Open + complex:* road trip, hotels 20–25 mi apart, Oregon → Mexican border
7. *Open / exploratory:* "Los Cabos Mexico alternative, upscale October trip from Chicago"
8. *Fully open:* "I am honestly just wanting to get away from my house… cheapest place from Melbourne/Palm Bay"

---

## 13. Key design decisions (Rosa & Emma flows)

- **Spring Break dates:** don't force exact dates; confirm a pre-filled *regional estimate* framed humbly ("Spring Break in the Chicago area typically falls Mar 14–22 — is that your week?") because the system cannot know a specific district's calendar. Escape hatch opens a *bounded* calendar (Mar 1–Apr 5), not the full year. Store as durable profile pref long-term.
- **Duration:** don't resolve before dates (coupled in a fixed window). Offer 5/7-night toggle; skip 6-night (no natural arc). If a trip-type pattern signals typical 5-night stays, pre-select 5 as an *inferred* chip with attribution, confirmed on any user action.
- **Area:** don't narrow to one city before showing inventory. Group results across Cancún/Riviera Maya, Los Cabos, Puerto Vallarta. At the *area-selection* moment the card should carry a **per-area package figure with hotel drill-in** — a "from" price or an in-budget range (flights netted in), **not** a single hero resort. A lone property makes the destination decision by proxy and misrepresents what the area costs; individual hotels are a drill-in *after* the area is picked, not the entry view. Use a "from N / range · X stays fit" figure, never a raw average (a mean across a $99 hostel and an $850 resort describes no bookable trip).
- **Results presentation:** show *all* qualifying results (transparency), but organized — group by area, best-match atop each group, per-person + total pricing, result-state summary, and a quiet note when a constraint excluded options ("Budget excluded 12 Cancún resorts, see them →"). Adults-only properties dimmed, not removed.
- **Fare-as-budget-gate (multi-airport regions):** for a package query where "Mexico beach" spans several airports (CUN/SJD/PVR), a shared budget like "$5k" must be applied as a *package* number, not a hotel-only ceiling. **Net the inferred-origin round-trip fare (× party) out of the budget per area *before* filtering lodging**, so each area's stays reflect what actually fits after flights (e.g. IAH→CUN ~$600 for 3 → ~$4,400 left; IAH→SJD ~$860 → ~$4,140 left). Areas whose fares alone strain the budget get flagged, and trophy resorts that break the package total are dimmed with a see-anyway escape hatch — never shown as if they fit. *(This is the mechanic behind "package under one budget"; leaving it implicit collapses the budget into a lodging-only number.)*
- **Destination-before-pricing ordering (why lodging leads a package query):** flight-first is impossible here because there is no destination airport yet — "Mexico beach" is multi-airport, so no fare is lockable until an area is chosen. Lodging-by-area is the **destination-resolution instrument**: browsing areas *is* how the traveler answers "which beach?", which is the precondition for pricing or locking anything. Causal order: **browse area (via lodging) → airport known → fare priced/lockable → book flight + room as one package.** Showing lodging first is a *browsing* step (destination selection), not a *commitment* step; the flight is still the first lock, it just waits on the area decision. Contrast Emma (flight-first) where the destination airport is already fixed.
- **Composer at results:** keep it for refinement queries, but hide the conversation history (replaced by the chip set); store full history in session, surface changes as result/chip updates, not new chat bubbles.
- **Context switch ("what about flights to London?"):** don't silently replace context, don't gate with a modal. Answer London as a new live-moment query while *parking* the Mexico trip-scoped context (persistent "Mexico trip · resume →"). Ask one clarifying question *after* showing London results. Strong argument for a persistent trip-switcher supporting multiple simultaneous trips.
- **Emma — flexible dates:** blocking, resolved with a light ask — but a flexible-date grid ("best prices across the next few months"), not a blank calendar. 30+ days out → no urgency framing.
- **Emma — party composition:** routes to **Confirm** (not Infer) because lap-infant status is safety- and fare-relevant. Explicit field with source attribution ("from your profile") and an edit control. Getting it wrong is an operational problem, not a suboptimal result.
- **Emma — value sort ≠ cheapest sort:** "value" as a named need means total cost of ownership (bags, change fees) ranks above sticker price.
- **xLOB handoff:** for a package query (Rosa) the framing is baked in from turn 1; for a flight-first query (Emma) the lodging continuation is *offered explicitly* at Commit, not assumed.

---

## 14. Style & palette conventions

Semantic color mapping used across all artifacts:

| Color | Meaning | Light / Dark hex |
|---|---|---|
| Teal | Known / execute | #085041 / #0F6E56 |
| Blue | Working / accent | #0C447C / #185FA5 |
| Purple | Infer / orient | #3C3489 / #534AB7 |
| Amber | Ask / warning | #633806 / #BA7517 |
| Coral/red | Open / confirm | #712B13 / #791F1F |
| Green | Success / known | #27500A |

Restrained formatting; dark-mode CSS custom properties; system fonts with Georgia serif for body/quotes; 0.5px borders; pill-shaped chips. Prose over heavy bulleting in prose deliverables.

---

## 15. Artifacts produced (reference)

- **Fuzzy intent clarification model** — interactive, per-query attribute decisions + surface patterns + safety net + context layers, across the eight test queries.
- **Blocking vs. narrowing matrix** — with MaxDiff scores, reach banner, comfort tiers, and journey sparklines.
- **Missing-attribute decision tree** — five outcomes (ask-blocking, ask-conversational, infer, confirm, skip).
- **Stage-based emphasis model** — how the surface foregrounds different attributes across Inspire/Orient/Decide/Commit/Live, anchored to MaxDiff journey scores.
- **Register × completeness matrix** — the two-axis model with off-diagonal cases marked.
- **10K query cluster analysis** — intent distribution + vision-level patterns.
- **Rosa & Emma recommended flows** — full annotated app-to-booking walkthroughs.
- **Query analyzer microsites** — rule-based (hostable), AI-powered (all-at-once), and guided (5-step, LT-focused: what would I see / when do we disambiguate / where do we take them after).

---

*End of reference. This document reflects the reverted framework state as of July 2026: dates blocking with lightweight confirm; destination narrowing with no formal discovery stage.*
