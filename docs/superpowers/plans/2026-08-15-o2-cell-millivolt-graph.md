# CCR O2 Cell Millivolt Graph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry per-cell CCR O2 sensor millivolts from libdivecomputer through to the dive profile chart, drawn as a selectable right-axis metric with one line per cell, plus a traffic-light agreement rug (see "Amendments" below — not part of the original goal).

**Architecture:** Six nullable INTEGER columns `o2_sensor_mv1..6` on `dive_profiles`, exactly parallel to the existing `o2_sensor1..6` (which hold ppO2 in bar). The value originates in `dc_sample_value_t.ppo2.millivolt` (merged in submersion-app/libdivecomputer PR #2), is captured by the C wrapper, marshalled across five hand-written platform paths, persisted via a Drift migration (planned as v151, shipped as v153 — see "Amendments"), and rendered by a new `ProfileRightAxisMetric.o2CellMv` that emits a `List<LineChartBarData>` rather than a single line.

**Tech Stack:** C (libdivecomputer wrapper), Pigeon (Dart/Swift/Kotlin/C++/GObject-C codegen), Kotlin + JNI (Android), Swift (Darwin), Drift ORM + SQLite, Flutter, Riverpod, fl_chart.

**Spec:** `docs/superpowers/specs/2026-08-15-o2-cell-millivolt-graph-design.md`

**Issue:** [#810](https://github.com/submersion-app/submersion/issues/810)

## Global Constraints

- **Branch:** `feat/810-o2-cell-mv-graph` (already created; the spec is committed on it).
- **Do not modify anything under `packages/libdivecomputer_plugin/third_party/libdivecomputer/`.** That submodule is finalized at `08bf592` and provides `ppo2.millivolt` already. If a task seems to need a change there, stop and report.
- **Absent-value sentinel in C:** `UINT32_MAX`, never `0`. Zero is libdivecomputer's "device does not report millivolts".
- **Android JNI array:** append only. Millivolts occupy indices 22–27; the array grows 22 → 28. Never insert mid-array.
- **Schema version 151, as planned at the time.** `origin/main` is at 150; PR #603 claims 138 and PR #954 claims 149, so 151 is free as of 2026-08-15. Re-verify in Task 5 Step 1 before writing the migration. (Shipped as v153 after a later rebase — see "Amendments".)
- **Formatting:** `dart format .` must produce no changes before any commit. `flutter analyze` must be clean.
- **No emojis** in code, comments, or docs. Keep comments sparse — rationale belongs in commit messages, not in code blocks.
- **Six cells everywhere.** Even though only three are ever populated today, every array, column set, and accessor list is six wide to stay 1:1 with `o2_sensor1..6`.
- **Commit after every task.** Never `git add -A` — stage explicit paths only.

---

## Amendments (post-implementation)

What shipped diverges from the tasks below in a few places. Task-by-task notes
mark each one; this is the summary.

- **Schema version 153, not 151.** By the time this branch rebased onto a moved
  `main`, two other features had already claimed v151 (`diver_settings.seascape_appearance`)
  and v152 (`site_features`). Same migration, same checklist, renumbered. See the
  note on Task 5.
- **Agreement rug.** Not in this plan at all — added after Task 11/12 shipped,
  once per-cell lines alone proved to ask more of the reader than a status strip
  would. Colored traffic-light green/yellow/red for tight/drifting/wide spread
  between cells, rendered together with the per-cell lines behind the same
  `showO2CellMv` toggle. An `O2CellDisplayMode { agreement, cells }` mode switch
  was built and then reverted in favor of always showing both — see the spec's
  "Agreement rug" section for why. Labeled "O2 Cell Spread"
  (`diveLog_o2CellSpread_label`), not "O2 Cells" (the legend toggle's own label,
  which is unchanged) or "O2 Cell Drift" (tried, dropped as a tautology against
  the "drifting" agreement word — see the spec).
- **Demo fixture, not a seed script.** `test/dives/102_o2_cell_traffic_light_demo.db.export`:
  a real, importable Shearwater Cloud DB whose profile blob is the existing
  `petrel3_ccr_o2_cells.bin` native fixture with only the millivolt bytes patched,
  reusing the app's normal Import Wizard end to end. An earlier `tool/` script that
  wrote directly to a fresh app-schema database was replaced by this once it
  became clear the Shearwater Cloud import path already carries millivolts
  end-to-end (`ParsedDiveProfileMapper.samples()` already maps `o2SensorMv1..6`
  from the FFI-parsed sample) — no import-code change was needed, just a fixture
  that exercises it.
- **Tooltip helpers extracted.** `_cellReadout`/`_valueAt` as sketched in Task 12
  shipped as `formatO2CellReadout`/`o2CellCount`/`valueAtSample` in a new
  `lib/features/dive_log/presentation/widgets/o2_cell_readout.dart`, alongside
  `kO2CellColors`/`o2CellColor` (see the note on Task 11). Extracted because the
  rug and both tooltip call sites all need the same cell-count/readout/color
  logic, not because the original design was wrong.

---

## File Structure

**Native capture (Task 1)**
- `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` — `libdc_sample_t.o2_sensor_mv[6]`
- `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` — per-sample reset + `DC_SAMPLE_PPO2` capture
- `packages/libdivecomputer_plugin/test/native/test_parse_raw_dive.c` — assertions

**Interface + non-Android platforms (Task 2)**
- `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` — `ProfileSample.o2SensorMv1..6`
- Generated: `lib/src/generated/dive_computer_api.g.dart`, `ios/Classes/DiveComputerApi.g.swift`, `android/.../DiveComputerApi.g.kt`, `windows/dive_computer_api.g.{h,cc}`, `linux/dive_computer_api.g.{h,cc}`
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`
- `packages/libdivecomputer_plugin/windows/dive_converter.cc`
- `packages/libdivecomputer_plugin/linux/dive_converter.c`

**Android (Task 3)** — highest risk, isolated into its own task
- `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`
- `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt`

**Domain entity (Task 4)**
- `lib/features/dive_log/domain/entities/dive.dart` — `DiveProfilePoint`

**Schema (Task 5)**
- `lib/core/database/database.dart` — columns, version, migration, backstop
- `test/core/database/migration_v151_o2_cell_mv_test.dart` (create)
- the exact-latest schema tripwire test (located in Step 1)

**Persistence wiring (Task 6)**
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — four sites
- `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`
- `lib/features/universal_import/data/services/parsed_dive_profile_mapper.dart`

**Sync (Task 7)**
- `lib/core/services/sync/sync_data_serializer.dart` — verify, change only if column-enumerating

**Curve derivation (Task 8)**
- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- `lib/features/dive_log/data/services/profile_analysis_service.dart` — `ProfileAnalysis.o2CellMvCurves`

**Metric definition (Task 9)**
- `lib/core/constants/profile_metrics.dart`
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — three exhaustive switches

**Toggle (Task 10)**
- `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`
- the legend UI widget that lists gas-analysis toggles (located in Step 1)

**Rendering (Task 11) and tooltip (Task 12)**
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- the four `o2SensorCurves` call sites: `dive_detail_page.dart:1722`, `dive_profile_panel.dart:379`, `fullscreen_profile_page.dart:423`

---

## Task 1: Native capture of millivolts

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:152`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:232-234, 271-283`
- Test: `packages/libdivecomputer_plugin/test/native/test_parse_raw_dive.c`

**Interfaces:**
- Consumes: `dc_sample_value_t.ppo2.millivolt` (unsigned int) from the frozen submodule.
- Produces: `libdc_sample_t.o2_sensor_mv[6]` — `unsigned int`, `UINT32_MAX` when that cell reported no millivolt.

- [ ] **Step 1: Read the existing fixture-based test to match its idiom**

Read `packages/libdivecomputer_plugin/test/native/test_parse_raw_dive.c` in full and note how it loads a fixture, builds a parser, and walks samples. Confirm the Petrel 3 fixture exists:

```bash
ls -l packages/libdivecomputer_plugin/test/native/fixtures/petrel3_ccr_o2_cells.bin
```

Expected: a 22400-byte file. That is the #810 dive; the merged libdivecomputer test pins it at 419 samples with cell millivolts in the 38–81 mV range.

- [ ] **Step 2: Write the failing test**

Add to `test_parse_raw_dive.c`. If that file has no Petrel 3 fixture case yet, model the parser setup on the existing cases in the file and on `test_shearwater_o2_millivolt.c` (which uses `find_descriptor("Shearwater", "Petrel 3", 10)`).

```c
/* Issue #810: the wrapper must carry the raw cell output through to
   libdc_sample_t, not just the (absent) ppO2 conversion. */
static void test_o2_cell_millivolts_reach_the_sample(void) {
    libdc_parsed_dive_t *dive = parse_petrel3_o2_fixture();
    assert(dive != NULL);
    assert(dive->sample_count == 419);

    unsigned int with_mv = 0;
    unsigned int mv_min = 0xFFFFFFFF, mv_max = 0;
    for (unsigned int i = 0; i < dive->sample_count; ++i) {
        const libdc_sample_t *s = &dive->samples[i];
        /* Only the first three cells are calibrated on this unit. */
        for (int c = 3; c < 6; ++c) {
            assert(s->o2_sensor_mv[c] == UINT32_MAX);
        }
        for (int c = 0; c < 3; ++c) {
            if (s->o2_sensor_mv[c] == UINT32_MAX) continue;
            with_mv++;
            if (s->o2_sensor_mv[c] < mv_min) mv_min = s->o2_sensor_mv[c];
            if (s->o2_sensor_mv[c] > mv_max) mv_max = s->o2_sensor_mv[c];
        }
    }

    assert(with_mv == 419 * 3);
    assert(mv_min >= 10 && mv_max <= 120);
    /* The aggregate carries no millivolt, so a per-sample reset must happen. */
    printf("PASS: test_o2_cell_millivolts_reach_the_sample (%u..%u mV)\n",
           mv_min, mv_max);
}
```

Call it from `main()` alongside the existing cases.

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd packages/libdivecomputer_plugin/test/native
cmake -B build -S . && cmake --build build --config Debug
ctest --test-dir build -R test_parse_raw_dive --output-on-failure
```

Expected: FAIL — compile error, `o2_sensor_mv` is not a member of `libdc_sample_t`.

- [ ] **Step 4: Add the struct field**

In `libdc_wrapper.h`, directly after the existing `o2_sensor` line:

```c
    double o2_sensor[6];       // per-cell ppO2 in bar (NAN if that cell absent)
    unsigned int o2_sensor_mv[6]; // per-cell raw output in mV (UINT32_MAX if absent)
```

- [ ] **Step 5: Reset the array per sample**

In `libdc_download.c`, in the new-sample block that already resets `o2_sensor`:

```c
        for (int cell = 0; cell < 6; cell++) {
            state->current_sample.o2_sensor[cell] = NAN;
            state->current_sample.o2_sensor_mv[cell] = UINT32_MAX;
        }
```

- [ ] **Step 6: Capture the millivolt**

In the `DC_SAMPLE_PPO2` branch, extend the per-cell arm:

```c
        } else if (value->ppo2.sensor < 6) {
            state->current_sample.o2_sensor[value->ppo2.sensor] =
                value->ppo2.value;
            // Zero means the device does not report millivolts; keep the
            // sentinel so it does not render as a flat 0 mV line.
            if (value->ppo2.millivolt) {
                state->current_sample.o2_sensor_mv[value->ppo2.sensor] =
                    value->ppo2.millivolt;
            }
        }
```

Leave the `DC_SENSOR_NONE` arm untouched — the aggregate carries no millivolt.

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd packages/libdivecomputer_plugin/test/native
cmake --build build --config Debug
ctest --test-dir build --output-on-failure
```

Expected: all tests PASS, including the pre-existing eight. If `test_parse_raw_dive` fails on `sample_count == 419`, the fixture is being parsed with a different descriptor — fix the descriptor lookup, not the assertion.

- [ ] **Step 8: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h \
        packages/libdivecomputer_plugin/macos/Classes/libdc_download.c \
        packages/libdivecomputer_plugin/test/native/test_parse_raw_dive.c
git commit -m "feat(libdc): capture per-cell O2 sensor millivolts (#810)"
```

---

## Task 2: Pigeon interface and the three compile-checked platforms

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:70-105`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:648-653`
- Modify: `packages/libdivecomputer_plugin/windows/dive_converter.cc:159-165`
- Modify: `packages/libdivecomputer_plugin/linux/dive_converter.c:138-140`
- Regenerate: all five `*.g.*` outputs

**Interfaces:**
- Consumes: `libdc_sample_t.o2_sensor_mv[6]` from Task 1.
- Produces: `ProfileSample.o2SensorMv1..6` — `int?` in Dart, null when that cell has no reading.

- [ ] **Step 1: Extend the Pigeon schema**

In `pigeons/dive_computer_api.dart`, add the six constructor params immediately after `this.o2Sensor6,`:

```dart
    this.o2SensorMv1,
    this.o2SensorMv2,
    this.o2SensorMv3,
    this.o2SensorMv4,
    this.o2SensorMv5,
    this.o2SensorMv6,
```

and the six fields immediately after `final double? o2Sensor6;`:

```dart
  /// Raw O2 cell output in millivolts (sensor 1..6), null when that cell
  /// reports none. Present even when the cell's ppO2 is unavailable because
  /// the logged calibration could not be trusted (issue #810).
  final int? o2SensorMv1;
  final int? o2SensorMv2;
  final int? o2SensorMv3;
  final int? o2SensorMv4;
  final int? o2SensorMv5;
  final int? o2SensorMv6;
```

Keep `gasMixIndex` last in both lists — several platforms pass constructor args positionally.

- [ ] **Step 2: Regenerate**

```bash
cd packages/libdivecomputer_plugin
dart run pigeon --input pigeons/dive_computer_api.dart
```

If that invocation does not match this repo, find the real one:

```bash
grep -rn "pigeon" packages/libdivecomputer_plugin/pubspec.yaml packages/libdivecomputer_plugin/README.md
```

Expected: all five generated files change. Confirm with `git status --short`.

- [ ] **Step 3: Build Darwin to see it fail**

```bash
flutter build macos --debug 2>&1 | tail -30
```

Expected: FAIL — `ProfileSample` initializer is missing arguments.

- [ ] **Step 4: Wire Darwin**

In `DiveComputerHostApiImpl.swift`, after the `o2Sensor6:` line:

```swift
                    // C `unsigned int o2_sensor_mv[6]` imports as a 6-tuple.
                    o2SensorMv1: s.o2_sensor_mv.0 == UInt32.max ? nil : Int64(s.o2_sensor_mv.0),
                    o2SensorMv2: s.o2_sensor_mv.1 == UInt32.max ? nil : Int64(s.o2_sensor_mv.1),
                    o2SensorMv3: s.o2_sensor_mv.2 == UInt32.max ? nil : Int64(s.o2_sensor_mv.2),
                    o2SensorMv4: s.o2_sensor_mv.3 == UInt32.max ? nil : Int64(s.o2_sensor_mv.3),
                    o2SensorMv5: s.o2_sensor_mv.4 == UInt32.max ? nil : Int64(s.o2_sensor_mv.4),
                    o2SensorMv6: s.o2_sensor_mv.5 == UInt32.max ? nil : Int64(s.o2_sensor_mv.5),
```

- [ ] **Step 5: Wire Windows**

In `dive_converter.cc`, mirror the existing `o2_sensor` handling. Where the file builds `std::optional` locals for each cell, add the millivolt locals using the `UINT32_MAX` sentinel (match the file's existing sentinel idiom for `heart_rate`/`tank_index`, which use `UINT32_MAX` the same way), then extend the constructor call after the six `o2_sensor[...]` args and before `gas_mix_index`:

```cpp
                    o2_sensor_mv[0] ? &*o2_sensor_mv[0] : nullptr,
                    o2_sensor_mv[1] ? &*o2_sensor_mv[1] : nullptr,
                    o2_sensor_mv[2] ? &*o2_sensor_mv[2] : nullptr,
                    o2_sensor_mv[3] ? &*o2_sensor_mv[3] : nullptr,
                    o2_sensor_mv[4] ? &*o2_sensor_mv[4] : nullptr,
                    o2_sensor_mv[5] ? &*o2_sensor_mv[5] : nullptr,
                    gas_mix_index ? &*gas_mix_index : nullptr)));
```

- [ ] **Step 6: Wire Linux**

In `dive_converter.c`, extend the `..._profile_sample_new()` call. Build the six values with the same sentinel-to-null idiom the file already uses for `heart_rate`, then:

```c
                    deco_time, deco_depth, tts, o2_sensor[0], o2_sensor[1],
                    o2_sensor[2], o2_sensor[3], o2_sensor[4], o2_sensor[5],
                    o2_sensor_mv[0], o2_sensor_mv[1], o2_sensor_mv[2],
                    o2_sensor_mv[3], o2_sensor_mv[4], o2_sensor_mv[5],
                    gas_mix_index);
```

- [ ] **Step 7: Verify all three build**

```bash
flutter build macos --debug 2>&1 | tail -20
flutter build windows --debug 2>&1 | tail -20
```

Expected: both succeed. Linux cannot be built on this machine; confirm by inspection that the argument count and order match the regenerated `linux/dive_computer_api.g.h` signature exactly, and state in the commit that Linux is compile-checked by review only.

- [ ] **Step 8: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons packages/libdivecomputer_plugin/lib \
        packages/libdivecomputer_plugin/ios packages/libdivecomputer_plugin/darwin \
        packages/libdivecomputer_plugin/windows packages/libdivecomputer_plugin/linux \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt
git commit -m "feat(plugin): add o2SensorMv1..6 to ProfileSample (#810)"
```

---

## Task 3: Android JNI and Kotlin decoders

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp:1007-1038`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:640-664`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt:165-189`
- Modify: `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt`

**Interfaces:**
- Consumes: `libdc_sample_t.o2_sensor_mv[6]` (Task 1), `ProfileSample.o2SensorMv1..6` (Task 2).
- Produces: nothing new — this task makes the Android path agree with the other four.

**Why this is its own task:** the JNI↔Kotlin contract is positional and unenforced by either compiler. A wrong index produces no error, just silently wrong data in two separate decoders.

- [ ] **Step 1: Determine whether a JVM test source set exists**

```bash
ls packages/libdivecomputer_plugin/android/src/
grep -n "testImplementation\|junit" packages/libdivecomputer_plugin/android/build.gradle
```

If `src/test` exists and JUnit is on the classpath, Step 3 writes a runnable JVM test. If not, record that fact — the decoder will be covered by the instrumented test only, which CI does not run, and that limitation must be stated in the PR description rather than glossed over.

- [ ] **Step 2: Add the shared field-count constant to the JNI side**

In `libdc_jni.cpp`, replace the hard-coded `22` with a named constant so the array size and the highest index cannot drift apart:

```c
/* Field count marshalled per sample. Kotlin decoders index this array
   positionally and must be updated together with it. Append only:
   inserting a field silently renumbers every field after it. */
#define LIBDC_SAMPLE_FIELD_COUNT 28
```

- [ ] **Step 3: Write the failing decoder test**

If `src/test` exists, create `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/SampleDecoderTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SampleDecoderTest {
    private fun sampleArray(): DoubleArray {
        val a = DoubleArray(28) { Double.NaN }
        a[0] = 60000.0            // time_ms
        a[1] = 12.5               // depth
        a[20] = UINT32_SENTINEL.toDouble()  // gasmix absent
        a[21] = UINT32_SENTINEL.toDouble()  // heading absent
        a[22] = 58.0              // cell 1 mV
        a[23] = 61.0              // cell 2 mV
        a[24] = 43.0              // cell 3 mV
        a[25] = UINT32_SENTINEL.toDouble()
        a[26] = UINT32_SENTINEL.toDouble()
        a[27] = UINT32_SENTINEL.toDouble()
        return a
    }

    @Test
    fun `millivolts decode from indices 22 through 27`() {
        val s = decodeProfileSample(sampleArray())
        assertEquals(58L, s.o2SensorMv1)
        assertEquals(61L, s.o2SensorMv2)
        assertEquals(43L, s.o2SensorMv3)
        assertNull(s.o2SensorMv4)
        assertNull(s.o2SensorMv5)
        assertNull(s.o2SensorMv6)
    }

    /** A stale .so returns the old 22-wide array; decoding must not throw. */
    @Test
    fun `short array yields null millivolts`() {
        val s = decodeProfileSample(sampleArray().copyOf(22))
        assertNull(s.o2SensorMv1)
        assertEquals(12.5, s.depthMeters, 0.0001)
    }
}
```

This requires extracting the decode body from `DiveComputerHostApiImpl.kt` into a top-level `decodeProfileSample(s: DoubleArray): ProfileSample` in a new `SampleDecoder.kt`, which both `DiveComputerHostApiImpl.kt` and `SerialDownloadRunner.kt` then call. That deduplication is the point: today the same positional contract is written out twice and can diverge.

If `src/test` does not exist, skip the JVM test and instead extend `DiveMarshalingTest.kt` with the same two cases, and note in the commit that they are instrumented-only.

- [ ] **Step 4: Run the test to verify it fails**

```bash
cd packages/libdivecomputer_plugin/android && ./gradlew test 2>&1 | tail -20
```

Expected: FAIL — `decodeProfileSample` unresolved, or the millivolt properties do not exist.

- [ ] **Step 5: Extend the JNI array**

In `libdc_jni.cpp`, update the comment, the array, and both size arguments:

```c
    // All 28 fields (14 base + 6 O2 cells + gas mix + heading + 6 cell mV).
    // Integer sentinels (UINT32_MAX) are cast to double; NAN doubles pass
    // through and become null on the Kotlin side.
    jdouble values[LIBDC_SAMPLE_FIELD_COUNT] = {
        // ... existing 22 entries unchanged, through s->heading ...
        static_cast<jdouble>(s->heading),
        static_cast<jdouble>(s->o2_sensor_mv[0]),
        static_cast<jdouble>(s->o2_sensor_mv[1]),
        static_cast<jdouble>(s->o2_sensor_mv[2]),
        static_cast<jdouble>(s->o2_sensor_mv[3]),
        static_cast<jdouble>(s->o2_sensor_mv[4]),
        static_cast<jdouble>(s->o2_sensor_mv[5])
    };
    jdoubleArray result = env->NewDoubleArray(LIBDC_SAMPLE_FIELD_COUNT);
    env->SetDoubleArrayRegion(result, 0, LIBDC_SAMPLE_FIELD_COUNT, values);
```

Do not reorder the existing 22 entries.

- [ ] **Step 6: Extract and extend the Kotlin decoder**

Create `SampleDecoder.kt` holding the shared decode, moving the body verbatim from `DiveComputerHostApiImpl.kt:640-664` and adding:

```kotlin
const val SAMPLE_FIELD_COUNT = 28

private fun mv(s: DoubleArray, i: Int): Long? =
    if (s.size < SAMPLE_FIELD_COUNT || s[i].toLong() == UINT32_SENTINEL) null
    else s[i].toLong()
```

then in the `ProfileSample(...)` construction, after `gasMixIndex`:

```kotlin
                o2SensorMv1 = mv(s, 22),
                o2SensorMv2 = mv(s, 23),
                o2SensorMv3 = mv(s, 24),
                o2SensorMv4 = mv(s, 25),
                o2SensorMv5 = mv(s, 26),
                o2SensorMv6 = mv(s, 27),
```

The `s.size < SAMPLE_FIELD_COUNT` guard follows the existing `heading` precedent at `DiveComputerHostApiImpl.kt:648` — a stale `.so` degrades to null rather than throwing.

Replace the decode bodies in both `DiveComputerHostApiImpl.kt` and `SerialDownloadRunner.kt` with calls to `decodeProfileSample`. Note that `SerialDownloadRunner.kt` uses its own `RUNNER_UINT32_SENTINEL`; confirm it has the same value as `UINT32_SENTINEL` before collapsing them, and if it differs, stop and report rather than assuming.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd packages/libdivecomputer_plugin/android && ./gradlew test 2>&1 | tail -20
```

Expected: PASS. Then confirm the app still assembles:

```bash
flutter build apk --debug 2>&1 | tail -20
```

- [ ] **Step 8: Commit**

```bash
git add packages/libdivecomputer_plugin/android
git commit -m "feat(android): marshal O2 cell millivolts at indices 22-27 (#810)"
```

---

## Task 4: DiveProfilePoint entity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart:795-898`
- Test: `test/features/dive_log/domain/entities/dive_profile_point_mv_test.dart` (create)

**Interfaces:**
- Produces: `DiveProfilePoint.o2SensorMv1..6` — `int?`, included in `copyWith` and `props`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveProfilePoint O2 cell millivolts', () {
    test('carries per-cell millivolts', () {
      const p = DiveProfilePoint(
        timestamp: 60,
        depth: 12.5,
        o2SensorMv1: 58,
        o2SensorMv2: 61,
        o2SensorMv3: 43,
      );
      expect(p.o2SensorMv1, 58);
      expect(p.o2SensorMv3, 43);
      expect(p.o2SensorMv4, isNull);
    });

    test('copyWith preserves and overrides millivolts', () {
      const p = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      expect(p.copyWith(o2SensorMv2: 61).o2SensorMv1, 58);
      expect(p.copyWith(o2SensorMv1: 60).o2SensorMv1, 60);
    });

    test('millivolts participate in equality', () {
      const a = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 58);
      const b = DiveProfilePoint(timestamp: 60, depth: 12.5, o2SensorMv1: 61);
      expect(a, isNot(equals(b)));
    });
  });
}
```

Adjust the required constructor args if `DiveProfilePoint` requires more than `timestamp` and `depth` — read the constructor first.

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/dive_log/domain/entities/dive_profile_point_mv_test.dart
```

