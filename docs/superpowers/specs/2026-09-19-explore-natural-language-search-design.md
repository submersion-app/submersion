# Explore: on-device natural-language search

Date: 2026-09-19
Status: approved in brainstorm, program spec (phase 1 fully specified,
phases 2 and 3 scoped)

## Summary

A diver types a sentence such as "Turtles below 20m in Bonaire with viz
over 20m" or "Show cold-water dives using my trilaminate suit where SAC
increased after 20 minutes and the final stop was unstable", and the app
answers with something it can prove: the filter it understood, rendered as
editable chips; the words it could not place; the match count; one to three
small charts; and the matching dives, each a link. The sentence is
understood by an on-device platform model. Everything after that is
deterministic Dart over the local database. No dive data leaves the device.

The feature is called Explore in the UI and lives in
`lib/features/explore/`.

## Decisions fixed in the brainstorm

| Decision | Choice |
| --- | --- |
| Sentence understanding | An onboard platform model: Apple Foundation Models on iOS 26 and macOS 26 or later, Gemini Nano through the ML Kit GenAI Prompt API on supported Android devices. No bundled model, no network model. |
| Unsupported devices, platforms and locales | The Explore entry point is hidden. No keyword fallback. Windows and Linux have no path today; Windows is revisited after the Aion Instruct runtime ships in November 2026. |
| Scope of predicates | Stored fields, the five existing safety findings, and new profile-derived predicates (SAC trend, SAC before versus after N minutes, final-stop stability). |
| Subjects | Full multi-subject search: dives first, then equipment, sites, buddies, species, trips and dive centers. Tags are criteria only. |
| Surface | A dedicated Explore page with handoffs into the dive list and the Statistics tab. |
| Persistence | The last 20 queries with their compiled form, device-local in the local cache database. Not synced, not named, no management UI. |
| Model output | A small clause list (schema version 1) that a pure-Dart compiler validates, grounds and lowers to the subject's existing filter model. The model never emits ids, SQL or the filter itself. |

## Program shape

Three phases, each with its own implementation plan. Phases 2 and 3 are
independent once phase 1 is merged.

1. **Phase 1, core plus dives.** The native model package and its gate,
   the query schema, the compiler and entity resolver, the Explore page,
   recent queries, and four new dive filter axes (water temperature,
   visibility, water type, species). Usable on its own.
2. **Phase 2, profile-derived predicates.** Two device-local, engine-versioned
   tables, the worker-isolate sweep, and the derived predicates wired into
   the field catalog and all three filter paths.
3. **Phase 3, other subjects.** Equipment, sites, buddies, species, trips and
   centers as query subjects, each with a field catalog, a lowering to its
   filter model, and a result list built from the existing list content
   widgets.

The phase 1 spec below fixes the seams (schema, catalog, compiler output)
that phases 2 and 3 extend, so they cannot drift.

## Architecture

Five units, each with one job. Arrows show data flow.

```
sentence --> [1] submersion_nl (native) --> JSON (schema v1)
                                              |
                                              v
                     [3] QueryModel <-- validate
                                              |
                                              v
   diver's names, unit settings --> [4] QueryCompiler --> CompiledQuery
                                                            |
                                                            v
                                     [5] Explore page: chips, count,
                                         charts, results, handoffs
   [2] gate providers decide whether [5] is reachable at all
```

### Unit 1: the `submersion_nl` package

A local path package under `packages/submersion_nl`, modeled on
`packages/submersion_ocr`: one plain `MethodChannel`, one shared Swift file
for iOS and macOS (`sharedDarwinSource: true`), one Kotlin file for Android.
No Windows or Linux implementation; the Dart side reports
`unsupportedPlatform` there without touching the channel.

Two calls:

- `availability(localeTag) -> NlAvailability`, one of `available`,
  `deviceNotEligible`, `notEnabled`, `modelNotReady`, `downloadable`,
  `downloading`, `unsupportedLocale`, `unsupportedPlatform`. Apple maps
  `SystemLanguageModel.default.availability` and `supportsLocale`. Android
  maps `Generation.getClient().checkStatus()` and reports
  `unsupportedLocale` for any language other than English and Korean, the
  only languages the Prompt API is validated for.
