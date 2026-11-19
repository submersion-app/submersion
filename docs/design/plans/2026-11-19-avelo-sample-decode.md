# Avelo Sample Decode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decode the Avelo record's buoyancy, gas remaining and computer RMV bytes, carry them into stored dive profiles, and show them as three optional profile-chart lines and an Avelo summary in the Cylinders card.

**Architecture:** The fork's Shearwater parser reports three new libdivecomputer sample types; the native glue and pigeon bridge carry them to Dart on every platform; the profile series codec gains v3 for series that use them; the chart follows the full optional-line pattern (right-axis metric, palette colour, synced default visibility); the summary is a pure function over the profile.

**Tech Stack:** C (libdivecomputer fork), Swift/Kotlin/C/C++ native glue, pigeon 22.7.4, Flutter/Dart, Drift, Riverpod.

**Spec:** `docs/design/specs/2026-11-19-avelo-sample-decode-design.md` (findings: `docs/design/findings/2026-11-19-avelo-sample-bytes.md`)

## Global Constraints

- Byte offsets are the parser's `offset + pnf + N` index (record byte N+1).
- Buoyancy: bytes 11-12 signed 16-bit big endian, raw / 1000 = kg; skip raw 0x7FF0..0x7FFF (0x7FFE seen).
- Gas remaining: byte 10, percent; skip raw > 100 (0xFE seen).
- Computer RMV: bytes 29-30 unsigned 16-bit big endian, raw / 100 = L/min; skip raw >= 0xFFF0.
- Each scale is a named constant with a comment that the unit is inferred from imperial-unit logs only.
- App names: `aveloBuoyancy` (double, kg), `aveloGasRemaining` (int, percent), `computerRmv` (double, L/min). Codec column names `avelo_buoyancy`, `avelo_gas_remaining`, `computer_rmv`.
- Non-Avelo dives must not change: no new lines offered, no summary, codec version unchanged (v1 or v2).
- Labels: "Avelo buoyancy" (never plain "Buoyancy"), "Gas remaining", "RMV (computer)".
- Units follow the active diver's settings: `UnitFormatter.formatWeight`, `formatRmv`, `formatPressure`.
- Never commit the diver's dives; tests synthesize Avelo records.
- New migration rung is v379 in `lib/core/database/migrations/` (never in `database.dart`); do not raise `minimumCompatibleSchemaVersion`.
- New chart defaults are `false`. Strings go through every ARB file.
- Local test runs: only the test files written or changed, by path (CLAUDE.md). No folder runs.

## Review Focus

1. A dive whose transmitter drops out mid-dive: special codes (0x7FFE, 0xFE, 0xFFF8 to 0xFFFE) must leave gaps, never zeros or 327 kg spikes. Tested in Task 1 and Task 6.
2. A non-Avelo Shearwater dive (record 0x01) whose bytes 10, 11-12 and 29-30 hold status, cell mV and other data must report none of the new samples. Tested in Task 1.
3. An Avelo dive with only surface samples (a pool check that never went below 0): the summary must be absent, not "0% to 0%". Tested in Task 6.
4. An older app on a synced device receiving a v3 series: it must be stored and refused for decode as a forward version, never treated as corrupt. Tested in Task 3 (forward-version tests move to 4, plus a v3 case).
5. An Android build whose native library predates the new array slots (short array): the decoder must return nulls for the new fields, not throw. Tested in Task 2.

---

### Task 1: Fork decode (patch 0011) with native test

**Files:**
- Modify (fork, `packages/libdivecomputer_plugin/third_party/libdivecomputer`): `include/libdivecomputer/parser.h` (append to `dc_sample_type_t` after `DC_SAMPLE_LOCATION`, add union members to `dc_sample_value_t`), `src/shearwater_predator_parser.c` (inside the DIVE/AVELO branch of `samples_foreach`, after the RBT callback ~:1140, gated on `type == LOG_RECORD_AVELO_SAMPLE`).
- Create: `packages/libdivecomputer_plugin/patches/0011-shearwater-avelo-samples.patch`
- Create: `packages/libdivecomputer_plugin/test/native/test_shearwater_avelo_samples.c`; Modify: `test/native/CMakeLists.txt` (target and `add_test`, modelled on `avelo_hydrotank` :429-448, :559-567)