Expected: FAIL — no named parameter `o2SensorMv1`.

- [ ] **Step 3: Add the fields**

After `final double? o2Sensor6;`:

```dart
  final int? o2SensorMv1;
  final int? o2SensorMv2;
  final int? o2SensorMv3;
  final int? o2SensorMv4;
  final int? o2SensorMv5;
  final int? o2SensorMv6;
```

After `this.o2Sensor6,` in the constructor:

```dart
    this.o2SensorMv1,
    this.o2SensorMv2,
    this.o2SensorMv3,
    this.o2SensorMv4,
    this.o2SensorMv5,
    this.o2SensorMv6,
```

In `copyWith`, six params after `double? o2Sensor6,`:

```dart
    int? o2SensorMv1,
    int? o2SensorMv2,
    int? o2SensorMv3,
    int? o2SensorMv4,
    int? o2SensorMv5,
    int? o2SensorMv6,
```

and six assignments after `o2Sensor6: o2Sensor6 ?? this.o2Sensor6,`:

```dart
      o2SensorMv1: o2SensorMv1 ?? this.o2SensorMv1,
      o2SensorMv2: o2SensorMv2 ?? this.o2SensorMv2,
      o2SensorMv3: o2SensorMv3 ?? this.o2SensorMv3,
      o2SensorMv4: o2SensorMv4 ?? this.o2SensorMv4,
      o2SensorMv5: o2SensorMv5 ?? this.o2SensorMv5,
      o2SensorMv6: o2SensorMv6 ?? this.o2SensorMv6,
```

