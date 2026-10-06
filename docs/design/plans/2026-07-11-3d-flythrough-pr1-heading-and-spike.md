# 3D Flythrough PR 1: Heading Column + three_js Spike - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land per-sample compass heading (`DC_SAMPLE_BEARING`) end-to-end from libdivecomputer into `dive_profiles`, and validate the three_js engine with a debug-gated spike page, so the 3D flythrough (PR 2) can build on proven foundations.

**Architecture:** Heading flows through the existing sample pipeline: shared C capture (`libdc_download.c`) -> per-platform serializers (JNI array / Swift / Linux FlValue / Windows EncodableValue) -> Pigeon `ProfileSample` -> Dart persistence in download AND reparse -> new nullable `dive_profiles.heading` column (schema v105). The spike is a throwaway debug page rendering a hardcoded 3D dive-path helix with orbit controls.

**Tech Stack:** Drift ORM (migration + codegen), Pigeon 22 (platform channel codegen), libdivecomputer C wrapper, three_js (Dart port of three.js).

**Spec:** `docs/superpowers/specs/2026-07-11-3d-flythrough-design.md`

## Global Constraints

- Schema version for this PR is **105**, NOT 104 (v104 is claimed by the in-flight weight-planner branch). Tripwire tests must reference 105.
- Heading is `double?` degrees (0-359) everywhere in Dart/Pigeon; `unsigned int` with `UINT32_MAX` sentinel in native C (matching the `heartbeat` pattern).
- `macos/Classes/libdc_download.c` and `ios/Classes/libdc_download.c` are byte-identical copies; every edit to one MUST be applied to the other, verified with `diff`.
- Reparse must mirror download persistence exactly (established project rule).
- Run `dart format .` (whole repo) before every commit; whole-project `flutter analyze` with no pipe filters.
- No emojis anywhere. No Claude attribution or session URLs in the PR body.
- Work happens in a dedicated worktree; the pre-push hook runs against the MAIN tree, so push with `git push --no-verify` after running checks manually.
- The spike page is debug-menu-gated; debug section strings are hardcoded English by existing precedent (no l10n needed for it).
- Flutter pinned at 3.44.4 in CI (`.github/flutter-version.txt`); the spike task must confirm three_js resolves against it.

---

### Task 0: Worktree initialization

**Files:** none (environment only)

- [x] **Step 1: Create worktree and branch**

```bash
git -C /Users/ericgriffin/repos/submersion-app/submersion worktree add \
  .claude/worktrees/flythrough-pr1 -b worktree-flythrough-pr1-heading
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/flythrough-pr1
```

- [x] **Step 2: Initialize (worktrees do not inherit submodules or build dirs)**

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: all three succeed; `lib/core/database/database.g.dart` regenerates cleanly.

All paths in later tasks are relative to this worktree root. Use worktree-absolute paths in every Edit/Write.

---

### Task 1: Schema v105 - `dive_profiles.heading` column

**Files:**
- Modify: `lib/core/database/database.dart` (4 regions: table class ~560, `currentSchemaVersion` 2086, `migrationVersions` ~2192, `onUpgrade` after ~5067, `beforeOpen` before ~5142)
- Create: `test/core/database/migration_v105_profile_heading_test.dart`

**Interfaces:**
- Produces: `DiveProfiles.heading` (`RealColumn`, nullable) => generated `DiveProfile.heading double?`, `DiveProfilesCompanion(heading: Value<double?>)`. Consumed by Tasks 2 and 5.

