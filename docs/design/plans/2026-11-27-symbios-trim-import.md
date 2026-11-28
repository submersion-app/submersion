# Symbios Trim Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decode the Halcyon Symbios trim record, carry the angle into stored dive profiles, and show it as an optional profile-chart line and in the Trim Calculator.

**Architecture:** The fork's Symbios parser reports a new `DC_SAMPLE_TRIM`; the native glue and pigeon bridge carry it to Dart on every platform; the profile series codec gains v4 for series that use it; the chart follows the full optional-line pattern (right-axis metric, palette colour, synced default visibility); the Trim Calculator (PR #5031) reads the same profile samples for a readout and a strip on its time slider.

**Tech Stack:** C (libdivecomputer fork), Swift/Kotlin/C/C++ native glue, pigeon 22.7.4, Flutter/Dart, Drift, Riverpod.

**Spec:** `docs/design/specs/2026-11-27-symbios-trim-import-design.md`. The Avelo samples plan (`docs/design/plans/2026-11-19-avelo-sample-decode.md`, PR #4775) walked the same path; when a step here says "as Avelo did", that plan and commit `58366dbe4fd` show the exact places.

## Global Constraints

- Trim is the signed byte at `data[offset + 2]` of an `ID_TRIM` (0x10) record, in whole degrees, read through `signed char` (the current `(signed int) data[...]` on an unsigned buffer is never negative). Values outside -90 to +90 are not reported.
- Positive is head up, negative head down, 0 flat (checked against the #5064 CSV). Stored as logged; only display words depend on it.
- App name `trim` (double, degrees) everywhere; codec column `trim` (float64); C `DC_SAMPLE_TRIM` / `value->trim`; wrapper `libdc_sample_t.trim` (double, NAN absent).
- Dives without trim must not change: no new line offered, no calculator readout, codec version unchanged.
- Labels: chart line and setting "Trim"; info-sheet term and calculator readout call it the angle the dive computer logged, never "your trim".
- Settings: `defaultShowTrim` (default false), `profileColorTrim` (nullable). Columns `default_show_trim`, `profile_color_trim`. One migration rung at the next free schema version after merging main, in `lib/core/database/migrations/` (never in `database.dart` beyond `currentSchemaVersion` and `migrationVersions`); do not raise `minimumCompatibleSchemaVersion`.
- Patch file `packages/libdivecomputer_plugin/patches/0012-halcyon-symbios-trim.patch`. Fork PR into `submersion-patches`, merged by us with a merge commit once green (maintainer approved), then the gitlink moves.
- The reporter's CSV is never committed; native tests synthesize trim records.
- Strings go through every ARB file. Local test runs: only the test files written or changed, by path.

## Review Focus

1. A trim byte of 0xF3 (-13): must store -13, not 243. Tested in Task 1.
2. A dive where trim records stop partway (or start late): the chart line gaps, and the calculator readout says no reading at a time before the first sample instead of showing a stale or zero value. Tested in Task 7 and Task 8.
3. A synced device still on an older build receives a v4 series: stored and refused for decode as a forward version, never treated as corrupt. Tested in Task 3.
4. An Android build whose native library predates the new slot (short array): the decoder returns null trim, not an exception. Tested in Task 2.
5. A dive that is nearly flat the whole way (trim within +/-3 degrees): the right axis stays at least +/-10 degrees so noise is not drawn as a large swing. Tested in Task 7.

---

### Task 1: Fork decode (patch 0012) with native test

**Files:**
- Modify (fork, `packages/libdivecomputer_plugin/third_party/libdivecomputer`): `include/libdivecomputer/parser.h` (append `DC_SAMPLE_TRIM` after `DC_SAMPLE_RMV`; `double trim;` in `dc_sample_value_t`, both marked `/* Submersion patch (Symbios trim) */`), `src/halcyon_symbios_parser.c:637-638`.
- Create: `packages/libdivecomputer_plugin/patches/0012-halcyon-symbios-trim.patch`, `packages/libdivecomputer_plugin/test/native/test_halcyon_symbios_trim.c`; Modify: `test/native/CMakeLists.txt` (target and `add_test`, modelled on the `shearwater_avelo_samples` entries).

**Interfaces:**
- Produces: `DC_SAMPLE_TRIM` with `value->trim` (double, degrees).

- [ ] **Step 1:** Grep the fork for tables or switches indexed by `dc_sample_type_t` (as Avelo did) and extend each for `DC_SAMPLE_TRIM`.
- [ ] **Step 2: Write the failing test** `test_halcyon_symbios_trim.c`: build a minimal Symbios log in memory (the records `halcyon_symbios_parser.c` requires to parse: log version, header, depth samples, trim records, footer; read the parser's header and footer handling for the minimum) and parse it with `dc_parser_samples_foreach`. Assert trim bytes 0x05, 0xF3, 0x00, 0x57 report 5, -13, 0, 87; bytes 0x9C (-100) and 0x7F (127) report nothing; a log with no trim records reports no `DC_SAMPLE_TRIM`.
- [ ] **Step 3:** Run, expect FAIL: `cd packages/libdivecomputer_plugin && cmake -B build/test test/native && cmake --build build/test && ctest --test-dir build/test --output-on-failure -R symbios_trim`
- [ ] **Step 4:** Implement the enum value, union member and the `ID_TRIM` callback.
- [ ] **Step 5:** Run the full native ctest (no `-R`); expect PASS.
- [ ] **Step 6:** Fork side: in the submodule branch `symbios-trim` from the current gitlink (`fe60f0a`), commit, write that commit's `git diff` to the patch file (bare `diff --git`, like 0011), push, open a PR into `submersion-patches` titled "Report the Halcyon Symbios trim angle" whose body ends "Submersion side: submersion-app/submersion, issue 5098 (patch `0012-halcyon-symbios-trim.patch`)". Merge with a merge commit once green; move the gitlink to the merge commit.
- [ ] **Step 7: Commit** the patch, native test, CMake change and gitlink: `feat(dive-computer): decode the Halcyon Symbios trim angle`.

### Task 2: Native glue and pigeon bridge

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` (`libdc_sample_t.trim`), `macos/Classes/libdc_download.c` (NAN reset at `DC_SAMPLE_TIME`, `case DC_SAMPLE_TRIM`), `pigeons/dive_computer_api.dart` (`ProfileSample.trim` double?, before `gasMixIndex`) then regenerate, `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`, `android/src/main/cpp/libdc_jni.cpp`, `android/src/main/kotlin/com/submersion/libdivecomputer/SampleDecoder.kt`, `linux/dive_converter.c`, `windows/dive_converter.cc`
- Test: `android/src/test/kotlin/com/submersion/libdivecomputer/SampleDecoderTest.kt`, `test/native/test_halcyon_symbios_trim.c` (wrapper-level case through `libdc_parse_raw_dive`), `test/native/test_dive_converter.c` if it pins sample fields.

**Interfaces:**
- Consumes: Task 1.
- Produces: pigeon `ProfileSample.trim` (double?). Android slot `LIBDC_AVELO_OFFSET + 3` (index `31 + LIBDC_MAX_TANKS`), `LIBDC_SAMPLE_FIELD_COUNT` and `SAMPLE_FIELD_COUNT` raised to `32 + LIBDC_MAX_TANKS`.

- [ ] **Step 1: Write failing tests:** wrapper-level: a parsed synthetic Symbios dive yields `libdc_sample_t.trim` -13 on the trim sample and NAN elsewhere; `SampleDecoderTest`: the new slot decodes to `trim`, NaN to null, and a pre-change-length array decodes `trim` as null.
- [ ] **Step 2:** Run native ctest and `cd packages/libdivecomputer_plugin/android && ./gradlew testDebugUnitTest --tests '*SampleDecoderTest*'`; expect FAIL.
- [ ] **Step 3:** Implement; regenerate with `cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart && dart format lib/src/generated`; confirm headers still say v22.7.4.
- [ ] **Step 4:** Run the same; expect PASS. `flutter analyze packages/libdivecomputer_plugin`.
- [ ] **Step 5: Commit** `feat(dive-computer): carry the trim angle through the native bridge`.

### Task 3: Domain field and profile codec v4

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`DiveProfilePoint.trim`: field, constructor, `copyWith`, `props`), `lib/features/dive_log/domain/codecs/profile_sample.dart` (field, constructor, `withoutSafetyStopCeiling`, `shiftedBy`, `withTissue`, `props`), `profile_sample_point.dart`, `profile_field_table.dart` (`kProfileFieldTableV4`), `profile_series_codec.dart` (version 4, encode choice, frozen kinds from V4, `_fieldOf`, decode, `_samplesFrom`)
- Test: the codec, field-table, golden, sample, shift and forward-version test files Avelo's Task 3 touched (same paths), extended.

**Interfaces:**
- Produces: `DiveProfilePoint.trim`, `ProfileSample.trim` (double?); `kProfileFieldTableV4 = [...kProfileFieldTableV3, ProfileField('trim', float64)]`; `ProfileSeriesCodec.version == 4`, field tables `{1, 2, 3, 4}`.

- [ ] **Step 1: Write failing tests:** V4 frozen as V3 plus `trim`; a series with trim encodes v4 and round-trips -13.0 and 87.0; a series with Avelo fields and no trim still v3; gf99-only still v2; plain still v1; a v3 blob decodes with trim null; a v4 golden blob; `shiftedBy`/`withTissue`/`withoutSafetyStopCeiling`/`copyWith` keep trim; props lengths +1; forward-version tests move the hypothetical future version from 4 to 5 and a v4 blob is readable.
- [ ] **Step 2:** Run those files by path; expect FAIL.
- [ ] **Step 3:** Implement. Encode choice: v4 if any sample has trim, else today's choice. `legacy_sample_staging.dart` stays on V1.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5: Commit** `feat(dive-log): store the trim angle in profile codec v4`.

### Task 4: Download, re-parse and re-import

**Files:**
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`, `domain/entities/downloaded_dive.dart`, `data/services/dive_parser.dart`, `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`_sampleFromPointData`, `ProfilePointData`), `lib/features/dive_computer/data/services/reparse_service.dart`, `lib/features/universal_import/data/services/parsed_dive_profile_mapper.dart` (map key `trim`, key doc), `lib/features/dive_import/data/services/imported_profile_readers.dart`, `dive_import/data/services/dive_reimport_service.dart`
- Test: `parsed_dive_mapper_test.dart`, `parsed_dive_profile_mapper_test.dart`, `dive_reimport_service_test.dart`, the re-parse service test.

**Interfaces:**
- Consumes: Task 2 pigeon field, Task 3 domain field.

- [ ] **Step 0:** `git grep -n computerRmv lib` and add `trim` beside every copy the list above misses (merge, consolidation, reduction), so no path drops it.
- [ ] **Step 1: Write failing tests:** each path carries a pigeon sample with `trim: -13.0` to the stored point unchanged and leaves it null when absent; re-parse of a dive whose raw data now yields trim writes it.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement the copies.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5: Commit** `feat(dive-computer): import the trim angle on download and re-parse`.

### Task 5: UDDF backup carriage

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_avelo_samples.dart` (add a `<trim>` child in the same private `<computertissue>` entry, same `t:value` pairs; rename nothing), `uddf_full_import_service.dart` if the apply step needs the new key.
- Test: `test/core/services/export/uddf/uddf_avelo_samples_round_trip_test.dart` (extend).

**Interfaces:**
- Produces: `hasData` true for a dive with trim only; `apply` sets `trim` by timestamp.

- [ ] **Step 1: Write failing tests:** a dive with trim only (no Avelo values) round-trips trim per timestamp; a dive with both keeps both; a dive with neither writes no block.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5: Commit** `feat(uddf): keep the trim angle in a Submersion backup`.

### Task 6: Chart line settings (metric, palette, synced default, rung)

**Files:** as Avelo's Task 7, for one metric instead of three:
- `lib/core/constants/profile_metrics.dart` (`ProfileRightAxisMetric.trim`, not in `fallbackPriority`), `profile_colors/profile_metric.dart`, `profile_metric_label.dart`, `widgets/profile_metric_colors.dart` (default colour), `profile_metric_swatches.dart`, `lib/core/database/tables/diver_tables.dart` (`defaultShowTrim` bool default false, `profileColorTrim` nullable int)
- Create: `lib/core/database/migrations/helpers/trim_line_migrations.dart` (part file, `_addColumnIfMissing` for both); Modify: `app_database_migrations.dart`, `ladder/rungs_v340_onward.dart`, `before_open_settings_columns.dart`, `database.dart` (`currentSchemaVersion`, `migrationVersions`)
- `lib/core/services/sync/sync_data_serializer.dart` (seed `default_show_trim` false), `settings_providers.dart` (`AppSettings.defaultShowTrim`, `setDefaultShowTrim`), `diver_settings_repository.dart`, `profile_metric_color_columns.dart`, `default_visible_metrics_page.dart`, `profile_metric_colors_page.dart`, `section_appearance_page.dart`, conflict `diver_settings_fields.dart`, `conflict_enum_labels_settings.dart`
- Regenerate: build_runner (background, unfiltered), `dart run tool/generate_sql_column_notes.dart`, `flutter gen-l10n`
- Test: create `test/core/database/migration_v<N>_trim_line_test.dart` (modelled on `migration_v379_avelo_lines_test.dart`) and `test/core/services/sync/sync_diver_settings_trim_line_test.dart`; extend the guard and fake-notifier tests Avelo's Task 7 lists.

**Interfaces:**
- Produces: `ProfileRightAxisMetric.trim`, `ProfileMetric.trim`, `AppSettings.defaultShowTrim`, `SettingsNotifier.setDefaultShowTrim(bool)`, `ProfileMetricColors.trim`.

- [ ] **Step 1: Write failing tests:** the rung (version listed, floor unchanged, both columns added, CHECK on the bool, existing rows kept, idempotent backstop); sync seeds `default_show_trim` false when a peer omits it and carries the colour; settings round-trip; guard tests extended.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement; run codegen in the background and wait.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze` (whole repo).
- [ ] **Step 5: Commit** `feat(settings): add default visibility and colour for the trim line`.

### Task 7: Draw the trim line

**Files:**
- Modify: `profile_legend_provider.dart` (`showTrim`), `profile_legend_config.dart` (`hasTrim`, `hasSecondaryToggles`), `active_legend_entries.dart`, `chart_options_dialog.dart` (row beside the Avelo rows), `dive_profile_chart.dart` (flag, legend sync, line from `profile[i].trim` with gaps for nulls, analysis cache signature, right-axis picker, readout row), `profile_right_axis_metric_labels.dart`, `profile_right_axis_tick_format.dart` (whole degrees with a sign, "°"), `profile_metric_palette.dart`, `info/dive_profile_info.dart`, `lib/shared/widgets/info_sheet/dive_terms.dart`, `docs/user/dive-profiles.md`, ARB files
- Test: create `test/features/dive_log/presentation/widgets/dive_profile_chart_trim_line_test.dart` and `chart_options_trim_line_test.dart`; extend the legend provider and right-axis label tests.

**Interfaces:**
- Consumes: Tasks 3 and 6.
- Produces: `double trimAxisHalfRange(Iterable<double> values)` in `profile_right_axis_tick_format.dart` (or beside the existing right-axis range code): `max(10, largest |value| rounded up to the next 5)`.

- [ ] **Step 1: Write failing tests:** legend state seeds from `defaultShowTrim` and toggles; the options row shows only when some point has trim; one line drawn with a gap across null samples and none on a dive without trim even when on; the readout shows "Trim" and "-13°"; as the right axis the range is symmetric: values within +/-3 give +/-10, a max of 87 gives +/-90; ticks print a sign and "°".
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5:** After screenshots of the chart, chart options and settings pages (see Screenshots).
- [ ] **Step 6: Commit** `feat(dive-log): draw the trim line on the profile chart`.

### Task 8: Trim Calculator readout and strip (after PR #5031 merges)

**Files:**
- Precondition: PR #5031 merged and `origin/main` merged into this branch (analyze before tests). If it is still open, ask the maintainer whether to wait or stack.
- Create: `lib/features/trim_calculator/domain/logged_trim.dart`, `lib/features/trim_calculator/presentation/widgets/logged_trim_strip.dart`
- Modify: `lib/features/trim_calculator/presentation/pages/trim_calculator_page.dart` (place the readout and strip directly above the time slider), its providers if the dive's profile is not already in reach, ARB files
- Test: `test/features/trim_calculator/domain/logged_trim_test.dart`, `test/features/trim_calculator/presentation/widgets/logged_trim_strip_test.dart`, the calculator page test.

**Interfaces:**
- Produces: `double? loggedTrimAt(List<DiveProfilePoint> profile, int seconds)` (the last sample with trim at or before `seconds`, null when none, or when the nearest is more than 60 s earlier); `String loggedTrimWords(AppLocalizations l10n, double degrees)` ("5° head up", "13° head down", "flat").

- [ ] **Step 0:** Before screenshot of the calculator on a dive (once #5031 is in), phone and desktop, light and dark.
- [ ] **Step 1: Write failing tests:** `loggedTrimAt` returns -13 at the sample's time and at a later time without a trim sample within 60 s, null before the first trim sample and after a gap over 60 s; the words; the page shows "Your computer logged 13° head down at 42:10" (time in the calculator's own format) and the strip for a dive with trim, neither for a dive without; the strip's marker follows the slider; the figure, gauges and verdict are identical with and without trim samples.
- [ ] **Step 2:** Run by path; expect FAIL.
- [ ] **Step 3:** Implement; the strip uses the same symmetric range rule as Task 7.
- [ ] **Step 4:** Run; expect PASS. `flutter analyze`.
- [ ] **Step 5:** After screenshots.
- [ ] **Step 6: Commit** `feat(trim-calculator): show the trim angle the dive computer logged`.

## Screenshots

Headless throwaway widget goldens (Eric's sync is configured and his log has no Symbios dive), kept in the scratchpad, never committed. Before shots of the chart, chart options, default visible metrics and metric colours pages were taken before Task 1; after shots in Task 7 Step 5; calculator before and after in Task 8. They go to the project's current secret screenshot gist and into the PR description.