- `download() -> Stream<double>` (Android only; Apple returns an empty
  stream).
- `compile(sentence, localeTag, schemaVersion) -> String` returning JSON.
  Apple builds a `DynamicGenerationSchema` at runtime from a schema
  description the Dart side passes once per session and constrains decoding
  to it. Android uses the compile-time Kotlin `@Generable` schema from the
  ML Kit schema compiler. Both tag the JSON with `"schemaVersion": 1`.

The package never receives dive data, entity names or unit settings. The
prompt is fixed text plus the schema, identical on every device, and stays
under 2,500 tokens so it fits the 4K context on shipping Apple hardware
(the adapter reads `contextSize` at runtime and refuses with
`contextExceeded` rather than truncating).

The Apple adapter prewarms a session when the Dart side calls `prepare()`
so the one to two second cold start happens while the page opens.

Error mapping (every native failure becomes one of these, surfaced as a
Dart `NlError`): `unsupportedLocale`, `contextExceeded`, `guardrail`,
`refusal`, `decodingFailure`, `modelNotReady`, `quotaExceeded`,
`schemaMismatch`, `unknown(message)`.

### Unit 2: gate providers

Two providers, kept separate as `isApplePlatformProvider` and
`iCloudAvailabilityProvider` are, so the entry point is never enabled
transiently while the probe loads:

- `explorePlatformSupportedProvider`: a synchronous `Provider<bool>` on
  `defaultTargetPlatform` (iOS, macOS, Android), overridable in tests.
- `exploreAvailabilityProvider`: a `FutureProvider<NlAvailability>` keyed
  on the active locale (`localeProvider`) that calls `availability`.

`exploreEnabledProvider` is true only when the first is true and the second
resolved to `available`. Every entry point watches it. `downloadable` is
shown on the Explore page itself as a download prompt, not on entry points.

### Unit 3: the query model

Pure Dart in `lib/features/explore/domain/query_model.dart`. This is the
JSON contract with the native layer, schema version 1:

```
ParsedQuery {
  schemaVersion: 1
  subject: dives | equipment | sites | buddies | species | trips | centers
  clauses: [ { field, op, value, unit?, text } ]
  mentions: [ { kind, text } ]
  time?: { text }
  unplaced: [ string ]
}
```

- `op` is one of `lt`, `lte`, `gt`, `gte`, `eq`, `between`, `in`, `not`.
- `value` is a number, a string, or a two-number list for `between`.
- `unit` is one of `m`, `ft`, `c`, `f`, `bar`, `psi`, `min`, `l_min`,
  `cuft_min`, or absent.
- `text` is the span of the sentence the clause came from; it is what the
  chip shows when the compiler cannot produce a better label.
- `kind` is one of `site`, `place`, `species`, `gear`, `buddy`, `tag`,
  `center`, `trip`, `computer`.
- `time.text` is the model's own words for a period ("last year",
  "May 2023", "since 2022"); the compiler lowers it.

Phase 1 accepts only `subject: dives`; any other subject is reported as
unplaced with the whole sentence, and the chip explains that only dives are
searchable yet. The field enum the native schema constrains is the phase 1
dive catalog below. Dart validates every payload against this model before
use; anything that fails validation is a `schemaMismatch`.

### Unit 4: the compiler

Pure Dart in `lib/features/explore/domain/`. `QueryCompiler.compile(
ParsedQuery, CompilerContext) -> CompiledQuery` where `CompilerContext`
carries the diver's unit settings, the locale, "now", and a
`NameIndex` (see below). Deterministic, no I/O.

`CompiledQuery`:

- `filter`: the subject's filter model, a `DiveFilterState` in phase 1.
- `chips`: an ordered list of `QueryChip` (label, the clause or mention it
  came from, the axis it clears when removed).
- `unresolved`: mentions that did not resolve, each with up to five ranked
  candidates.
- `unplaced`: words and rejected clauses, with their text.
- `charts`: the chart requests chosen by rule (see the page section).

Grounding rules, all owned by the compiler:

1. **Units.** A clause with a unit converts to metric storage units. A
   clause without a unit on a dimensioned field takes the diver's unit for
   that dimension (depth, temperature, pressure, SAC). The chip always shows
   the resolved unit.
