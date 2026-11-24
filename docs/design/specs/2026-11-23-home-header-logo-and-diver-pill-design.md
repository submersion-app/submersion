# Home header: logo spacing and an always-shown diver pill

Date: 2026-11-23
Status: approved
Code: `lib/features/dashboard/presentation/widgets/home_header_bar.dart`

## Intent

The app icon closing Home's header bar looks squished into place and is not
aesthetically pleasing. It is drawn at 40 pt inside a 48 pt bar, which leaves
4 pt above it, about 3 pt below (the bar's bottom border takes the last
point), 4 pt between it and the diver switcher and 8 pt to the screen edge.
It is also far taller than everything else in the bar: the + icon is 24 pt,
and the status pills and the diver switcher are about 28 pt.

Separately, the diver profile pill should always show, including for a diver
with a single profile. Today it is hidden below two profiles.

## Goals

- The logo sits in the bar with visible room around it and reads as part of
  the same row as the other controls.
- The diver pill shows whatever the profile count.

## Non-goals

- No change to the bar's height, the + quick actions menu, the status lights,
  the divider or the phone status strip.
- No change to the diver switcher sheet. It already lists a single profile
  with a check mark and pins "Add new diver" below the list.

## Anti-goals

- Shrinking the logo's tap target below 44 by 44 pt.
- A pill whose tap does different things depending on the profile count.

## Approaches considered

| Approach | Trade-off | Picked |
| --- | --- | --- |
| A: smaller tile, more air (32 pt tile, 8 pt above and below, 8 pt gap, 12 pt to the edge) | Still reads as the logo; nothing else moves | Yes |
| B: match the controls (28 pt tile, same height as the pills and switcher) | Quietest and most uniform, but the logo becomes just another control | No |
| C: taller bar (keep the 40 pt tile, bar grows to 56 pt) | Spends 8 pt of vertical room on every Home layout, phones included, for the logo alone | No |

For tapping the pill with one profile, two behaviours were considered:
opening the existing switcher sheet, or opening the diver profile page. The
sheet was picked: one behaviour regardless of profile count, and its "Add new
diver" row is the natural path to a second profile.

## Design

Logo (`_AboutLogo` and `HomeHeaderBar.logoSize`):

- Tile size 40 pt to 32 pt; corner radius 10 to 8 (keeps the same
  proportion).
- All distances below are to the drawn tile, as seen, not to its button.
  The tile sits centred in a 44 pt button, so 6 pt of each gap is the
  button's own padding.
- The tile's edge sits 8 pt from the diver switcher (was 6 pt) and 12 pt
  from the bar's end (was 10 pt).
- Bar height stays 48 pt, so the tile has about 8 pt above and below (the
  bar's 1 pt bottom border takes half a point of the lower gap).
- Tap target stays at least 44 by 44 pt and still opens About Submersion.
- On a phone the switcher is a 28 pt avatar centred in a 44 pt box, so the
  visible gap there is 16 pt; that is accepted, not corrected.

Diver pill (`_DiverSwitcher`):

- Shown with any number of profiles. The `diverCountProvider` check, and its
  "unknown counts as one" loading guess, go away.
- While the active diver loads, the existing 44 pt placeholder holds the
  space. On a phone that matches the loaded avatar, so the bar does not
  jump; wider, the named pill is wider than 44 pt and the lights shift once
  when it arrives, as they already did with several profiles.
- With no diver to show (loading failed, or none stored), the pill and its
  placeholder both collapse, leaving no empty gap.
- The name still shows only above phone width; phones show the avatar alone.
- Tapping still opens `showDiverSwitcherSheet`.

Doc comments on `HomeHeaderBar`, `logoSize` and `_DiverSwitcher` that mention
"more than one diver profile" or "a few points above and below" are updated
to match.

## Tests

In `test/features/dashboard/presentation/widgets/home_header_bar_test.dart`:

- The existing `'no switcher with one diver'` test flips to expect the pill.
- The existing `'the logo is 40 points ...'` test becomes 32 pt with at
  least 7 pt above and below inside the bar.
- New checks: the tile sits 8 pt from the switcher and 12 pt from the bar's
  end, in left-to-right and right-to-left, and keeps a hit area of at least
  44 pt.

## Left to the builder

- Whether `diverCountProvider` is still used anywhere else after this; remove
  the import only, never the provider, if Home no longer needs it.
- How the existing tests that pump two divers to show the switcher are
  simplified, if at all.
