# Dive Site Contact Details and Opening Hours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session (no subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dive sites gain a street address, phone, email, website and structured per-day opening hours, shown in a Contact card and an Opening hours card with directions, tap actions and an "open now" line.

**Architecture:** Four nullable text columns plus one JSON text column on `dive_sites`. A pure-Dart `OpeningHours` value type in `lib/core/opening_hours/` owns the model, JSON codec and open-now logic. The entity holds the decoded value; the repository encodes it. Two new site detail cards (`SiteDetailSectionId.contact`, `.openingHours`) follow the in-place card editing pattern of issue #4527.

**Tech Stack:** Flutter, Drift, Riverpod, url_launcher, `package:timezone` via `SiteTimeZone`.

**Spec:** `docs/design/specs/2026-11-27-dive-site-contact-and-hours-design.md` (issue #5073)

## Global Constraints

- New columns: `address`, `phone`, `email`, `website`, `opening_hours`; all nullable TEXT; schema rung v387; `minimumCompatibleSchemaVersion` stays 386; no data rewritten.
- Empty or whitespace-only input is stored as null.
- Hours JSON carries `"v": 1`; missing day key = closed, `"24h"` = open all day, ranges `[[opensAt, closesAt]]` in minutes, `0 <= opensAt < closesAt <= 1440`.
- Only `http`/`https` web links are ever launched (reuse `parseWebLink`).
- Open-now uses the site's time zone (`SiteTimeZone.wallClockFromInstant`) when the site has GPS, else device local time.
- Times through `UnitFormatter.formatMinutesOfDay` (diver's 12/24 h); `closesAt == 1440` is formatted as `formatMinutesOfDay(0)`.
- Every new string in all 12 ARB files (`test/l10n/arb_parity_test.dart`), `flutter gen-l10n` output committed.
- No em-dashes anywhere; no emojis; files under 800 lines (new cards in their own files, never in `site_detail_page.dart`).
- Run only the test files you changed, by path; never a folder or the suite.
- Rules (`site_rule_field.dart`) get nothing.

## Review Focus

1. A malformed or hand-edited `opening_hours` value (from sync, CSV, UDDF or agent writes) must decode to null or drop the bad part, never throw on the site page. Test in Task 1.
2. A season that wraps the year end (1 Nov to 31 Mar) and 29 Feb in a non-leap year must resolve correctly. Test in Task 2.
3. A site with GPS in another time zone shows open/closed in the site's clock, not the device's. Test in Task 6.
4. A website value like `mailto:x@y.com` or `javascript:...` must never launch and must be rejected on save. Test in Tasks 3 and 8.
5. A site with ten schedules and long notes stays readable at 375 px width without overflow. Test in Task 7.

---

### Task 1: OpeningHours model and JSON codec

**Files:**
- Create: `lib/core/opening_hours/opening_hours.dart`
- Create: `lib/core/opening_hours/opening_hours_codec.dart`
- Test: `test/core/opening_hours/opening_hours_codec_test.dart`

**Interfaces:**
- Produces (all immutable, `Equatable`, with `copyWith`):
  - `class TimeRange { final int opensAt; final int closesAt; }` with `bool get isValid` (`0 <= opensAt < closesAt <= 1440`).
  - `enum DayHoursKind { closed, open24h, ranges }`; `class DayHours { final DayHoursKind kind; final List<TimeRange> ranges; }` with `const DayHours.closed()`, `const DayHours.open24h()`, `DayHours.ranges(List<TimeRange>)` (sorts by `opensAt`).
  - `class MonthDay { final int month; final int day; }` with `bool get isValid` (day valid for the month in a leap year, so 29 Feb is valid).
  - `class YearlyDateRange { final MonthDay start; final MonthDay end; }` (inclusive; `end` before `start` wraps the year) with `bool contains(DateTime date)` and `int get lengthInDays`.
  - `class OpeningSchedule { final String? name; final YearlyDateRange? season; final Map<int, DayHours> days; }`; keys are `DateTime.monday..DateTime.sunday`; `DayHours dayHours(int weekday)` returns closed for a missing key.
  - `class OpeningHours { final bool alwaysOpen; final List<OpeningSchedule> schedules; final String? note; }` with `bool get isEmpty` (`!alwaysOpen && schedules.isEmpty && (note?.trim().isEmpty ?? true)`).
  - `String? encodeOpeningHours(OpeningHours? hours)` returns null for null or `isEmpty`.
  - `OpeningHours? decodeOpeningHours(String? json)`.

- [ ] **Step 1: Write failing tests** in `opening_hours_codec_test.dart`:
  - `round trips the spec example` (two schedules Summer 04-01..10-31 and Winter 11-01..03-31, split Saturday ranges, note): `decodeOpeningHours(encodeOpeningHours(h)) == h`.
  - `encodes the spec JSON shape`: `jsonDecode(encode(h))` has `v == 1`, `schedules[0]['season'] == {'start': '04-01', 'end': '10-31'}`, `days['sat'] == [[480, 720], [780, 1020]]`, and no `'mon'` key for a closed Monday.
  - `"24h" day value decodes to open24h` and encodes back to `"24h"`.
  - `empty hours encode to null`: `encodeOpeningHours(const OpeningHours()) == null`.
  - `not JSON / not an object decodes to null`: inputs `'garbage'`, `'[]'`, `'42'`, `''`, `null`.
  - `drops a malformed range and keeps the rest`: `'sat': [[600, 500], [540, 600], 'x']` gives `[TimeRange(540, 600)]`.
  - `drops an invalid season and treats the schedule as all year`: `{'start': '02-30', 'end': '13-01'}` gives `season == null`.
  - `ignores unknown keys`: extra `"foo": 1` at top and schedule level decodes equal to the clean value.
- [ ] **Step 2: Run** `flutter test test/core/opening_hours/opening_hours_codec_test.dart`. Expected: FAIL (files missing).
- [ ] **Step 3: Implement** both files. Day keys `mon tue wed thu fri sat sun`; MonthDay as `MM-DD`. Decoding never throws: wrap in try/catch, `developer.log` what is dropped.
- [ ] **Step 4: Run** the test file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): add the opening hours model and its JSON codec`.

### Task 2: Which schedule applies, and open-now status

**Files:**
- Create: `lib/core/opening_hours/opening_status.dart`
- Test: `test/core/opening_hours/opening_status_test.dart`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `OpeningSchedule? scheduleOn(OpeningHours hours, DateTime date)`: schedules whose season contains `date` (null season contains every date); shortest `lengthInDays` wins (all year counts 366); ties go to the earlier schedule.
  - `sealed class OpeningStatus`; `class OpenNow extends OpeningStatus { final DateTime? closesAt; }` (null when open 24 h or always open); `class ClosedNow extends OpeningStatus { final DateTime? nextOpen; final bool outOfSeason; }`; `class OpeningUnknown extends OpeningStatus`.
  - `OpeningStatus openingStatusAt(OpeningHours hours, DateTime wallClock)`. Wall-clock digits only (time zone handled by the caller). `closesAt`/`nextOpen` are wall-clock `DateTime`s with the same flavour as the input.

- [ ] **Step 1: Write failing tests:**
  - `summer inside an all-year schedule wins in July`, `all-year applies in December`.
  - `wrapping winter season contains 15 Jan and 1 Nov, not 1 Apr`.
  - `29 Feb season start in a non-leap year`: season `02-29..03-31` contains 1 Mar 2027 and not 28 Feb 2027.
  - `open inside a range`: Sat 10:30 with `[[480,720]]` gives `OpenNow(closesAt: Sat 12:00)`.
  - `closed in the lunch gap`: Sat 12:30 with `[[480,720],[780,1020]]` gives `ClosedNow(nextOpen: Sat 13:00, outOfSeason: false)`.
  - `next opening is days away`: Tue 09:00, only Sat `[[600,840]]` gives `nextOpen == Sat 10:00`.
  - `out of season`: 15 Dec with only Summer 04-01..10-31 gives `ClosedNow(nextOpen: 1 Apr at first opening, outOfSeason: true)`.
  - `never opens`: a schedule with every day closed gives `ClosedNow(nextOpen: null)`.
  - `midnight join`: Fri `[[1080,1440]]`, Sat `[[0,120]]`, at Fri 23:00 gives `OpenNow(closesAt: Sat 02:00)`.
  - `alwaysOpen` gives `OpenNow(closesAt: null)`; `open24h` day gives `OpenNow(closesAt: null)` unless the next day is not open24h, in which case `closesAt` is midnight.
  - `note only` gives `OpeningUnknown`.
- [ ] **Step 2: Run** the test file. Expected: FAIL.
- [ ] **Step 3: Implement.** Scan forward day by day (at most 366 days) through `scheduleOn`; join a range ending at 1440 with a next-day range starting at 0.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): work out whether a site is open now`.

### Task 3: Shared web-link and maps-link helpers

**Files:**
- Create: `lib/core/util/web_link.dart` (move `parseWebLink` and its doc comment here unchanged)
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (remove the function; `export 'package:submersion/core/util/web_link.dart' show parseWebLink;`)
- Create: `lib/core/util/maps_link.dart`
- Test: `test/core/util/maps_link_test.dart`

**Interfaces:**
- Produces:
  - `Uri? parseWebLink(String? raw)` (unchanged behaviour).
  - `enum MapsPlatform { android, apple, other }`; `MapsPlatform currentMapsPlatform()` (web and Windows/Linux are `other`; iOS and macOS `apple`).
  - `Uri? siteDirectionsUri({String? address, double? latitude, double? longitude, String? label, required MapsPlatform platform})`: null when neither a non-blank address nor both coordinates.

- [ ] **Step 1: Write failing tests** with exact URIs:
  - Android address: `geo:0,0?q=Stoney%20Cove%2C%20LE9%204DW`.
  - Android pin: `geo:52.5763,-1.2905?q=52.5763,-1.2905(Stoney%20Cove)`.
  - Apple address: `https://maps.apple.com/?q=Stoney%20Cove%2C%20LE9%204DW`; Apple pin: `https://maps.apple.com/?ll=52.5763,-1.2905&q=Stoney%20Cove`.
  - Other: `https://www.google.com/maps/search/?api=1&query=<encoded address>` and `query=52.5763,-1.2905`.
  - Address wins over coordinates; blank address with coordinates uses the pin; nothing gives null; newlines in the address become `, `.
  - Existing `parseWebLink` tests still pass from the new import path (`test/features/equipment/domain/equipment_purchase_attributes_test.dart`).
- [ ] **Step 2: Run** `flutter test test/core/util/maps_link_test.dart test/features/equipment/domain/equipment_purchase_attributes_test.dart`. Expected: maps test FAIL.
- [ ] **Step 3: Implement** both files (percent-encode with `Uri.encodeComponent`).
- [ ] **Step 4: Run** both. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(core): share the web link parser and add a maps link builder`.

### Task 4: Schema, entity, mapper, repository and search

**Files:**
- Modify: `lib/core/database/tables/site_tables.dart` (five columns after `parkingInfo`, each with a trailing `//` comment, which feeds the agent schema notes)
- Create: `lib/core/database/migrations/helpers/site_contact_hours_migrations.dart` (`_assertSiteContactHoursColumns()` using `_addColumnIfMissing` for each column, `TEXT`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (`part` line), `migrations/ladder/rungs_v340_onward.dart` (rung `if (from < 387)`), `migrations/before_open_child_columns.dart` (backstop call), `lib/core/database/database.dart` (`currentSchemaVersion = 387`, append 387 to `migrationVersions` with "floor unchanged" comment)
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart` (fields `address, phone, email, website` as `String?`, `openingHours` as `OpeningHours?`; constructor, `copyWith` with `clearAddress/clearPhone/clearEmail/clearWebsite/clearOpeningHours`, `props`; `bool get hasContactInfo`)
- Modify: `lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart` (decode `openingHours`)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (the four companions at `createSite`, `_writeSiteUpdate`, `_undoMergeInner`, `_updateSiteRow`; `encodeOpeningHours`; `searchSites` adds `address`, `phone`, `email`, `website` `.searchFold().contains(needle)`)
- Modify: `docs/developer/database.md` (dive_sites DDL), `docs/developer/reference/entities.md`
- Regenerate: `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v387_site_contact_hours_test.dart` (copy the shape of `migration_v369_site_catalogue_answers_test.dart`), `test/features/dive_sites/data/repositories/site_repository_contact_hours_test.dart`

**Interfaces:**
- Produces: `DiveSite.address/phone/email/website/openingHours`, the `clearX` flags, `DiveSite.hasContactInfo` (any of the four text fields non-blank).

- [ ] **Step 1: Write failing tests:**
  - Migration: `migrationVersions` contains 387; floor still 386; upgrading a v386 database adds all five columns, nullable.
  - Repository: create then read back a site with all five fields (hours equal after round trip); `updateSite` with `clearOpeningHours: true` stores null; `searchSites('LE9')`, `searchSites('1455')`, `searchSites('stoneycove')`, `searchSites('info@')` each find the site.
- [ ] **Step 2: Run** both test files. Expected: FAIL.
- [ ] **Step 3: Implement** everything listed under Files; run `dart run build_runner build --delete-conflicting-outputs` (unfiltered) and the notes generator.
- [ ] **Step 4: Run** the two new tests plus `test/core/database/fresh_schema_declared_columns_test.dart`, `test/features/agent_access/data/resources/schema_resource_test.dart`, `test/features/dive_sites/data/services/site_edit_save_census_test.dart` (expected to FAIL until Task 5; note it and move on). Others: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): store a site's address, contact details and opening hours`.

### Task 5: Sitting fields and the two new card ids

**Files:**
- Modify: `lib/core/constants/site_detail_sections.dart` (add `contact` and `openingHours` to `SiteDetailSectionId` directly after `location`; `icon` `Icons.contact_phone_outlined` / `Icons.schedule`; names and descriptions; `defaultSections` entries)
- Modify: `lib/features/dive_sites/presentation/editing/site_plain_fields.dart` (`siteAddressField`, `sitePhoneField`, `siteEmailField`, `siteWebsiteField` via `_text(..., SiteDetailSectionId.contact)`; `siteOpeningHoursField` as `EditField<DiveSite, OpeningHours?>` with id `openingHours`, card `openingHours`, write clears on null or `isEmpty`; all five in `siteSittingFields`)
- Modify: ARB `app_en.arb` (section names/descriptions)
- Test: `test/core/constants/site_detail_sections_test.dart` (extend the pinned list), `test/features/dive_sites/presentation/editing/site_plain_fields_test.dart` (roundTrip/clears for each), `test/features/dive_sites/data/services/site_edit_save_census_test.dart` (extend the full-entity fixture at 61-112)

- [ ] **Step 1: Extend the three tests** (pinned id list with `contact, openingHours` after `location`; round trip and clear for all five fields; census fixture with the five values).
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter gen-l10n`.
- [ ] **Step 4: Run** the three files plus `test/features/dive_sites/presentation/widgets/site_detail_section_pairs_test.dart` and `test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): add contact and opening hours card slots`.

### Task 6: Contact card and directions on the site page

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_contact_card.dart`
- Create: `lib/features/dive_sites/presentation/helpers/site_link_launcher.dart` (`typedef SiteLinkLauncher = Future<bool> Function(Uri uri)`; `final siteLinkLauncherProvider = Provider<SiteLinkLauncher>(...)` defaulting to `launchUrl(uri, mode: LaunchMode.externalApplication)`, so tests can capture URIs)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_sectionCards`: `_shownWhileLaidOut(SiteDetailSectionId.contact, ..., build: (c) => SiteContactCard(site: site))`; GPS row in `_buildLocationSection` gets a trailing directions `IconButton` when `site.hasCoordinates && (site.address?.trim().isEmpty ?? true)`)
- Modify: `lib/features/dive_sites/presentation/editing/site_edit_cards.dart` (register `contact` with `isEmpty: (s) => !s.hasContactInfo`; editor added in Task 8)
- Test: `test/features/dive_sites/presentation/widgets/site_contact_card_test.dart`

**Interfaces:**
- Produces: `class SiteContactCard extends ConsumerWidget { const SiteContactCard({required DiveSite site}); }`. Rows keyed `ValueKey('site_contact_address')`, `_phone`, `_email`, `_website`, directions button `ValueKey('site_contact_directions')`, GPS button `ValueKey('site_location_directions')`.

- [ ] **Step 1: Write failing widget tests** (override `siteLinkLauncherProvider` with a recorder):
  - Shows only the set rows; hidden entirely (`SizedBox.shrink`) via the page when none set.
  - Tap phone launches `tel:+441455273089` (spaces stripped); tap email `mailto:info@stoneycove.com`; tap website `https://stoneycove.com`; website displayed without scheme.
  - Website `javascript:alert(1)` shows as text but tapping launches nothing.
  - Directions with address on Android platform override launches the `geo:` address URI from Task 3.
  - Long-press copies to clipboard and shows the copied snackbar.
  - On the page: a site with GPS and no address shows `site_location_directions`; with an address it does not.
  - Launcher returning false shows the "Could not open maps" snackbar.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** Reuse `RecordCardHeader`; rows like `_ContactTile` in `dive_center_detail_page.dart`. Add `MapsPlatform` override seam via a `mapsPlatformProvider` in the same helper file.
- [ ] **Step 4: Run** the file plus `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): show a site's contact details with directions`.

### Task 7: Opening hours card on the site page

**Files:**
- Create: `lib/features/dive_sites/presentation/opening_hours_summary.dart` (pure display logic)
- Create: `lib/features/dive_sites/presentation/widgets/site_opening_hours_card.dart`
- Modify: `site_detail_page.dart` `_sectionCards` (register `openingHours` card), `site_edit_cards.dart` (`isEmpty: (s) => s.openingHours == null`)
- Test: `test/features/dive_sites/presentation/opening_hours_summary_test.dart`, `test/features/dive_sites/presentation/widgets/site_opening_hours_card_test.dart`

**Interfaces:**
- Consumes: Task 2 `openingStatusAt`, `scheduleOn`; `SiteTimeZone.wallClockFromInstant`.
- Produces:
  - `class DayGroup { final List<int> weekdays; final DayHours hours; }`; `List<DayGroup> groupDays(OpeningSchedule s, {required int firstDayOfWeek})`: consecutive days (in locale week order) with equal `DayHours` collapse.
  - `List<OpeningSchedule> schedulesInDisplayOrder(OpeningHours h, DateTime today)`: the schedule from `scheduleOn(today)` first, the rest in stored order.
  - `class SiteOpeningHoursCard extends ConsumerWidget { const SiteOpeningHoursCard({required DiveSite site, DateTime Function()? now}); }`.
- Copy (English, l10n keys under `diveSites_hours_*`): "Open now, closes {time}", "Open 24 hours", "Open 24/7", "Closed, opens {day} {time}", "Closed for the season, opens {date}", "Closed", day group "Mon to Fri", "Closed", "Open 24 hours", ranges joined by ", ", season "Summer, 1 Apr to 31 Oct", unnamed season "1 Apr to 31 Oct".

- [ ] **Step 1: Write failing tests:**
  - `groupDays`: Mon-Fri same + Sat/Sun same gives two groups; Monday-first vs Sunday-first locales order differently; all closed gives one group of seven.
  - Card: London device clock 15:00 UTC, site at Florida coordinates with Sat 10:00-14:00 shows "Closed, opens" in Florida time (inject `now`).
  - Status line colour uses `colorScheme` success for open (assert via the `Text` style's colour equals the theme's green token used elsewhere for "open", or `colorScheme.primary` if none; pick one constant in the card and assert it).
  - Lone unnamed all-year schedule shows no season heading; named seasons show heading with dates; today's group row is bold.
  - `alwaysOpen` shows only "Open 24/7" plus the note.
  - 10 schedules with 3 ranges each and a 300-char note at 375x800 render with no overflow exceptions.
  - Midnight close shows `formatMinutesOfDay(0)`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.** First day of week from `MaterialLocalizations.of(context).firstDayOfWeekIndex`; weekday names from `DateFormat.E(locale)`; dates from `DateFormat.MMMd(locale)`.
- [ ] **Step 4: Run** both. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): show a site's opening hours and whether it is open now`.