2. **Field catalog.** `DiveFieldCatalog` maps each field to its axis,
   dimension, allowed ops and value type. A clause the catalog rejects
   becomes an unplaced entry carrying its text.
3. **Mentions.** Resolved by normalized Dice similarity
   (`lib/core/text/fuzzy_match.dart`) against a `NameIndex` built once per
   page open from the diver's own data. The index holds, per kind, the
   candidate label and the id it maps to. Match order and lowering:
   - `place`: site country, region, island, city, then site name; lowers to
     a site id set on the new `siteIds` axis (a `place` that matches one site
     name lowers to `siteId`).
   - `site`: site name; lowers to `siteId`.
   - `species`: localized name, stored English name, scientific name; lowers
     to the new `speciesIds` axis.
   - `gear`: equipment name, brand plus model, then attribute choice labels;
     an item lowers to `equipmentIds`, a choice label lowers to an
     `EquipmentAttrCondition` on that attribute key.
   - `buddy`: buddy name (entity) and legacy free-text names; lowers to
     `buddyId` or `buddyNameFilter`.
   - `tag`, `center`, `trip`, `computer`: their name; lowers to `tagIds`,
     `diveCenterId`, `tripId`, `computerId`.
   The threshold is 0.75, the site resolver's value. A best match that is
   below threshold, or a top two within 0.05 of each other, produces an
   unresolved entry with candidates instead of a guess.
4. **Time.** A small deterministic grammar over the model's `time.text` for
   years, month-year, "last N days, weeks, months, years", "this year",
   "since <year>", and ISO dates; lowers to `startDate` and `endDate`. Text
   the grammar does not accept becomes unplaced.
5. **Sanity.** Reversed `between` bounds are swapped; a negative depth or a
   temperature outside -5 to 45 C becomes unplaced; a unit on a unitless
   field is ignored with the chip showing the bare value.

The `NameIndex` is built by `NameIndexBuilder` from the existing
repositories with one query per kind and holds only ids and labels, so a
5,000-dive library builds it in well under a second on the main isolate.
The species labels come from the localized name lookup that the marine-life
feature already uses.

### Unit 5: the Explore page

Route `/dives/explore` under the dive list shell, pushed (never `go`, per
issue 647). Entry points: an icon in the dive list app bar and an app
shortcut, both watching `exploreEnabledProvider`.

Layout, top to bottom:

1. Sentence field with a submit action; below it up to five recent queries
   as chips. Selecting one reuses its stored `ParsedQuery` and skips the
   model.
2. A thin progress line while the model runs.
3. **Understood row.** One chip per clause and per resolved mention, in the
   app language regardless of the sentence's language, worded like the
   existing active-filter chips. Tapping a chip opens `DiveFilterSheet` on
   the Explore filter provider; the remove action drops the clause and
   recompiles. Once phase 3 lands the subject chip comes first.
4. **Needs attention row.** Unresolved mentions as outlined chips that open a
   candidate picker, and unplaced words as plain chips. The row hides when
   empty.
5. Count line from the existing dive count query.
6. **Charts.** Chosen by rule, never by the model, at most three, each drawn
   with `DiveTrendChart` or `HorizontalCategoryBarChart` at 180 px:
   - always: dives over time for the matched set;
   - one per numeric clause field among depth, water temperature, bottom
     time and (phase 2) SAC: a date-axis trend over the matched dives with
     tap-to-open;
   - one per mention kind that resolved to more than one entity (for
     example sites in Bonaire): dive count per entity.
   When more than three qualify, the order above wins.
7. Results: the existing dive list content in list mode, driven by the
   Explore filter provider.
8. Bottom bar: "Open in dive list" and "Open in Statistics". Each copies the
   compiled `DiveFilterState` into `diveFilterProvider` or
   `statisticsFilterProvider` and navigates there.

`exploreFilterProvider` is a third `StateProvider<DiveFilterState>`, so
editing chips never rescopes the dive list or Statistics until a handoff.

The existing active-filter chip row in the dive list gains chips for the
axes it does not show today (computer, weekdays, deco, rating, duration,
O2, custom field, gear attributes, excluded-only) and for the four new
axes, so a handoff never lands on a list whose filter is invisible.

## New dive filter axes (phase 1)

