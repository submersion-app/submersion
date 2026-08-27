# First-Sync Date Cutoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a file import (e.g., Subsurface), the first dive computer connect downloads only dives newer than a user-editable cutoff date instead of the whole device, and seeds the incremental-download fingerprint.

**Architecture:** Two tiers sharing one cutoff. Tier 1 (all backends): a pre-download date prompt plus import-stage auto-skip of dives at-or-before the cutoff. Tier 2 (Shearwater petrel family): the app synthesizes a fingerprint from the cutoff date — exploiting the fact that the petrel fingerprint IS the dive-start timestamp (u32 big-endian ticks) — and a small vendored-fork patch makes the driver treat a non-matching fingerprint as a timestamp floor, skipping profile fetches for older dives. No pigeon API changes, no request order/type changes.

**Tech Stack:** Flutter/Dart, Riverpod (legacy StateNotifier via `core/providers/provider.dart` barrel), Drift, C (vendored libdivecomputer fork), CMake native tests.

**Spec:** `docs/superpowers/specs/2026-08-04-first-sync-date-cutoff-design.md` — read it first.

## Global Constraints

- Work in the existing worktree `.claude/worktrees/first-sync-cutoff` (branch `feat/first-sync-cutoff`); submodule already initialized. Before Task 1: `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` in the worktree.
- The Bash cwd can silently reset to the main checkout between commands — run `pwd` before trusting any relative path or grep result (known trap).
- Fork (submodule) commits go on a new branch `fingerprint-timestamp-floor` created off the pinned SHA (`git rev-parse HEAD` inside `packages/libdivecomputer_plugin/third_party/libdivecomputer`; expected `e4b10a8b52f20c5eeb50d45943dd5f9581297abe`). NEVER push the fork or the app from a task — pushes happen only at the very end with explicit user approval, fork first (CI recursive-checkout trap).
- No database schema changes anywhere in this plan. Do not touch `database.dart` schemaVersion.
- No emojis in code or comments. Immutability always. `dart format .` (whole project) must be clean before every commit. `flutter analyze` on the whole project must be clean — infos are fatal in CI; NEVER pipe analyze output through `tail`/`head` (masks the exit code).
- l10n: every new key goes into `lib/l10n/arb/app_en.arb` AND all 10 non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then regenerate (`flutter gen-l10n` or the project's configured codegen — check how existing keys regenerate).
- Native tests: configure CMake with NO `-DCMAKE_BUILD_TYPE` — Release defines NDEBUG which strips the `assert()`-based tests (known trap).
- Existing behavior invariants that must not change: exact-fingerprint incremental downloads, cancel semantics (fingerprint advances only through processed dives on cancel), duplicate matching, consolidation.

---

### Task 1: Fork — fingerprint timestamp floor in `shearwater_petrel.c`

**Files:**
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_petrel.c` (submodule; commit on fork branch `fingerprint-timestamp-floor`)
- Modify: `packages/libdivecomputer_plugin/test/native/test_shearwater_petrel_foreach.c`
- Create: `packages/libdivecomputer_plugin/patches/0005-shearwater-fingerprint-timestamp-floor.patch`

**Interfaces:**
- Consumes: existing driver internals — manifest record layout (offset +0 header `0xA5C4`/`0x5A23`, +4 fingerprint/ticks u32 BE, +20 address), `device->fingerprint[4]`, the dive loop at the bottom of `shearwater_petrel_device_foreach`.
- Produces: driver behavior — when the manifest walk finds NO exact fingerprint match and the fingerprint is non-zero, records with `array_uint32_be(record+4) <= array_uint32_be(device->fingerprint)` are skipped (no download request issued) and excluded from progress maximum. Exact-match and zero-fingerprint behavior bit-identical to today. Later tasks rely on this contract only via the synthesized fingerprint string (Task 2).

- [ ] **Step 1: Create the fork branch**

```bash
cd packages/libdivecomputer_plugin/third_party/libdivecomputer
git rev-parse HEAD   # expect e4b10a8b52f20c5eeb50d45943dd5f9581297abe
git checkout -b fingerprint-timestamp-floor
```

- [ ] **Step 2: Read the existing test harness, then write failing tests**

Read `test/native/test_shearwater_petrel_foreach.c` fully. It `#include`s `shearwater_petrel.c`, mocks the `shearwater_common_*` transport with scripted manifest pages and dive payloads by address, and records the last progress event. Reuse its existing fixture builders/mocks — do not invent a parallel harness. Add three test functions (names and assertions below; adapt fixture-building calls to the harness's existing helpers):

```c
// Records in the scripted manifest are newest-first. Encode each record's
// ticks at offset +4 and address at offset +20, matching the fixtures the
// existing tests build.

static void test_floor_skips_older_dives(void) {
  // Manifest: 4 valid records, ticks 4000, 3000, 2000, 1000 (newest first).
  // Fingerprint set to ticks 2500 (big-endian bytes {0x00,0x00,0x09,0xC4})
  // — matches no record.
  // Expect: exactly the dives with ticks 3000 and 4000 delivered, in that
  // order (oldest-first), no download request issued for 1000/2000, and the
  // final progress event has current == maximum.
}

static void test_exact_match_behavior_unchanged(void) {
  // Same manifest; fingerprint == ticks 2000's record bytes (exact match).
  // Expect: dives 3000 and 4000 delivered oldest-first — identical delivery
  // AND identical download-request sequence to the pre-patch driver (the
  // manifest walk truncates at the match; the floor logic must be inert).
}

static void test_zero_fingerprint_downloads_all(void) {
  // Same manifest; fingerprint unset (all zeros).
  // Expect: all 4 dives delivered oldest-first (1000..4000).
}

// Also extend test_floor_skips_older_dives (or add a fourth case) with a
// deleted record (header 0x5A23) whose ticks are below the floor, asserting
// it affects neither delivery nor the progress maximum.
```

- [ ] **Step 3: Run native tests to verify the new ones fail**

```bash
cd packages/libdivecomputer_plugin/test/native
cmake -B build            # NO -DCMAKE_BUILD_TYPE (Release strips asserts)
cmake --build build
ctest --test-dir build --output-on-failure
```

Expected: the three new tests FAIL (floor not implemented — older dives are delivered); existing tests still PASS. If the harness runs as a single binary rather than via ctest, run that binary directly — match how CI runs it (check `.github/workflows` for the native test job).

- [ ] **Step 4: Implement the floor in `shearwater_petrel_device_foreach`**

Three edits, all inside `shearwater_petrel_device_foreach` in `src/shearwater_petrel.c`:

(a) Track exact-match in the manifest walk (the `memcmp` break around line 284):

```c
	unsigned int found = 0;
	...
	// Check the fingerprint data.
	if (memcmp (data + offset + 4, device->fingerprint, sizeof (device->fingerprint)) == 0) {
		found = 1;
		break;
	}
```

Declare `found` before the manifest-page `while (1)` loop so it survives across pages.

(b) After the manifest pages are collected and `data`/`size` are re-cached from `manifests` (around line 320), before the progress event for the manifest phase is emitted, compute the floor and repair the progress maximum:

```c
	// A fingerprint that matched no manifest record is treated as a
	// timestamp floor: the petrel fingerprint is the dive start time
	// (big-endian ticks, mirrored at record offset 4), so records at or
	// before the floor are skipped without issuing their download request.
	// An exact match (found) keeps the historical behavior untouched.
	unsigned int floor_ticks = 0;
	if (!found)
		floor_ticks = array_uint32_be (device->fingerprint);
	if (floor_ticks) {
		unsigned int nrecords = size / RECORD_SIZE;
		for (unsigned int i = 0; i < nrecords; ++i) {
			unsigned int offset = i * RECORD_SIZE;
			if (array_uint16_be (data + offset) == 0x5A23)
				continue;
			if (array_uint32_be (data + offset + 4) <= floor_ticks)
				maximum -= 1;
		}
	}
```

(c) In the reverse dive-download loop (around line 330), after the deleted-record skip and before the address read:

```c
		// Skip dives at or before the timestamp floor.
		if (floor_ticks && array_uint32_be (data + offset + 4) <= floor_ticks)
			continue;
```

Note the pre-existing `nrecords` declaration at the dive loop — rename one of them or hoist a single declaration so the file still compiles cleanly with the project's C flags.

- [ ] **Step 5: Run native tests to verify all pass**

Same commands as Step 3. Expected: ALL tests PASS, including the pre-existing #480 regression tests (delivery order and deleted-record accounting must be untouched).

- [ ] **Step 6: Commit the fork change and mirror the patch**

```bash
cd packages/libdivecomputer_plugin/third_party/libdivecomputer
git add src/shearwater_petrel.c
git commit -m "shearwater_petrel: treat unmatched fingerprint as timestamp floor"
git diff HEAD~1 HEAD > ../../patches/0005-shearwater-fingerprint-timestamp-floor.patch
```

House style for `patches/`: plain `git diff` output, no commit headers — compare with `patches/0003-*.patch` and match exactly.

- [ ] **Step 7: Commit in the app repo**

```bash
cd <worktree root>   # pwd first — cwd may have reset
dart format .        # no-op for C, but keeps the pre-commit invariant
git add packages/libdivecomputer_plugin/third_party/libdivecomputer \
        packages/libdivecomputer_plugin/patches/0005-shearwater-fingerprint-timestamp-floor.patch \
        packages/libdivecomputer_plugin/test/native/test_shearwater_petrel_foreach.c
git commit -m "feat(libdc): shearwater fingerprint timestamp floor"
```

The submodule pointer now references a commit that exists only locally — that is expected until the final push (fork pushes first).

---

### Task 2: Cutoff synthesis utility and family gate

**Files:**
- Create: `lib/features/dive_computer/domain/services/first_sync_cutoff.dart`
- Test: `test/features/dive_computer/domain/services/first_sync_cutoff_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces (exact signatures later tasks import):
  - `int shearwaterWallclockTicks(DateTime t)`
  - `String synthesizeShearwaterFingerprint(DateTime cutoff)` — 8 lowercase hex chars, big-endian u32
  - `bool supportsTimestampFingerprintFloor({String? vendor, String? product})`

- [ ] **Step 1: Write the failing tests**

Generate the reference ticks vector programmatically first (project rule: never hand-compute test vectors):

```bash
dart eval 'print(DateTime.utc(2026, 6, 12, 14, 30, 5).millisecondsSinceEpoch ~/ 1000);'
# If `dart eval` is unavailable: dart run with a 3-line script in the scratchpad.
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/first_sync_cutoff.dart';

void main() {
  group('shearwaterWallclockTicks', () {
    test('uses wallclock fields regardless of isUtc flag', () {
      final utc = DateTime.utc(2026, 6, 12, 14, 30, 5);
      final local = DateTime(2026, 6, 12, 14, 30, 5);
      expect(shearwaterWallclockTicks(utc), shearwaterWallclockTicks(local));
      expect(
        shearwaterWallclockTicks(utc),
        DateTime.utc(2026, 6, 12, 14, 30, 5).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('drops sub-second precision', () {
      final t = DateTime.utc(2026, 6, 12, 14, 30, 5, 999);
      expect(
        shearwaterWallclockTicks(t),
        DateTime.utc(2026, 6, 12, 14, 30, 5).millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('synthesizeShearwaterFingerprint', () {
    test('encodes ticks as 8 lowercase hex chars, big-endian', () {
      final cutoff = DateTime.utc(2026, 6, 12, 14, 30, 5);
      final hex = synthesizeShearwaterFingerprint(cutoff);
      expect(hex.length, 8);
      expect(hex, hex.toLowerCase());
      expect(int.parse(hex, radix: 16), shearwaterWallclockTicks(cutoff));
    });
  });

  group('supportsTimestampFingerprintFloor', () {
    test('accepts Shearwater petrel-family products', () {
      for (final product in ['Teric', 'Perdix 2', 'Petrel 3', 'Peregrine']) {
        expect(
          supportsTimestampFingerprintFloor(
            vendor: 'Shearwater',
            product: product,
          ),
          isTrue,
        );
      }
    });

    test('rejects Predator, other vendors, and nulls', () {
      expect(
        supportsTimestampFingerprintFloor(
          vendor: 'Shearwater',
          product: 'Predator',
        ),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: 'Suunto', product: 'D5'),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: null, product: 'Teric'),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: 'Shearwater', product: null),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_computer/domain/services/first_sync_cutoff_test.dart`
Expected: FAIL — file/functions do not exist.

- [ ] **Step 3: Implement**

```dart
/// Utilities for the first-sync date cutoff (see
/// docs/superpowers/specs/2026-08-04-first-sync-date-cutoff-design.md).
///
/// The Shearwater petrel-family fingerprint is the dive start timestamp: a
/// big-endian u32 ticks value that round-trips to Dart through
/// dc_datetime_gmtime and DateTime.utc. Synthesizing a fingerprint from a
/// cutoff date lets the driver's timestamp floor skip older dives without
/// any plugin API changes.
library;

/// Ticks for [t]'s wallclock fields, independent of its isUtc flag.
///
/// Downloaded dive times are reassembled as DateTime.utc from the device's
/// wallclock fields; using the same convention here makes cutoff ticks
/// comparable to device ticks.
int shearwaterWallclockTicks(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second)
        .millisecondsSinceEpoch ~/
    1000;

/// Hex fingerprint (8 chars, big-endian u32) for [cutoff].
String synthesizeShearwaterFingerprint(DateTime cutoff) =>
    shearwaterWallclockTicks(cutoff).toRadixString(16).padLeft(8, '0');

/// Whether this vendor/product pair uses the shearwater_petrel backend,
/// whose fingerprint is a timestamp (Predator uses the older backend).
bool supportsTimestampFingerprintFloor({String? vendor, String? product}) {
  if (vendor == null || product == null) return false;
  if (vendor.trim().toLowerCase() != 'shearwater') return false;
  return !product.toLowerCase().contains('predator');
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_computer/domain/services/first_sync_cutoff_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_computer/domain/services/first_sync_cutoff.dart \
        test/features/dive_computer/domain/services/first_sync_cutoff_test.dart
git commit -m "feat: shearwater fingerprint synthesis and family gate"
```

---

### Task 3: Newest-dive query and cutoff default provider

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`
- Test: extend the existing dive repository test file (locate it under `test/features/dive_log/`; follow its in-memory Drift database setup exactly)

**Interfaces:**
- Consumes: Drift `dives` table (`diveDateTime`, `diverId` columns), `currentDiverIdProvider`, `diveRepositoryProvider`.
- Produces:
  - `Future<DateTime?> getNewestDiveDateTime({required String diverId})` on `DiveRepository`
  - `final firstSyncCutoffDefaultProvider = FutureProvider<DateTime?>(...)` in `download_providers.dart`

- [ ] **Step 1: Write the failing repository test**

In the existing dive repository test file (reuse its database/repository fixtures):

```dart
group('getNewestDiveDateTime', () {
  test('returns the newest dive time for the diver, including '
      'legacy null-diverId dives', () async {
    // Seed: dive A (diverId: 'diver-1', 2026-01-10), dive B (diverId:
    // 'diver-1', 2026-03-05), dive C (diverId: null, 2026-02-01),
    // dive D (diverId: 'diver-2', 2026-06-01).
    final result =
        await repository.getNewestDiveDateTime(diverId: 'diver-1');
    expect(result, DateTime.utc(2026, 3, 5)); // match the stored convention
  });

  test('returns null when the diver has no dives', () async {
    final result =
        await repository.getNewestDiveDateTime(diverId: 'nobody');
    expect(result, isNull);
  });
});
```

Adjust the expected `DateTime` construction to whatever convention the fixture seeding uses (compare with how the existing tests in that file assert `diveDateTime`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test <that repository test file>`
Expected: FAIL — method not defined.

- [ ] **Step 3: Implement the repository method**

In `dive_repository_impl.dart`, following the class's existing query style:

```dart
/// Newest dive start time for [diverId], or null when the log is empty.
///
/// Legacy dives with a null diverId belong to the primary diver and are
/// included (same scoping rule as the rest of the app — see the
/// diverId-orphan convention used by other queries in this class).
Future<DateTime?> getNewestDiveDateTime({required String diverId}) async {
  final query = (_db.select(_db.dives)
    ..where((d) => d.diverId.equals(diverId) | d.diverId.isNull())
    ..orderBy([(d) => OrderingTerm.desc(d.diveDateTime)])
    ..limit(1));
  final row = await query.getSingleOrNull();
  return row?.diveDateTime;
}
```

Check how sibling queries in this repository scope by diver (`equals` alone vs `equals | isNull`) and match the established convention; if the codebase scopes strictly (`equals` only), drop the `isNull` arm and fix the test seed expectation accordingly.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test <that repository test file>`
Expected: PASS.

- [ ] **Step 5: Add the provider**

In `download_providers.dart`:

```dart
/// Default first-sync cutoff: the newest dive in the active diver's log.
///
/// Null when the log is empty (no cutoff prompt is shown then).
final firstSyncCutoffDefaultProvider = FutureProvider<DateTime?>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  if (diverId == null || diverId.isEmpty) return null;
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getNewestDiveDateTime(diverId: diverId);
});
```

Verify `currentDiverIdProvider`'s exact type/name by reading its definition (it is used throughout `lib/features/statistics/presentation/providers/statistics_providers.dart`) and adjust the null/empty guard to match its actual nullability. Add whatever import the diver provider requires.

- [ ] **Step 6: Analyze, format, commit**

Run: `flutter analyze` (whole project) — expect clean.

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        lib/features/dive_computer/presentation/providers/download_providers.dart \
        <repository test file>
git commit -m "feat: newest-dive query and first-sync cutoff default provider"
```

Note: adding a watched provider dependency can break existing consumer widget tests that build a narrow ProviderScope (known trap — `flutter analyze` will NOT catch it). `firstSyncCutoffDefaultProvider` is new and unconsumed so far, so no existing test should break yet; Task 5 handles the consumer-side overrides.

---

### Task 4: DownloadState.sinceCutoff and fingerprint synthesis in startDownload

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`
- Test: `test/features/dive_computer/presentation/providers/download_providers_test.dart` (create if absent; if a test for this notifier exists elsewhere, extend it — search `grep -rn "DownloadNotifier" test/`)

**Interfaces:**
- Consumes: Task 2's `synthesizeShearwaterFingerprint` / `supportsTimestampFingerprintFloor`; `DiscoveredDevice.recognizedModel` (`DeviceModel` with `manufacturer`, `model` fields — see `device_model.dart:73-75`).
- Produces:
  - `DownloadState.sinceCutoff` (`DateTime?`, default null, cleared by `reset()`)
  - `void setSinceCutoff(DateTime? value)` on `DownloadNotifier`
  - `startDownload` fingerprint precedence: stored `lastDiveFingerprint` > synthesized-from-cutoff (Shearwater non-Predator only) > null

- [ ] **Step 1: Write the failing notifier tests**

Mock `pigeon.DiveComputerService` with mocktail (match the mocking style used by existing dive_computer tests; the settings-notifier tests are the project's reference for notifier mocking). Capture the `fingerprint` argument of `startDownload`. A `downloadEvents` stub returning a never-completing stream is sufficient.

```dart
test('synthesizes fingerprint from cutoff for Shearwater with no stored '
    'fingerprint', () async {
  final cutoff = DateTime.utc(2026, 6, 12, 14, 30, 5);
  notifier.setSinceCutoff(cutoff);
  await notifier.startDownload(shearwaterDevice, computer: computerWithoutFp);
  final captured = verify(
    () => service.startDownload(any(), fingerprint: captureAny(named: 'fingerprint')),
  ).captured.single as String?;
  expect(captured, synthesizeShearwaterFingerprint(cutoff));
});

test('stored fingerprint wins over cutoff', () async {
  notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
  await notifier.startDownload(shearwaterDevice, computer: computerWithFp);
  // captured fingerprint == computerWithFp.lastDiveFingerprint
});

test('no synthesis for non-Shearwater device', () async {
  notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
  await notifier.startDownload(suuntoDevice, computer: computerWithoutFp);
  // captured fingerprint == null
});

test('no synthesis when newDivesOnly is off', () async {
  notifier.setNewDivesOnly(false);
  notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
  await notifier.startDownload(shearwaterDevice, computer: computerWithoutFp);
  // captured fingerprint == null
});

test('reset clears sinceCutoff', () {
  notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
  notifier.reset();
  expect(notifier.state.sinceCutoff, isNull);
});
```

Build `shearwaterDevice` as a `DiscoveredDevice` whose `recognizedModel` has `manufacturer: 'Shearwater', model: 'Teric'`; `suuntoDevice` analogously. Use the real `DiscoveredDevice`/`DeviceModel` constructors from `device_model.dart`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_computer/presentation/providers/download_providers_test.dart`
Expected: FAIL — `sinceCutoff`/`setSinceCutoff` undefined.

- [ ] **Step 3: Implement**

In `DownloadState`: add `final DateTime? sinceCutoff;` to the fields, constructor (default null), and `copyWith` (standard `sinceCutoff ?? this.sinceCutoff` — `reset()` already clears it by constructing a fresh `const DownloadState()`).

In `DownloadNotifier`:

```dart
/// Set the first-sync cutoff. Dives at or before this time are excluded
/// from the download for backends that support the timestamp floor.
/// Cleared by [reset]; must be set after reset and before [startDownload],
/// like the forceFullDownload flag.
void setSinceCutoff(DateTime? value) {
  state = state.copyWith(sinceCutoff: value);
}
```

Replace the fingerprint block in `startDownload` (currently lines 161-165):

```dart
      // Determine fingerprint for incremental download. A stored fingerprint
      // (from a completed prior download) always wins. With none stored, a
      // first-sync cutoff is synthesized into a timestamp-floor fingerprint
      // for Shearwater petrel-family devices (the fork treats an unmatched
      // fingerprint as a timestamp floor; other backends never receive a
      // synthesized value).
      String? fingerprint;
      if (state.newDivesOnly) {
        fingerprint = _computer?.lastDiveFingerprint;
        final cutoff = state.sinceCutoff;
        final model = device.recognizedModel;
        if (fingerprint == null &&
            cutoff != null &&
            supportsTimestampFingerprintFloor(
              vendor: model?.manufacturer,
              product: model?.model,
            )) {
          fingerprint = synthesizeShearwaterFingerprint(cutoff);
        }
      }
```

Add the import of `first_sync_cutoff.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_computer/presentation/providers/download_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_computer/presentation/providers/download_providers.dart \
        test/features/dive_computer/presentation/providers/download_providers_test.dart
git commit -m "feat: synthesize timestamp-floor fingerprint from first-sync cutoff"
```

---

### Task 5: Pre-download cutoff prompt in DownloadStepWidget + l10n

**Files:**
- Modify: `lib/features/dive_computer/presentation/widgets/download_step_widget.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (pass the default cutoff)
- Modify: `lib/l10n/arb/app_en.arb` + the 10 non-English arb files, then regenerate
- Test: `test/features/dive_computer/presentation/widgets/download_step_widget_test.dart` (create or extend; search for an existing one first)

**Interfaces:**
- Consumes: Task 3's `firstSyncCutoffDefaultProvider`; Task 4's `setSinceCutoff`; existing `forceFullDownload` post-reset ordering pattern (`download_step_widget.dart:62-81`).
- Produces: new `DownloadStepWidget` constructor parameter `final DateTime? firstSyncCutoffDefault;` — when non-null AND `widget.computer?.lastDiveFingerprint == null` AND `!widget.forceFullDownload`, the widget shows a prompt instead of auto-starting; both prompt actions start the download (with or without cutoff).

- [ ] **Step 1: Add l10n keys (English + all 10 locales + regenerate)**

In `app_en.arb` (names and shapes; translate meaningfully for ar, de, es, fr, he, hu, it, nl, pt, zh — no machine-garbage placeholders):

```json
"diveComputer_downloadStep_firstSyncTitle": "First download from this computer",
"diveComputer_downloadStep_firstSyncBody": "Your logbook already has dives. You can skip downloading dives you already have.",
"diveComputer_downloadStep_onlyAfterDate": "Only download dives after {date}",
"@diveComputer_downloadStep_onlyAfterDate": {
  "placeholders": { "date": { "type": "String" } }
},
"diveComputer_downloadStep_downloadNew": "Download new dives",
"diveComputer_downloadStep_downloadAll": "Download all dives"
```

Regenerate localizations and confirm `flutter analyze` is clean.

- [ ] **Step 2: Write the failing widget tests**

Follow the project's widget-test conventions (pin `MaterialApp` locale to English — host-locale forwarding breaks assertions otherwise; provide `ProviderScope` overrides for `downloadNotifierProvider`'s dependencies the same way existing dive_computer widget tests do; beware fakeAsync + Drift deadlocks — these tests need no database).

```dart
testWidgets('shows prompt instead of auto-starting when no fingerprint '
    'and a cutoff default exists', (tester) async {
  await pumpDownloadStep(
    tester,
    computer: computerWithoutFingerprint,
    firstSyncCutoffDefault: DateTime.utc(2026, 6, 12, 14, 30),
  );
  expect(find.text('Download new dives'), findsOneWidget);
  expect(find.text('Download all dives'), findsOneWidget);
  verifyNever(() => service.startDownload(any(),
      fingerprint: any(named: 'fingerprint')));
});

testWidgets('auto-starts when a fingerprint exists', (tester) async {
  await pumpDownloadStep(
    tester,
    computer: computerWithFingerprint,
    firstSyncCutoffDefault: DateTime.utc(2026, 6, 12),
  );
  await tester.pump();
  verify(() => service.startDownload(any(),
      fingerprint: any(named: 'fingerprint'))).called(1);
  expect(find.text('Download new dives'), findsNothing);
});

testWidgets('auto-starts when cutoff default is null (empty log)', ...);
testWidgets('auto-starts when forceFullDownload is set', ...);

testWidgets('"Download new dives" starts with the cutoff set', (tester) async {
  // pump prompt, tap 'Download new dives', then assert the notifier state
  // captured sinceCutoff == the default, and startDownload was called.
});

testWidgets('"Download all dives" starts with no cutoff', ...);

testWidgets('tapping the date row opens a date picker and updates the '
    'label', (tester) async {
  // tap the date row, pick a different day in showDatePicker, confirm the
  // label re-renders with the new date and start uses start-of-day.
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`
Expected: FAIL — parameter and prompt UI do not exist.

- [ ] **Step 4: Implement the prompt**

In `DownloadStepWidget`:
- Add `final DateTime? firstSyncCutoffDefault;` (constructor, default null).
- Add state fields: `DateTime? _cutoff;` (initialized in `initState` from `widget.firstSyncCutoffDefault`) and `bool _promptResolved = false;`.
- Gate the auto-start: in `initState`, only schedule `_startDownload()` when the prompt does not apply. Prompt applies iff `widget.firstSyncCutoffDefault != null && widget.computer?.lastDiveFingerprint == null && !widget.forceFullDownload`.
- `_startDownload` change (mirroring the forceFullDownload comment at lines 72-77 — cutoff must be set AFTER `reset()`):

```dart
    if (widget.forceFullDownload) {
      notifier.setNewDivesOnly(false);
    }
    if (_useCutoff && _cutoff != null) {
      notifier.setSinceCutoff(_cutoff);
    }
```

  where `_useCutoff` is set true only by the "Download new dives" action.
- Build the prompt UI when the prompt applies and `!_promptResolved`: a `Card` with the title/body strings, a `ListTile` showing `context.l10n.diveComputer_downloadStep_onlyAfterDate(DateFormat.yMMMd(...).format(_cutoff!))` with a calendar icon that opens `showDatePicker` (initialDate `_cutoff`, lastDate now; picked date becomes `DateTime.utc(picked.year, picked.month, picked.day)` — start-of-day so the picked day's dives are included), a primary `FilledButton` "Download new dives" (`_useCutoff = true; _promptResolved = true; _startDownload()`), and an `OutlinedButton` "Download all dives" (`_useCutoff = false; _promptResolved = true; _startDownload()`).
- Everything after prompt resolution renders the existing download UI unchanged.

In `dc_adapter_steps.dart` where `DownloadStepWidget` is constructed (line 373):

```dart
    final cutoffDefault = ref.watch(firstSyncCutoffDefaultProvider).valueOrNull;
    ...
    return DownloadStepWidget(
      ...
      firstSyncCutoffDefault: cutoffDefault,
      ...
    );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`
Expected: PASS. Also run the full existing dive_computer and import_wizard widget test directories — the new watched provider in `dc_adapter_steps` can break narrow ProviderScope tests (known trap; add overrides where needed).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/dive_computer/presentation/widgets/download_step_widget.dart \
        lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart \
        lib/l10n/ test/features/dive_computer/presentation/widgets/
git commit -m "feat: first-sync cutoff prompt on the download step"
```

---

### Task 6: Tier-1 auto-skip — adapter cutoff, EntityGroup.autoSkipIndices, wizard pre-selection

**Files:**
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (`EntityGroup`, line ~115)
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (`_captureAndAdvance`, line ~397)
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (pre-selection loop, line ~273)
- Test: extend the existing adapter test (find it: `grep -rln "DiveComputerAdapter" test/`) and the wizard providers test

**Interfaces:**
- Consumes: Task 4's `DownloadState.sinceCutoff`.
- Produces:
  - `EntityGroup.autoSkipIndices` (`Set<int>?`, optional constructor param)
  - `void setSinceCutoff(DateTime? cutoff)` on `DiveComputerAdapter`
  - Wizard pre-selection: indices in `autoSkipIndices` default to `DuplicateAction.skip` and are excluded from pending review, exactly like `matchedExistingSource` hits

- [ ] **Step 1: Write the failing adapter test**

In the existing adapter test file (mock repos, no real DB — the established pattern):

```dart
test('buildBundle marks below-cutoff dives as autoSkip', () async {
  adapter.setSinceCutoff(DateTime.utc(2026, 6, 12, 14, 30, 5));
  adapter.setDownloadedDives([
    diveAt(DateTime.utc(2026, 6, 12, 14, 30, 5)), // == cutoff -> skip
    diveAt(DateTime.utc(2026, 6, 1)),             // older -> skip
    diveAt(DateTime.utc(2026, 6, 20)),            // newer -> keep
  ]);
  final bundle = await adapter.buildBundle(...); // match existing test calls
  final group = bundle.groups[ImportEntityType.dives]!;
  expect(group.autoSkipIndices, {0, 1});
});

test('buildBundle has no autoSkip when cutoff is null', () async {
  // autoSkipIndices null or empty
});
```

And a providers test asserting an `autoSkipIndices` entry is pre-selected `DuplicateAction.skip` and absent from the pending-review set (mirror the existing `matchedExistingSource` pre-selection test).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test <adapter test file> <providers test file>`
Expected: FAIL — `autoSkipIndices`/`setSinceCutoff` undefined.

- [ ] **Step 3: Implement**

`EntityGroup` (import_bundle.dart): add `final Set<int>? autoSkipIndices;` with constructor param, keeping the class immutable and matching its existing style.

`DiveComputerAdapter`:

```dart
  DateTime? _sinceCutoff;

  /// First-sync cutoff captured from the download state. Dives at or before
  /// it default to skip in the review step (tier-1 filter for backends that
  /// transferred them anyway).
  void setSinceCutoff(DateTime? cutoff) {
    _sinceCutoff = cutoff;
  }
```

Where the dives `EntityGroup` is constructed with `matchResults` (line ~423), compute and pass:

```dart
      final cutoff = _sinceCutoff;
      final autoSkip = <int>{
        if (cutoff != null)
          for (var i = 0; i < _downloadedDives.length; i++)
            if (!_downloadedDives[i].startTime.isAfter(cutoff)) i,
      };
      // ... EntityGroup(..., matchResults: matchResults,
      //                autoSkipIndices: autoSkip.isEmpty ? null : autoSkip)
```

Also clear `_sinceCutoff` in `resetState()` alongside the other session fields.

`dc_adapter_steps.dart` `_captureAndAdvance` (line ~397), before `setDownloadedDives`:

```dart
    widget.adapter.setSinceCutoff(state.sinceCutoff);
    widget.adapter.setDownloadedDives(state.downloadedDives);
```

`import_wizard_providers.dart` pre-selection (line ~273): extend the existing loop (or add a sibling loop over `group.autoSkipIndices`) so those indices get `DuplicateAction.skip` and are removed from pending review — read the surrounding code and reuse the exact mechanism `matchedExistingSource` uses (same collections, same removal). An index that is both matched and auto-skipped must end up skipped once, not twice.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test <adapter test file> <providers test file>`
Expected: PASS. Then run the whole `test/features/import_wizard/` directory — the `EntityGroup` constructor change must not break other adapters (it is optional, so `UniversalAdapter`/`HealthKitAdapter` need no changes).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/ test/features/import_wizard/
git commit -m "feat: auto-skip below-cutoff dives in the import wizard"
```

---

### Task 7: Review step collapsed summary row for auto-skipped dives

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart` and/or `entity_review_list.dart` (read both first; put the row where the dive list renders)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locales + regenerate
- Test: extend the existing review step widget test (find via `grep -rln "ReviewStep" test/`)

**Interfaces:**
- Consumes: Task 6's `EntityGroup.autoSkipIndices` and pre-selected skip state.
- Produces: UI only — an `ExpansionTile` summarizing auto-skipped dives; expanding reveals those dives using the existing per-dive row widget so the user can rescue any (changing an action uses the existing action-change mechanism unchanged).

- [ ] **Step 1: Add the l10n key (plural, English + 10 locales + regenerate)**

```json
"importWizard_review_olderDivesSkipped": "{count, plural, one{1 older dive skipped — already in your log} other{{count} older dives skipped — already in your log}}",
"@importWizard_review_olderDivesSkipped": {
  "placeholders": { "count": { "type": "int" } }
}
```

- [ ] **Step 2: Write the failing widget test**

```dart
testWidgets('collapses auto-skipped dives into a summary row', (tester) async {
  // Pump the review step with a group of 5 dives, autoSkipIndices {0,1,2}.
  expect(
    find.text('3 older dives skipped — already in your log'),
    findsOneWidget,
  );
  // The three auto-skipped dives are not individually listed until expanded.
  await tester.tap(find.byType(ExpansionTile));
  await tester.pumpAndSettle();
  // Now their rows are visible and still marked skip.
});

testWidgets('no summary row when autoSkipIndices is empty', ...);
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test <review step test file>`
Expected: FAIL.

- [ ] **Step 4: Implement**

In the dive-list rendering path: partition indices into auto-skipped (from `group.autoSkipIndices`) and the rest. Render the rest as today. When the auto-skipped set is non-empty, render one `ExpansionTile` (leading `Icons.history`, title = the plural string, collapsed by default) whose children are the same per-dive row widgets the normal list uses. Do not fork the row widget — reuse it so action changes keep working.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test <review step test file>` and the whole `test/features/import_wizard/` directory.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/import_wizard/ lib/l10n/ test/features/import_wizard/
git commit -m "feat: collapse auto-skipped older dives in review step"
```

---

### Task 8: Full verification sweep

**Files:** none new.

- [ ] **Step 1: Full static and format check**

```bash
pwd            # confirm worktree
dart format .  # must produce no changes; if it does, commit them
flutter analyze
```

Expected: analyze clean (infos are fatal). Never pipe analyze through tail.

- [ ] **Step 2: Full test suite**

```bash
flutter test
```

Expected: PASS. Known pre-existing flakes unrelated to this diff: the recovery-code yo-yo split test (~0.6%), backup suite ordering, media upload drain. Re-run a failed suspect once before investigating; do not chase pre-existing flakes as regressions.

- [ ] **Step 3: Native tests once more**

Re-run the Task 1 CMake/ctest commands. Expected: PASS.

- [ ] **Step 4: Commit any stragglers and report**

Report completion status, then STOP. Do not push. The handoff back to the user must state:
1. Fork branch `fingerprint-timestamp-floor` must be pushed to `submersion-app/libdivecomputer` BEFORE the app branch is pushed (CI recursive submodule checkout fails otherwise).
2. Hardware smoke on a real Shearwater is the release gate: one post-import download with a synthesized fingerprint (expect only recent dives to transfer) and one normal incremental download (expect unchanged behavior).
