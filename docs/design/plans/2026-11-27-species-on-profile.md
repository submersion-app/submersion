# Where on the dive each species was seen: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task (inline, in this session). Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** A depth chip on each placeable sighting in the Marine life card that
highlights the species on the dive profile and pinned strip, fed by tagged
photos, video tracks and a new optional "Seen at" time on the sighting.

**Architecture:** One nullable synced column on `sightings`. A pure domain
function turns a dive's sightings, media, tags, accepted identifications and
chart profile into per-species spans and moments. A per-dive selection
provider (mutually exclusive with the safety finding selection) drives a new
species overlay on `DiveProfileChart` and a new always-on pinned strip layer.

**Tech stack:** Flutter, Riverpod (legacy `StateProvider` as used by
`selectedSafetyFindingProvider`), Drift, fl_chart.

**Spec:** `docs/design/specs/2026-11-27-species-on-profile-design.md`.
Issue #5092.

## Global constraints

- Seconds from the dive start everywhere (the chart x-axis unit). Depth is
  never stored; it is read from the chart profile (`watchChartProfile`).
- Null `seen_at_seconds` means no time. No backfill, no data rewrite.
- `minimumCompatibleSchemaVersion` rises to the new schema version.
- "Seen at" upper bound: chart profile's last second, else
  `dive.measuredRuntime`, else `dive.bottomTime`, else 86,400. Never
  `effectiveRuntime`.
- Unconfirmed app tags and the identifications accepted for them count like
  the diver's own.
- Depth chip text in the active diver's unit, whole units (`27 m`,
  `16 to 18 m`; `89 ft`). Every new string in every ARB locale.
- No em-dash characters anywhere (code, comments, ARB, commits).
- New `lib/` files stay under 400 lines; nothing new goes into
  `database.dart` beyond the two version constants and the floor's doc
  paragraph.
- Local test runs: only the test files a task names, by path.

## Review focus

1. **Clearing a time** in the edit sheet must store null, not keep the old
   value (`updateSighting` always writes the column). Test in Task 1.
2. **Media with no place on the profile** (no enrichment, `noProfile`
   confidence, outside the dive window, a document) contributes nothing and
   never throws. Test in Task 2.
3. **A multi-computer dive viewed on another source**: positions use the
   chart profile the diver is looking at, not `dive.profile`. Test in Task 3.
4. **A selected species whose sighting is deleted or loses every position**
   draws nothing and the stale selection does not resurrect a chip. Test in
   Task 4.
5. **Imperial units**: a 4.6 to 5.4 m span reads `15 to 18 ft`, and a range
   that rounds to one value reads as one value (`16 m`, not `16 to 16 m`).
   Test in Task 6.

---

### Task 1: The column, the entity and the repository

**Files:**
- Modify: `lib/core/database/tables/marine_life_tables.dart` (`Sightings`)
- Create: `lib/core/database/migrations/helpers/sighting_seen_at_migrations.dart`
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart`
- Modify: `lib/core/database/migrations/before_open_child_columns.dart`
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`,
  `minimumCompatibleSchemaVersion` and its doc paragraph)
- Modify: `lib/features/marine_life/domain/entities/species.dart` (`Sighting`)
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart`
- Modify: `lib/features/marine_life/presentation/providers/species_providers.dart`
  (`addSighting` passes it through)
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart`
  (`dart run tool/generate_sql_column_notes.dart`)
- Test: `test/core/database/migration_v<N>_sighting_seen_at_test.dart`
- Test: `test/features/marine_life/data/repositories/species_repository_seen_at_test.dart`
- Test: `test/core/services/sync/sync_serializer_upsert_test.dart` (one case)

**Interfaces:**
- Produces: Drift column `Sightings.seenAtSeconds` (`seen_at_seconds`,
  `integer().nullable()`), with a doc comment naming v`<N>` and #5092.
- Produces: `Sighting.seenAtSeconds` (`int?`), in `props`;
  `Sighting.copyWith({..., int? seenAtSeconds, bool clearSeenAt = false})`.
