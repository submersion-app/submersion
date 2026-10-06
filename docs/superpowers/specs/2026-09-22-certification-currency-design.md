# Certification Currency and Renewal Warnings

Date: 2026-09-22
Status: approved design; phase 1 plan written, phases 2 to 5 planned
separately
Branch: ericgriffin/build-feature-2267-788b28 (the design and the first
phase 1 commits were written on `ericgriffin/cert-renewal-warning-chips-481afd`
and ported here)
Issue: #2267. Built as one PR whose body says `Closes #2267` (see Phasing).

## Problem

A certification can stop being good enough to dive on without its card
changing at all. PADI suggests a ReActivate when a diver has been out of the
water for six to twelve months, SSI calls the same thing a Scuba Skills
Update, a first aid credential lapses on a date, a professional membership
renews annually, GUE ratings need periodic revalidation, and a cave or
rebreather diver can be current in general while being two years away from
the discipline the card is for.

Submersion holds every fact needed to say so and says almost none of it. The
home strip has a last-dive chip that turns amber at 180 days and red at 365
(`gauge_strip.dart`, `kCurrencyWarnDays` and `kCurrencyAlertDays`), with
"typical agency refresher guidance" in its comment, but it never names a
consequence or a credential. A second chip counts certifications whose
`expiryDate` falls within 90 days, which only works for the minority of
cards where the diver typed a date, and knows nothing about what the
credential is. Nothing connects a diver's agencies and ratings to what those
agencies ask of them.

## Decisions

Taken during brainstorming and fixed for this spec.

- Scope covers all four cases: inactivity refreshers, dated credential
  renewals, formal agency revalidation, and per-discipline currency.
- The rule catalog is a synced table seeded with built-in rows, and the
  diver can add custom rules. Built-in rows are immutable reference data;
  editing one is copy-on-write into a custom rule that supersedes it.
- Per-certification overrides (interval, mute, which dive types count) live
  in their own table and sync.
- Which dives count toward a discipline rule ships as a default mapping the
  diver can confirm and change per certification.
- A completed refresher, renewal or revalidation is recorded in a per
  certification event ledger, in the shape of the gear service-record ledger.
- Home shows one summary chip, not one chip per credential.
- That chip is the existing `HomeChipType.certifications` chip, which the
  currency engine subsumes. The old expiring-certifications behavior becomes
  a date clock anchored on `expiryDate`.
- The chip opens the certification list filtered to "needs attention". Per
  credential controls live on the certification detail page.
- Rules apply on by default, mutable per rule. No first-run grace period and
  no acknowledgement gate.
- Hardening (rendering through the diver's hide, as gear, insurance and the
  flight window do) applies only to a lapsed date clock anchored on a date
  the diver entered. Inferred lapses stay hideable.
- No rule text ever says "required". Rules carry advisory wording naming the
  agency's guidance, because this catalog is our reading of rules that vary
  by region, shop and year.
- `CertificationLevel` gains `firstAid` and `oxygenProvider` in phase 1, so
  the dated first aid rule has something to match.

## Domain model

A rule answers one question about one credential: when does this need
attention, and what resets it? Every rule has a scope, a clock kind and an
interval.

**Scope** selects credentials by agency and level, each as a JSON array where
an empty array means "any", following the `applicableTypes` pattern already
on `ServiceKinds`.

**Clock kind** is one of two:

- `date`: the clock counts from a date on the card. Anchor precedence is
  `expiryDate`, else the newest ledger event for that rule, else
  `issueDate` plus the interval. When none of the three exists the
  credential has no clock and never warns.
- `activity`: the clock counts from the later of the last qualifying dive and
  the newest ledger event, so a logged refresher resets it without diving.
  Qualifying means the confirmed dive types and dive modes, or any dive when
  the mapping is empty. A diver with no dives gets no warning.

**Interval** is a lapse threshold in days plus a lead time in days, giving
three severities: `current`, `dueSoon` (inside the lead window), `lapsed`
(at or past the threshold). The names are deliberately distinct from
`ServiceClockSeverity`, whose `overdue` gear chips sit beside these on the
same strip and in the same translation files.

A negative elapsed time (an anchor in the future, from a forward-dated card
or device clock skew) reads as `current`.

### Collapsing

