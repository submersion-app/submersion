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
  It shows only where NDL dips below the top of that scale: held at the top
  it was a bar across most of a recreational dive. Each stretch reaches out
  to the at-the-top sample either side, so it drops in from the top edge and
  climbs back out to it.
- **Deco:** where the dive has an obligation, the stop band
  (`decoStopBandColor` at `decoStopFillAlpha`, with its 1 px step edge) and
  the ceiling band (`ProfileMetricColors.ceiling` at `ceilingFillAlpha`, with
  its 1 px line) shade from the surface down, as on the full chart.
- **Max-depth marker:** a 3.5 px dot in `ProfileMetricColors.maxDepth`, ringed
  in the surface colour, at the deepest sample. No depth label: the tooltip
  reads the depth wherever the cursor is.
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

Every layer behaves as the depth line does. The NDL line, deco bands and
max-depth marker travel through the same moving mapping at full strength,
lying on the full chart's own wherever the chart draws them, and only
cross-fade in with the strip's surface, as the line does. Fading them with
the condense as well covered the chart's own bands and then faded them back
in.

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

- Removing the now-unused hint strings from every ARB file and from
  `test/l10n/kept_english_values.dart`.

## As built

Where the build settled details this design left open or got wrong:

- **Colours follow the diver's chart colours.** The full chart draws its
  series in `ProfileMetricPalette` (Settings > Appearance); the strip's depth
  line and shading, NDL line, ceiling, max-depth marker and tooltip bullets
  come from the same palette, falling back to the defaults named above. The
  stop band keeps `decoStopBandColor`, which the palette does not cover.
- **Tooltip ppO2** reads with its unit (`0.69 bar`), as the full chart's
  tooltip does.
- **Tooltip NDL** is read from the analysis's NDL curve, the one the NDL line
  is drawn from (the computer's NDL where the dive has one), so the readout
  agrees with the line. The stop and its duration still come from the
  calculated deco status, the only source of a duration, so they agree with
  the deco status card; where the curve says deco and the model does not,
  the NDL row reads `--`.
- **Screen readers** read the rows once, as the strip's semantics value; the
  floating tooltip itself is excluded from semantics.
