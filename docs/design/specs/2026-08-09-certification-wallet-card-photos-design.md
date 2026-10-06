# Certification wallet: show uploaded card photos

## Problem

The certification wallet (`/certifications/wallet`) never shows a diver's uploaded
card image on the front of the card. It always renders a generated gradient card,
and that generated card is mostly empty space.

Two distinct defects:

1. **Uploaded front photo is ignored.** In
   `lib/features/certifications/presentation/widgets/certification_ecard.dart`,
   `_CardBack` checks `certification.photoBack != null` and renders the image
   full-bleed. `_CardFront` has no equivalent check. A diver who uploads both
   sides of a card sees the real image only after tapping to flip.

2. **The generated card wastes its area.** `_CardFront` places two `Spacer()`
   widgets around a single centred `Text`. On the CR80 aspect ratio (1.586) the
   middle third of the card is blank whenever the certification has no level, no
   card number and no expiry date. The expiry *date* never appears on the front
   at all; expiry is conveyed only as a coloured badge.

The image bytes are already available. Both repository mappers
(`_mapQueryRowToCertification` and `_mapRowToCertification` in
`certification_repository.dart`) hydrate `photoFront` and `photoBack`, so
`certificationListNotifierProvider` hands the wallet full bytes. No new query,
provider or migration is required.

The `photoFrontPath` / `photoBackPath` text columns in `database.dart` are
vestigial. Nothing under `lib/` reads them and this work does not change that.

## Goals

- The wallet shows the diver's uploaded front image when one exists.
- The generated fallback card presents every field a dive operator checks at
  check-in: agency, level, diver name, card number, issue date, expiry date.
- Both card faces render photos the same way.
- The e-card widgets gain their first test coverage.

## Non-goals

- The `_MiniCertCard` stack on the home dashboard
  (`certification_wallet_card.dart`) keeps its gradient minis. It will look
  different from the wallet it links to; that is accepted for this change.
- The share-sheet renderer (`certification_card_renderer.dart`) is unchanged.
- No change to the detail page, the edit page, or how photos are captured and
  stored.

## Design

### File decomposition

`certification_ecard.dart` is 431 lines and already holds the public widget, two
private face widgets and a `CustomPainter`. Adding a photo layer and a field grid
would push it past 600 lines, over the 200-400 line norm in `CLAUDE.md`. It
splits into four files under `presentation/widgets/`:

| File | Responsibility |
| --- | --- |
| `certification_ecard.dart` | Public `CertificationEcard`: aspect ratio, semantics, gestures, the flip `AnimatedSwitcher`. Delegates both faces. |
| `certification_ecard_front.dart` | Front face. Chooses photo vs generated. Owns the field grid and `_WavePatternPainter`. |
| `certification_ecard_back.dart` | Back face. Chooses photo vs generated magstripe design. |
| `certification_card_photo.dart` | `CertificationCardPhoto`, the shared blurred-backdrop photo treatment used by both faces. |

`CertificationEcard`'s public API is unchanged, so `certification_ecard_stack.dart`
and `certification_wallet_page.dart` need no edits.

### CertificationCardPhoto

A three-layer `Stack` clipped to the card's 16px rounded rectangle.

1. **Backdrop.** The same bytes at `BoxFit.cover` with `cacheWidth: 64`, wrapped
   in `ImageFiltered(ImageFilter.blur(sigmaX: 24, sigmaY: 24))` and dimmed with a
   black overlay at alpha 0.35. Decoding at 64px is both cheaper than blurring a
   full-resolution decode and produces a smoother result.

2. **Photo.** `BoxFit.contain`, so nothing is ever cropped. `cacheWidth` is
   derived from the card's laid-out width times `MediaQuery.devicePixelRatio`
   via `LayoutBuilder`.

3. **Chrome.** Optional status badge, top-right. Optional info strip, bottom.