**Interfaces:**
- Produces: `DC_SAMPLE_BUOYANCY` (`value->buoyancy`, double kg), `DC_SAMPLE_GASREMAINING` (`value->gasremaining`, unsigned int percent), `DC_SAMPLE_RMV` (`value->rmv`, double L/min). Each marked `/* Submersion patch (Avelo samples) */`.

- [ ] **Step 1:** Grep the fork for tables or switches indexed by `dc_sample_type_t` (`DC_SAMPLE_LOCATION`, sample-name arrays in `examples/` and `src/`) and extend each so the new values do not index past an array.
- [ ] **Step 2: Write the failing test** `test_shearwater_avelo_samples.c`, reusing `make_avelo` from `test_shearwater_avelo_hydrotank.c` (Petrel 3 fixture rewritten to 0x03 records) and a `dc_sample_callback_t` collector like `test_shearwater_o2_millivolt.c`. Overwrite bytes in chosen records and assert:
  - buoyancy raw 0xFE77 reports -0.393 kg; raw 0x04DA reports 1.242; raw 0x7FFE reports nothing for that sample.
  - gas remaining raw 100 reports 100; raw 35 reports 35; raw 0xFE reports nothing.
  - RMV raw 0x042C reports 10.68; raw 0x0B9F reports 29.75; raws 0xFFFA, 0xFFF9, 0xFFF8, 0xFFFE report nothing.
  - the unmodified Petrel 3 fixture (0x01 records) reports none of the three types.
- [ ] **Step 3:** Build and run; expect the new test to FAIL (types undefined): `cd packages/libdivecomputer_plugin && cmake -B build/test test/native && cmake --build build/test && ctest --test-dir build/test --output-on-failure -R avelo_samples`
- [ ] **Step 4:** Implement the enum, union members and parser callbacks, with `AVELO_BUOYANCY_KG_PER_UNIT 0.001` and `AVELO_RMV_LPM_PER_UNIT 0.01` as named constants carrying the "inferred from imperial-unit logs" comment.
- [ ] **Step 5:** Run the full native ctest (same command without `-R`); expect PASS.
- [ ] **Step 6:** Verify against the real dives, uncommitted: a scratch program in the scratchpad parses each `raw/*.pnf` (scratchpad `raw/` from the findings) through `libdc_parse_raw_dive("Shearwater","Perdix 2",...)` and prints min/max/mean buoyancy, min/max RMV and first/last gas remaining over samples with depth > 0. Expect the table in the findings document on all 8 dives.
- [ ] **Step 7:** Fork side: in the submodule, branch `avelo-samples` from the current gitlink (fbd2c42), commit, write `git diff` of that commit to `patches/0011-shearwater-avelo-samples.patch` (bare `diff --git`, like 0010). Push the branch to `submersion-app/libdivecomputer` and open a PR into `submersion-patches` titled "Decode the Shearwater Avelo sample fields", body ending "Submersion side: submersion-app/submersion, issue 4664 (patch `0011-shearwater-avelo-samples.patch`)". Merge with a merge commit (never squash) once green; then move the gitlink to the merge commit.
- [ ] **Step 8: Commit** (main repo) the patch file, native test, CMake change and gitlink: `feat(dive-computer): decode the Shearwater Avelo sample fields`.