- Produces: `SpeciesRepository.addSighting({..., int? seenAtSeconds})`;
  `updateSighting` writes `seenAtSeconds` as `Value(sighting.seenAtSeconds)`
  (null included); `getSightingsForDive`, `getSightingById` and
  `getSightingsForDives` read it.

`<N>` is the next schema number no open PR claims: run
`gh pr list --state open --limit 100` and grep their diffs for
`currentSchemaVersion = ` before picking (387 and 388 were claimed on
2026-11-27).

- [ ] **Step 1: Write the failing tests**
  - Migration test (copy the shape of `migration_v350_sighting_abundance_test.dart`):
    `'v<N> adds a nullable sightings.seen_at_seconds and keeps every row'`:
    a v`<N-1>` database with one sighting migrates, the row survives with
    `seen_at_seconds` null, and `PRAGMA table_info(sightings)` lists the
    column; `'the beforeOpen backstop re-adds a missing column'`.
  - Repository tests: `'addSighting stores seenAtSeconds'` (add with 720,
    `getSightingsForDive` returns 720); `'updateSighting clears a time'` (add
    with 720, update with `copyWith(clearSeenAt: true)`, read back null);
    `'getSightingsForDives carries seenAtSeconds'`.
  - Sync serializer case: a sightings row with `seen_at_seconds: 720`
    round-trips through upsert (follow the v350 abundance case in that file).
- [ ] **Step 2:** Run the three files; expect failures (missing column/field).
- [ ] **Step 3:** Implement: the column; `_assertSightingSeenAtColumn()` in the
  new part file (`_addColumnIfMissing('sightings', 'seen_at_seconds', 'INTEGER')`,
  guarded by `_tableExists`); the rung `if (from < N)` with
  `reportProgress()`; the backstop call next to the abundance one; both
  version constants to `<N>` and a floor paragraph in the style of the v350
  one (old peers drop the key; after upgrading they publish an explicit null
  that erases the time everywhere). Entity, repository, sitting
  (`addSighting(..., seenAtSeconds: sighting.seenAtSeconds)`), notifier.
  Run `dart run build_runner build --delete-conflicting-outputs` (never
  `--build-filter`) and regenerate the column notes.
- [ ] **Step 4:** Run the three files; expect PASS. Run
  `test/features/marine_life/data/repositories/species_repository_abundance_test.dart`
  and `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting_test.dart`.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, commit
  `feat(dive-log): store an optional time on a sighting`.

### Task 2: Species positions on the profile (pure)

**Files:**
- Create: `lib/features/dive_log/domain/services/species_profile_positions.dart`
- Test: `test/features/dive_log/domain/services/species_profile_positions_test.dart`

**Interfaces:**
- Consumes: `photoMarkerFor` (`photo_marker_layout.dart`), `profileDepthAt`
  (`domain/services/profile_depth_at.dart`), `cropsOfSpecies` and
  `videoStretches` (`species_id/domain/services/species_crops.dart`).
- Produces:

```dart
typedef SpeciesMoment = ({int seconds, double depthMeters});
typedef SpeciesSpan = ({int start, int end, double minDepth, double maxDepth});

class SpeciesProfilePositions {
  const SpeciesProfilePositions({required this.moments, required this.spans});
  final List<SpeciesMoment> moments; // time-sorted
  final List<SpeciesSpan> spans; // time-sorted, merged
  bool get isEmpty;
  double get minDepthMeters; // over moments and spans
  double get maxDepthMeters;
}

/// Positions per species id, for the species that have any.
Map<String, SpeciesProfilePositions> speciesProfilePositions({
  required List<Sighting> sightings,
  required List<MediaItem> media,
  required Map<String, List<MediaSpeciesTag>> tagsByMedia,
  required Map<String, List<MediaIdentification>> identificationsByMedia,
  required List<DiveProfilePoint> profile,
});
```

