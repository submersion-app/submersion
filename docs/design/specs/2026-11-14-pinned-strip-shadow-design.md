# Pinned profile strip: deeper shadow

## Why

The condensed profile strip pinned at the top of dive details (#4423) should
read clearly as floating above the cards that scroll beneath it. Today it is a
`Material` at elevation 3, barely above the cards it covers (elevation 2 in the
Submersion preset, 1 in Deep, 0 in Minimalist and Console) and below them in
Tropical (cards at 4). Its black shadow also nearly vanishes against dark
surfaces, so in dark mode the strip and the cards under it run together.

## Goals

- A clearly deeper shadow under the pinned strip, the same in every theme
  preset.
- Real separation in dark mode too.
- Keep the condense smooth: nothing switches on or off in a single frame.

## Non-goals

- The full profile card and the other cards keep their current shadows.
- No setting for shadow strength.
- The cursor tooltip below the strip is unchanged.

## Approaches considered

- **B. Material elevation 8.** Smallest change, still the theme's shadow. But
  it stays a fixed number against each preset's card elevation, and adds little
  in dark mode.
- **C. Custom shadow.** A hand-tuned two-layer drop shadow, much stronger in
  dark mode. Same look in every preset.
- **D. C plus a dark-mode rim.** As C, plus a faint light edge on the strip's
  sides and bottom in dark mode, the way dark interfaces usually show
  elevation.

Chosen: **D**, picked from mockups of all four (A being today's).

## Design

- The strip stops using `Material.elevation` and draws its own shadow outside
  its clip, following its rounded bottom corners.
- Shadow, chosen by the theme's brightness:
  - Light: black 18% at offset (0, 2), blur 4; black 24% at offset (0, 10),
    blur 22.
  - Dark: black 65% at offset (0, 2), blur 6; black 70% at offset (0, 12),
    blur 28.
- Dark rim: a 1 px line in white at 12% along the sides and bottom (no top
  edge), on the same path the theme outline already uses. Where the theme's
  cards have their own outline, that outline is drawn instead of the rim, so
  there is never a double line. Light mode has no rim.
- As today, there is no shadow while the strip's surface is still see-through.
  Once the surface is opaque, shadow and rim grow in with the condense: the
  shadow's opacity and its offset and blur scale with it, and the rim's
  opacity does.

## Left to the builder

- The shadow and rim helpers live in a small file beside the strip.
- Tests pin the light and dark shadow lists, the condense scaling, no shadow
  while see-through, and rim versus theme outline.