and six entries in `props` after `o2Sensor6,`.

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/dive_log/domain/entities/dive_profile_point_mv_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_profile_point_mv_test.dart
git add lib/features/dive_log/domain/entities/dive.dart \
        test/features/dive_log/domain/entities/dive_profile_point_mv_test.dart
git commit -m "feat(dive-log): add O2 cell millivolts to DiveProfilePoint (#810)"
```

---

## Task 5: Drift schema v151

**Shipped as v153.** Written as v151 first, exactly as this task describes. A
later rebase onto `main` found v151 and v152 already claimed by unrelated
in-flight features (`diver_settings.seascape_appearance`, `site_features`), so
every `151` below — the version constant, the migration block, the backstop, the
tripwire, and the test file name (`migration_v153_o2_cell_mv_test.dart`) —
became `153` at that point. Same checklist, same idempotent-helper pattern,
different number.

**Files:**
- Modify: `lib/core/database/database.dart:797-802` (columns), `:2965` (version), migration block, `beforeOpen` backstop, `migrationVersions`
- Create: `test/core/database/migration_v151_o2_cell_mv_test.dart`
- Modify: the exact-latest schema tripwire test (located in Step 1)

**Interfaces:**
- Produces: `dive_profiles.o2_sensor_mv1..6` (nullable INTEGER); `DiveProfile.o2SensorMv1..6` and `DiveProfilesCompanion(o2SensorMv1: ...)` on the generated Drift classes; `AppDatabase.currentSchemaVersion == 151`.

- [ ] **Step 1: Re-verify the version number and locate the tripwire**

```bash
git fetch origin --quiet
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
grep -rn "currentSchemaVersion, 150\|currentSchemaVersion, equals(150)" test/
```

Expected: `origin/main` prints 150. If it prints ≥ 151, claim the next free number and substitute it everywhere this task says 151. Record which test file holds the exact-latest tripwire.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v151_o2_cell_mv_test.dart`, modelled on `test/core/database/migration_v89_o2_cells_test.dart` — read that file first and copy its harness exactly.

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v151 adds the six O2 cell millivolt columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('SELECT 1');

    final cols = await db.customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    for (var n = 1; n <= 6; n++) {
      expect(names, contains('o2_sensor_mv$n'));
    }
    await db.close();
  });

  test('the migration is idempotent on a database that already has them',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('SELECT 1');
    // Re-running the helper must not throw "duplicate column name".
    await db.customStatement('SELECT 1');
    await db.close();
  });

  test('the helper no-ops when dive_profiles does not exist', () async {
    // Partial-schema case: the guard reads PRAGMA table_info, which returns
    // empty for a missing table, so no DDL is attempted.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('DROP TABLE IF EXISTS dive_profiles');
    await db.customStatement('SELECT 1');
    await db.close();
  });

  test('v151 is the current schema version', () {
    expect(AppDatabase.currentSchemaVersion, 151);
  });
}
```

Match the real harness: if `migration_v89_o2_cells_test.dart` opens old-schema databases via a helper rather than `forTesting`, use that helper instead — the partial-schema case is the whole reason the PRAGMA guard exists and must exercise the real upgrade path.

- [ ] **Step 3: Run to verify it fails**

```bash
flutter test test/core/database/migration_v151_o2_cell_mv_test.dart
```

Expected: FAIL — columns absent, version is 150.

- [ ] **Step 4: Add the columns**

In `database.dart`, after `RealColumn get o2Sensor6 => real().nullable()();`:

```dart
  IntColumn get o2SensorMv1 => integer().nullable()();
  IntColumn get o2SensorMv2 => integer().nullable()();
  IntColumn get o2SensorMv3 => integer().nullable()();
  IntColumn get o2SensorMv4 => integer().nullable()();
  IntColumn get o2SensorMv5 => integer().nullable()();
  IntColumn get o2SensorMv6 => integer().nullable()();