Added to `DiveFilterState` and threaded through all three evaluation paths
(`buildFilteredDiveIdSubquery`, `DiveRepositoryImpl._buildFilterWhereClauses`
with its count, and `apply()`), each with a parity test:

| Axis | Storage | Notes |
| --- | --- | --- |
| `minWaterTemp`, `maxWaterTemp` | `dives.water_temp` celsius | Nullable rows never match. |
| `minVisibility`, `maxVisibility` | `dives.visibility_meters` | The legacy bucket column is read-only and ignored. |
| `waterTypes` | `dives.water_type` | Set of enum names, OR within the axis. |
| `speciesIds` | `sightings.species_id` | EXISTS subquery, OR within the axis. |
| `siteIds` | `dives.site_id` | Set form of the existing `siteId`; used by `place` mentions. |

`sightings` joins a new table, so the paginator's change tick follows a
sightings watch only while `speciesIds` is set, mirroring the
equipment-attribute tick rule, and `watchStatisticsChanges` gains
`sightings`.

The `DiveFilterSheet` gains sections for the four new axes so a chip can be
edited in place.

## Recent queries

Table `recent_queries` in the local cache database (`sentence`, `locale`,
`parsedJson`, `schemaVersion`, `subject`, `lastUsedAt`, primary key on the
normalized sentence plus locale). Capped at 20 rows by deleting the oldest
on insert. Rows whose `schemaVersion` is older than the current one are
ignored and deleted lazily. Accessed through a repository that takes an
optional database override and otherwise uses
`LocalCacheDatabaseService.instance`, exposed by
`recentQueriesProvider` (a notifier that appends on search).

## Phase 2: profile-derived predicates

Two tables in the main database, device-local by construction: no `hlc`
column, never synced, never backed up, cascade on dive delete, one migration
rung with an idempotent `_assert*` helper also called from `beforeOpen`.

**`dive_derived_metrics`** (primary key `dive_id`): `engine_version`,
`source_updated_at`, `computed_at`, `final_stop_kind` (safety, deco, none),
`final_stop_start_s`, `final_stop_duration_s`, `final_stop_depth_stddev_m`,
`final_stop_max_excursion_m`, `sac_mean_bar_min`, `sac_slope_bar_min_per_min`,
`runtime_s`, `unsupported_reason` (no profile, gauge mode, no pressure
series, too short).

**`dive_sac_buckets`** (primary key `dive_id`, `bucket_index`):
`sac_bar_min` per five-minute bucket, written only when SAC is computable.

Engine: `DerivedMetricsService` (pure, `static const int version = 1`)
reuses the profile analysis SAC segmentation and safety-stop detection from
`ProfileAnalysisService` and `GasAnalysisService`. The final stop is the
last level segment shallower than 7 m lasting at least 60 s; stability is
its depth standard deviation and max excursion from its median depth. The
worker decodes undecoded blobs on an isolate exactly as
`computeSensorSummaryFromBlobs` does, including the corrupt-blob and
forward-version rules.

Scheduler: `DerivedMetricsScheduler`, a copy of `SensorSummaryScheduler`
(singleton, single-flight tail, burst merging, always-completing callback,
`enabled` flag flipped off in `flutter_test_config.dart`), hooked into the
same import, save, split, consolidate, reparse and repair sites, with a stale
sweep at startup and after sync or restore. Stale rows: missing, older
engine, or `source_updated_at` drift, oldest dive first.

Predicates added to the dive field catalog, all SQL-only (skipped by
`apply()`, intersected by id set as `decoOnly` is today):

| Field | Lowering |
| --- | --- |
| `sacTrend` rising, falling, flat | slope above 0.02, below -0.02, or between |
| `sacAfterVsBefore` with N minutes | AVG of buckets with index >= N/5 compared with AVG of earlier buckets |
| `finalStopUnstable` | `final_stop_max_excursion_m` above a threshold the chip shows (default 1.0 m) |
| `finalStopDuration` | `final_stop_duration_s` |
| `finding` rapidAscent, missedDecoStop, omittedSafetyStop, sawtoothProfile, highSurfaceGf | EXISTS on `dive_safety_findings` with a current engine version |

The native schema's field enum grows by these names, which is a schema
version bump to 2 on all three sides.

## Phase 3: other subjects