### Task 2: Native glue and pigeon bridge

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:249-282` (`libdc_sample_t`), `macos/Classes/libdc_download.c` (reset at `DC_SAMPLE_TIME` :295-334, three new cases beside `DC_SAMPLE_RBT` :390)
- Modify: `pigeons/dive_computer_api.dart` `ProfileSample` (three fields before `gasMixIndex`, which stays last), then regenerate
- Modify: `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:842-874`, `android/src/main/cpp/libdc_jni.cpp:1140-1191`, `android/src/main/kotlin/com/submersion/libdivecomputer/SampleDecoder.kt`, `linux/dive_converter.c`, `windows/dive_converter.cc`
- Test: `android/src/test/kotlin/com/submersion/libdivecomputer/SampleDecoderTest.kt`, `test/native/test_parse_raw_dive.c` (or the new avelo test through `libdc_parse_raw_dive`)

**Interfaces:**
- Consumes: Task 1's three sample types.
- Produces: `libdc_sample_t.avelo_buoyancy` (double, NAN absent), `.gas_remaining` (uint32, UINT32_MAX absent), `.computer_rmv` (double, NAN absent); pigeon `ProfileSample.aveloBuoyancy` (double?), `.aveloGasRemaining` (int?), `.computerRmv` (double?).

- [ ] **Step 1: Write failing tests:** a wrapper-level native assertion that an Avelo record with the Task 1 bytes yields `libdc_sample_t` values -0.393 / 100 / 10.68 and the absent sentinels for skipped codes; `SampleDecoderTest` cases for the three new slots and for a short array (pre-change length) decoding them as null.
- [ ] **Step 2:** Run native ctest and `cd packages/libdivecomputer_plugin/android && ./gradlew testDebugUnitTest --tests '*SampleDecoderTest*'` (or the project's existing Kotlin test command); expect FAIL.
- [ ] **Step 3:** Implement. Android: append the three slots AFTER the tank-pressure block (indexes `28 + LIBDC_MAX_TANKS` to `+2`), raising `LIBDC_SAMPLE_FIELD_COUNT` and `SAMPLE_FIELD_COUNT` to `31 + MAX_TANKS`, so the tank offset (28) does not move. Regenerate: `cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart && dart format lib/src/generated`; confirm the generated headers still say v22.7.4.
- [ ] **Step 4:** Run the same tests; expect PASS. `flutter analyze packages/libdivecomputer_plugin`.
- [ ] **Step 5: Commit** `feat(dive-computer): carry the Avelo samples through the native bridge`.

### Task 3: Domain fields and profile codec v3

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`DiveProfilePoint` fields, constructor, `copyWith`, `props`)
- Modify: `lib/features/dive_log/domain/codecs/profile_sample.dart` (fields, constructor, `withoutSafetyStopCeiling`, `shiftedBy`, `withTissue`, `props`), `profile_sample_point.dart` (`toPoint`, `profileSampleFromPoint`), `profile_field_table.dart` (`kProfileFieldTableV3`), `profile_series_codec.dart` (version 3, three-way encode choice, `_frozenKinds` from V3, `_fieldOf`, decode reads, `_samplesFrom`)
- Test: `test/features/dive_log/domain/codecs/profile_series_field_table_test.dart`, `profile_series_codec_test.dart`, `profile_series_golden_test.dart`, `profile_sample_test.dart`, `deco_type_test.dart`, `sample_shift_test.dart`, `test/features/dive_log/domain/entities/dive_profile_point_tissue_fields_test.dart`, `test/core/services/sync/series_forward_version_test.dart`, `test/features/equipment/data/services/sensor_summary_worker_test.dart`, `test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart`

**Interfaces:**
- Produces: `DiveProfilePoint.aveloBuoyancy`/`aveloGasRemaining`/`computerRmv`; same on `ProfileSample`; `kProfileFieldTableV3 = [...kProfileFieldTableV2, avelo_buoyancy float64, avelo_gas_remaining deltaInt, computer_rmv float64]`; `ProfileSeriesCodec.version == 3`, `baseVersion == 1`, default `fieldTables {1: V1, 2: V2, 3: V3}`.

- [ ] **Step 1: Write failing tests:**
  - field table: V3 frozen as V2 plus the three entries in that order; `version == 3`; keys `{1,2,3}`; the props-length guard moves to V3.
  - codec: a series with any new field encodes as v3 and round-trips the values; a series with only gf99 still encodes v2; a plain series still v1; a v2 blob decodes with the new fields null.
  - v3 golden blob added beside the v2 golden.
  - `shiftedBy`, `withTissue`, `withoutSafetyStopCeiling` keep the three fields; `DiveProfilePoint.copyWith` keeps and replaces them; `props` lengths updated (`profile_sample_test` 30 to 33).
  - forward-version tests: the hypothetical future version moves from 3 to 4, and a v3 blob is now readable.
- [ ] **Step 2:** Run those files by path; expect FAIL.
- [ ] **Step 3:** Implement. Encode choice: v3 if any sample has a new field, else v2 if any has gf99 or n2Load, else v1. Leave `legacy_sample_staging.dart` on V1.
- [ ] **Step 4:** Run the same files; expect PASS. `flutter analyze`.
- [ ] **Step 5: Commit** `feat(dive-log): store the Avelo samples in profile codec v3`.

### Task 4: Import, re-parse and Shearwater Cloud mapping

**Files:**
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart:80-110`, `lib/features/dive_computer/domain/entities/downloaded_dive.dart:317-361`, `lib/features/dive_computer/data/services/dive_parser.dart:22-60`, `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`_sampleFromPointData` :2885, `ProfilePointData` :3125-3167), `lib/features/dive_computer/data/services/reparse_service.dart:930-958`, `lib/features/universal_import/data/services/parsed_dive_profile_mapper.dart:38-117` (map keys `aveloBuoyancy`, `aveloGasRemaining`, `computerRmv`; update its key doc), `lib/features/dive_import/data/services/imported_profile_readers.dart:28-61`, `lib/features/dive_import/data/services/dive_reimport_service.dart:728-740`
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`, `test/features/universal_import/data/services/parsed_dive_profile_mapper_test.dart`, `test/features/universal_import/data/services/shearwater_dive_mapper_profile_test.dart`, `test/features/dive_import/data/services/dive_reimport_service_test.dart`, plus the existing re-parse service test file