### Task 8: Contact card editor

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_contact_card_editor.dart`
- Modify: `site_edit_cards.dart` (`editorBuilder: (ctx, session) => SiteContactCardEditor(session: session)`)
- Test: `test/features/dive_sites/presentation/editing/site_contact_card_editor_test.dart`

**Interfaces:**
- Produces: `class SiteContactCardEditor extends ConsumerStatefulWidget { const SiteContactCardEditor({required session}); }`, modelled on `SiteAccessCardEditor` (`siteWordsBinding(session, field)`, `SuggestionFormRow`).
- Validation: `String? validateSiteEmail(String text)` (blank ok; else must match `^[^@\s]+@[^@\s]+\.[^@\s]+$`) and `String? validateSiteWebsite(String text)` (blank ok; else `parseWebLink(text) != null`), returning l10n error keys; both live in the editor file and are exported for tests.

- [ ] **Step 1: Write failing tests:** editing each field writes through the session; address field is multi-line (`maxLines: 4`); phone uses `TextInputType.phone`, email `emailAddress`, website `url`; invalid email `info@` and website `mailto:x@y.com` show inline errors and the card's Save is blocked (follow how an existing editor blocks save, e.g. depth validation in the depth card editor); blank values save as null.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** plus `test/features/dive_sites/presentation/pages/site_detail_page_unlock_cards_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): edit a site's contact details`.