```

- [ ] **Step 5: Add the guarded helper**

Place it beside the other `_assert*` helpers:

```dart
  Future<void> _assertO2CellMillivoltColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    if (cols.isEmpty) return;
    final existing = cols.map((c) => c.read<String>('name')).toSet();
    for (var n = 1; n <= 6; n++) {
      if (!existing.contains('o2_sensor_mv$n')) {
        await customStatement(
          'ALTER TABLE dive_profiles ADD COLUMN o2_sensor_mv$n INTEGER',
        );
      }
    }
  }
```

- [ ] **Step 6: Bump the version and wire both call sites**

Change `static const int currentSchemaVersion = 150;` to `151`, append `151` to `migrationVersions`, add at the end of `onUpgrade` after the `if (from < 150) await reportProgress();` line:

```dart
        // v151: raw O2 cell output in millivolts (issue #810).
        if (from < 151) {
          await _assertO2CellMillivoltColumns();
        }
        if (from < 151) await reportProgress();
```

and add the backstop in `beforeOpen`, beside the other backstop calls:

```dart
        // v151 backstop: re-assert the O2 cell millivolt columns.
        await _assertO2CellMillivoltColumns();
```

Both call sites are required — the backstop is what repairs a database whose `onUpgrade` was interrupted.

- [ ] **Step 7: Regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
```