Statuses collapse for display by (rule, anchor). A diver holding Open Water,
Advanced Open Water and Rescue from one agency shares one rule and one
anchor (their last dive), so they see one row, not three. The representative
credential is the most advanced matching one, tie-broken by newest
`issueDate` then by id. A mute or interval override applied from a collapsed
row writes prefs for every member of the group, so the row means what it
appears to mean.

## Default catalog

Fifteen-hundred-word agency rulebooks do not belong in a seed, so these are
deliberately few, conservative, and editable. Levels named below are
`CertificationLevel` values; dive types are the seeded `dive_types` slugs.

| id | name | scope | clock | lead | lapse | counts |
| --- | --- | --- | --- | --- | --- | --- |
| `padi_reactivate` | PADI refresher (ReActivate) | agency padi, ladder levels | activity | 185 | 365 | any dive |
| `ssi_skills_update` | SSI Scuba Skills Update | agency ssi, ladder levels | activity | 185 | 365 | any dive |
| `generic_refresher` | Refresher | agencies naui, sdi, tdi, raid, bsac, cmas, iantd, psai, ffessm, acuc, other; ladder levels | activity | 185 | 365 | any dive |
| `first_aid_24mo` | First aid and CPR renewal | any agency, levels firstAid, oxygenProvider and DAN's provider credentials | date | 60 | 730 | n/a |
| `pro_membership_annual` | Professional membership renewal | any agency except ffessm and gue, professional levels including ACUC's and DAN's | date | 45 | 365 | n/a |
| `gue_revalidation` | GUE revalidation | agency gue, any level | date | 90 | 1095 | n/a |
| `ffessm_licence_annual` | FFESSM licence and medical certificate | agency ffessm, any level | date | 45 | 365 | n/a |
| `cave_currency` | Cave currency | any agency, levels cave, cavern, gueCave1, gueCave2 | activity | 90 | 365 | dive types cave, cavern |
| `rebreather_currency` | Rebreather currency | any agency, level rebreather | activity | 90 | 180 | dive modes ccr, scr |
| `deco_currency` | Decompression currency | any agency, levels decompression, trimix, advancedTrimix, advancedNitrox, techDiver, extendedRange, gueTech1, gueTech2 | activity | 90 | 365 | dive type technical |

"Ladder levels" means every rung of each named agency's ladder in
`CertificationLevelCatalog.ladderFor`, professional rungs included (decided
during implementation), not the specialty list. TDI, IANTD and PSAI use the
tech ladder, so the generic refresher's union includes its rungs too. A
seeded rule stores the resolved level names, so the catalog's own grouping
can change later without moving a diver's rules;
`currency_seed_catalog_test.dart` pins the two together.

A lead of 185 days against a lapse of 365 turns a refresher amber at 180
days since the last dive, the same day the home strip's last-dive chip does.

`gue` is left out of `generic_refresher` because `gue_revalidation` already
speaks for those cards. `ffessm` is in both, because an annual licence and
in-water currency are two different things.

ACUC and DAN arrived from #3011 while this was open. ACUC is a diver
ladder like any other, so it joins `generic_refresher` and membership. DAN
issues first aid and emergency credentials rather than diver grades, so its
provider credentials renew with `first_aid_24mo` and its instructor ratings
with membership; it gets no refresher. `currency_seed_catalog_test.dart`
fails when a later agency is covered by no refresher.

No rule ships for nitrox, sidemount, drysuit, wreck, ice, night, drift, deep
or altitude. Nothing about them lapses, and a catalog that warns about a
nitrox card teaches divers to ignore the chip.

## Data model

Three new tables in the main (synced) database, mirroring the
`ServiceKinds` / `ServiceSchedules` / `ServiceRecords` triple, plus two
enum additions.

### `certification_currency_rules`

| column | type | notes |
| --- | --- | --- |
| `id` | text pk | stable slug for built-ins, UUID for custom |
| `diver_id` | text null | null for built-ins, references `Divers` |
| `name` | text | English for built-ins, resolved to l10n at render |
| `clock_kind` | text | `date` or `activity` |
| `applicable_agencies` | text | JSON array of `CertificationAgency` names, `'[]'` = any |
| `applicable_levels` | text | JSON array of `CertificationLevel` names, `'[]'` = any |
| `lapse_days` | int | |
| `lead_days` | int | |
| `counted_dive_type_ids` | text | JSON array of `dive_types.id`, `'[]'` = any dive |
| `counted_dive_modes` | text | JSON array of `DiveMode` names, `'[]'` = any |
| `advisory_key` | text null | l10n key for built-ins |
| `advisory_text` | text null | free text for custom rules |
| `supersedes_rule_id` | text null | set on a copy-on-write custom rule |
| `is_built_in` | bool | default false |
| `created_at`, `updated_at` | int | |
| `hlc` | text null | |