- [x] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v105_profile_heading_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v105 adds heading column to dive_profiles, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
        // Minimal pre-v105 dive_profiles shape (no heading column).
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            temperature REAL,
            heart_rate INTEGER
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, heart_rate) "
          "VALUES ('p1', 'dive1', 60, 20.0, 72)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('heading'));

    final row = await db
        .customSelect(
          "SELECT heart_rate, heading FROM dive_profiles WHERE id = 'p1'",
        )
        .getSingle();
    expect(row.data['heart_rate'], 72);
    // Existing rows read the new column as NULL.
    expect(row.data['heading'], isNull);
  });

  test('v105 migration is idempotent when heading already exists', () async {
    // Exercises the PRAGMA guard branch: no duplicate ALTER.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            heading REAL
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, heading) "
          "VALUES ('p1', 'dive1', 60, 20.0, 275.0)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(
      names.where((name) => name == 'heading').length,
      1,
      reason: 'heading should exist exactly once',
    );

    final row = await db
        .customSelect("SELECT heading FROM dive_profiles WHERE id = 'p1'")
        .getSingle();
    expect(row.data['heading'], 275.0);
  });

  test('beforeOpen backstop heals a database already at '
      'currentSchemaVersion that is missing the heading column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('heading'),
    );
  });

  test('version ladder includes 105', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(105));
    expect(AppDatabase.migrationVersions, contains(105));
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v105_profile_heading_test.dart`
Expected: FAIL (`heading` not in table_info; ladder does not contain 105).

- [x] **Step 3: Add the column to the table class**

In `lib/core/database/database.dart`, `class DiveProfiles` (line ~546), directly after `IntColumn get heartRate => integer().nullable()();` (line ~560):

```dart
  // Compass heading in degrees (0-359) from DC_SAMPLE_BEARING; null when the
  // computer does not report bearing samples.
  RealColumn get heading => real().nullable()();
```

- [x] **Step 4: Bump version and ladder**

At line ~2086 change `static const int currentSchemaVersion = 103;` to `= 105;`.
At the end of `migrationVersions` (line ~2192, after `103,`) append:

```dart
    // 104 is claimed by the weight-planner branch; do not reuse.
    105,
```

- [x] **Step 5: Add the onUpgrade block**

In `onUpgrade`, after the `if (from < 103) await reportProgress();` line (~5067), add (copies the v89/v103 PRAGMA-guarded pattern):

```dart
        if (from < 105) {
          // v105: per-sample compass heading (DC_SAMPLE_BEARING) on
          // dive_profiles. PRAGMA-guarded so a healthy database no-ops.
          // v104 belongs to the weight-planner branch.
          final cols = await customSelect(
            "PRAGMA table_info('dive_profiles')",
          ).get();
          if (cols.isNotEmpty) {
            final hasHeading = cols.any(
              (c) => c.read<String>('name') == 'heading',
            );
            if (!hasHeading) {
              await customStatement(
                'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
              );
            }
          }
        }
        if (from < 105) await reportProgress();
```

- [x] **Step 6: Add the beforeOpen backstop**

In `beforeOpen`, after the v103 `diver_role` re-assert (~line 5140) and BEFORE `ensurePerformanceIndexes(this)`:

```dart
        // v105 backstop: heading column on dive_profiles.
        final profileCols = await customSelect(
          "PRAGMA table_info('dive_profiles')",
        ).get();
        final hasHeadingCol = profileCols.any(
          (c) => c.read<String>('name') == 'heading',
        );
        if (profileCols.isNotEmpty && !hasHeadingCol) {
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
          );
        }
```

- [x] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds; `database.g.dart` now contains `heading` on `DiveProfile`, `DiveProfilesCompanion`, `fromJson`/`toJson`.

- [x] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/database/migration_v105_profile_heading_test.dart`
Expected: 4 tests PASS.

- [x] **Step 9: Run neighboring schema tests (regression)**

Run: `flutter test test/core/database/`
Expected: PASS (run this directory only; whole-suite timeouts are a known trap).

- [x] **Step 10: Commit**

```bash
dart format .
git add -A
git commit -m "feat(db): add dive_profiles.heading column (schema v105)"
```

---

### Task 2: `DiveProfilePoint.heading` + repository mapping sites

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart:777-895` (field, ctor, copyWith, props)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (4 sites: ~472 read, ~534 write, ~600 read, ~1024 write)
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart:~229` (full-row companion build)
- Test: `test/features/dive_log/domain/entities/dive_profile_point_heading_test.dart`

**Interfaces:**
- Consumes: `DiveProfilesCompanion.heading` from Task 1.
- Produces: `DiveProfilePoint.heading double?` (field + ctor param + copyWith param + props member). Consumed by PR 2's reconstructor and Task 5.