**Interfaces:**
- Consumes: pigeon fields (Task 2), domain fields (Task 3).

- [ ] **Step 1: Write failing tests:** each mapper carries a pigeon sample with `aveloBuoyancy -0.393`, `aveloGasRemaining 100`, `computerRmv 10.68` through to the `DiveProfilePoint` / codec sample unchanged, and leaves them null when absent; the Shearwater Cloud mapper test proves the values survive `ShearwaterGf99Aligner.apply`.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement the copies.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5: Commit** `feat(dive-computer): import the Avelo samples on download, re-parse and Shearwater Cloud import`.

### Task 5: UDDF backup carriage

**Files:**
- Create: `lib/core/services/export/uddf/uddf_avelo_samples.dart` (modelled on `uddf_computer_tissue.dart`: space-separated `t:value` pairs; `hasData`, write, parse, apply-by-timestamp). As built, the pairs ride as `<avelobuoyancy>`, `<avelogasremaining>` and `<computerrmv>` children of the dive's entry in the existing private `<computertissue>` block, not a block of their own, so they reuse its place in both writers and the streamed export.
- Modify: `uddf_dive_stream_writer.dart:183`, `uddf_export_builders.dart` (fallback writer ~:1505 and `hasData` use ~:802), `uddf_full_import_service.dart:619-630`
- Test: `test/core/services/export/uddf/uddf_avelo_samples_round_trip_test.dart`

**Interfaces:**
- Produces: `UddfAveloSamples.hasData(Dive)`, a writer called beside the computer-tissue writer, and an `apply` that sets `aveloBuoyancy`/`aveloGasRemaining`/`computerRmv` on the imported point maps by timestamp.

- [ ] **Step 1: Write the failing round-trip test:** export a single-source dive whose points carry the three values (one sample with only some of them), re-import, and assert equality per timestamp; a dive without them writes no block.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5: Commit** `feat(uddf): keep the Avelo samples in a Submersion backup`.

### Task 6: Avelo summary in the Cylinders card

**Files:**
- Create: `lib/features/dive_log/domain/services/avelo_summary.dart`, `lib/features/dive_log/presentation/widgets/avelo_summary_block.dart`
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (`_tankRow`, after the Hydrotank note :487), `lib/l10n/arb/app_*.arb` (all locales), then `flutter gen-l10n`
- Test: `test/features/dive_log/domain/services/avelo_summary_test.dart`, `test/features/dive_log/presentation/widgets/avelo_summary_block_test.dart`, the existing cylinders card test file

**Interfaces:**
- Produces: `class AveloSummary { double? minBuoyancyKg, maxBuoyancyKg, meanBuoyancyKg; double? minRmv, maxRmv; int? gasRemainingStart, gasRemainingEnd; double? maxPressureBar; }` and `AveloSummary? aveloSummaryOf(List<DiveProfilePoint> profile, List<TankPressurePoint>? hydrotankPressures)`.

- [ ] **Step 0: Before screenshots** (see Screenshots): the Cylinders card and profile chart for an Avelo dive with a Hydrotank, captured with today's code.
- [ ] **Step 1: Write failing tests** for `aveloSummaryOf`:
  - only samples with depth > 0 count: a surface sample with buoyancy -0.096 and gas remaining 100 before the first underwater sample is excluded.
  - buoyancy min/max/mean and RMV min/max over underwater samples; gas remaining start and end are the first and last underwater values; max pressure is the highest Hydrotank pressure at an underwater sample's timestamp (a higher surface pressure is excluded).
  - returns null when no underwater sample carries any of the three values (surface-only dive, and a non-Avelo dive).
  - a missing value leaves only its own field null.
