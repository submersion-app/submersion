# Country flags beside dive site locations

Release: v1.8.5

## Intent

A small flag beside a site's location lets the diver recognise a dive, a
site or a trip at a glance while scanning a list, before reading any text.
It is a recognition aid, not information the diver lacks: the country name
is already on screen. So the flag must stay very small and quiet, and never
compete with the site or trip name.

## Goals

- Show a small flag on five surfaces:
  1. **Site list:** before the location line of each site row.
  2. **Site details:** in the header (`SiteDetailHeader`), the flag takes
     the place of the `location_on_outlined` pin before the location line.
     When there is no flag (country unknown, or flags turned off) the pin
     comes back exactly as today.
  3. **Dive details:** before the site location line, which ends in the
     country (`DiveHeroHeader` and `DiveDetailEmbeddedHeader`).
  4. **Trip list:** after the trip name, one flag per country.
  5. **Trip details:** after the trip name in the header, one flag per
     country.
- On by default, with one on/off switch that hides every flag at once.
- Look identical on macOS, iOS, Android, Windows and Linux.

## Non-goals

- No new country field, picker or validation on the site edit page. The
  stored country stays free text, exactly as today.
- No flags in other places that show a location (map popups, site picker,
  dive list rows, exports, PDFs). They can follow later if wanted.
- No change to how trips store their own `location` text.

## Anti-goals (a failure even if it works)

- A flag large or bright enough to pull the eye away from the name.
- A wrong flag. A missing flag is fine; a wrong one is not, so the
  recognizer only matches confident, exact names.
- A placeholder, grey box or "?" when the country is unknown.
- Emoji flags that turn into two letters on Windows.

## Decisions made with the user

- **Style A:** a small drawn flag image, the same on every platform (chosen
  over emoji flags in the mockup review).
- **Unknown country:** no flag and nothing in its place; the text reads as
  it does today.
- **Trips:** a trip has no country of its own, so its flags come from the
  countries of its dives' sites, one flag per distinct country.
- **Setting:** one on/off switch in Settings > Appearance, default on,
  covering all five surfaces.
- **Pin on site details:** the flag replaces the pin; the pin returns when
  there is no flag (chosen over showing pin and flag together).
- The site list's round leading `location_on` avatar is the row's icon, not
  part of the location line, and is unchanged.

## How it works

### Recognising a country

`country` on a site is free text from three sources: typed by the diver,
imported (UDDF, MacDive, CSV, Divemate), or filled by reverse geocoding in
the diver's place-name language (`PlaceNameLanguage.supportedCodes`: en, es,
fr, de, it, nl, pt, hu, ar, he, zh).

A new pure function in `lib/core` resolves that text to an ISO 3166-1
alpha-2 code, or null:

- Trim, then compare case-insensitively and accent-insensitively.
- Accept a 2-letter alpha-2 code that is a real assigned code, and a
  3-letter alpha-3 code.
- Accept country names in all eleven place-name languages, generated from
  CLDR territory names.
- On top of that, a small hand-kept alias list (my call): every alias already
  in `_isoFromCountry` (USA, Czech Republic, and so on), plus UK, England,
  Scotland, Wales and Northern Ireland to GB, Holland to NL, and Bonaire,
  Sint Eustatius and Saba to BQ. Aliases are added only when the mapping is
  unambiguous.
- Where one name means different countries in different languages, the name
  gets no code (no flag beats a wrong flag).
- Exact match only. No substring or fuzzy matching ("Mexico City" or
  "Gulf of Mexico" must not produce a Mexican flag).

The Safety feature's private `_isoFromCountry` in
`lib/features/safety/presentation/providers/emergency_providers.dart`
becomes a call to this shared function, so the emergency card and the flags
always agree about a site's country. My call: this intentionally changes the
emergency card for some existing data, for the better. Localized names
("Mexique") and aliases ("UK") now resolve to a real region where they used
to fall back to the worldwide hotline, and an unassigned 2-letter string
("EU") now resolves to unknown instead of being passed through. The Safety
tests are updated to match.

### Drawing the flag

- Dependency: `country_flags` (MIT; vector flags from an ISO code via
  `jovial_svg`; lists Android, iOS, macOS, Windows and Linux).
- One shared widget renders a flag for a code: about 16 by 11 logical
  pixels in list rows (scaled to the line's text size in headers), slightly
  rounded corners, a hairline outline so white-edged flags (Japan,
  Indonesia) stay visible on a light background and dark ones on a dark
  background.
- The flag is decoration: excluded from semantics, because the country name
  next to it is already read out. Where a trip row shows flags without the
  country names, the flags carry a semantic label and tooltip with the
  country names.

### Trips

A trip's flags come from the same set of dives its dive count already uses
(my call): the current diver's dives, scoped the way `trip_repository.dart`
scopes trip stats, with a parent trip including its side trips' dives
(`tripDivesJoinSql`, issue #3658). Flags and the dive count therefore always
agree. The flags are the distinct resolved countries of those dives' sites,
ordered by how many of the trip's dives were in each country (most first),
ties by first dive date. Sites whose country does not resolve contribute
nothing. A trip with no resolvable country shows no flags.

### The setting

`showCountryFlags`, a synced per-diver setting like
`showMapBackgroundOnSiteCards`: a column on the diver settings table
(default true), a schema migration, the settings model and repository, the
sync-conflict catalogue entry, and a switch with a short description on the
Appearance settings page. New strings go through l10n in every supported
language.

## Constraints

- Follow the repo's CLAUDE.md: TDD, `dart format`, `flutter analyze`,
  architecture tests for new files under `lib/`.
- Trip list rows must not add a query per row; trip countries load with the
  list (or one batched query), not N+1.
- The setting migration follows the existing migration ladder.

## Left to the builder (marked as my calls)

- Exact flag size per surface, within "very small": my call is 16x11 in
  rows, text-height-matched in headers.
- Where the multilingual name table comes from: my call is generating a
  Dart constant from CLDR territory names (Unicode licence) with a
  committed script, not hand-typing it.
- How many flags a trip row shows before collapsing: my call is up to 3
  flags, then a "+N" in the row's secondary text style; trip details shows
  them all.
- Which list tile density variants of the site and trip lists get the flag:
  my call is every variant that already shows the location (sites) or the
  trip name (trips).