### Task 9: Opening hours card editor

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_opening_hours_card_editor.dart` (card editor: 24/7 switch, schedule list, note)
- Create: `lib/features/dive_sites/presentation/editing/opening_schedule_editor.dart` (one schedule: name, Seasonal switch with day/month pickers, seven day rows)
- Create: `lib/features/dive_sites/presentation/editing/opening_day_row.dart` (closed / 24 h / hours segmented control, ranges with add/remove, time pickers, "Copy these hours to..." day picker dialog)
- Create: `lib/features/dive_sites/presentation/editing/opening_hours_validation.dart` (`List<String> openingHoursErrors(OpeningHours h)`: per-day range not valid or ranges overlapping, with weekday and schedule index)
- Modify: `site_edit_cards.dart` (register editor)
- Test: `test/features/dive_sites/presentation/editing/opening_hours_validation_test.dart`, `test/features/dive_sites/presentation/editing/site_opening_hours_card_editor_test.dart`

**Interfaces:**
- Consumes: `siteOpeningHoursField`; the session's generic field binding (`session.value(field)` / `session.set(field, value)`; use whatever `siteWordsBinding` is built on).
- The 24/7 switch keeps schedules in the value (spec: "hidden but kept").

- [ ] **Step 1: Write failing tests:**
  - Validation: `[[600,500]]` invalid; `[[480,720],[700,800]]` overlap; `[[480,720],[720,800]]` valid (touching ranges allowed).
  - Editor: adding a schedule starts all days closed; setting Sat to hours adds `08:00-12:00` default range (480-720); add a second range; "Copy these hours to..." with Sun ticked copies Sat to Sun only; Seasonal switch reveals pickers and sets `04-01..10-31` defaults (1 Apr to 31 Oct); toggling 24/7 on then off restores the schedules; deleting the last schedule and clearing the note writes null; an overlap blocks Save with an inline error.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** On phones the schedule editor sits inline in the card (scrolls with the page).
- [ ] **Step 4: Run** both plus `site_detail_page_unlock_cards_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): edit a site's opening hours`.