- [ ] **Step 2: Write failing widget tests:** the block shows under the Hydrotank tank with "Avelo", gas remaining "100% to 35%", buoyancy range and average in the diver's weight unit with a sign on positive values, "RMV (computer)" range via `formatRmv`, max pressure via `formatPressure`; lines with no value are omitted; no block on a non-Avelo dive; when no tank has the Hydrotank role but the profile has Avelo data, the block shows under the first tank.
- [ ] **Step 3:** Run both by path; expect FAIL.
- [ ] **Step 4:** Implement. The card passes `dive.profile` and the Hydrotank's resolved series (`seriesByTank[tank.id]`).
- [ ] **Step 5:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 6: Commit** `feat(dive-log): show an Avelo summary under the Hydrotank`.

### Task 7: Chart line settings (metrics, palette, synced defaults, rung v379)

**Files:**
- Modify: `lib/core/constants/profile_metrics.dart` (three `ProfileRightAxisMetric` values after `buoyancy`, not in `fallbackPriority`), `lib/features/dive_log/presentation/profile_colors/profile_metric.dart` and `profile_metric_label.dart`, `widgets/profile_metric_colors.dart` (default colours), `lib/core/database/tables/diver_tables.dart` (three `defaultShow...` bools default false, three nullable `profileColor...` ints)
- Create: `lib/core/database/migrations/helpers/avelo_line_migrations.dart` (part file; `_addColumnIfMissing` for the six columns); Modify: `migrations/app_database_migrations.dart` (part), `ladder/rungs_v340_onward.dart` (v379 rung), `before_open_settings_columns.dart` (backstop), `database.dart` (`currentSchemaVersion = 379`, append 379 to `migrationVersions` only)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_applyDiverSettingDefaults` seeds for the three bools)
- Modify: settings `settings_providers.dart` (`AppSettings` fields, constructor, copyWith, setters `setDefaultShowAveloBuoyancy`, `setDefaultShowAveloGasRemaining`, `setDefaultShowComputerRmv`), `diver_settings_repository.dart`, `profile_metric_color_columns.dart`
- Modify UI: `pages/default_visible_metrics_page.dart`, `pages/profile_metric_colors_page.dart` (groups), `pages/section_appearance_page.dart` (`_visibleMetricToggles`, right-axis switch), conflict catalogue `diver_settings_fields.dart`, `conflict_enum_labels_settings.dart`
- Regenerate: `dart run build_runner build --delete-conflicting-outputs` (background), `dart run tool/generate_sql_column_notes.dart`, `flutter gen-l10n`
- Test: `test/core/database/migration_v379_avelo_lines_test.dart` (create, modelled on `migration_v370_buoyancy_default_test.dart`), `test/core/services/sync/sync_diver_settings_avelo_lines_test.dart` (create, modelled on `sync_diver_settings_gtr_fallback_test.dart`), and updates to `every_setter_waits_for_load_test.dart`, `section_appearance_page_test.dart` (the hard-coded count), `profile_metric_color_columns_test.dart`, `conflict_field_catalogue_coverage_test.dart`, `conflict_labels_complete_test.dart`, `profile_color_fields_test.dart`, `profile_right_axis_tick_format_test.dart`, `fresh_schema_declared_columns_test.dart`, `migration_column_names_test.dart`, and the fake notifiers (`test/helpers/mock_providers.dart`, `records_page_test.dart`, `settings_page_test.dart`, `settings_page_shared_data_test.dart`)

**Interfaces:**
- Produces: `ProfileRightAxisMetric.aveloBuoyancy|aveloGasRemaining|computerRmv`; `ProfileMetric` values of the same names; `AppSettings.defaultShowAveloBuoyancy|defaultShowAveloGasRemaining|defaultShowComputerRmv`; columns `default_show_avelo_buoyancy`, `default_show_avelo_gas_remaining`, `default_show_computer_rmv`, `profile_color_avelo_buoyancy`, `profile_color_avelo_gas_remaining`, `profile_color_computer_rmv`.

- [ ] **Step 1: Write failing tests:** migration v379 (version listed, floor unchanged, columns added, CHECK on the bools, existing values kept, idempotent backstop); sync seeds the three bools to false when a peer omits them and carries the colours; settings round-trip each default and colour; the guard tests above extended.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement, then run codegen in the background and wait for it.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze` (whole repo).
- [ ] **Step 5: Commit** `feat(settings): add default visibility and colours for the Avelo chart lines`.