- [ ] **Step 8: Update the tripwire test**

In the file found in Step 1, change the exact-latest assertion from 150 to 151. If the convention in that file is `greaterThanOrEqualTo`, follow whichever form the file already uses.

- [ ] **Step 9: Run the database tests**

```bash
flutter test test/core/database/ 2>&1 | tail -20; echo "exit=$?"
```

Expected: all pass. Capture the exit code explicitly — piping to `tail` masks it.

- [ ] **Step 10: Commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_v151_o2_cell_mv_test.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart \
        test/core/database/
git commit -m "feat(db): v151 adds O2 cell millivolt columns to dive_profiles (#810)"
```

---

## Task 6: Persistence wiring

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:545, 608, 682, 1187`
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart:71-76`
- Modify: `lib/features/universal_import/data/services/parsed_dive_profile_mapper.dart`
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`, `test/features/dive_log/data/repositories/dive_profile_mv_roundtrip_test.dart` (create)

**Interfaces:**
- Consumes: `ProfileSample.o2SensorMv1..6` (Task 2), `DiveProfilePoint.o2SensorMv1..6` (Task 4), the Drift columns (Task 5).
- Produces: millivolts surviving a write/read round trip through `dive_profiles`.

- [ ] **Step 1: Write the failing mapper test**

Add to `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`, matching the file's existing construction of a `pigeon.ProfileSample`:

```dart
    test('maps O2 cell millivolts through to profile points', () {
      final parsed = buildParsedDive(samples: [
        pigeonSample(timeSeconds: 60, depthMeters: 12.5,
            o2SensorMv1: 58, o2SensorMv2: 61, o2SensorMv3: 43),
      ]);
      final points = ParsedDiveMapper.toProfilePoints(parsed);
      expect(points.first.o2SensorMv1, 58);
      expect(points.first.o2SensorMv2, 61);
      expect(points.first.o2SensorMv3, 43);
      expect(points.first.o2SensorMv4, isNull);
    });
```

Use the file's own helper/constructor names — read it first; the names above are placeholders for whatever that file already uses, and must be replaced with the real ones.

- [ ] **Step 2: Write the failing round-trip test**

Create `test/features/dive_log/data/repositories/dive_profile_mv_roundtrip_test.dart`, modelled on the existing repository tests: insert a dive with a profile point carrying `o2SensorMv1..3`, read it back through the repository, and assert all six fields survive (three values, three nulls).

- [ ] **Step 3: Run to verify both fail**

```bash
flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart \
             test/features/dive_log/data/repositories/dive_profile_mv_roundtrip_test.dart
```

Expected: FAIL — no such named parameter.

- [ ] **Step 4: Wire the mapper**

In `parsed_dive_mapper.dart`, after `o2Sensor6: s.o2Sensor6,`:

```dart
            o2SensorMv1: s.o2SensorMv1,
            o2SensorMv2: s.o2SensorMv2,
            o2SensorMv3: s.o2SensorMv3,
            o2SensorMv4: s.o2SensorMv4,
            o2SensorMv5: s.o2SensorMv5,
            o2SensorMv6: s.o2SensorMv6,
```

Apply the identical block in `parsed_dive_profile_mapper.dart` at its `o2Sensor6:` site.

- [ ] **Step 5: Wire all four repository sites**

At `dive_repository_impl.dart:545` and `:682` (row → entity), after `o2Sensor6: ...`:

```dart
                o2SensorMv1: p.o2SensorMv1,
```

through `o2SensorMv6` — using `p.` at `:545` and `row.` at `:682`, matching each site's local variable.

At `:608` and `:1187` (entity → companion), after `o2Sensor6: Value(point.o2Sensor6),`:

```dart
                o2SensorMv1: Value(point.o2SensorMv1),
                o2SensorMv2: Value(point.o2SensorMv2),
                o2SensorMv3: Value(point.o2SensorMv3),
                o2SensorMv4: Value(point.o2SensorMv4),
                o2SensorMv5: Value(point.o2SensorMv5),
                o2SensorMv6: Value(point.o2SensorMv6),
```

All four sites are required. Missing one produces a silent data loss on one write path only.

- [ ] **Step 6: Run to verify they pass**

```bash
flutter test test/features/dive_computer/ test/features/dive_log/data/ 2>&1 | tail -20; echo "exit=$?"
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        lib/features/dive_computer/data/services/parsed_dive_mapper.dart \
        lib/features/universal_import/data/services/parsed_dive_profile_mapper.dart \
        test/features/dive_computer/data/services/parsed_dive_mapper_test.dart \
        test/features/dive_log/data/repositories/dive_profile_mv_roundtrip_test.dart
git commit -m "feat(dive-log): persist O2 cell millivolts through import and repository (#810)"
```

---

## Task 7: Sync coverage

**Files:**
- Inspect, and modify only if needed: `lib/core/services/sync/sync_data_serializer.dart`
- Test: `test/core/services/sync/` (add a case to the existing profile sync test if one exists)

**Interfaces:**
- Consumes: the Drift columns from Task 5.
- Produces: millivolts surviving a sync export/import round trip.

- [ ] **Step 1: Determine how dive_profiles rows are serialized**

```bash
grep -n "diveProfiles" lib/core/services/sync/sync_data_serializer.dart
grep -rn "diveProfiles" lib/core/services/sync/sync_service.dart | head -20
```

Look for whether the row map is built by `row.toJson()` / `toJsonString()` (generic — new columns ride along automatically) or by an explicit `{'o2_sensor1': ..., ...}` literal (needs the six added).

- [ ] **Step 2: Write the failing round-trip test**

Add a case to the existing sync profile test (find it with `grep -rln "diveProfiles" test/core/services/sync/`): serialize a profile row carrying `o2SensorMv1: 58`, deserialize it, and assert 58 survives. If the serialization is generic this test passes immediately — that is a valid outcome and the test is still worth keeping as a regression guard.