### Task 10: Shared libraries, sync conflicts and agent access

**Files:**
- Modify: `lib/core/services/shared_library/site_document.dart` (`fieldNames`: `'address','phone','email','website','openingHours'` before the list fields), `site_document_bridge.dart` (`fieldValue` switch; `apply()` companion, hours as the encoded string)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart` (`address` as `FieldKind.longText`, `opening_hours`/`openingHours` key as `FieldKind.longText`; `email`, `website`, `phone` reuse existing keys; add `'diveSites.x'` overrides in `siteTripOverrides` for site-specific labels if the generic label reads wrong)
- Modify: `lib/features/agent_access/data/documents/site_documents.dart` (`address, phone, email, website` snake_case; `opening_hours` as the decoded JSON map or null), `data/writes/families/site_writes.dart` (text codecs `maxLength: 500` for address, 200 for the rest; website validated by `parseWebLink`, email by `validateSiteEmail`; `opening_hours` via `JsonObjectCodec` normalised through decode/encode, rejected when decode returns null for a non-null input)
- Test: `test/core/services/shared_library/site_document_test.dart` (length 30, last still `features`), `test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`, `test/features/agent_access/data/writes/site_writes_test.dart`

- [ ] **Step 1: Extend tests:** document field list; bridge round trip of all five; agent write sets and clears each, rejects `website: "javascript:x"` and malformed hours; read document carries them.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): carry contact details and hours through shared libraries and agent access`.