### Task 8: Draw the three chart lines

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (`showAveloBuoyancy`, `showAveloGasRemaining`, `showComputerRmv`: state, count, copyWith, ==, hash, settings seeding, toggles), `widgets/profile_legend_config.dart` (`hasAveloBuoyancy`, `hasAveloGasRemaining`, `hasComputerRmv`, `hasSecondaryToggles`), `widgets/active_legend_entries.dart`, `widgets/chart_options_dialog.dart`, `widgets/dive_profile_chart.dart` (flags, legend sync, line drawing from `profile[i]` values with gaps for nulls, analysis cache signature, right-axis picker, tooltip rows in `_buildTooltipRowsForIndex`), `widgets/profile_right_axis_metric_labels.dart` (every exhaustive switch), `widgets/profile_right_axis_tick_format.dart`, `profile_colors/profile_metric_palette.dart`, `profile_metric_bands.dart`, `info/dive_profile_info.dart`, `lib/shared/widgets/info_sheet/dive_terms.dart`, `docs/user/dive-profiles.md`, ARB files
- Test: the legend provider test, `dive_profile_chart` line and tooltip tests for these metrics (extend the existing GTR-line test file or create `dive_profile_chart_avelo_lines_test.dart`), `profile_right_axis_metric_labels` test

**Interfaces:**
- Consumes: Task 3 point fields, Task 7 settings and metrics.

- [ ] **Step 1: Write failing tests:** legend state seeds from the three defaults and toggles each; config offers each line only when some point carries its value (a non-Avelo dive offers none); the chart draws a line per enabled metric with a gap where values are null; the cursor readout shows "Avelo buoyancy" in the diver's weight unit, "Gas remaining" as a percent, "RMV (computer)" via `formatRmv`; each metric works as the right axis with its range and tick format.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement. The curves come from the profile points (no new host parameters).
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5: After screenshots** of the same screens (see Screenshots).
- [ ] **Step 6: Commit** `feat(dive-log): draw the Avelo buoyancy, gas remaining and computer RMV lines`.

### Task 9: Hydrotank water-and-gas figure (follow-up, spec section 6)

**Files:**
- Create: `lib/features/dive_log/domain/services/hydrotank_contents.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tank_fill_levels.dart` (optional `water` level), `tank_figure.dart` (paint the water band, optional water label), `cylinders_card.dart` (Hydrotank figure inputs, end state and cursor), ARB files
- Test: `test/features/dive_log/domain/services/hydrotank_contents_test.dart`, `tank_fill_levels` test, `cylinders_card_avelo_summary_test.dart`

**Interfaces:**
- Produces: `({double water, double gasLeft})? hydrotankContents({required double startBar, required double nowBar, required int gasRemainingPercent})` (fractions of the tank, `gasLeft` measured from the bottom, i.e. the top of the solid zone); `TankFillLevels.hydrotank({required double water, required double gasLeft, double? now})`.

- [ ] **Step 1: Failing tests:** contents for dive 1636's end (3488 to 1302 psi, 36%) give water about 0.036; dive 1640's pump-in (3428 to 2532 psi, 41%) about 0.445; water clamps to 0 when the formula goes negative and to 1 at most; null for a non-positive pressure. The card draws the water figure (keyed `tank-water-label-<id>`) for a Hydrotank with gas remaining, and today's figure without it.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement; the card picks the gas remaining at the cursor from the last profile sample at or before the cursor time.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5:** After screenshots of the Cylinders card (end state, and at a pump-in with the cursor).
- [ ] **Step 6: Commit** `feat(dive-log): draw the Hydrotank as water and gas`.

## Screenshots

Eric's sync is configured, so screenshots come from headless widget captures (the 2026-11-19 choice for #3022), never from launching the dev app. A scratch capture test (not committed) renders the Cylinders card and the profile chart for a synthesized Avelo dive (values from the findings table) at phone and desktop widths, light and dark. Before shots in Task 6 Step 0, after shots in Task 8 Step 5. They go to the project's current secret screenshot gist and into the PR description.
