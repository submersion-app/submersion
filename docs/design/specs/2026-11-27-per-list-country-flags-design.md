# Country flags per list: dives, buddies, sites and trips

Issue: #5001. Release: v1.8.7.

## Intent

A diver asked for the small country flag that the Dive Sites list shows to
appear in the Dives list and the Buddies list too, so they can see at a
glance where a dive was and where a buddy is from. The maintainer added that
flags must be optional in Settings, with a separate switch for each list.

Today one switch, Settings > Appearance > Country flags (v360, issue #4426,
`diver_settings.show_country_flags`, default on), governs every flag: site
rows, the site and dive detail headers, trip rows and trip story pages, and
buddy rows and the buddy detail page. The Dives list rows draw no flag at
all, and a buddy row draws one only when its subtitle slot is set to
Country, which is not the default, so most divers never see a buddy flag.

## Goals

- Dive list rows show the dive site's flag.
- Buddy rows show the buddy's flag without the diver changing a slot.
- Four switches, one per section (Sites, Dives, Buddies, Trips), each on
  that section's appearance page, replace the single global switch.
- A diver who turned flags off before this change still sees no flags
  anywhere after it, on every device, including one set up fresh.

## Non-goals

- Flags in table views (the site table has none today either), including
  the home page's Recent dives panel
  (`lib/features/dashboard/presentation/panels/recent_dives_panel.dart`),
  which is its own small table and not a dive card (builder check, my
  call).
- A flag badge on the buddy detail page's avatar. The detail page keeps its
  Country row with the flag.
- A master "all flags" switch.
- Any change to how a country code is derived from the country text.

## Anti-goals

- Undoing a choice a diver already made: anyone with flags off must not see
  them return on trips, dives or buddies after the upgrade.
- A buddy row showing two flags.
- Rows jumping or misaligning when a flag is present on some rows and not
  others.

## Approaches considered

For where the switches live:

- **A. One switch on each section's appearance page (chosen).** Matches how
  every other per-list display option works (for example "map background on
  site cards" on the Sites page). Each switch also covers that section's
  detail page. No flag is gated twice.
- B. Keep the global switch as a master plus per-section switches. Gives a
  quick "all off", but two switches gate one flag, so "why no flags on
  dives?" has two answers in two places. Rejected.
- C. Four switches grouped on the Appearance page. All in one place, but adds
  four rows to a page of app-wide settings and breaks the section-page
  pattern. Rejected.

For buddy rows: a badge on the avatar (chosen) over a flag beside the name or
keeping today's subtitle-only rule.

For existing divers: copy the current switch into the three new ones
(chosen) over starting the new switches on for everyone, which would turn
trip flags back on for a diver who had turned them off.

## Decided design

### Settings

| Section page | Switch governs | Storage (diver_settings) |
| --- | --- | --- |
| Sites | site rows (detailed, compact, dense), site detail header | existing `show_country_flags`, wire key `showCountryFlags` |
| Dives | dive rows (detailed, compact), dive detail header | new `show_dive_country_flags` |
| Buddies | buddy rows (standard, compact), buddy detail Country row | new `show_buddy_country_flags` |
| Trips | trip rows (all modes), trip story pages | new `show_trip_country_flags` |

- Each switch is a `SwitchListTile` titled "Country flags" in the List View
  section of `SectionAppearancePage`, for the sections `sites`, `dives`,
  `buddies` and `trips` only. Its subtitle names what it covers for that
  section (for example "Show a small flag beside each dive's site
  location").
- The global tile in `AppearanceGeneralTiles`
  (`appearance_settings_tiles.dart`) is removed.
- The existing column keeps its name and wire key: older peers still send
  `showCountryFlags`, and renaming a synced column is costly. It now means
  Sites only. The Dart field names (`AppSettings`, provider, setter) may be
  renamed for clarity (for example `showSiteCountryFlags`), but the Drift
  column getter and the sync and conflict keys stay `showCountryFlags`.
- The conflict catalogue (`diver_settings_fields.dart`) gets an entry for
  each new column, and the existing entry's label changes from "Country
  flags" to one naming sites.
- All new strings in all 11 languages.

### Schema v396

- Three columns on `diver_settings`, each `INTEGER NOT NULL DEFAULT 1
  CHECK (<col> IN (0, 1))`, matching what Drift gives a fresh install's
  boolean column (as the v360 helper does).
- The v396 rung asserts the columns, then copies the current switch in one
  statement:
  `UPDATE diver_settings SET show_dive_country_flags = show_country_flags,
  show_buddy_country_flags = show_country_flags, show_trip_country_flags =
  show_country_flags`.
- The copy runs in the ladder only. `beforeOpen` re-asserts the columns but
  never copies, or it would undo a section switch the diver later changed.
- The rung stamps neither `updated_at` nor the HLC: every device copies its
  own row, and a stamp would let one device's upgrade outrank newer settings
  from another.
- `changeLogRewrittenColumns` is not needed: the rung writes only the new
  columns, and no logged value holds an older shape of them.
- The minimum compatible schema version (the sync floor) does not move: an
  older peer omits the new keys and the rules below cover that.

### Sync with older peers

A peer below v396 sends diver_settings rows without the three new keys.

- **This device already holds the row:** `_withLocalForOmitted` keeps this
  device's values for the omitted keys (existing behaviour, no change).
- **The row is new to this device** (a device set up fresh, or a new diver
  arriving): before `_withSchemaDefaults` fills the column default, derive
  each omitted new key from the same payload's `showCountryFlags`. This is
  the issue #2030 pattern (`_withDerivedDistanceUnit`) and goes in both
  apply paths (`_upsertRecordApply` and the batch path) at the same point.
- `_applyDiverSettingDefaults` gains the three keys with default `true`, for
  records where even `showCountryFlags` is absent.
- Known limit, accepted: when a diver flips the single switch on a device
  still below v396, an upgraded device that already holds the row changes
  only its Sites switch. Overwriting the other three from an older peer
  would undo per-section choices made on the upgraded device every time the
  older device saved any setting.

### Drawing

- `shownFlagCode` and `LocationWithFlag` (`lib/shared/widgets/country_flag.dart`)
  stop reading the global provider and take the section's switch instead,
  so every caller states which section it belongs to. How (a section
  parameter or a passed boolean) is the builder's call.
- **Dives, detailed card** (`DiveListTile` in `dive_list_page.dart`): the
  "region, country" line becomes a `LocationWithFlag` fed by the summary's
  `siteCountry` and `siteCountryCode`, exactly as the site rows do.
- **Every dive row follows the Dives switch, wherever it is drawn**
  (builder check, my call): the dive rows inside a trip's story and day map
  pages and in global search come from the same `DiveListItem`, so they
  follow Dives, while the trip's own flags on those pages follow Trips. A
  row's switch is the switch of the record it shows.
- **Dives, compact card** (`CompactDiveListTile`): the flag sits before the
  line 1 title when the title slot shows the site name or the site
  location, and not for any other title field. A dive with no site or a
  site with no recognised country draws no flag and no gap. When the flag
  is drawn and the card shows no country text, the card's semantics label
  names the country after the site (builder check, my call), the same rule
  as the buddy badge below.
- **Dive detail header** (`dive_hero_header.dart`): follows the Dives
  switch.
- **Buddies, standard row** (`BuddyListTile`): a small flag badge on the
  avatar's lower trailing corner, for any buddy with a recognised country,
  whatever the subtitle slot shows. The subtitle no longer draws a flag
  beside a Country subtitle, so the buddy never shows two. The badge must
  stay legible on a photo avatar (for example with a thin ring in the
  surface colour); its exact size and ring are the builder's call.
- **Buddies, compact row** (`CompactBuddyListTile`): no avatar, so it keeps
  today's rule: a flag beside the subtitle only when the subtitle slot is
  Country.
- **Buddies, dense row**: no flag (no avatar and no country text).
- **Buddy detail page** Country row: follows the Buddies switch; with the
  switch off it shows the globe it shows today when flags are off.
- **Sites** (all rows and the detail header) follow the Sites switch.
- **Trips** (`TripCountryFlags` and every caller, trip story included)
  follow the Trips switch.
- Every flag stays hidden from screen readers, as today, because the
  country is always named in nearby text or a label. The avatar badge on a
  standard buddy row is the exception where the country text may not be on
  the row, so the row's semantics label adds the country when a badge is
  drawn.

## Constraints

- Settings changes go through the repository's full wiring: the table,
  the ladder rung and `beforeOpen` backstop, `DiverSettingsRepository`
  (insert, update and read), `AppSettings` (field, constructor, `copyWith`),
  a setter that waits for load, a selector provider, the sync serializer
  defaults and the conflict catalogue.
- `section_appearance_page.dart` is already 876 lines; the new tile goes in
  its own widget file rather than growing the page.
- `dive_list_page.dart` is already 1231 lines; the detailed card change must
  stay a few lines there.
- New tables or rungs go under `lib/core/database/tables/` and
  `migrations/`, never in `database.dart`.
- Paths in tests are platform-agnostic; tests that change process-wide state
  restore it.

## Left to the builder

- Names of the new Dart fields, providers and setters.
- How the section reaches `shownFlagCode` and `LocationWithFlag`.
- Exact wording of each section's switch subtitle and the conflict labels.
- The avatar badge's size, offset and ring, within "legible on a photo,
  never covering the initials' centre".
- Whether the now-unused global subtitle string is removed from the ARB
  files.