- [x] **Step 1: Write the failing test**

Create `test/features/dive_log/domain/entities/dive_profile_point_heading_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('DiveProfilePoint carries heading through copyWith and equality', () {
    const point = DiveProfilePoint(
      timestamp: 60,
      depth: 18.5,
      heading: 275.0,
    );
    expect(point.heading, 275.0);

    final copied = point.copyWith(depth: 20.0);
    expect(copied.heading, 275.0, reason: 'copyWith must preserve heading');

    final reheaded = point.copyWith(heading: 90.0);
    expect(reheaded.heading, 90.0);

    // props must include heading so Equatable sees the difference.
    expect(point == reheaded, isFalse);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_profile_point_heading_test.dart`
Expected: FAIL - `heading` is not a defined named parameter.

- [x] **Step 3: Add the field to the entity (all four spots)**

In `lib/features/dive_log/domain/entities/dive.dart` `class DiveProfilePoint`:
- Fields block (~778-801), after `final int? heartRate;`:

```dart
  /// Compass heading in degrees (0-359); null when not reported.
  final double? heading;
```

- Const constructor (~803-824): add `this.heading,`.
- `copyWith` (~826-870): add parameter `double? heading,` and body line `heading: heading ?? this.heading,`.
- `props` (~872-894): add `heading,`.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_profile_point_heading_test.dart`
Expected: PASS.

- [x] **Step 5: Wire the four repository mapping sites**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`:

Read site ~472 (inline row -> entity, sets `heartRate: p.heartRate`): add

```dart
            heading: p.heading,
```

Write site ~534 (`saveEditedProfile` companion, sets `heartRate: Value(point.heartRate)`): add

```dart
        heading: Value(point.heading),
```

Read site ~600 (`_profilePointFromRow`, sets `heartRate: row.heartRate`): add

```dart
      heading: row.heading,
```

Write site ~1024 (createDive insert companion): add

```dart
          heading: Value(point.heading),
```

- [x] **Step 6: Wire the merge service**

In `lib/features/dive_log/data/services/dive_merge_service.dart` (~229), the full-row `DiveProfilesCompanion` build (consolidation must not drop heading): add alongside `heartRate`:

```dart
        heading: Value(point.heading),
```

(If this site maps from a Drift row rather than the entity, use the matching accessor, e.g. `Value(row.heading)` - mirror exactly how `heartRate` is sourced on the neighboring line.)

- [x] **Step 7: Analyze and run dive_log tests**

Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test test/features/dive_log/`
Expected: PASS.

- [x] **Step 8: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dives): carry heading through DiveProfilePoint and repositories"
```

---

### Task 3: Pigeon contract + shared native capture

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` (`class ProfileSample`, ~53-104)
- Regenerate: all `*.g.*` Pigeon outputs (dart/swift/kotlin/gobject/cpp)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:136-155` AND `packages/libdivecomputer_plugin/ios/Classes/libdc_wrapper.h` (identical copies)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` AND `packages/libdivecomputer_plugin/ios/Classes/libdc_download.c` (identical copies)

**Interfaces:**
- Produces: Pigeon `ProfileSample.heading double?` (regenerated on every platform); `libdc_sample_t.heading unsigned int` with `UINT32_MAX` = absent. Consumed by Task 4 serializers and Task 5 Dart mappers.

- [x] **Step 1: Add heading to the Pigeon message**

In `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`, `class ProfileSample`: add constructor arg `this.heading,` (near `this.heartRate,` ~line 60) and field (near `final int? heartRate;` ~line 82):

```dart
  /// Compass heading in degrees (0-359) from DC_SAMPLE_BEARING.
  final double? heading;