- [ ] **Step 3: Run it**

```bash
flutter test test/core/services/sync/ 2>&1 | tail -20; echo "exit=$?"
```

If it passes without any production change, the serialization is generic — record that in the commit message. If it fails, add the six keys to the explicit map in Step 4.

- [ ] **Step 4: Add the columns only if Step 3 failed**

Extend the explicit map with `o2_sensor_mv1` through `o2_sensor_mv6`, following the exact key-naming and null-handling convention the neighbouring `o2_sensor1..6` keys use in that file.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/
git add lib/core/services/sync test/core/services/sync
git commit -m "test(sync): cover O2 cell millivolts in profile sync round trip (#810)"
```

---

## Task 8: Derive the millivolt curves

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:432-441, 505-520`
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:237, 305, 395, 426`
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`

**Interfaces:**
- Consumes: `DiveProfilePoint.o2SensorMv1..6` (Task 4).
- Produces: `ProfileAnalysis.o2CellMvCurves` — `List<List<int?>>?`, index `i` is cell `i+1`, null when the dive has no millivolt data anywhere. Task 11 and Task 12 consume it.

- [ ] **Step 1: Write the failing tests**

Add to `profile_analysis_provider_test.dart`:

```dart
    test('builds millivolt curves independently of ppO2 availability', () {
      // The #810 case: cells report millivolts but no bar value, and this
      // profile also has no aggregate ppO2 and no setpoint, so the
      // rebreather ppO2 resolver returns null.
      final profile = [
        const DiveProfilePoint(
            timestamp: 0, depth: 5, o2SensorMv1: 58, o2SensorMv2: 61,
            o2SensorMv3: 43),
        const DiveProfilePoint(
            timestamp: 10, depth: 10, o2SensorMv1: 59, o2SensorMv2: 60,
            o2SensorMv3: 41),
      ];
      final (analysis, _) = overlayComputerDecoData(baseAnalysis, profile);

      expect(analysis.o2CellMvCurves, isNotNull);
      expect(analysis.o2CellMvCurves!.length, 3);
      expect(analysis.o2CellMvCurves![0], [58, 59]);
      expect(analysis.o2CellMvCurves![2], [43, 41]);
    });

    test('leaves millivolt curves null when no cell reports them', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 5, o2Sensor1: 1.1),
      ];
      final (analysis, _) = overlayComputerDecoData(baseAnalysis, profile);
      expect(analysis.o2CellMvCurves, isNull);
    });

    test('keeps a gap as null rather than carrying the last reading', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 5, o2SensorMv1: 58),
        const DiveProfilePoint(timestamp: 10, depth: 10),
        const DiveProfilePoint(timestamp: 20, depth: 12, o2SensorMv1: 57),
      ];
      final (analysis, _) = overlayComputerDecoData(baseAnalysis, profile);
      expect(analysis.o2CellMvCurves![0], [58, null, 57]);
    });
```

Use the file's existing `baseAnalysis` fixture and `overlayComputerDecoData` call convention — read the neighbouring `o2SensorCurves` tests at lines 856-900 first and match them.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
```

Expected: FAIL — `o2CellMvCurves` is not defined.

- [ ] **Step 3: Add the field to ProfileAnalysis**

In `profile_analysis_service.dart`, beside `o2SensorCurves`:

```dart
  /// Raw O2 cell output in millivolts, one curve per cell (index i == cell
  /// i+1), or null when no cell reports millivolts.
  final List<List<int?>>? o2CellMvCurves;
```

plus the constructor param, the `copyWith` param, and the `copyWith` assignment — all four sites, mirroring exactly how `o2SensorCurves` appears at `:237`, `:305`, `:395`, and `:426`.

- [ ] **Step 4: Derive the curves**

In `profile_analysis_provider.dart`, add the accessor list beside the existing `_cellAccessors`:

```dart
const _cellMvAccessors = <int? Function(DiveProfilePoint)>[
  (p) => p.o2SensorMv1,
  (p) => p.o2SensorMv2,
  (p) => p.o2SensorMv3,
  (p) => p.o2SensorMv4,
  (p) => p.o2SensorMv5,
  (p) => p.o2SensorMv6,
];

/// Millivolt curves are derived independently of [resolveRebreatherPpO2]:
/// that resolver gates on the cells' bar values, which are absent whenever
/// the logged calibration cannot be trusted (issue #810).
List<List<int?>>? resolveO2CellMvCurves(List<DiveProfilePoint> profile) {
  var highestCell = -1;
  for (var i = 0; i < _cellMvAccessors.length; i++) {
    if (profile.any((p) => _cellMvAccessors[i](p) != null)) highestCell = i;
  }
  if (highestCell < 0) return null;
  return [
    for (var i = 0; i <= highestCell; i++)
      profile.map(_cellMvAccessors[i]).toList(),
  ];
}
```

Then in `overlayComputerDecoData`, beside `final o2SensorCurves = resolved?.sensorCurves;`:

```dart
  final o2CellMvCurves = resolveO2CellMvCurves(profile);
```

and pass `o2CellMvCurves: o2CellMvCurves,` wherever `o2SensorCurves:` is passed — including the early-return path around `:456` where none of the deco overlays apply. Missing that path is how the curves would silently vanish on OC-style profiles that still carry cells.

- [ ] **Step 5: Run to verify they pass**

```bash
flutter test test/features/dive_log/presentation/providers/ 2>&1 | tail -20; echo "exit=$?"
```

Expected: PASS, with the pre-existing `o2SensorCurves` tests still green.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart \
        lib/features/dive_log/data/services/profile_analysis_service.dart \
        test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git commit -m "feat(profile): derive O2 cell millivolt curves (#810)"
```

---

## Task 9: The right-axis metric

**Files:**
- Modify: `lib/core/constants/profile_metrics.dart:114-120`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:241, 543, 5618, 5721, 5766`
- Test: `test/core/constants/profile_metrics_test.dart`

**Interfaces:**
- Consumes: `ProfileAnalysis.o2CellMvCurves` (Task 8).
- Produces: `ProfileRightAxisMetric.o2CellMv`; `DiveProfileChart.o2CellMvCurves` constructor param (`List<List<int?>>?`).

- [ ] **Step 1: Write the failing test**

Add to `test/core/constants/profile_metrics_test.dart`:

```dart
    test('o2CellMv is a gas analysis metric measured in millivolts', () {
      const m = ProfileRightAxisMetric.o2CellMv;
      expect(m.category, ProfileMetricCategory.gasAnalysis);
      expect(m.unitSuffix, 'mV');
    });

    test('o2CellMv is not in the fallback chain', () {
      // It is diagnostic; it must never be auto-selected when the preferred
      // metric has no data.
      expect(ProfileRightAxisMetric.fallbackPriority,
          isNot(contains(ProfileRightAxisMetric.o2CellMv)));
    });
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/core/constants/profile_metrics_test.dart
```

Expected: FAIL — no such enum constant.

- [ ] **Step 3: Add the enum value**

In `profile_metrics.dart`, after the `otu(...)` entry, changing `otu`'s trailing `;` to `,`:

```dart
  o2CellMv(
    displayName: 'O2 Cell mV',
    shortName: 'Cell',
    color: Color(0xFF00838F), // Cyan 800 - same family as ppO2, darker
    unitSuffix: 'mV',
    category: ProfileMetricCategory.gasAnalysis,
  );
```

Do not add it to `fallbackPriority`.

- [ ] **Step 4: Add the chart constructor param**

In `dive_profile_chart.dart`, beside `o2SensorCurves` at `:241` and `:543`:

```dart
  /// Raw O2 cell output in millivolts, one curve per cell.
  final List<List<int?>>? o2CellMvCurves;