Rules (spec, "Where a species' positions come from"): empty profile gives an
empty map. A sighting's `seenAtSeconds` is a moment clamped to
`[0, profile.last.timestamp]`, depth `profileDepthAt`. A non-video tagged
with the species is a moment at its `photoMarkerFor` place and depth. A video
tagged with the species: base = its `photoMarkerFor` elapsed seconds; spans
from `videoStretches(cropsOfSpecies(ids, speciesId).where((i) => i.isTrack))`
as `base + startMs ~/ 1000` to `base + (endMs + 999) ~/ 1000`; with no such
track, one span `base` to `base + durationSeconds` (a moment at `base` when
the duration is unknown). Spans are clamped to the profile and merged when
they overlap or touch. A span's depths are the min and max of
`profileDepthAt` at its ends and every profile sample inside it.

- [ ] **Step 1: Write the failing tests** (build `MediaItem`s with a
  `MediaEnrichment`, a 50 minute profile as in the PR shot test):
  - `'a sighting time is a moment at the profile depth'`: 720 gives
    `moments == [(seconds: 720, depthMeters: profileDepthAt(profile, 720))]`.
  - `'a time past the profile end is clamped'`: 9000 gives a moment at
    `profile.last.timestamp`.
  - `'a tagged photo is a moment at its marker'`.
  - `'an unconfirmed tag counts'`: a tag whose row is unconfirmed still places.
  - `'accepted video tracks become spans offset by the clip start'`: clip
    at 600 s, tracks 2,000 to 9,500 ms and 9,800 to 14,000 ms give one span
    602 to 614.
  - `'a hand-tagged video with no track spans the clip'`: clip at 600 s,
    duration 45 gives 600 to 645.
  - `'rejected and other-species tracks are ignored'`.
  - `'overlapping spans from two videos merge'`.
  - `'media with no place contribute nothing'` (no enrichment, `noProfile`,
    outside the window, a document): empty map, no throw.
  - `'depth range spans moments and spans'`: min and max over both.
  - `'an empty profile gives no positions'`.
- [ ] **Step 2:** Run the file; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file; expect PASS.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): place a dive's species on its profile`.

### Task 3: Positions and selection providers

**Files:**
- Create: `lib/features/dive_log/presentation/providers/species_profile_providers.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_review_section.dart`
  (`_toggleSelected` clears the species when it selects a finding)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart`
  (`onSafetyFindingTap` likewise)
- Test: `test/features/dive_log/presentation/providers/species_profile_providers_test.dart`

**Interfaces:**
- Consumes: Task 2; `mediaForDiveProvider`, `mediaSpeciesRepositoryProvider`
  (`getTagsForMediaIds`, `watchTagChanges`), `mediaIdentificationRepositoryProvider`
  (`forMediaIds(ids, withPaths: false)`, `watchChanges`),
  `mediaRepositoryProvider.watchMediaChanges`, `diveSightingsProvider`,
  `watchChartProfile`.
- Produces:

```dart
typedef DiveSpeciesMediaInputs = ({
  List<MediaItem> media,
  Map<String, List<MediaSpeciesTag>> tagsByMedia,
  Map<String, List<MediaIdentification>> identificationsByMedia,
});
final diveSpeciesMediaInputsProvider =
    FutureProvider.family<DiveSpeciesMediaInputs, String>(...); // by dive id

/// Per-species positions on the profile the chart is drawing; an empty map
/// while anything loads. Memoised on its inputs' identities.
Map<String, SpeciesProfilePositions> watchSpeciesPositions(
  WidgetRef ref,
  Dive dive,
);

/// The species highlighted on a dive's profile, by species id.
final selectedProfileSpeciesProvider =
    StateProvider.family<String?, String>((ref, diveId) => null);

/// Selects [speciesId], or clears it when already selected; selecting
/// clears the dive's selected safety finding.
void toggleProfileSpecies(WidgetRef ref, String diveId, String speciesId);

/// What the chart and strip draw: the selected species' positions and
/// colour, or null when nothing (or nothing placeable) is selected.
SpeciesProfileHighlight? watchSpeciesHighlight(WidgetRef ref, Dive dive);