```

- [x] **Step 2: Regenerate Pigeon outputs**

```bash
cd packages/libdivecomputer_plugin
dart run pigeon --input pigeons/dive_computer_api.dart
cd ../..
```

Expected: regenerates `lib/src/generated/dive_computer_api.g.dart`, `ios/Classes/DiveComputerApi.g.swift`, `android/.../DiveComputerApi.g.kt`, `linux/dive_computer_api.g.h/.cc`, `windows/dive_computer_api.g.h/.cc`. `git status` shows all five touched.

- [x] **Step 3: Add the struct field (BOTH copies)**

In `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` `libdc_sample_t` (~136-155), after `unsigned int heartbeat;`:

```c
    unsigned int heading;      // degrees 0-359 (UINT32_MAX if unavailable)
```

Apply the identical edit to `packages/libdivecomputer_plugin/ios/Classes/libdc_wrapper.h`.

- [x] **Step 4: Capture DC_SAMPLE_BEARING (BOTH copies)**

In `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c`:

In the `DC_SAMPLE_TIME` reset block (~line 184, next to `state->current_sample.heartbeat = UINT32_MAX;`):

```c
        state->current_sample.heading = UINT32_MAX;
```

In the sample-type switch (next to `case DC_SAMPLE_HEARTBEAT:` ~212):

```c
    case DC_SAMPLE_BEARING:
        state->current_sample.heading = value->bearing;
        break;
```

Apply identical edits to `packages/libdivecomputer_plugin/ios/Classes/libdc_download.c`.

- [x] **Step 5: Verify the copies are still identical**

```bash
diff packages/libdivecomputer_plugin/macos/Classes/libdc_download.c \
     packages/libdivecomputer_plugin/ios/Classes/libdc_download.c
diff packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h \
     packages/libdivecomputer_plugin/ios/Classes/libdc_wrapper.h
```

Expected: no output from either diff.

- [x] **Step 6: Compile check via macOS build**

Run: `flutter build macos --debug`
Expected: builds successfully (compiles the wrapper + Swift serializer; Task 4 Step 2 has not happened yet, which is fine - Swift `ProfileSample` gained an optional field with a default and existing call sites still compile. If the generated Swift ctor makes `heading` required, do Task 4 Step 2 first, then rerun this build.)

- [x] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(libdc): capture DC_SAMPLE_BEARING and expose heading via Pigeon"
```

---

### Task 4: Four platform serializers

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp:942-980`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:~544`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt:~166`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:585-608`
- Modify: `packages/libdivecomputer_plugin/linux/dive_converter.c:64-141`
- Modify: `packages/libdivecomputer_plugin/windows/dive_converter.cc:70-140`

**Interfaces:**
- Consumes: `libdc_sample_t.heading` (Task 3), Pigeon `ProfileSample.heading` (Task 3).
- Produces: heading populated in the Pigeon `ProfileSample` on every platform. Android JNI array grows 21 -> 22 doubles; heading is index 21.

- [x] **Step 1: Android JNI array (3 edits in libdc_jni.cpp)**

In `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` (~942-980): append to the values array after the `gasmix` entry (index 20):

```c
    static_cast<jdouble>(s->heading)      // index 21
```

and change all three occurrences of `21` to `22`:

```c
jdouble values[22] = {
...
jdoubleArray result = env->NewDoubleArray(22);
env->SetDoubleArrayRegion(result, 0, 22, values);
```

(Add a comma after the previous last element.)

- [x] **Step 2: Kotlin decoders (2 sites)**

In `DiveComputerHostApiImpl.kt` (~544-550), inside the `ProfileSample(...)` construction, mirroring the `heartRate` sentinel line:

```kotlin
    heading = if (s[21].toLong() == UINT32_SENTINEL) null else s[21],
```

In `SerialDownloadRunner.kt` (~166-172):

```kotlin
    heading = if (s[21].toLong() == RUNNER_UINT32_SENTINEL) null else s[21],
```

(The array elements are already `Double`; pass through without conversion. Match the exact sentinel constant name used in each file.)

- [x] **Step 3: Swift serializer**

In `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (~585-608), inside `ProfileSample(...)`, next to the `heartRate:` line:

```swift
    heading: s.heading == UInt32.max ? nil : Double(s.heading),
```

- [x] **Step 4: Linux serializer**

In `packages/libdivecomputer_plugin/linux/dive_converter.c` (~99-141), mirroring the heartbeat pattern:

```c
    double heading_val = (double)s->heading;
    double* heading_ptr = (s->heading == UINT32_MAX) ? NULL : &heading_val;