```

and `this.o2CellMvCurves,` in the constructor.

- [ ] **Step 5: Satisfy the three exhaustive switches**

The analyzer now reports three non-exhaustive switches. Add to each:

`_hasDataForMetric`:

```dart
      case ProfileRightAxisMetric.o2CellMv:
        return widget.o2CellMvCurves != null &&
            widget.o2CellMvCurves!.any((c) => c.any((v) => v != null));
```

`_getMetricRange`:

```dart
      case ProfileRightAxisMetric.o2CellMv:
        final curves = widget.o2CellMvCurves;
        if (curves == null) return null;
        int? maxMv;
        for (final curve in curves) {
          for (final v in curve) {
            if (v != null && (maxMv == null || v > maxMv)) maxMv = v;
          }
        }
        if (maxMv == null) return null;
        return (min: 0.0, max: maxMv * 1.2);
```

`_formatRightAxisValue` — add the case to the existing group that returns `value.toStringAsFixed(0)` alongside `cns` and `otu`.

`_rightAxisLabel` needs no case: its `default` builds `"Cell (mV)"` from `shortName` and `unitSuffix`.

- [ ] **Step 6: Forward the curves from the four call sites**

Add `o2CellMvCurves: analysis?.o2CellMvCurves,` beside each existing `o2SensorCurves: analysis?.o2SensorCurves,`:

- `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1722`
- `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart:379`
- `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:423`

(The fourth match is inside a plan document under `docs/` — leave it alone.)

- [ ] **Step 7: Run to verify it passes**

```bash
flutter analyze 2>&1 | tail -20
flutter test test/core/constants/profile_metrics_test.dart
```

Expected: analyzer clean, test PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/ test/
git add lib/core/constants/profile_metrics.dart \
        lib/features/dive_log/presentation/ \
        test/core/constants/profile_metrics_test.dart
git commit -m "feat(profile): add the O2 cell millivolt right-axis metric (#810)"
```

---

## Task 10: Legend toggle

**Amendment:** this toggle shipped exactly as described here, then later grew to
also gate the agreement rug (Task 11's follow-up — see "Amendments" at the top).
No `o2CellMode` field was added to `ProfileLegendState`: a mode split was tried
and reverted, so the toggle stayed this single bool.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` (field, constructor, `copyWith`, `==`, `hashCode`, `activeSecondaryCount`, toggle method)
- Modify: the legend UI widget listing gas-analysis toggles (located in Step 1)
- Test: `test/features/dive_log/presentation/providers/` (legend provider test)

**Interfaces:**
- Produces: `ProfileLegendState.showO2CellMv` (bool, default `false`) and `ProfileLegend.toggleO2CellMv()`. Task 11 reads it as `_showO2CellMv`.

- [ ] **Step 1: Locate the legend UI and the provider test**

```bash
grep -rln "togglePpHe\|showPpHe" lib/features/dive_log/presentation/widgets/
grep -rln "ProfileLegendState" test/
```

Record the widget that renders the gas-analysis toggle group and the existing provider test file.

- [ ] **Step 2: Write the failing test**

Add to the legend provider test:

```dart
    test('o2 cell millivolts default to hidden and toggle on', () {
      const state = ProfileLegendState();
      expect(state.showO2CellMv, isFalse);
      expect(state.copyWith(showO2CellMv: true).showO2CellMv, isTrue);
    });

    test('showing o2 cell millivolts counts as an active secondary toggle', () {
      const off = ProfileLegendState();
      final on = off.copyWith(showO2CellMv: true);
      expect(on.activeSecondaryCount, off.activeSecondaryCount + 1);
    });
```

- [ ] **Step 3: Run to verify it fails**

```bash
flutter test test/features/dive_log/presentation/providers/ 2>&1 | tail -20
```

Expected: FAIL — no member `showO2CellMv`.

- [ ] **Step 4: Add the toggle**

In `profile_legend_provider.dart`, add `final bool showO2CellMv;` beside `showOtu`, then `this.showO2CellMv = false,` in the constructor, `if (showO2CellMv) count++;` in `activeSecondaryCount`, `bool? showO2CellMv,` plus `showO2CellMv: showO2CellMv ?? this.showO2CellMv,` in `copyWith`, `showO2CellMv == other.showO2CellMv &&` in `==`, `showO2CellMv,` in `hashCode`, and:

```dart
  void toggleO2CellMv() {
    state = state.copyWith(showO2CellMv: !state.showO2CellMv);
  }
```

Do **not** seed it from `settingsProvider` in `build()`. It is session-only, following the `showMod: false, // MOD not in settings yet` precedent — a persisted default would need a non-nullable `diver_settings` column and its sync default seed.

- [ ] **Step 5: Add the legend UI entry**

In the widget found in Step 1, add a toggle row for the new metric alongside the ppO2/ppN2/ppHe entries, copying that group's exact row construction. Gate it on the chart having millivolt data, matching how neighbouring rows gate themselves.

- [ ] **Step 6: Run to verify it passes**

```bash
flutter test test/features/dive_log/presentation/ 2>&1 | tail -20; echo "exit=$?"
```

- [ ] **Step 7: Commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/ test/features/dive_log/presentation/
git commit -m "feat(profile): add the O2 cell millivolt legend toggle (#810)"
```

---

## Task 11: Draw one line per cell

**Amendment:** the color palette below (`cellColors`, three shades of cyan) is
not what shipped. The final palette is `kO2CellColors` in the extracted
`lib/features/dive_log/presentation/widgets/o2_cell_readout.dart` — an ordered
six-entry ramp (Cyan 300, Teal 300, Light Green 300, Yellow 300, Orange 300, Red
300 — all one Material weight, spread further apart on the wheel), shared with
the tooltip bullets and the agreement rug's colors rather than defined locally
per call site. This task also grew a sibling: `_buildO2CellRug`, the traffic-light
agreement strip described in "Amendments" at the top and not part of the
original plan.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:2713-2719` (line list), plus a new builder near `_buildPpO2Line` at `:4775`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `widget.o2CellMvCurves` (Task 9), `_showO2CellMv` (Task 10).
- Produces: `_buildO2CellMvLines(MetricBand band, UnitFormatter units)` returning `List<LineChartBarData>` — one entry per cell that has at least one reading. It takes `units` only to reach `_getMetricRange`, so the lines and the axis cannot drift onto different scales.

- [ ] **Step 1: Write the failing tests**

Add to `dive_profile_chart_test.dart`, using the file's existing `_buildChart` helper (it takes named curve params — extend it with `o2CellMvCurves`):

```dart
    testWidgets('draws one line per O2 cell with millivolt data',
        (tester) async {
      final curves = <List<int?>>[
        List.generate(10, (i) => 58 + i % 3),
        List.generate(10, (i) => 61 - i % 3),
        List.generate(10, (i) => 43),
      ];
      await tester.pumpWidget(_buildChart(
        profile: profile,
        o2CellMvCurves: curves,
        showO2CellMv: true,
      ));
      final chart = tester.widget<DiveProfileChart>(
          find.byType(DiveProfileChart));
      expect(chart.o2CellMvCurves!.length, 3);
    });

    testWidgets('offers no millivolt metric when no cell reports one',
        (tester) async {
      await tester.pumpWidget(_buildChart(profile: profile));
      // _hasDataForMetric is false, so the metric must not be selectable.
      // Assert via whatever selector the neighbouring ppHe test uses.
    });

    testWidgets('breaks the line at a gap instead of interpolating',
        (tester) async {
      final curves = <List<int?>>[
        [58, null, 57, 56, 55, 54, 53, 52, 51, 50],
      ];
      await tester.pumpWidget(_buildChart(
        profile: profile,
        o2CellMvCurves: curves,
        showO2CellMv: true,
      ));
      // A gap must produce fewer spots than samples, not a bridged segment.
    });
```

Complete the two assertion bodies by copying the assertion style of the nearest existing metric-line test in that file — read it before writing.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
```

Expected: FAIL — no named parameter `o2CellMvCurves` on the test helper.

- [ ] **Step 3: Write the builder**

Near `_buildPpO2Line`:

```dart
  /// One line per O2 cell, in graded shades of a single hue so the three read
  /// as one metric. Gaps stay gaps: a cell that stops reporting must break the
  /// line rather than interpolate across the dropout.
  List<LineChartBarData> _buildO2CellMvLines(
    MetricBand band,
    UnitFormatter units,
  ) {
    final curves = widget.o2CellMvCurves!;
    const cellColors = [
      Color(0xFF4DD0E1), // Cyan 300
      Color(0xFF00ACC1), // Cyan 600
      Color(0xFF00838F), // Cyan 800
    ];
    final range = _getMetricRange(ProfileRightAxisMetric.o2CellMv, units);
    if (range == null) return const [];

    final lines = <LineChartBarData>[];
    for (var cell = 0; cell < curves.length; cell++) {
      final curve = curves[cell];
      final spots = <FlSpot>[];
      for (final i in _decimatedCurveIndices(curve)) {
        final mv = curve[i];
        if (mv == null) continue;
        final yValue = band.map(
          mv.toDouble().clamp(range.min, range.max),
          range.min,
          range.max,
        );
        spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
      }
      if (spots.isEmpty) continue;
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: cellColors[cell % cellColors.length],
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      ));
    }
    return lines;
  }