class SpeciesProfileHighlight {
  const SpeciesProfileHighlight({required this.positions, required this.color});
  final SpeciesProfilePositions positions;
  final Color color; // colorForSpeciesCategory of the sighting's category
}
```

- [ ] **Step 1: Write the failing tests** (`ProviderContainer` plus a
  `testWidgets` harness for the `WidgetRef` helpers):
  - `'toggling selects, then clears'`.
  - `'selecting a species clears the selected safety finding'` and
    `'selecting a finding clears the species'` (drive the safety section's
    toggle).
  - `'the highlight uses the active source profile'`: a dive whose
    `activeSourceProfileProvider` returns a different profile places a
    sighting time at that profile's depth.
  - `'a selected species with no positions gives no highlight'`.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement. The inputs provider invalidates itself on tag,
  media and identification changes (`ref.invalidateSelfWhen`, as
  `diveSpeciesPhotoCountsProvider` does).
- [ ] **Step 4:** Run; expect PASS. Also run
  `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): select a species to highlight on the profile`.

### Task 4: The species overlay on the profile chart

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/species_profile_overlay.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
  (one parameter, three call sites; keep the logic in the overlay file)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart`
  (passes `watchSpeciesHighlight(ref, dive)`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_species_test.dart`

**Interfaces:**
- Consumes: `SpeciesProfileHighlight` (Task 3), `visibleHighlightSpan`.
- Produces: `DiveProfileChart({..., SpeciesProfileHighlight? speciesHighlight})`
  and in the overlay file:

```dart
List<VerticalRangeAnnotation> speciesHighlightBands(
  SpeciesProfileHighlight? highlight,
  {required double visibleMinX, required double visibleMaxX});
List<VerticalLine> speciesMomentLines(
  SpeciesProfileHighlight? highlight,
  {required double visibleMinX, required double visibleMaxX});
LineChartBarData? speciesMomentDots(
  SpeciesProfileHighlight? highlight,
  {required double Function(double meters) y, required Color ring});
```

Bands use alpha 0.12 like the finding band, drawn after counterdiffusion and
before the selected finding in `_buildHighlightRangeAnnotations`. Moment lines
are 1 px at alpha 0.7; dots follow the max-depth marker's ringed
`FlDotCirclePainter` (`y` is the chart's `-units.convertDepth`).

- [ ] **Step 1: Write the failing tests** (pump like
  `dive_profile_chart_highlight_test.dart`):
  - `'no species highlight adds nothing'`.
  - `'a span draws one band'`: span 600 to 645 gives a
    `VerticalRangeAnnotation` x1 600, x2 645.
  - `'a moment draws a line and a dot'`: moment 720 gives a vertical line at
    720 and a dot bar with one spot at x 720.
  - `'a highlight outside the zoomed window draws nothing'`.
  - `'a deleted sighting leaves no highlight'` (Review focus 4: a selection
    whose species has no positions draws nothing).
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run; expect PASS; also run
  `dive_profile_chart_highlight_test.dart` and
  `dive_profile_chart_secondary_ranges_test.dart`.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): draw the selected species on the profile`.

### Task 5: The species layer on the pinned strip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart`
  (`StripLayer.species`, `isLine` false, `kAlwaysOnStripLayers = {StripLayer.species}`)
- Modify: `.../layers/pinned_strip_layer_animator.dart` (`available` adds
  `kAlwaysOnStripLayers` that have data)
- Modify: `.../layers/strip_layer_sources.dart` and `strip_layer_data.dart`
  (`StripLayerInputs.species`; bands and ticks for it)
- Modify: `.../layers/strip_band_painter.dart` (species band edge like the
  finding's) and `strip_marker_painter.dart` if ticks need it
- Modify: `.../layers/pinned_strip_layer_host.dart` (watches
  `watchSpeciesHighlight`)
- Test: the existing tests beside each file (`strip_layer_test.dart`,
  `pinned_strip_layer_animator_test.dart`, `strip_layer_sources_test.dart`;
  create any that do not exist)

**Interfaces:**
- Consumes: `SpeciesProfileHighlight`.
- Produces: `StripLayerInputs({..., SpeciesProfileHighlight? species})`;
  species spans become `StripBand(layer: StripLayer.species, ...)` and moments
  `StripTick(layer: StripLayer.species, ...)` in the highlight colour.

- [ ] **Step 1: Write the failing tests:**
  - `'species is not tied to a card'`: `stripLayersFor(all cards)` lacks it
    and `kAlwaysOnStripLayers` has it.
  - `'the species layer is active with no card in view'`: animator with
    `cardsInView: {}`, settled, data with species bands: `active` contains
    `StripLayer.species`.
  - `'sources turn a highlight into bands and ticks'`.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run those files; expect PASS.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): show the selected species on the pinned profile strip`.

### Task 6: The depth chip on the Marine life card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/sighting_depth_label.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_sighting_row.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart`
- Modify: `lib/l10n/arb/app_*.arb` (every locale), then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/sighting_depth_label_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_sighting_row_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_card_test.dart`

**Interfaces:**
- Consumes: Tasks 2 and 3; `unitFormatterProvider`; `settingsProvider`
  `diveDetailSections.shows(DiveDetailSectionId.profile, gauge:)`.
- Produces:

```dart
/// `27 m`, or `16 to 18 m` when the whole-unit ends differ.
String sightingDepthLabel(
  SpeciesProfilePositions positions, UnitFormatter units, AppLocalizations l10n);

DiveSightingRow({..., String? depthLabel, bool depthSelected = false,
  VoidCallback? onToggleDepth, String? seenAtLabel});
```

New ARB keys: `diveLog_detail_sightingDepthRange` (`{from} to {to}`, both
already formatted with the unit on the second only),
`diveLog_detail_sightingSeenAt` (`at {minutes} min`),
`diveLog_detail_semantics_showOnProfile` (`Show {species} on the profile, {depth}`).

Row rules: chip (key `sighting_depth`) beside the photo chip, a `FilterChip`
styled selected while `depthSelected`; with no `onToggleDepth` (profile card
hidden or no chart) it is a plain label; with no positions and a
`seenAtSeconds` on a dive with an empty chart profile, `seenAtLabel` shows as
text after the name; neither otherwise. The row's own tap still calls
`onOpen`. The section clears `selectedProfileSpeciesProvider(dive.id)` when
the selected species is no longer among the dive's sightings (a
post-frame write, never during build).

- [ ] **Step 1: Write the failing tests:**
  - Label: `'one depth'` (27.2 to 27.4 m gives `27 m`), `'a range'`
    (16.2 to 18.4 m gives `16 to 18 m`), `'imperial'` (4.6 to 5.4 m gives
    `15 to 18 ft`), `'a range that rounds to one value is one value'`.
  - Row: `'tapping the depth chip toggles, the row still opens the species'`;
    `'no positions, no chip'`; `'a time on a profileless dive reads as text'`;
    `'with the profile card hidden the chip is a label'`; semantics label
    contains the species and depth.
  - Card: `'a sighting with a time shows its chip and selecting it sets
    selectedProfileSpeciesProvider'`; `'deleting the selected sighting
    clears the selection'`.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement; translate the three keys into every locale.
- [ ] **Step 4:** Run the three files plus
  `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_list_test.dart`
  if PR #5076 has landed.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): show each species' depth on the Marine life card`.

### Task 7: "Seen at" in the sighting edit sheet

**Files:**
- Create: `lib/features/dive_log/domain/services/sighting_time_bound.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_card_editor.dart`
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_log/domain/services/sighting_time_bound_test.dart`
- Test: `test/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet_test.dart`

**Interfaces:**
- Produces: `int sightingTimeMaxSeconds(Dive dive, List<DiveProfilePoint> profile)`
  (profile last second, else `measuredRuntime`, else `bottomTime`, else
  86,400); `EditSightingSheet({..., List<DiveProfilePoint>? profile, int? maxSeconds})`
  where a null `maxSeconds` hides the field (bulk edit);
  `SightingsEditor({..., List<DiveProfilePoint>? timeProfile, int? timeMaxSeconds})`
  passed through by `DiveSightingsCardEditor` only.
- Field: `MinutesSecondsField` (label `diveLog_editSighting_seenAt`, "Seen at";
  format error reuses `diveLog_annotation_time_invalid`, bound error
  `diveLog_annotation_time_outsideDive`) with a clear suffix button; an empty
  field is no time (check how `MinutesSecondsField` treats empty text and
  accept it here). With a non-empty profile: `MiniProfilePicker` below it and
  the depth at the chosen second (`units.formatDepth(profileDepthAt(...))`).

- [ ] **Step 1: Write the failing tests:**
  - Bound: each fallback in order, and that `effectiveRuntime` alone is not
    used.
  - Sheet: `'saves a typed time'` (`12:30` saves 750); `'picking on the
    profile fills the time'`; `'clear saves no time'`; `'past the bound shows
    the error and does not save'`; `'empty saves no time'`;
    `'no maxSeconds hides the field'`.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run both files and
  `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_card_test.dart`.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): set when a sighting was seen`.

### Task 8: Merge and consolidation carry the time

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`MarineSighting.seenAtSeconds`)
- Modify: `lib/features/dive_log/data/services/dive_sightings_hydration.dart`
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart`
  (both the read at :183 and the insert at :662)
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart` (:801)
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`
- Test: the consolidation service test that covers sightings (find with
  `grep -rl sightingRows test/features/dive_log`)