```

and pass `heading_ptr` into the `libdivecomputer_plugin_profile_sample_new(...)` call in the position the regenerated signature expects (the Pigeon regen in Task 3 changed this generated function; the compiler enforces the position). Match the exact local-variable style of the surrounding heartbeat code.

- [x] **Step 5: Windows serializer**

In `packages/libdivecomputer_plugin/windows/dive_converter.cc` (~113-140), add the constructor argument in the position the regenerated `ProfileSample` ctor expects:

```cpp
    (s.heading == UINT32_MAX)
        ? std::nullopt
        : std::optional<double>(static_cast<double>(s.heading)),
```

Match the surrounding heartbeat expression style exactly (e.g. if it uses `EncodableValue()` for null, mirror that).

- [x] **Step 6: Build what is buildable locally**

Run: `flutter build macos --debug`
Expected: SUCCESS (validates Swift + shared C).
If an Android toolchain is available: `flutter build apk --debug` (validates JNI + Kotlin). Otherwise Windows/Linux/Android compile errors will surface in CI - watch the `Build Windows`, `Build Linux`, and Android jobs on the PR (Windows CI is the strictest: /WX).

- [x] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(libdc): serialize heading across all four platform channels"
```

---

### Task 5: Dart pipeline - download and reparse persistence

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart:181+` (`ProfileSample`)
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart:~56`
- Modify: `lib/features/dive_computer/data/services/dive_parser.dart:~29`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`ProfilePointData` ~1608, companion ~1019)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart:~437`
- Test: extend `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart` (exists, has ParsedDive fixtures)

**Interfaces:**
- Consumes: Pigeon `ProfileSample.heading` (Task 3), `DiveProfilesCompanion.heading` (Task 1).
- Produces: domain `ProfileSample.heading double?`; `ProfilePointData.heading double?`; heading persisted on download AND reparse.

- [x] **Step 1: Write the failing mapper test**

The mapper is a top-level function: `DownloadedDive parsedDiveToDownloaded(pigeon.ParsedDive parsed)` (`parsed_dive_mapper.dart:6`); it maps each Pigeon sample into the domain `ProfileSample` at lines ~52-73 (`heartRate: s.heartRate,` etc.).

Open `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`, copy its existing `pigeon.ParsedDive` fixture construction into a new test case, set `heading: 275.0` on one of the fixture's `pigeon.ProfileSample`s, and assert:

```dart
  test('carries heading into domain ProfileSample', () {
    // fixture: copy the ParsedDive builder used by the neighboring tests in
    // this file, with samples[0] given heading: 275.0 and samples[1] no heading
    final result = parsedDiveToDownloaded(parsed);
    expect(result.profile[0].heading, 275.0);
    expect(result.profile[1].heading, isNull);
  });
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: FAIL - compile error: `heading` is not a parameter of `pigeon.ProfileSample` (Task 3 adds it) or of domain `ProfileSample` (Step 3 adds it). If Task 3 is already merged in this branch, only the domain side fails.

- [x] **Step 3: Add heading to the domain entity and DTO**

`lib/features/dive_computer/domain/entities/downloaded_dive.dart`, `class ProfileSample` (~181): add field + ctor param next to `heartRate`:

```dart
  /// Compass heading in degrees (0-359); null when not reported.
  final double? heading;
```

`lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, `class ProfilePointData` (~1608): add field + ctor param:

```dart
  final double? heading;
```

- [x] **Step 4: Wire the two mappers and two persistence sites**

- `parsed_dive_mapper.dart` ~56 (next to `heartRate: s.heartRate,`):

```dart
      heading: s.heading,
```

- `dive_parser.dart` ~29 (`ProfilePointData(...)` from Pigeon sample):

```dart
        heading: sample.heading,
```

- `dive_computer_repository_impl.dart` ~1019 (download `DiveProfilesCompanion`):

```dart
          heading: Value(point.heading),
```

- `reparse_service.dart` ~437 (reparse `DiveProfilesCompanion`, `s` is the Pigeon sample - THE mirror site):

```dart
        heading: Value(s.heading),
