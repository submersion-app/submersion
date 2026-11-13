# Pinned profile strip styling

Follows the pinned strip of issue #4423 (PR #4452,
[design](2026-11-10-pinned-profile-strip-design.md)).

## Why

The strip pinned at the top of dive details, once the profile card scrolls
away, reads as bland: a faint depth curve that says nothing until it is
touched, over a row of four plain numbers that looks like a table footer. The
strip should carry the dive's shape and its decompression picture at a
glance, and read values the way the full profile chart does.

## Goals

- Show the dive's no-deco limit, or its ceiling and deco stops, on the strip
  wherever the dive has them.
- Mark the deepest point of the dive.
- Read values in a floating tooltip styled like the full chart's, instead of
  a fixed row under the curve.

## Non-goals and anti-goals

- No change to the depth line or its fill: same 1 px line, same gradient
  (option "A" was declined).
- No water tint on the background and no divider under the strip: the
  background stays the card colour (both were mocked and declined).
- No per-strip toggles. The strip does not follow the full chart's series
  switches.
- The condense from the full card into the strip must still show only one
  depth line at every frame.

## Design

### Curve area

- The values row goes away. The strip shrinks from 56 to 44 px, all curve,
  with the existing 4 px breathing room above and below.
- **NDL line:** `ProfileMetricColors.ndl`, 1.5 px, round joins, on its own
  scale, the same one the full chart uses (`ProfileMetricBands.ndl`): 0 at the
  bottom of the curve area, 60 minutes at the top, longer limits held flat at
  the top. Drawn only where NDL is above zero; it ends where the diver goes
  into deco and starts again once NDL returns, never bridging the gap.
- **Deco:** where the dive has an obligation, the stop band
  (`decoStopBandColor` at `decoStopFillAlpha`, with its 1 px step edge) and
  the ceiling band (`ProfileMetricColors.ceiling` at `ceilingFillAlpha`, with
  its 1 px line) shade from the surface down, as on the full chart.
- **Max-depth marker:** a 3.5 px dot in `ProfileMetricColors.maxDepth`, ringed
  in the surface colour, at the deepest sample, with the depth beside it in
  the diver's units (10 px, semi-bold; a lighter pink in dark mode for
  contrast). The label goes on whichever side of the dot is clear of the
  strip's edge and of the NDL line.
- All curves come from the analysis the full chart draws
  (`sourceProfileAnalysisProvider`: `ndlCurve`, `ceilingCurve`,
  `decoStopCurve`), index-aligned with the chart profile, so the strip and
  the chart always agree, computer-reported values included.

### Tooltip

- Shown only while scrubbing or hovering; nothing shows when idle. The
  "Drag to scrub" / "Hover to scrub" hint goes away; the strip's semantics
  label keeps the instruction.
- A compact dark box in the full chart's colours (`tooltipBackgroundColor`,
  `tooltipTextColor`): 6 px coloured bullets, dimmed labels, bold values,
  11 px tabular figures, 6 px corner radius.
- Rows: Time, Depth, ppO2, then NDL when out of deco, or Stop and Ceiling in
  deco. Bullets match the strip's lines (depth blue, NDL yellow, stop red,
  ceiling purple). Values use the diver's units and the existing NDL and stop
  formatting (">99" for an unlimited NDL, stop minutes rounded up).
- It hangs 4 px below the strip, its left edge 10 px right of the cursor,
  flipping to the cursor's left near the right edge, and never past the
  page's edges. It ignores pointers, so it never blocks the page.
- Rendered through an `OverlayPortal` anchored to the strip with a
  `CompositedTransformFollower`, so no ancestor's clip can cut it off.
- Screen readers: while the cursor is set, the strip's semantics value reads
  the tooltip's rows.

### Condense

The new layers (NDL line, deco bands, max-depth marker) fade in with the
condense, so the hand-over from the full chart never shows two sets of deco
bands at full strength.

## Approaches considered

1. **`OverlayPortal` with a follower (chosen).** Draws above everything and
   tracks the strip through the condense.
2. Turning off clipping on the overlay's stacks and painting below the strip.
   Fragile: the strip's own `Material` clips, and any future clip breaks it.
3. Growing the overlay's box to hold the tooltip. The box is sized to the
   strip so the page never reflows; growing it covers content when idle.

Tooltip size was chosen from mockups: the full chart's box (covered too much
of the page), a compact box (chosen), and a one-line pill (overflowed a phone
in deco and lost the colour link to the lines).

## Left to the builder

- How the label-placement check against the NDL line is done.
- Removing the now-unused hint strings from every ARB file and from
  `test/l10n/kept_english_values.dart`.