### Task 11: CSV and UDDF

**Files:**
- Modify: `lib/core/services/export/csv/csv_sites_writer.dart` (append headers at the END: `Address`, `Phone`, `Email`, `Website`, `Opening Hours`; address newlines to `, `; hours as the encoded JSON)
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart`, `lib/features/dive_import/data/services/uddf_entity_importer.dart` (both branches at ~2128 and ~2243; decode hours)
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (elements `address`, `phone`, `email`, `website`, `openinghours`, the last following the `catalogueanswers` JSON pattern), `uddf_import_parsers.dart` (`parseFullSite`)
- Modify: `test/core/services/export/csv/goldens/sites_metric.csv`, `csv_test_fixtures.dart`
- Test: `test/core/services/export/csv/csv_round_trip_test.dart`, `csv_metric_golden_test.dart`, and the UDDF site round-trip test (find with `grep -rln parkinginfo test/core/services/export/uddf test/features/dive_import`)

- [ ] **Step 1: Extend tests** so the fixture site carries all five and round trips through CSV and UDDF equal.
- [ ] **Step 2: Run** those files. Expected: FAIL.
- [ ] **Step 3: Implement**; update the golden.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): export and import site contact details and hours`.

### Task 12: Merge page and table editor

**Files:**
- Modify: `site_merge_page_fields.dart` (four text controllers), `site_merge_page_candidates.dart` (`text(...)` entries, `_textControllerFor`; hours via `_buildDistinctCandidates` + `_pick` like difficulty), `site_merge_page.dart` (render a Contact group and an hours picker), `site_merge_page_save.dart` (carry all five)
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart` (append `address, phone, email, website` after `tags`, with every switch case and `enum_siteField_X`/`_short` l10n), `lib/features/table_editor/entities/site_table_editor_entity.dart` (`text(SiteField.x, ...)` columns; `_withValues` carries all five, hours unchanged)
- Test: the merge page test (`grep -rln SiteMergePage test`), `test/features/dive_sites/domain/constants/site_field_test.dart`, `test/features/table_editor/entities/column_round_trip_test.dart`

- [ ] **Step 1: Extend tests:** merging two sites where only the second has a phone and hours keeps both; picking the first site's hours keeps them whole; table editor round trip keeps hours when editing phone.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): merge and table-edit site contact details`.

