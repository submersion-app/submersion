# Fullscreen Profile Draggable Readout Card

Date: 2026-07-05
Status: Approved

## Problem

The dive profile chart pins its hover tooltip above the chart's plot box
(`showOnTopOfTheChartBoxArea: true`, `fitInsideVertically: false`) so the
bubble never covers the profile. That works on the dive detail page, where
scroll content above the chart gives the overflow room to paint. The
fullscreen profile page has no headroom -- the plot top sits at the screen
edge -- so the bubble clips off-screen and hover data is unreadable.

An interim fix (uncommitted on this branch) clamped the bubble inside the
plot via a `tooltipInsidePlot` flag. Feedback: a bubble inside the plot
covers the profile while hovering. The chosen direction is a readout card
that never chases the cursor and can be dragged out of the way.

## Decisions

1. The fullscreen page gets an always-visible floating readout card that
   shows the hovered/scrubbed sample. Before the first hover it shows a
   placeholder hint line.
2. The card replaces the painted tooltip bubble on the fullscreen page.
   The bottom instrument bar stays unchanged. The interim
   `tooltipInsidePlot` flag is reverted (superseded).
3. The card's dragged position is remembered across sessions in app
   settings.
4. The dive detail page keeps its current above-the-chart tooltip,
   pinned by a widget test.

## Architecture

Page-owned overlay. The fullscreen page wraps its chart area in a `Stack`;
the card is a `Positioned` child owned by the page. The chart runs in its
existing external-tooltip mode (`tooltipBelow: true` + `onTooltipData`),
which suppresses the painted bubble and emits structured `TooltipRow`
data (label, value, bulletColor -- already unit-formatted, localized, and
multi-computer-aware). No new chart plumbing.

Alternatives rejected:

- `OverlayPortal`: lets the card cover the instrument bar and transport
  controls, which is an anti-feature; more lifecycle complexity.
- Hosting the card inside `DiveProfileChart`: leaks a page concern into a
  shared widget that is already far over the repo's file-size ceiling.

## Components

### DraggableReadoutCard (new widget, `draggable_readout_card.dart`)

- Renders the latest `List<TooltipRow>`: one row per metric with a color
  bullet, label, and value, in a compact vertical list. Styling:
  `surfaceContainerLow` background, rounded corners, `outlineVariant`
  border, elevation-free.
- Placeholder state (no rows yet): a single localized hint line,
  "Hover or scrub the profile" (works for pointer and touch). One new
  l10n string, translated into all 10 non-English locales.
- The whole card is the drag surface (`GestureDetector.onPanUpdate`).
  No close button, no resizing.
- Constructor takes: rows (nullable), current fractional position,
  callbacks for position change (during drag) and drag end (persist).

### Fullscreen page wiring (`fullscreen_profile_page.dart`)

- Wrap the chart `Padding` in a `Stack`; add the card as a positioned
  overlay clamped to the chart region (it cannot cover the source bar or
  instrument bar, which sit below in the `Column`).
- Pass `tooltipBelow: true` and `onTooltipData` to the chart. Keep the
  existing `onPointSelected` wiring (instrument bar and playback sync are
  untouched).
- State: hold the last non-null rows; `onTooltipData(null)` (hover end)
  does NOT clear the card -- values are sticky. The card starts in
  placeholder state each page open.

### Position model and persistence

- Position is stored as fractional coordinates (0..1) of the card's
  top-left over the movable range (stack size minus card size), so 0 is
  flush left/top, 1 is flush right/bottom, and different window and
  screen sizes re-derive a sensible spot.
- Clamped on every layout so the card stays fully inside the chart area.
- Default (unset): top-right corner with a 12 px inset.
- Two new nullable doubles on `AppSettings`:
  `fullscreenReadoutCardX`, `fullscreenReadoutCardY` (null = default),
  persisted by a new `SettingsNotifier` setter
  `setFullscreenReadoutCardPosition(double x, double y)`. The four
  settings test mocks gain the new member.
- Position saves on drag end only (not per-frame).

## Reverts

The uncommitted `tooltipInsidePlot` changes on this branch are dropped:
the flag, its `LineTouchTooltipData` ternaries, its two placement tests,
and the fullscreen page's `tooltipInsidePlot: true`. Kept: the
"default keeps the bubble pinned above the chart box" widget test, which
pins the detail-page behavior against future drift.

## Testing

- Card widget tests: renders rows with bullet colors; placeholder before
  first data; pan gesture moves the card; position clamps at the bounds;
  drag end invokes the persist callback with fractional coordinates.
- Fullscreen page tests: chart receives `tooltipBelow: true`; card is
  present; simulated touch emission populates the card (reuse the
  existing touch-interaction test pattern from the chart tests); rows
  survive hover end (sticky).
- Settings: round-trip of the new fields through the existing settings
  persistence test pattern; mocks updated.
- Detail page: existing default-placement test continues to pass
  unchanged.

## Non-goals

- Hide/show toggle for the card.
- Card resizing.
- Using the card on the dive detail page.
- Replacing or changing the instrument tile row.