### `certification_currency_prefs`

One row per (certification, rule) the diver has touched. An absent row means
"inherit everything", which is what makes on-by-default need no seeding.

| column | type | notes |
| --- | --- | --- |
| `id` | text pk | |
| `certification_id` | text | references `Certifications`, cascade delete |
| `rule_id` | text | plain text, no FK, so a pref survives deleting a custom rule |
| `lapse_days_override` | int null | |
| `lead_days_override` | int null | |
| `counted_dive_type_ids` | text null | null inherits the rule's mapping |
| `counted_dive_modes` | text null | null inherits the rule's mapping |
| `muted` | bool | default false |
| `created_at`, `updated_at` | int | |
| `hlc` | text null | |

### `certification_currency_events`

| column | type | notes |
| --- | --- | --- |
| `id` | text pk | |
| `certification_id` | text | references `Certifications`, cascade delete |
| `rule_id` | text null | plain text; null means a refresher not tied to a rule |
| `event_type` | text | `refresher`, `renewal`, `revalidation`, `skillsUpdate`, `other` |
| `event_date` | int | |
| `provider` | text null | shop, club or instructor |
| `notes` | text | default `''` |
| `created_at`, `updated_at` | int | |
| `hlc` | text null | |

All three carry their own `hlc` rather than riding the certification's clock.
Editing a pref never touches the certification row, so a clockless child
would never replicate, which is the reason `service_schedules` carries its
own clock today.

### Enum additions

`CertificationLevel.firstAid` ("First Aid / CPR") and
`CertificationLevel.oxygenProvider` ("Emergency Oxygen Provider"), both
agency-agnostic specialties added to `CertificationLevelCatalog.specialties`.
Levels persist as enum-name text, so existing rows are untouched, but both
values need display names in all eleven locales and both need to round trip
through UDDF import and export.

### Nothing stores a status

No computed severity, next-due date or elapsed count is persisted.
`ServiceSchedules` already carries the comment explaining why, and it binds
harder here: an activity clock moves every time a dive is logged, so a
stored status would dirty every credential on every dive and churn sync rows
for data any device can recompute.

## Seeding and catalog updates

Built-ins are seeded by the migration rung and by a `beforeOpen`
`CREATE TABLE IF NOT EXISTS` plus `INSERT OR IGNORE` self-heal, following
`kSeedBuiltInDiveTypesSql` and the v88 `cavern` precedent where
`INSERT OR IGNORE` preserves a user-created row that collides with a
built-in id.

Two rules for later releases:

- A new built-in rule arrives by `INSERT OR IGNORE`.
- A correction to an existing built-in's interval is for fresh databases
  only. No rung ever `UPDATE`s an existing rule row, because that would
  silently rewrite a diver's tuning.