```

No `_withSurfaceLeadIn` and no carry-forward: unlike ppO2, a missing cell reading is a real dropout, not a sampling gap. Check the signature of `_decimatedCurveIndices` before use — if it is typed to `List<double>` rather than a generic list, add a `List<int?>` overload or inline the index generation rather than widening the existing helper.

- [ ] **Step 4: Add the toggle getter and the line entry**

Beside the other `_showX` getters, add `_showO2CellMv` reading `showO2CellMv` from the legend state exactly as `_showPpHe` reads `showPpHe`. Then in the line list, after the ppHe entry:

```dart
                    // O2 cell millivolt lines (one per calibrated cell)
                    if (_showO2CellMv && widget.o2CellMvCurves != null)
                      ..._buildO2CellMvLines(metricBand, units),
```

- [ ] **Step 5: Run to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart 2>&1 | tail -20; echo "exit=$?"
```

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart \
        test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat(profile): draw one line per O2 cell millivolt curve (#810)"
```

---

## Task 12: Tooltip rows

**Amendment:** `_cellReadout`/`_valueAt` as sketched below shipped as
`formatO2CellReadout`/`o2CellCount`/`valueAtSample` in the extracted
`o2_cell_readout.dart` (see Task 11's note), not as private methods on the chart
state — the agreement rug needs the same cell-count/readout logic the tooltip
does. The bullet color is `o2CellColor(cell)` per cell, not the fixed
`0xFF80DEEA` shown below. A later fix also decoupled these rows from the
`_showPpO2` gate this task leaves in place (see below) — hiding the aggregate
ppO2 line used to hide every cell reading with it; the cell rows now follow
`_showPpO2 || _showO2CellMv`. And a further row was added beyond the per-cell
ones: the agreement verdict, `O2 Cell Spread    tight (2 mV)` — see the spec's
"Tooltip" section.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1337-1352` and the mirrored fullscreen block at `:3246`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Consumes: `widget.o2SensorCurves` and `widget.o2CellMvCurves`.
- Produces: one combined tooltip row per cell.

- [ ] **Step 1: Write the failing tests**

Three cases, using the file's existing tooltip-inspection helper (find it near the tests at `:2669` and `:2726`):

```dart
    testWidgets('tooltip shows bar and millivolts together', (tester) async {
      // sensorCurves [[0.98]], mvCurves [[58]] -> "0.98 bar (58 mV)"
    });

    testWidgets('tooltip shows millivolts alone when the cell has no ppO2',
        (tester) async {
      // sensorCurves [[null]], mvCurves [[58]] -> "58 mV"
    });

    testWidgets('tooltip is unchanged when a cell has only ppO2',
        (tester) async {
      // sensorCurves [[0.98]], mvCurves null -> "0.98 bar"
    });
```

Fill each body by copying the tooltip-assertion pattern from the neighbouring sensor-row tests.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart -n tooltip
```

- [ ] **Step 3: Build the combined row**

Add a helper near the tooltip builders:

```dart
  /// One row per physical cell: ppO2 when the calibration is trustworthy,
  /// the raw output when it is not, both when both are available.
  String? _cellReadout(int cell, int spotIndex) {
    final bar = _valueAt(widget.o2SensorCurves, cell, spotIndex);
    final mv = _valueAt(widget.o2CellMvCurves, cell, spotIndex);
    if (bar == null && mv == null) return null;
    if (bar == null) return '$mv mV';
    if (mv == null) return '${bar.toStringAsFixed(2)} bar';
    return '${bar.toStringAsFixed(2)} bar ($mv mV)';
  }

  T? _valueAt<T>(List<List<T?>>? curves, int cell, int spotIndex) {
    if (curves == null || cell >= curves.length) return null;
    final curve = curves[cell];
    if (spotIndex >= curve.length) return null;
    return curve[spotIndex];
  }
```

- [ ] **Step 4: Use it in both tooltip blocks**

Replace the per-cell loop body at `:1339-1351` and the mirrored block at `:3246` with:

```dart
        final cellCount = math.max(
          widget.o2SensorCurves?.length ?? 0,
          widget.o2CellMvCurves?.length ?? 0,
        );
        for (var cell = 0; cell < cellCount; cell++) {
          final readout = _cellReadout(cell, spot.spotIndex);
          if (readout == null) continue;
          rows.add(
            TooltipRow(
              label: '${context.l10n.diveLog_tooltip_sensor} ${cell + 1}',
              value: readout,
              bulletColor: const Color(0xFF80DEEA),
            ),
          );
        }
```

Both blocks sit inside `if (_showPpO2 && widget.ppO2Curve != null)`. Leave that gate as it is — changing it is out of scope, and the lines themselves (Task 11) already render independently of it.

**Amendment:** left in place here, then changed in a follow-up fix once it turned out to be a real bug: the cell rows sat inside the ppO2 gate, so hiding the loop ppO2 line took every sensor reading with it. The gate became `if (_showPpO2 || _showO2CellMv)` so the cell rows follow their own toggles.

- [ ] **Step 5: Run to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart 2>&1 | tail -20; echo "exit=$?"
```

- [ ] **Step 6: Full verification before the PR**

```bash
dart format --set-exit-if-changed lib/ test/ ; echo "format exit=$?"
flutter analyze 2>&1 | tail -10
flutter test 2>&1 | tail -20; echo "test exit=$?"
cd packages/libdivecomputer_plugin/test/native && ctest --test-dir build --output-on-failure
```

All four must be clean. Do not claim completion on a piped `tail` alone — read the captured exit codes.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart \
        test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "feat(profile): show O2 cell millivolts in the profile tooltip (#810)"
```

---

## PR description notes

State plainly, without softening:

- Which layers are tested (native capture, Android decoder if a JVM source set exists, migration, mappers, repository round trip, resolver, chart widget).
- Which are **reviewed but not executed by any test**: the Windows, Linux, and Darwin marshallers — the same status as the existing `o2Sensor1..6` fields.
- That existing dives need a re-parse (downloads) or a re-import (file imports) to gain millivolts, and that no migration backfills them.
- That ppO2 per cell remains absent when the logged calibration is untrusted, by design.

Per repo convention: no Claude attribution line and no session URL in the PR body.