- [ ] **Step 1: Write the failing tests:**
  - `'a second dive's sighting time shifts by its offset'`: dives 30 min
    apart (entry times), dive 2 sighting at 120 gives 1,920 on the merged dive.
  - `'one species on both dives keeps the earlier shifted time'`, and
    `'keeps whichever exists'`.
  - Consolidation: `'a secondary time fills a target sighting without one'`,
    `'a target time is never replaced'`.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement (shift with `offsets[d.id]`).
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): keep sighting times through merge and consolidation`.

### Task 9: Agent access, UDDF and the conflict catalogue

**Files:**
- Modify: `lib/features/agent_access/data/writes/families/sighting_writes.dart`
  (`'seen_at_seconds': FieldCodec.integer(min: 0, max: 86400)`, nullable; a
  value past `sightingTimeMaxSeconds` of the dive is dropped, not an error)
- Modify: `lib/features/agent_access/data/documents/dive_document.dart`,
  `lib/features/agent_access/data/records/families/dive_records.dart`
- Modify: `lib/core/services/export/uddf/uddf_shared_dive_writer.dart`,
  `uddf_export_builders.dart` (attribute `seenat` in seconds, only when set),
  `uddf_full_import_service.dart`, and
  `lib/features/dive_import/data/services/uddf_entity_importer.dart`
  (reads it, drops a value outside 0 to 86,400 or past the imported dive's
  profile)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart`
  (`'seenAtSeconds'`, `FieldKind.durationSeconds`, label
  `diveLog_editSighting_seenAt`)