The rung number is the next free one at implementation time. When this
spec was written main was at 222; when implementation started it was at
260; main then shipped 261 (#767), 262 (#2991), 263 (#3004), 264 (#2939), 265 (#2381), 266 (#3001), 267 (#3011), 269 (#3007) and 270 (#2999) while this was open, and an open branch holds 268, so the rung is 271. Either way
the self-heal matters: parallel branches have collided on this ladder
before. Adding tables never raises `minimumCompatibleSchemaVersion`.

## Sync and backup

- Three `hlcTargets` entries, three export functions, three import paths.
- Rule export filters `is_built_in = 0`. Built-ins are re-seeded identically
  on every device, so exporting one publishes nothing, which is the rule
  every other seeded table in this codebase already follows.
- Because built-ins never sync, the UI never edits one in place. Editing a
  built-in creates a custom rule with `supersedes_rule_id` set, which syncs
  normally, and the engine then ignores the built-in it supersedes.
- Custom rules need an entry in `diver_owned_rows.dart` so deleting a diver
  cleans them up.
- `deleteAllRecords` must spare `is_built_in` rows in the rules table. Sync
  adopt clears every synced entity and refills from an export that excludes
  built-ins, so an unguarded clear deletes 10 seeded rules and restores 0.
  That is exactly how built-in dive types were permanently wiped (PR #530),
  and `sync_builtin_reference_data_test.dart` discovers every `is_built_in`
  table from the schema, so this table inherits that coverage on day one and
  will fail the suite until both the spare and the re-seed are in place.
- The byte-copy `.db` backup carries all three tables for free. The
  hand-written UDDF full backup must carry custom rules, prefs and events
  explicitly, or they are lost on format conversion. Restoring one goes
  through the import wizard, so they also cross it: carried as payload
  metadata, as custom dive roles are, with no selection step of their own.
  Custom rules restore unconditionally, keeping their id unless one is
  already here. Prefs and events ride along with the certifications the
  import created, as service records ride along with equipment, and are
  skipped for a certification the review matched to an existing card. There is no test that
  enumerates tables against the backup, so this needs a new per-feature
  provider-capture test in the shape of
  `export_uddf_site_features_test.dart`, which intercepts
  `#saveAllDataToUddfFile` and catches a correct writer the app never calls
  with the data.

## The engine

`lib/features/certifications/domain/services/certification_currency_engine.dart`,
pure and total: no database, no `DateTime.now()`, nothing thrown.

```dart
List<CredentialCurrency> evaluateCurrency({
  required List<Certification> certifications,
  required List<CurrencyRule> rules,
  required List<CurrencyPref> prefs,
  required List<CurrencyEvent> events,
  required DiveActivityIndex activity,
  required DateTime now,
})
```

Matching runs over `Certification.credentials`, not the row's `agency` and
`level`, because one card can grant several recognitions (the FFESSM Niveau 1
that is also a CMAS 1-star), and a CMAS rule has to see that card. Matches
are deduped per (certification, rule) before collapsing.

A built-in rule is dropped when a live custom rule supersedes it. A muted
pref still yields a status carrying `muted`, so the currency list can show it
greyed while the chip ignores it.

Each `CredentialCurrency` carries its severity, its anchor date, and the
anchor's origin (`cardExpiry`, `cardIssue`, `ledgerEvent`, `lastDive`,
`lastQualifyingDive`), so every surface can explain itself in the diver's
words: "last cave dive 4 Mar 2026", "EFR expiry 1 Jan 2026", "refresher
logged 2 Aug 2025". The diver is allowed to disagree with a rule, so the app
has to show its work.

Elapsed time is calendar-day arithmetic, built with `DateTime(y, m, d + n)`,
never `DateTime.now().add(Duration(days: n))` and never `Duration.inDays`.
Intervals here run from 90 to 1095 days, so a window straddling a local DST
transition is near certain, and that exact mistake reddened main for every
open PR on 2026-09-20.

Consumer ordering mirrors gear: severity first, then soonest due, undated
last.

## Activity index

`DiveActivityIndex` holds `lastDiveAt`, `lastDiveByTypeId` and
`lastDiveByMode`, built from three `GROUP BY` aggregates. It is never one
query per certification, and a statement-count test pins that.

Dive timestamps are UTC-flagged wall clocks and this codebase is already
inconsistent about reading them (site aggregates read local, statistics read
UTC). The index reads them exactly as `daysSinceLastDiveProvider` does, so
the currency chip and the last-dive chip sitting inches apart on the same
strip can never disagree by a day.

## Home chip

`HomeChipType.certifications` keeps its name, its hide key and its place in
the strip, and changes meaning: it now reports the worst currency severity
across the diver's credentials, with a count label, and hides at zero. Tone
is alert when anything is lapsed, warn when only due soon.

Keeping the enum name is deliberate. A diver who has already hidden the
expiring-certifications chip stays hidden, and no migration rewrites their
`hiddenHomeChips` setting, which a rung must never do.

Hardening: the chip renders through a hide only when a lapsed status has an
anchor origin of `cardExpiry` or `ledgerEvent`, meaning a date the diver
entered. `cardIssue`, `lastDive` and `lastQualifyingDive` lapses stay
hideable, because they rest on the catalog's guess rather than the diver's
data.

The currency provider catches its own repository failures, logs them, and
returns an empty status list. `dashboardGaugesProvider` awaits everything
into one future, so an uncaught throw would take the whole strip to its retry
chip, including the hardened gear and flight-window chips that exist
precisely to be un-hideable. A currency bug costs the currency chip, not the
safety chips. The degradation is logged, never silent.

## Certification list scope

The chip opens `/certifications` scoped to "needs attention" (any status that
is `lapsed` or `dueSoon` and not muted). The scope is real filter state with
a visible, clearable indicator in the list header, so a diver is never
staring at a short list wondering where their cards went. The certification
list has sort and view-mode providers today and no filter, so this adds a
one-axis filter; unlike the dive list there is only one path to teach it.

The new route goes into the chip-destination list in
`test/core/router/app_router_test.dart`. PR #2259 landed the same shape for
gear on 2026-09-21 (one chip per severity opening a filtered equipment
list), so phase 3 follows `equipment_service_navigation.dart` and
`service_due_filter_display.dart` rather than inventing a pattern: the
filter is replaced rather than merged, because a leftover narrowing would
hide items the chip just counted. The gauge-strip widget test
navigates a hand-written stub router and would pass against a path that does
not exist in the app.

## Certification detail Currency section

A section on the certification detail page, in the shape of
`service_history_section.dart`: each matching rule with its severity, its
anchor in plain language, its advisory sentence, and actions to

- edit the interval (copy-on-write when the rule is built-in),
- mute or unmute the rule for this card,
- edit which dive types and modes count (activity clocks only),
- log a refresher, renewal or revalidation, which writes a ledger event,

followed by this credential's event history with delete.

## Settings, Manage, Certification currency

Browse the catalog, create and delete custom rules, and see which built-ins a
custom rule supersedes. Follows the settled convention for Manage pages: a
lower-right extended FAB and inline edit and delete icons, never an app-bar
plus button and never a row overflow menu.

## Localization

Built-in rule names and advisory sentences are l10n keys resolved at render
time through `builtInCurrencyRuleName(l10n, id)` and
`builtInCurrencyRuleAdvisory(l10n, id)`, the shape `builtInDiveTypeName`
already uses, so a seeded row never stores a translated string. Custom rules
store the diver's own text and are never translated.

All new keys land in all eleven ARB files. Only `app_en.arb` is alphabetical,
so inserts in the other ten anchor on a neighbouring key, and any plural
form spells its count with the placeholder rather than a literal digit.

Dates and intervals render through `UnitFormatter` so they respect the active
diver's settings, and a date formatted for a sentence passes `l10n:` rather
than shipping an English connector to every locale.

## Edge cases

- Only the active diver's certifications are evaluated, through whatever
  `allCertificationsProvider` returns. Buddy-owned cards are out of scope.
- A card with no `expiryDate`, no `issueDate` and no ledger event has no
  clock at all and never warns. Imported logbooks routinely carry undated
  cards, and a feature whose first act is to flag twelve of them is a feature
  the diver switches off.
- A diver with no dives gets no activity warnings. The last-dive chip
  already says "no dives yet".
- An activity rule that matches a card but has nothing counted yet (no
  dives, or none of the counted types and modes, and no logged refresher)
  keeps a neutral row on the detail page: "No counted dive logged yet". It
  never warns and never counts for the chip, but it keeps the row's
  actions, so a mapping narrowed to dives the diver has not logged can
  still be changed back (decided during review of the PR).
- Deleting a custom rule leaves inert prefs and intact history, rather than
  cascading away the record of a refresher the diver actually did.
- Deleting a certification cascades its prefs and events.
- Two devices logging the same refresher produce two ledger rows, visible and
  deletable, exactly as duplicate service records are today.
- Any new rung means a database this build has opened cannot be opened by an
  older stable build. That is the existing beta-ratchet behavior and belongs
  in the release notes.

## Files

New:

- `lib/features/certifications/domain/entities/currency_rule.dart`
- `lib/features/certifications/domain/entities/currency_pref.dart`
- `lib/features/certifications/domain/entities/currency_event.dart`
- `lib/features/certifications/domain/entities/credential_currency.dart`
- `lib/features/certifications/domain/entities/dive_activity_index.dart`
- `lib/features/certifications/domain/services/certification_currency_engine.dart`
- `lib/features/certifications/data/repositories/certification_currency_repository.dart`
- `lib/features/certifications/presentation/providers/certification_currency_providers.dart`
- `lib/features/certifications/presentation/currency_rule_display.dart`
- `lib/features/certifications/presentation/widgets/certification_currency_section.dart`
- `lib/features/certifications/presentation/widgets/currency_event_dialog.dart`
- `lib/features/certifications/presentation/widgets/currency_rule_edit_dialog.dart`
- `lib/features/settings/presentation/pages/manage_currency_rules_page.dart`

Modified:

- `lib/core/database/tables/certification_currency_tables.dart` (new: the
  three tables and the seed SQL)
- `lib/core/database/migrations/helpers/certification_currency_migrations.dart`
  (new: the schema assert, called by the rung and by `beforeOpen`)
- `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (the rung)
- `lib/core/database/migrations/before_open.dart` (the self-heal)
- `lib/core/database/database.dart` (the table list, `currentSchemaVersion`
  and `migrationVersions` only; since the split in #2502 no table or rung
  lives there)
- `lib/core/constants/certification_enums.dart` (`firstAid`, `oxygenProvider`)
- `lib/core/constants/certification_levels.dart` (specialties)
- `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`)
- `lib/core/services/sync/sync_data_serializer.dart` (export and import)
- `lib/features/divers/data/repositories/diver_owned_rows.dart`
- `lib/features/dashboard/presentation/providers/gauge_providers.dart`
- `lib/features/dashboard/presentation/widgets/gauge_strip.dart`
- `lib/features/certifications/presentation/providers/certification_providers.dart`
- `lib/features/certifications/presentation/widgets/certification_list_content.dart`
- `lib/features/certifications/presentation/pages/certification_detail_page.dart`
- `lib/core/router/app_router.dart`
- the UDDF full backup writer and reader
- eleven ARB files

## Testing

TDD. The engine's purity is what makes that cheap: nearly every rule is a
table test with no database and no widget tree.

Engine:

- matching across `credentials`, including a dual-agency card
- anchor precedence for both clock kinds, and no-dates-no-clock
- no dives at all, and a future-dated anchor
- severity exactly at the threshold and one day either side
- a window straddling a local DST transition
- muting, superseding, and collapsing by (rule, anchor) with the
  representative chosen correctly
- ordering

Data and sync:

- the rung on a fresh database and on an upgrade, with no stale version
  literals in the rung test
- `INSERT OR IGNORE` preserving a user-created row that collides with a
  built-in slug
- the `beforeOpen` self-heal creating missing tables
- the hlc census recognizing all three tables
- built-in rules excluded from export
- two devices tuning the same pref, merged by hlc
- statement count for the activity index constant between one certification
  and fifty, measured with `NativeDatabase.memory(logStatements: true)`
- UDDF full-backup round trip for custom rules, prefs and events, plus a new
  provider-capture test in the `export_uddf_site_features_test.dart` shape

Widgets and routing:

- chip label and tone, absence at zero
- hardening through a hide for a `cardExpiry` lapse, and no hardening for a
  `lastDive` lapse
- the existing guard that every rendered chip has a non-null `onTap`
- the new route in `app_router_test`'s chip-destination list
- the list's filter scope, its indicator, and clearing it
- the detail section: logging a refresher flips severity
- copy-on-write: editing a built-in produces a custom rule that supersedes it

Project-wide: the architecture guards scan all of `lib/`, so they run after
the new files land, plus ARB parity across eleven locales and the
generated-l10n staleness check.

## Phasing

One PR, built in five stages, each its own run of commits. The design was
first drawn as five PRs; it ships as one so the feature lands whole, which
also means no release carries a catalog the diver cannot see.

1. Enum additions, three tables, the rung and seed, entities, repository,
   sync and backup wiring. No UI.
2. Engine, activity index, providers, the full test tables.
3. Home chip fold and the filtered list scope.
4. Certification detail Currency section: status, ledger, interval, mute,
   mapping.
5. Settings Manage rules page, copy-on-write editing, l10n sweep.

Phases 1 and 2 carry the risk. Phases 3 through 5 are UI against a settled
engine.

## Out of scope

- Buddy certification currency.
- Notifications or reminders outside the app.
- Booking or linking to an agency's refresher course.
- Inferring a discipline dive from profile shape (deco stops, depth, CCR
  mode) when the dive type tag is absent. The mapping is diver-confirmed.
- Making certification agencies or levels user-extensible (issue #690 and
  issue #1648), which this design assumes stays as it is.