Each subject gets a `FieldCatalog`, a lowering target, a result widget and
an entity link. The compiler's subject dispatch is a sealed switch, so an
unsupported subject is a compile error, not a runtime surprise.

| Subject | Lowering target | Notes |
| --- | --- | --- |
| Equipment | `EquipmentFilterState` (status, service due, type, attribute conditions, tag ids) plus new `dueWithinDays`, `lastUsedBefore`, `lastUsedAfter`, `minDiveCount` evaluated from the existing service clock and exposure providers | "Regulators due for service in 30 days" |
| Sites | `SiteFilterState` (country, region, difficulty, depth, rating, coordinates, has dives, site types, tag ids) plus `lastDivedBefore` and `minDiveCount` from the site aggregates | "Sites in Bonaire I have not dived since 2022" |
| Buddies | new `BuddyFilterState` (`minDiveCount`, `lastDiveAfter`, `lastDiveBefore`, `roleId`, `favoritesOnly`) applied in Dart over `BuddyWithDiveCount` | "Who have I dived with most this year" |
| Species | the existing `filterSeenSpecies` signature plus `minSightings`, `firstSeenAfter`, `lastSeenBefore`, `category` | "Species I have only seen once" |
| Trips | `TripFilterState` gains `startAfter`, `endBefore`, `minDiveCount`, `tripType`, `location` | "Liveaboard trips in 2024" |
| Centers | new `DiveCenterFilterState` (`country`, `city`, `minDiveCount`, `minRating`) applied in Dart | "Centers in Mexico I have used more than twice" |

Subject-specific mentions reuse the same `NameIndex`. Results reuse the
subject's existing list content widget with its detail route. Handoffs go to
that subject's list page and write its filter provider. Charts for non-dive
subjects are a single count-per-entity bar chart.

## Error handling

- Every adapter failure is one `NlError`, shown as a one-line explanation
  under the field; the field stays editable. Nothing falls back silently to
  another kind of search.
- JSON that fails Dart validation, or a native `schemaVersion` older than
  the Dart one, is a `schemaMismatch`: logged with both versions and shown
  as "could not understand this". A stale native build therefore fails
  loudly rather than compiling wrong filters.
- Model nonsense is normalized where unambiguous (reversed bounds) and
  otherwise unplaced.
- Derived-metrics gaps write a row with `unsupported_reason` so the sweep
  never revisits them and predicates simply do not match.
- The scheduler callback always completes normally; per-dive failures are
  caught and counted.
- Privacy: only the sentence and the locale reach the model. Chips, counts,
  charts and results come from the local database. Recent queries store the
  sentence and the parsed JSON, never results.

## Testing

- **Compiler and resolver**: unit tests with a fixture of sentences, their
  canned `ParsedQuery` JSON and the expected `DiveFilterState`, including
  both sentences from the summary, metric and imperial divers, near-equal
  site candidates, unplaced words, and every catalog field. No model.
- **Three-path parity**: for each new axis, a database test asserting that
  Statistics, the paginated list and the id query select the same dives,
  plus the stats-scope census.
- **Derived metrics**: engine tests on synthetic profiles (stable stop,
  excursion, rising and flat SAC, no pressure series); scheduler tests with
  a same-isolate runner; a stale-row query test for all three staleness
  cases; a migration test for the rung.
- **Page**: widget tests with a fake adapter for the gate (hidden when
  unavailable, hidden on an unsupported locale, never enabled while the
  probe loads), both chip rows, the chart selection rule including the
  three-chart cap, and both handoffs writing the right provider.
- **Native contract**: a manual smoke per platform recorded in each plan,
  since CI has no Apple Intelligence or AICore hardware; the adapter's JSON
  is validated by the same Dart validator the app uses.
- **Architecture guards**: `test/architecture` runs after the new feature
  directory is added.

## Out of scope

- A keyword or grammar fallback for devices without a model.
- A bundled or network-hosted model.
- Named or synced saved queries.
- Windows support before the Aion Instruct runtime ships.
- Free-form answers: Explore never shows model-written prose.

## Deviations recorded during implementation (phase 1)