The info strip is a gradient scrim overlaying the bottom 30% of the card
(transparent to black at alpha 0.75), not reserved space above the photo.
Reserving space would shrink the photo by nearly a third on a 1.586 card. The
scrim covers the region where a physical card prints the holder's name and
number, which is exactly what the strip repeats, so no information is lost.

Strip contents: agency display name and certification name on the first line,
diver name and card number on the second. Empty fields are omitted rather than
rendered blank.

### Front face

```
photoFront != null  -> CertificationCardPhoto(badge: true, infoStrip: true)
photoFront == null  -> generated field-grid card
```

The generated card keeps the agency `LinearGradient` and `_WavePatternPainter`
but replaces the two `Spacer()` widgets with fixed spacing:

- Header row: agency display name, status badge.
- Hero block: certification name (22px), level display name below it if present.
- Hairline divider at white alpha 0.25.
- Field grid, two rows of two columns:
  - `DIVER` / `CARD NO.`
  - `ISSUED` / `VALID UNTIL`

Each cell is a small uppercase label above its value. A cell whose value is null
or empty renders nothing, and a row whose cells are all empty collapses entirely,
so a certification carrying only a name and agency produces a tighter card rather
than a grid of blanks.

`VALID UNTIL` tints its value to match the status badge: `Colors.orange` when the
certification expires within 90 days, `Colors.red` when it has expired, white
otherwise. These are the literal colours `_buildStatusBadge` already uses, not
`ColorScheme` roles, because the card sits on an agency gradient rather than on a
theme surface.

Dates render as `MMM yyyy` through `DateFormat`, so they localise.

### Back face

`_CardBack` currently renders `photoBack` with a bare `BoxFit.cover`. It switches
to `CertificationCardPhoto` with the badge and info strip disabled, so both faces
of a flipped card look like one object. This changes existing behaviour: the back
photo stops being cropped.

The generated back design (magstripe, instructor block, "Certified by") is
unchanged apart from moving file.

### Performance

`Image.memory` keys Flutter's `ImageCache` by `Uint8List` reference identity, not
by content. The bytes come from the cached provider entity list, so repeated
rebuilds during a `PageView` swipe hit the cache. Every re-emission of
`certificationListNotifierProvider` allocates fresh `Uint8List`s from Drift and
forces a full re-decode; that is accepted here, since a wallet holds a handful of
cards, not a grid of hundreds. `cacheWidth` on both layers bounds the decoded
cost either way.

### Localisation

Three new ARB keys, reusing the existing `certifications_ecard_label_issued`:

- `certifications_ecard_label_diver` -> `DIVER`
- `certifications_ecard_label_cardNumber` -> `CARD NO.`
- `certifications_ecard_label_validUntil` -> `VALID UNTIL`

Added to `app_en.arb` with `@` descriptions and translated in all ten other
locales: `ar`, `de`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`.

## Testing

The e-card widgets have no test coverage today. Two new files under
`test/features/certifications/presentation/widgets/`.

Tests build `Image.memory` against a 1x1 PNG byte literal so image resolution
needs no file or network I/O.

`certification_card_photo_test.dart`:

- renders two `Image` widgets, backdrop and foreground
- foreground uses `BoxFit.contain`, backdrop uses `BoxFit.cover`
- badge and info strip are absent when disabled
- info strip omits the card number when it is null

`certification_ecard_test.dart`:

- front with `photoFront` renders `CertificationCardPhoto` and no
  `_WavePatternPainter`
- front without `photoFront` renders the field grid, including the `DIVER` label
- `VALID UNTIL` appears with an expiry date and is absent without one
- `CARD NO.` is absent when `cardNumber` is null or empty
- expired certification shows the `EXPIRED` badge over a photo card
- back with `photoBack` renders `CertificationCardPhoto`
- back without `photoBack` renders the generated magstripe design

## Verification

- `flutter test test/features/certifications/`
- `flutter analyze`
- `dart format .`