### Task 13: Catalogue adopt and gap-fill website

**Files:**
- Modify: `lib/features/dive_sites/domain/services/catalogue_site_mapping.dart` (`website: site.website`)
- Modify: `domain/catalogue_gaps/catalogue_gap_field.dart` (add `website`), `catalogue_offer.dart`, `data/repositories/site_catalogue_fill_repository.dart` (`_companion`), `presentation/editing/site_catalogue_sitting.dart` (`_fill` with `siteWebsiteField`), `presentation/catalogue_gap_display.dart` (label, value)
- Test: `catalogue_site_mapping_test.dart`, `catalogue_offer_test.dart`, `catalogue_gap_display_test.dart`, `site_catalogue_fill_repository_test.dart`

- [ ] **Step 1: Extend tests:** adopt copies website; offer when site website blank and record has one; no offer when site has its own; fill writes trimmed website.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Only a website `catalogueWebsiteUri` accepts is copied or offered.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): take a catalogue site's website on adopt and fill`.

### Task 14: Translations, checks and after screenshots

- [ ] **Step 1:** Translate every new `app_en.arb` key into the 11 other ARB files (values must differ from English unless listed in `test/l10n/kept_english_values.dart`, which suits "Email" or "Website" only where a locale genuinely uses the English word). `flutter gen-l10n`.
- [ ] **Step 2: Run** `test/l10n/arb_parity_test.dart`, `test/l10n/untranslated_english_values_test.dart`, `test/l10n/arb_no_duplicate_keys_test.dart`. Expected: PASS.
- [ ] **Step 3:** `dart format .`, `flutter analyze` (expected: no issues), and every test file touched in Tasks 1 to 13 by path.
- [ ] **Step 4:** After screenshots with the throwaway golden harness (`STAGE=after`): site page phone light/dark and desktop with both cards; contact and hours editors unlocked; a site with only GPS showing the directions button. Delete `test/_pr_shots/` before pushing.
- [ ] **Step 5: Commit** `feat(dive-sites): translate site contact and hours strings`.