- Android ships prompt-only JSON validated by Dart; constrained decoding via
  the ML Kit schema compiler is deferred until it leaves alpha. The
  `genai-prompt` 1.0.0-beta4 API returns `download()` as a
  `Flow<DownloadStatus>` and `checkStatus()` as an integer, not the callback
  and enum the plan assumed; the adapter follows the real API.
- The Apple schema declares clause values as strings because a
  `DynamicGenerationSchema` property has one type; Dart coerces quoted
  numbers, lists and booleans and strips `unit: "none"` (`_coerceValue`).
  Apple's error families are mapped by case name so both the 26.x and 27.x
  error types land on the documented channel codes.
- ARB keys with several placeholders carry `@key` placeholder metadata in
  the template file, because `flutter gen-l10n` orders untyped placeholders
  alphabetically and the labels came out reversed without it.
- The Drift generated files are gitignored in this repository and are
  produced by codegen, so `local_cache_database.g.dart` is not committed.
- The recent-query recorder provider carries the tick guard's `no-tick`
  marker: it returns a write function, and the list provider follows the
  table's own change stream.
- The manual macOS and Android smoke of the model adapters is owed: both
  platforms compile (Xcode 27, `genai-prompt` beta4), but neither model was
  exercised on hardware during implementation.

## Deviations recorded during implementation (phase 2)

- The engine computes SAC itself rather than calling
  `GasAnalysisService.calculateCylinderSac`. That method takes a hydrated
  `Dive`, and this work runs on a worker isolate from undecoded blobs, so the
  spec's "reuses the existing SAC segmentation" is honoured in rule, not in
  code path.
- A level run at the final stop is judged by the run's SPREAD, not by each
  sample's distance from a running median. A diver alternating above and
  below the median moves it on every sample, which ended the run at the first
  swing even though the whole swing sat inside the band.
- Engine constants, none of which the spec fixed: a final stop is a level run
  under 7.0 m lasting at least 60 s, with a level window of 1.5 m either side
  (so a spread of 3.0 m). SAC buckets are 300 s wide.
- A bucket whose tank pressure ROSE is skipped, not recorded as zero. A tank
  change or a sensor glitch would otherwise drag both the mean and the slope
  toward zero and read as a falling trend.
- A tank can carry one pressure series per computer that logged it. The
  repository picks the longest series, with the row id as tie-break, so the
  stored metrics do not depend on the order the query returned rows in.
- Both derived tables are children of `dives` with `ON DELETE CASCADE` and no
  `hlc` column. Schema rung v223; `migrationVersions` gained 223 beside the
  bump, and the v222 rung test handed over its exact-version assertions. The
  rung was renumbered from 222, which the per-site seascape vertical
  exaggeration overrides (#2141 follow-up) took on main while this was in
  review: two branches each bumping the ladder is the ordinary case, and the
  `beforeOpen` re-assert exists precisely so a collision cannot strand a
  database.
- The SQL table is named `dive_derived_metrics` via a `tableName` override,
  because the Drift class has to be `DiveDerivedMetricsRows` to avoid
  colliding with the `DiveDerivedMetrics` domain type.
- Two derived clauses are deliberately not expressible and stay unplaced. A
  stable final stop is the negation of an EXISTS, which would also match
  every dive with no stop at all, and a multi-valued SAC trend matches every
  dive with any slope.
- `safetyFindingNames` is spelled out in the field catalog rather than
  derived from `SafetyRuleId.values`, because `enumValues` sits in a const
  map. A guard test asserts the two stay in step.
- The prompt interpolates `kQuerySchemaVersion` instead of repeating the
  number, so the schema version can never drift from the constant again.
- German uses AMV, not SAC: a repo guard enforces that across the German ARB
  file, and the first draft of the new strings tripped it.
- The manual macOS and Android smoke owed from phase 1 is still owed, and now
  also covers whether the model reaches for the five new fields.

## Open items for the implementation plans

- Confirm with a device probe whether the Apple context is 4,096 or 8,192
  tokens on the maintainer's hardware, and size the prompt for 4,096.
- Confirm that the ML Kit schema compiler's alpha artifact builds under the
  app's Kotlin and KSP versions; if not, the Android adapter ships
  prompt-only JSON and relies on Dart validation, and the plan says so.
- A GitHub issue for the program must exist before the first PR; each phase
  PR references it with `Refs` and the last one closes it.