```

- [x] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_heading_test.dart`
Expected: PASS.

- [x] **Step 6: Analyze + dive_computer test dir**

Run: `flutter analyze`
Expected: No issues found. (This also catches any remaining `ProfileSample`/`ProfilePointData` construction site that enumerates all fields as a missing-parameter error - fix any it reports by passing `heading: null` equivalent source data.)
Run: `flutter test test/features/dive_computer/`
Expected: PASS.

- [x] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(download): persist heading in download and reparse pipelines"
```

---

### Task 6: three_js spike page (debug-gated)

**Files:**
- Modify: `pubspec.yaml` (UI Components group, ~44-58)
- Create: `lib/features/settings/presentation/pages/flythrough_spike_page.dart`
- Modify: `lib/core/router/app_router.dart` (import + route under `/settings` children ~784-973)
- Modify: `lib/features/settings/presentation/pages/debug_log_viewer_page.dart` (AppBar action to open the spike)

**Interfaces:**
- Consumes: `debugModeNotifierProvider` gating (existing), route name `flythroughSpike`.
- Produces: proof that three_js renders + orbits on each platform; go/no-go input for PR 2.

- [x] **Step 1: Add the dependency**

In `pubspec.yaml` under the UI Components group (~44-58), alphabetically within the group:

```yaml
  three_js: ^0.3.0  # 3D engine spike for dive flythrough (issue: 3D flythrough)
```

Run: `flutter pub get`
Expected: resolves against Flutter 3.44.4 / Dart ^3.10.0. If resolution fails or the resolved version pulls a flutter_angle that will not build, STOP and report - this is the spike's first go/no-go gate.

- [x] **Step 2: Create the spike page**

Create `lib/features/settings/presentation/pages/flythrough_spike_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

/// Throwaway spike proving three_js renders a dive-path-like polyline with
/// orbit controls on every platform. Reached only from the debug menu.
/// Delete when PR 2 lands the real flythrough viewport.
class FlythroughSpikePage extends StatefulWidget {
  const FlythroughSpikePage({super.key});

  @override
  State<FlythroughSpikePage> createState() => _FlythroughSpikePageState();
}

class _FlythroughSpikePageState extends State<FlythroughSpikePage> {
  late final three.ThreeJS _threeJs;
  three.OrbitControls? _controls;

  @override
  void initState() {
    super.initState();
    _threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
    );
  }

  @override
  void dispose() {
    _controls?.dispose();
    _threeJs.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    _threeJs.scene = three.Scene();
    _threeJs.scene.background = three.Color.fromHex32(0x0a1a2a);

    _threeJs.camera = three.PerspectiveCamera(
      60,
      _threeJs.width / _threeJs.height,
      0.1,
      2000,
    );
    _threeJs.camera.position.setValues(80, 60, 120);

    // Hardcoded dive-path-like helix: descends to -30, spirals, returns.
    final points = <three.Vector3>[];
    for (var i = 0; i <= 300; i++) {
      final t = i / 300.0;
      final angle = t * 4 * 3.14159;
      final radius = 40.0 * (1.0 - 0.5 * t);
      final depth = -30.0 * (t < 0.5 ? (t * 2) : (2 - t * 2));
      points.add(three.Vector3(
        radius * math.cos(angle),
        depth,
        radius * math.sin(angle),
      ));
    }
    final geometry = three.BufferGeometry().setFromPoints(points);
    final line = three.Line(
      geometry,
      three.LineBasicMaterial.fromMap({'color': 0x4fc3f7}),
    );
    _threeJs.scene.add(line);

    // Water surface reference plane at y = 0.
    final grid = three.GridHelper(200, 20, 0x2196f3, 0x1a3a4a);
    _threeJs.scene.add(grid);

    _controls = three.OrbitControls(_threeJs.camera, _threeJs.globalKey);
    _threeJs.addAnimationEvent((dt) {
      _controls?.update();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('three_js Spike')),
      body: _threeJs.build(),
    );
  }
}
```

Add `import 'dart:math' as math;` at the top. NOTE: this code targets the three_js 0.3.x API as documented; the spike's purpose is to validate that API. If a symbol differs (e.g. `OrbitControls` living in `package:three_js_controls`, or `Color.fromHex32` naming), consult https://pub.dev/documentation/three_js/latest/ and the package examples at https://github.com/Knightro63/three_js/tree/main/examples, adapt, and record every deviation in the task summary - those deviations are the spike's primary deliverable for PR 2 planning. If `OrbitControls` requires a separate dependency, add `three_js_controls` to pubspec in the same group.

- [x] **Step 3: Register the route**

In `lib/core/router/app_router.dart`: add the import near the debug-logs import (~line 97):

```dart
import '../../features/settings/presentation/pages/flythrough_spike_page.dart';
```

and inside the `/settings` route children (next to the `debug-logs` route ~911-915):

```dart
        GoRoute(
          path: 'flythrough-spike',
          name: 'flythroughSpike',
          builder: (context, state) => const FlythroughSpikePage(),
        ),