- Test: `test/features/agent_access/data/writes/sighting_writes_test.dart`,
  `test/core/services/export/uddf/uddf_shared_dive_writer_test.dart`,
  `test/core/services/export/uddf/uddf_export_profiles_test.dart` (round trip),
  and the conflict catalogue coverage guard under
  `test/features/settings/presentation/conflicts/`

- [ ] **Step 1: Write the failing tests:** MCP create and update set and
  clear the time, and a too-late value is dropped; UDDF writes `seenat="750"`
  only when set and a Submersion round trip keeps it; the catalogue lists the
  column.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement; regenerate column notes if the docs changed.
- [ ] **Step 4:** Run those files; expect PASS.
- [ ] **Step 5:** Format, analyze, commit
  `feat(dive-log): carry sighting times through agent access and UDDF`.

### Task 10: After screenshots and the whole-branch check

- [ ] Update `test/_pr_shots/species_profile_shots_test.dart` (untracked) to
  pass the new parameters for `STAGE=after`: depth chips on the rows (one
  selected), a species highlight on the chart (a band and a moment), the
  sheet with "Seen at" filled. Render light, dark, phone and desktop.
- [ ] Check the 360 px row with a long name and both chips, and a 40 species
  card, in the goldens.
- [ ] `flutter analyze` on the whole repo; `dart format .`; delete
  `test/_pr_shots/` before pushing.
