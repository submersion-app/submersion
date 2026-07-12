# Dive Detail: Side-by-Side Card Pairs

**Date:** 2026-07-12

## Problem

On the Dive Details page every section renders as a full-width card in a single
vertical column. When the detail pane is wide (a large window, or the
master-detail split on desktop), short cards leave a lot of empty horizontal
space. Two natural pairs of related, compact cards should sit next to each other
when there is room:

- **Details** + **Conditions** (the `environment` section)
- **Buddies** + **Signatures**

## Goals

- When the available width is wide enough, render each pair as two side-by-side
  columns; otherwise keep today's stacked layout unchanged.
- Measure the *pane's own* available width, so behavior is correct both in the
  standalone detail page and inside the narrower master-detail pane.
- Respect the existing user-configurable section system (sections are
  individually reorderable and hideable).

## Non-goals

- No general "any two short sections flow into columns" behavior. Only the two
  named pairs.
- No change to the section-config settings UI.
- No equal-height cards. Each card keeps its intrinsic height (top-aligned).

## Behavior

Pairing is **fixed-pairs, adjacency-gated**:

| Condition | Result |
|---|---|
| `details` immediately followed by `environment` in the configured order **and** `_hasEnvironmentData(dive)` | pair |
| `buddies` immediately followed by `signatures` in the configured order **and** (dive has buddies **or** `courseId != null`) | pair |
| the two are reordered apart, one is hidden, or the second is empty | each renders full-width, exactly as today |
| pane too narrow | the pair widget stacks the two cards — identical to today |

"Adjacency" is adjacency in the **configured section order**. If the user drops
another visible section between the two, they stack.

### Why the presence predicates differ

- **Conditions** already self-suppresses: the `environment` builder returns `[]`
  when `!_hasEnvironmentData(dive)`, so Details renders full-width today. Reuse
  that same predicate to gate the pair.
- **Signatures** self-erases to `SizedBox.shrink()` when the dive has no buddies
  (`buddy_signatures_section.dart`), but the section *also* renders a
  course-instructor signature card when `dive.courseId != null`. So "Signatures
  present" = `buddies.isNotEmpty || dive.courseId != null`. **Buddies** always
  renders a card (even a "solo dive" placeholder), so it has no presence gate.

## Design

### 1. `ResponsiveSectionPair` widget

A small, focused widget (new file
`lib/features/dive_log/presentation/widgets/responsive_section_pair.dart`)
mirroring the house idiom already used by `ResponsiveFormColumns`:

- `LayoutBuilder`; if `constraints.maxWidth >= minRowWidth` (default **700**) →
  `Row(crossAxisAlignment: start, [Expanded(first), SizedBox(width: columnGap),
  Expanded(second)])`.
- else → `Column(crossAxisAlignment: start, [first, SizedBox(height: stackGap),
  second])`.
- Defaults: `minRowWidth: 700` (pane content width — the page pads 16 each side,
  so ≈ 730px pane), `columnGap: 16`, `stackGap: 24`.

The widget always wraps both cards; it chooses row-vs-stack purely from its own
measured width. The stacked branch is pixel-identical to rendering the two cards
as adjacent stacked sections.

### 2. Extract two card seams (no behavior change)

So the normal path and the pair path render the same content:

- `_detailsCard(...)` — the attribution `Consumer` currently inline in the
  `details` section builder. The `details` builder becomes
  `[_detailsCard(...)]`.
- `_signaturesColumn(...)` — `BuddySignaturesSection` plus the optional course
  signature card (the body currently inline in the `signatures` builder). The
  `signatures` builder becomes `[SizedBox(height: 24), _signaturesColumn(...)]`.

### 3. Pairing pass in the section loop

Replace the current spread loop in `_buildContent`:

```dart
for (final section in settings.diveDetailSections)
  if (section.visible) ...builders[section.id]?.call() ?? [],
```

with a look-ahead pass (`_buildOrderedSections`) over the visible section ids:

- Compute `hasConditions = _hasEnvironmentData(dive)` and, from
  `buddiesForDiveProvider(dive.id)`, `hasSignatures = buddies.isNotEmpty ||
  dive.courseId != null`.
- When `details` is followed by `environment` and `hasConditions`, emit a
  `ResponsiveSectionPair(first: _detailsCard(...), second:
  _buildEnvironmentSection(...))` and skip the consumed `environment`. Details
  has no leading spacer today, so the pair gets none either.
- When `buddies` is followed by `signatures` and `hasSignatures`, emit
  `SizedBox(height: 24)` (Buddies' existing leading gap) then a
  `ResponsiveSectionPair(first: _buildBuddiesSection(...), second:
  _signaturesColumn(...))` and skip the consumed `signatures`.
- Otherwise spread the section's generic builder output, exactly as today.

## Spacing fidelity

The stacked fallback and the leading spacers reproduce today's layout to the
pixel: Details has no leading spacer; Buddies keeps its 24px leading spacer; the
inter-card gap in the stacked branch is 24px. At narrow widths nothing moves.

## Testing

Widget tests (in the dive_detail_page test suite plus a unit test for the new
widget):

- Wide pane → Details and Conditions are inside one `Row` (both findable, side by
  side); narrow pane → stacked (no `Row` pairing them).
- Conditions-absent dive → Details renders full-width, no pair.
- Solo dive (no buddies, no course) → Buddies full-width, Signatures absent.
- Buddies-present dive, wide pane → Buddies and Signatures paired in a `Row`.
- `ResponsiveSectionPair` unit test: renders `Row` at/above `minRowWidth`,
  `Column` below.