```

- [x] **Step 4: Add the debug entry point**

In `lib/features/settings/presentation/pages/debug_log_viewer_page.dart`, add an AppBar action (find the existing `AppBar(` and its `actions:` list; create the list if absent):

```dart
          IconButton(
            icon: const Icon(Icons.threed_rotation),
            tooltip: '3D spike',
            onPressed: () => context.push('/settings/flythrough-spike'),
          ),
```

Add `import 'package:go_router/go_router.dart';` if not already imported.

- [ ] **Step 5: Verify on macOS (primary platform)**

```bash
flutter run -d macos
```

Manual check: Settings -> tap version 5 times to enable debug mode -> Debug -> 3D spike icon. Expected: dark blue scene, light-blue helix, grid at surface level, drag orbits, scroll/pinch zooms. Navigate back, re-enter twice - no crash, no black screen (validates dispose). Record frame smoothness impression.

- [x] **Step 6: Analyze + widget smoke test**

Run: `flutter analyze`
Expected: No issues found. (No widget test for the GL page - it cannot render in the test harness; the route registration is exercised by existing router tests if any assert route tables.)

- [x] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(debug): add three_js flythrough spike page behind debug menu"
```

---

### Task 7: Full verification sweep + PR

**Files:** none new

- [x] **Step 1: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: format changes nothing (or commit what it fixes); analyze reports No issues found (never pipe through tail/head).

- [x] **Step 2: Run the affected test directories**

```bash
flutter test test/core/database/ test/features/dive_log/ test/features/dive_computer/
```

Expected: all PASS. (Do not run the whole suite in one command - known timeout trap; shard if broader coverage is wanted.)

- [x] **Step 3: Push and open the PR**

```bash
git push --no-verify -u origin worktree-flythrough-pr1-heading
```

Then create the PR against `submersion-app/submersion` main titled "Add per-sample compass heading (DC_SAMPLE_BEARING) and three_js spike". Body: substantive summary of schema v105, native capture + 4 serializers, download/reparse persistence, spike page; note v104 is reserved by the weight-planner branch; note device smoke test of a bearing-reporting computer is pending. NO attribution line, NO session URL.

- [ ] **Step 4: Watch CI**

Watch: analyze job, test job, Build Windows (strictest - /WX), Build Linux, Android build, Apple builds. The three_js/flutter_angle native compile on Windows/Linux is this PR's second go/no-go gate. If a platform fails on the three_js dependency itself, report back before attempting fixes - that outcome feeds the PR 2 plan (fallback discussion).

---

## Post-PR 1 follow-ups (NOT in this plan)

- PR 2 plan (reconstruction + fullscreen flythrough) is written AFTER the spike verdict, incorporating any three_js API deviations recorded in Task 6.
- Device smoke test: download from a bearing-reporting computer (e.g. many Shearwater/Suunto models) and confirm heading lands in dive_profiles; then re-parse an existing dive and confirm the same.
- Importer support for heading (UDDF `<heading>`, FIT `absolute_pressure`-adjacent fields) is deliberately out of scope until a source format demands it.
