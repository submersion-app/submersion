# Bulk Dive Editing — Form (Plan 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the user-facing bulk-edit form for dives — reuse `DiveEditPage` in a bulk mode that gates each field behind an "apply?" toggle and writes only enabled fields/collections to all selected dives via the Plan 1 engine.

**Architecture:** `DiveEditPage` gains a `bulkDiveIds` constructor param + `isBulk` getter (mirroring `SiteEditPage.mergeSiteIds`/`isMerging`). In bulk mode the page renders a dedicated build path (`_buildBulkForm`) that composes **reused leaf widgets** (`FormRow`, pickers, dropdowns, `StatCell`, the collection editors) wrapped in a new `BulkFieldGate`. Save builds a `BulkEditRequest` from the enabled gates and applies it through `bulkDiveEditServiceProvider` (Plan 1), with a confirm dialog and snackbar-undo. The shared form primitives (`FormRow`/`StatCell`/`FormSection`) and the `edit_sections/` widgets are NOT modified — gating happens at the page's bulk build path.

**Tech Stack:** Flutter, Riverpod, go_router, Drift companions. Consumes Plan 1's `BulkDiveEditService`, `BulkEditRequest`, `BulkCollectionOp`, and the repository bulk methods (merged in PR #393).

## Global Constraints

- **Reuse, don't modify shared primitives.** Do not change `lib/shared/widgets/forms/form_row.dart`, `stat_strip.dart`, or `form_section.dart`, nor the `edit_sections/*.dart` widgets. Bulk gating lives entirely in `DiveEditPage`'s bulk build path + the new `BulkFieldGate`.
- **Bulk mode never calls `updateDive`/`addDive`.** Save builds a `BulkEditRequest` and calls `ref.read(bulkDiveEditServiceProvider).apply(request)`; undo calls `.undo(snapshot)`.
- **Only enabled fields are written.** A `BulkEditRequest`'s scalar `DivesCompanion` contains a column only when that field's gate is on. The engine already guards an all-absent companion (`bulkUpdateFields` no-ops).
- **Hidden in bulk mode** (identity + measured): dive number, entry/exit date-times, durations (bottom time/runtime), max/avg depth, the profile, CNS/OTU, GPS, dive computer serial/firmware, import metadata. These are simply never added to the bulk build path.
- **Enum persistence** matches `updateDive` (verbatim from `dive_repository_impl.dart`): most enums via `.name` (`visibility`, `waterType`, `currentDirection`, `currentStrength`, `entryMethod`, `exitMethod`, `weightType`, `windDirection`, `cloudCover`, `precipitation`, `weatherSource`), but `diveMode` and `scrType` via `.code`. FKs are `siteId`/`tripId`/`diveCenterId`/`courseId`. Numeric/duration conversions match `_saveDive` (depth→meters, temp→celsius, surfacePressure mbar/1000, durations `.inSeconds`, weather times `~/1000`).
- **Routing:** the literal `/dives/bulk-edit` route MUST be registered before the `:diveId` path-parameter child in `app_router.dart` (mirroring `match-sites`), or go-router matches `bulk-edit` as a dive id.
- **l10n:** every new user-facing string goes in `lib/l10n/arb/app_en.arb` + all 10 non-English ARBs, then `flutter gen-l10n`. Extend the existing `diveLog_bulkEdit_*` namespace.
- **Format/analyze:** run `dart format .` as the LAST step before each commit (a pre-format that drifts from canonical fails CI `dart format --set-exit-if-changed`). Whole-project `flutter analyze` must be clean (CI fails on info/warning). No `Co-Authored-By` trailers in commit messages.

---

## Phase 1 — Wiring: route, entry point, and bulk-mode shell

### Task 1: `BulkDiveEditPage` wrapper + `/dives/bulk-edit` route

**Files:**
- Create: `lib/features/dive_log/presentation/pages/bulk_dive_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (add route before `:diveId`)
- Test: `test/features/dive_log/presentation/pages/bulk_dive_edit_page_test.dart` (new)

**Interfaces:**
- Produces: `BulkDiveEditPage({required List<String> diveIds})` — a thin `StatelessWidget` that returns `DiveEditPage(bulkDiveIds: diveIds)` (mirrors `SiteMergePage`). The `DiveEditPage(bulkDiveIds:)` param is added in Task 2; for this task, stub it so the wrapper compiles, or sequence Task 2 first. (Recommended: do Task 2's constructor change first, then this task.)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

void main() {
  test('BulkDiveEditPage forwards ids to DiveEditPage in bulk mode', () {
    const page = BulkDiveEditPage(diveIds: ['a', 'b']);
    final inner = page.build(_FakeContext()) as DiveEditPage;
    expect(inner.bulkDiveIds, ['a', 'b']);
    expect(inner.isBulk, isTrue);
  });
}

class _FakeContext extends StatelessElement {
  _FakeContext() : super(const SizedBox());
}
```

(If constructing a `BuildContext` is awkward, instead make this a `testWidgets` that pumps `BulkDiveEditPage(diveIds: ['a','b'])` inside a `MaterialApp` with the needed Riverpod scope and asserts `find.byType(DiveEditPage)` plus reads the widget's `bulkDiveIds`. Use whichever compiles cleanly; the assertion that matters is `bulkDiveIds == ['a','b']` and `isBulk`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_page_test.dart`
Expected: FAIL — `BulkDiveEditPage`/`bulkDiveIds` not defined.

- [ ] **Step 3: Write minimal implementation**

`bulk_dive_edit_page.dart`:
```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

/// Thin wrapper that opens [DiveEditPage] in bulk mode for [diveIds].
/// Mirrors `SiteMergePage` for the merge flow.
class BulkDiveEditPage extends StatelessWidget {
  const BulkDiveEditPage({super.key, required this.diveIds});

  final List<String> diveIds;

  @override
  Widget build(BuildContext context) {
    return DiveEditPage(bulkDiveIds: diveIds);
  }
}
```

In `app_router.dart`, add this child to the `/dives` GoRoute's `routes:` list, immediately after the `match-sites` route and BEFORE the `:diveId` route:
```dart
              GoRoute(
                path: 'bulk-edit',
                name: 'bulkEditDives',
                builder: (context, state) {
                  final ids =
                      (state.extra as List<dynamic>?)?.cast<String>() ??
                      const <String>[];
                  return BulkDiveEditPage(diveIds: ids);
                },
              ),
```
Add the import `import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';` to `app_router.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_page_test.dart` and `flutter analyze lib/core/router/app_router.dart lib/features/dive_log/presentation/pages/bulk_dive_edit_page.dart`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkDiveEditPage + /dives/bulk-edit route"
```

### Task 2: `DiveEditPage` bulk-mode constructor + `isBulk` + bulk init

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (constructor, getters, initState/load, build branch)

**Interfaces:**
- Produces on `DiveEditPage`: `final List<String>? bulkDiveIds;`, `bool get isBulk => bulkDiveIds != null && bulkDiveIds!.isNotEmpty;`, and a constructor assert that `diveId`/`bulkDiveIds` are mutually exclusive. In bulk mode `build` returns a new `_buildBulkScaffold(units)` (skeleton here; filled in later phases).

- [ ] **Step 1: Add constructor param + getter (mirror SiteEditPage)**

In the `DiveEditPage` widget class, add the field and assert:
```dart
  final List<String>? bulkDiveIds;
```
Update the constructor:
```dart
  const DiveEditPage({
    super.key,
    this.diveId,
    this.bulkDiveIds,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  }) : assert(
         diveId == null || bulkDiveIds == null,
         'diveId and bulkDiveIds are mutually exclusive',
       );

  bool get isEditing => diveId != null;
  bool get isBulk => bulkDiveIds != null && bulkDiveIds!.isNotEmpty;
```

- [ ] **Step 2: Skip dive-loading in bulk mode**

In `_DiveEditPageState.initState`/the load path (the method that loads `_existingDive` when `widget.isEditing`), guard it so bulk mode loads nothing and starts from empty form state (same as the "new dive" branch, but with no draft and no auto-fetch). Find the load trigger (`if (widget.isEditing) { _loadDive(); }` style) and add: in bulk mode, set `_isLoading = false` and leave all controllers/typed state at their empty defaults. Do NOT initialize a default tank or default preset in bulk mode (bulk tanks are Add/Replace, not a starting list).

- [ ] **Step 3: Branch the build method**

In `build`, before constructing the normal `formBody`, add:
```dart
    if (isBulk) {
      return _buildBulkScaffold(units);
    }
```
Add a skeleton method (filled in later phases):
```dart
  Widget _buildBulkScaffold(UnitFormatter units) {
    return EditFormScaffold(
      title: context.l10n.diveLog_bulkEdit_appBarTitle(widget.bulkDiveIds!.length),
      embedded: widget.embedded,
      isSaving: _isSaving,
      hasUnsavedChanges: _hasUnsavedChanges,
      onSave: () => _saveBulk(units),
      onCancel: widget.onCancel,
      headerIcon: Icons.edit_note,
      child: _buildBulkForm(units),
    );
  }
```
Add temporary stubs so it compiles (replaced in later phases):
```dart
  Widget _buildBulkForm(UnitFormatter units) => const SizedBox.shrink();
  Future<void> _saveBulk(UnitFormatter units) async {}
```
Add the l10n key `diveLog_bulkEdit_appBarTitle` (e.g. "Edit {count} dives") in Task (l10n phase); for now use a literal or land the key first.

- [ ] **Step 4: Verify it compiles + existing edit-form tests still pass**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart` then `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart` (the existing edit-page tests — bulk changes must not regress single-edit).
Expected: analyze clean; existing tests PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add DiveEditPage bulk mode (constructor, isBulk, build branch skeleton)"
```

### Task 3: Replace the bulk-edit bottom sheet with navigation to the route

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_showBulkEditSheet` → navigate)

**Interfaces:**
- Consumes: the `/dives/bulk-edit` route (Task 1). Produces: `_openBulkEdit()` replacing `_showBulkEditSheet`, wired from both selection toolbars.

- [ ] **Step 1: Replace `_showBulkEditSheet` body**

Replace the `_showBulkEditSheet()` method with a navigation that passes the selected ids and exits selection mode when the route returns:
```dart
  Future<void> _openBulkEdit() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    await context.pushNamed('bulkEditDives', extra: ids);
    if (mounted) _exitSelectionMode();
  }
```
Keep `_showTripSelector`/`_showAddTagsDialog`/`_showRemoveTagsDialog` for now (they are no longer reached from the sheet, but other code/tests may reference them; remove only if unused — verify with `flutter analyze`). Update the two toolbar buttons (`_buildSelectionAppBar` and `_buildSelectionBar`) `onPressed: _showBulkEditSheet` → `onPressed: _openBulkEdit`.

(`context.pushNamed` comes from go_router, already imported in this file.)

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_list_content.dart`
Expected: clean (if `_showTripSelector` et al. became unused, either delete them and their helpers or keep — analyze will flag unused private methods; remove flagged ones).

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): open bulk-edit route from multi-select toolbar"
```

---

## Phase 2 — The gate widget + the gated-scalar mechanism

### Task 4: `BulkFieldGate` widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/bulk_field_gate.dart`
- Test: `test/features/dive_log/presentation/widgets/bulk_field_gate_test.dart` (new)

**Interfaces:**
- Produces: `BulkFieldGate({required bool enabled, required ValueChanged<bool> onChanged, required Widget child})` — a leading checkbox + the field; when disabled, the child is dimmed and non-interactive (the "leave this field alone" state). Tapping the checkbox toggles `enabled`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';

void main() {
  testWidgets('toggling the gate checkbox reports enabled changes', (tester) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BulkFieldGate(
              enabled: enabled,
              onChanged: (v) => setState(() => enabled = v),
              child: const Text('field'),
            ),
          ),
        ),
      ),
    );
    expect(enabled, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
  });

  testWidgets('disabled gate blocks interaction with the child', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkFieldGate(
            enabled: false,
            onChanged: (_) {},
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('inner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('inner'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tapped, isFalse); // IgnorePointer blocks it while gate is off
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/bulk_field_gate_test.dart`
Expected: FAIL — `BulkFieldGate` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';

/// Wraps an edit-form field with a leading "apply this field?" checkbox.
/// When [enabled] is false the field is dimmed and non-interactive — the
/// "leave this field alone across the selected dives" state.
class BulkFieldGate extends StatelessWidget {
  const BulkFieldGate({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: enabled,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: enabled ? 1.0 : 0.4,
            child: IgnorePointer(ignoring: !enabled, child: child),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/bulk_field_gate_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkFieldGate field wrapper"
```

### Task 5: Bulk-mode field-enabled state + scalar `DivesCompanion` builder

This task adds the per-field enabled state and the function that turns enabled gates + current controller/typed values into the scalar `DivesCompanion` for the `BulkEditRequest`. The actual gated rows are added per-section in Phase 3; this establishes the mechanism and a unit-testable builder.

**Files:**
- Create: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (a small enum/keys + a pure builder usable from tests)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (hold a `Set<BulkField> _bulkEnabled` and a `BulkEditFieldValues` snapshot builder)
- Test: `test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`

**Interfaces:**
- Produces:
  - `enum BulkField { diveCenter, trip, course, diveType, rating, isFavorite, waterType, visibility, currentDirection, currentStrength, swellHeight, entryMethod, exitMethod, altitude, surfacePressure, surfaceInterval, gradientFactorLow, gradientFactorHigh, decoAlgorithm, decoConservatism, diveComputerModel, windSpeed, windDirection, cloudCover, precipitation, humidity, weatherDescription, diveMode, setpointLow, setpointHigh, setpointDeco, diluentGas, scrubber, notes }` (the gated scalar universe; collections are handled separately).
  - `DivesCompanion buildScalarCompanion(Set<BulkField> enabled, BulkScalarInputs inputs)` — a PURE function that, for each enabled `BulkField`, sets the matching `DivesCompanion` column from `inputs` (a plain value-holder of the already-parsed/metric values). Absent for disabled fields. `notes` is excluded here when notes-mode is Append (handled via `notesAppend` on the request).
  - `class BulkScalarInputs { ... }` — a value holder with one field per `BulkField` (e.g. `String? diveCenterId; int? rating; String? waterType; double? altitude; ...`), already unit-converted to metric / mapped to `.name`/`.code` strings.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_edit_field_set.dart';

void main() {
  test('buildScalarCompanion includes only enabled fields', () {
    final companion = buildScalarCompanion(
      {BulkField.diveCenter, BulkField.rating},
      BulkScalarInputs(diveCenterId: 'dc1', rating: 5, waterType: 'salt'),
    );
    final cols = companion.toColumns(false);
    expect(cols.containsKey('dive_center_id'), isTrue);
    expect(cols.containsKey('rating'), isTrue);
    expect(cols.containsKey('water_type'), isFalse); // not enabled
  });

  test('an enabled field set to null clears that column', () {
    final companion = buildScalarCompanion(
      {BulkField.diveCenter},
      BulkScalarInputs(diveCenterId: null),
    );
    expect(companion.diveCenterId, const Value<String?>(null));
  });
}
```

(Use the actual SQL column names from `database.dart` — `dive_center_id`, `water_type`, `rating`, etc. Confirm each with a quick grep of the `Dives` table if unsure.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`
Expected: FAIL — file/types not defined.

- [ ] **Step 3: Write minimal implementation**

`bulk_edit_field_set.dart` — the enum, the inputs holder, and the builder. For each `BulkField`, map to its `DivesCompanion` column verbatim against the `updateDive` companion (in `dive_repository_impl.dart`). Pattern (showing several; the implementer fills ALL enum cases from the field table in Phase 3):
```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

enum BulkField {
  diveCenter, trip, course, diveType, rating, isFavorite, waterType,
  visibility, currentDirection, currentStrength, swellHeight, entryMethod,
  exitMethod, altitude, surfacePressure, surfaceInterval, gradientFactorLow,
  gradientFactorHigh, decoAlgorithm, decoConservatism, diveComputerModel,
  windSpeed, windDirection, cloudCover, precipitation, humidity,
  weatherDescription, diveMode, setpointLow, setpointHigh, setpointDeco,
  diluentO2, diluentHe, scrubberType, scrubberDuration, notes,
}

/// Already-converted values (metric, enum `.name`/`.code` strings, FK ids).
class BulkScalarInputs {
  BulkScalarInputs({
    this.diveCenterId, this.tripId, this.courseId, this.diveTypeId,
    this.rating, this.isFavorite, this.waterType, this.visibility,
    this.currentDirection, this.currentStrength, this.swellHeight,
    this.entryMethod, this.exitMethod, this.altitude, this.surfacePressure,
    this.surfaceIntervalSeconds, this.gradientFactorLow, this.gradientFactorHigh,
    this.decoAlgorithm, this.decoConservatism, this.diveComputerModel,
    this.windSpeed, this.windDirection, this.cloudCover, this.precipitation,
    this.humidity, this.weatherDescription, this.diveMode, this.setpointLow,
    this.setpointHigh, this.setpointDeco, this.diluentO2, this.diluentHe,
    this.scrubberType, this.scrubberDuration, this.notes,
  });
  final String? diveCenterId;
  final String? tripId;
  final String? courseId;
  final String? diveTypeId;
  final int? rating;
  final bool? isFavorite;
  final String? waterType;
  final String? visibility;
  final String? currentDirection;
  final String? currentStrength;
  final double? swellHeight;
  final String? entryMethod;
  final String? exitMethod;
  final double? altitude;
  final double? surfacePressure;
  final int? surfaceIntervalSeconds;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final String? decoAlgorithm;
  final int? decoConservatism;
  final String? diveComputerModel;
  final double? windSpeed;
  final String? windDirection;
  final String? cloudCover;
  final String? precipitation;
  final double? humidity;
  final String? weatherDescription;
  final String? diveMode; // .code
  final double? setpointLow;
  final double? setpointHigh;
  final double? setpointDeco;
  final double? diluentO2;
  final double? diluentHe;
  final String? scrubberType;
  final int? scrubberDuration;
  final String? notes;
}

/// Build the partial scalar companion from the enabled gates.
DivesCompanion buildScalarCompanion(Set<BulkField> enabled, BulkScalarInputs i) {
  DivesCompanion c = const DivesCompanion();
  for (final f in enabled) {
    c = switch (f) {
      BulkField.diveCenter => c.copyWith(diveCenterId: Value(i.diveCenterId)),
      BulkField.trip => c.copyWith(tripId: Value(i.tripId)),
      BulkField.course => c.copyWith(courseId: Value(i.courseId)),
      BulkField.diveType => c.copyWith(diveType: Value(i.diveTypeId ?? 'recreational')),
      BulkField.rating => c.copyWith(rating: Value(i.rating)),
      BulkField.isFavorite => c.copyWith(isFavorite: Value(i.isFavorite ?? false)),
      BulkField.waterType => c.copyWith(waterType: Value(i.waterType)),
      BulkField.visibility => c.copyWith(visibility: Value(i.visibility)),
      BulkField.currentDirection => c.copyWith(currentDirection: Value(i.currentDirection)),
      BulkField.currentStrength => c.copyWith(currentStrength: Value(i.currentStrength)),
      BulkField.swellHeight => c.copyWith(swellHeight: Value(i.swellHeight)),
      BulkField.entryMethod => c.copyWith(entryMethod: Value(i.entryMethod)),
      BulkField.exitMethod => c.copyWith(exitMethod: Value(i.exitMethod)),
      BulkField.altitude => c.copyWith(altitude: Value(i.altitude)),
      BulkField.surfacePressure => c.copyWith(surfacePressure: Value(i.surfacePressure)),
      BulkField.surfaceInterval => c.copyWith(surfaceIntervalSeconds: Value(i.surfaceIntervalSeconds)),
      BulkField.gradientFactorLow => c.copyWith(gradientFactorLow: Value(i.gradientFactorLow)),
      BulkField.gradientFactorHigh => c.copyWith(gradientFactorHigh: Value(i.gradientFactorHigh)),
      BulkField.decoAlgorithm => c.copyWith(decoAlgorithm: Value(i.decoAlgorithm)),
      BulkField.decoConservatism => c.copyWith(decoConservatism: Value(i.decoConservatism)),
      BulkField.diveComputerModel => c.copyWith(diveComputerModel: Value(i.diveComputerModel)),
      BulkField.windSpeed => c.copyWith(windSpeed: Value(i.windSpeed)),
      BulkField.windDirection => c.copyWith(windDirection: Value(i.windDirection)),
      BulkField.cloudCover => c.copyWith(cloudCover: Value(i.cloudCover)),
      BulkField.precipitation => c.copyWith(precipitation: Value(i.precipitation)),
      BulkField.humidity => c.copyWith(humidity: Value(i.humidity)),
      BulkField.weatherDescription => c.copyWith(weatherDescription: Value(i.weatherDescription)),
      BulkField.diveMode => c.copyWith(diveMode: Value(i.diveMode ?? 'oc')),
      BulkField.setpointLow => c.copyWith(setpointLow: Value(i.setpointLow)),
      BulkField.setpointHigh => c.copyWith(setpointHigh: Value(i.setpointHigh)),
      BulkField.setpointDeco => c.copyWith(setpointDeco: Value(i.setpointDeco)),
      BulkField.diluentO2 => c.copyWith(diluentO2: Value(i.diluentO2)),
      BulkField.diluentHe => c.copyWith(diluentHe: Value(i.diluentHe)),
      BulkField.scrubberType => c.copyWith(scrubberType: Value(i.scrubberType)),
      BulkField.scrubberDuration => c.copyWith(scrubberDurationMinutes: Value(i.scrubberDuration)),
      BulkField.notes => c.copyWith(notes: Value(i.notes ?? '')),
    };
  }
  return c;
}
```

> Verify each `copyWith` column name against the generated `DivesCompanion` in `database.g.dart` / the `updateDive` companion (e.g. `diveType`, `scrubberDurationMinutes`, `surfaceIntervalSeconds`). The switch must be exhaustive over `BulkField` (the analyzer enforces this).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart` and `flutter analyze lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart`
Expected: PASS; analyze clean (exhaustive switch).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkField set + scalar DivesCompanion builder"
```

---

## Phase 3 — The gated scalar form

### Task 6: `_buildBulkForm` structure + gated-row helper + the Logistics group

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

**Interfaces:**
- Produces in `_DiveEditPageState`: `final Set<BulkField> _bulkEnabled = {};`, a `Widget _gatedRow(BulkField field, Widget child)` helper, and `_buildBulkForm(units)` returning a `ResponsiveFormColumns` of `FormSection`s whose children are gated rows. Also `BulkScalarInputs _collectScalarInputs(UnitFormatter units)` reading the reused controllers/typed state.

- [ ] **Step 1: Add the enabled-set + gated-row helper**

The bulk form reuses the SAME controllers/typed-state fields the normal form already declares (`_selectedDiveCenter`, `_selectedTrip`, `_selectedCourse`, `_selectedDiveTypeId`, `_rating`, `_waterType`, the weather/deco controllers, etc.), so no new per-field state is needed beyond `_bulkEnabled`. Add:
```dart
  final Set<BulkField> _bulkEnabled = {};

  Widget _gatedRow(BulkField field, Widget child) {
    return BulkFieldGate(
      enabled: _bulkEnabled.contains(field),
      onChanged: (v) => setState(() {
        if (v) {
          _bulkEnabled.add(field);
        } else {
          _bulkEnabled.remove(field);
        }
      }),
      child: child,
    );
  }
```

- [ ] **Step 2: Implement `_buildBulkForm` with the Logistics group**

Replace the `_buildBulkForm` stub. Each row is a reused `FormRow`/picker wrapped in `_gatedRow`. The Logistics group covers the issue's headline fields:
```dart
  Widget _buildBulkForm(UnitFormatter units) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ResponsiveFormColumns(
        splitIndex: 2,
        children: [
          FormSection(
            label: l10n.diveLog_bulkEdit_group_logistics,
            expanded: true,
            onToggle: null,
            children: [
              _gatedRow(
                BulkField.diveCenter,
                FormRow.picker(
                  label: l10n.diveLog_edit_row_diveCenter,
                  value: _selectedDiveCenter?.name,
                  placeholder: l10n.diveLog_edit_row_notSet,
                  onTap: _showDiveCenterPicker,
                  onClear: _selectedDiveCenter == null
                      ? null
                      : () => setState(() => _selectedDiveCenter = null),
                ),
              ),
              _gatedRow(
                BulkField.trip,
                FormRow.picker(
                  label: l10n.diveLog_edit_row_trip,
                  value: _selectedTrip?.name,
                  placeholder: l10n.diveLog_edit_row_notSet,
                  onTap: _showTripPicker,
                  onClear: _selectedTrip == null
                      ? null
                      : () => setState(() => _selectedTrip = null),
                ),
              ),
              _gatedRow(
                BulkField.diveType,
                FormRow.custom(
                  label: l10n.diveLog_edit_row_diveType,
                  child: _diveTypeSelector(), // reuse the page's dive-type selector widget
                ),
              ),
              _gatedRow(
                BulkField.rating,
                FormRow.rating(
                  label: l10n.diveLog_edit_section_rating,
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ),
              _gatedRow(
                BulkField.isFavorite,
                FormRow.toggle(
                  label: l10n.diveLog_edit_label_favorite,
                  value: _existingDive?.isFavorite ?? _bulkFavorite,
                  onChanged: (v) => setState(() => _bulkFavorite = v),
                ),
              ),
            ],
          ),
          _buildBulkConditionsSection(units),
          _buildBulkDecoComputerSection(units),
          _buildBulkWeatherSection(units),
          _buildBulkRebreatherSection(units),
          _buildBulkCollectionsSection(units),
          _buildBulkNotesSection(),
        ],
      ),
    );
  }
```

Notes:
- Reuse the existing picker openers (`_showDiveCenterPicker`, `_showTripPicker`, `_showCoursePicker`, `_showSitePicker`) and the dive-type/water-type/enum selector widgets the normal form already builds (search `dive_edit_page.dart` for `_showDiveCenterPicker`, `_diveTypeSelector`/the `DropdownButtonFormField` builders, `_environmentChild`). If a selector is currently inlined inside `_environmentChild`, extract the needed `DropdownButtonFormField`s into small private builder methods so both the normal form and the bulk form can call them (this is the only refactor of existing code; keep behavior identical for the normal form).
- Add a `bool _bulkFavorite = false;` field for the favorite toggle in bulk mode (there is no `_existingDive` in bulk mode).
- `_buildBulkConditionsSection`/`_buildBulkDecoComputerSection`/etc. are added in Task 7; stub them returning `const SizedBox.shrink()` so this compiles, then fill them.

- [ ] **Step 3: Implement `_collectScalarInputs`**

Reads the reused controllers/typed-state and converts to metric / enum strings, mirroring `_saveDive`'s parsing:
```dart
  BulkScalarInputs _collectScalarInputs(UnitFormatter units) {
    double? parseDepth(TextEditingController c) => c.text.isNotEmpty
        ? units.depthToMeters(double.tryParse(c.text) ?? 0)
        : null;
    return BulkScalarInputs(
      diveCenterId: _selectedDiveCenter?.id,
      tripId: _selectedTrip?.id,
      courseId: _selectedCourse?.id,
      diveTypeId: _selectedDiveTypeId,
      rating: _rating > 0 ? _rating : null,
      isFavorite: _bulkFavorite,
      waterType: _waterType?.name,
      visibility: _selectedVisibility != Visibility.unknown
          ? _selectedVisibility.name
          : null,
      currentDirection: _currentDirection?.name,
      currentStrength: _currentStrength?.name,
      swellHeight: _swellHeightController.text.isNotEmpty
          ? units.depthToMeters(double.tryParse(_swellHeightController.text) ?? 0)
          : null,
      entryMethod: _entryMethod?.name,
      exitMethod: _exitMethod?.name,
      altitude: _altitudeController.text.isNotEmpty
          ? units.altitudeToMeters(double.tryParse(_altitudeController.text) ?? 0)
          : null,
      surfacePressure: _surfacePressureController.text.isNotEmpty
          ? (double.tryParse(_surfacePressureController.text) ?? 0) / 1000
          : null,
      surfaceIntervalSeconds: null, // wire if a surface-interval control is added
      gradientFactorLow: int.tryParse(_gfLowController.text),
      gradientFactorHigh: int.tryParse(_gfHighController.text),
      decoAlgorithm: _decoAlgorithm,
      decoConservatism: int.tryParse(_decoConservatismController.text),
      diveComputerModel: _diveComputerModelController.text.isEmpty
          ? null
          : _diveComputerModelController.text,
      windSpeed: _windSpeedController.text.isNotEmpty
          ? units.windSpeedToMs(double.tryParse(_windSpeedController.text) ?? 0)
          : null,
      windDirection: _windDirection?.name,
      cloudCover: _cloudCover?.name,
      precipitation: _precipitation?.name,
      humidity: _humidityController.text.isNotEmpty
          ? double.tryParse(_humidityController.text)
          : null,
      weatherDescription: _weatherDescriptionController.text.isEmpty
          ? null
          : _weatherDescriptionController.text,
      diveMode: _diveMode.code,
      setpointLow: _setpointLow,
      setpointHigh: _setpointHigh,
      setpointDeco: _setpointDeco,
      diluentO2: _diluentGas?.o2,
      diluentHe: _diluentGas?.he,
      scrubberType: _scrubberType,
      scrubberDuration: _scrubberDurationMinutes,
      notes: _notesController.text,
    );
  }
```

> Confirm exact controller names against the state-field list in `dive_edit_page.dart` (e.g. `_gfLowController`/`_gfHighController` may be named differently — grep `gradientFactor`/`_decoAlgorithm`). Wire any that don't yet have a control as `null` and add the control in its section task.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart` and `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
Expected: clean; existing tests pass. (The bulk form renders but most sections are stubs until Task 7-8.)

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): bulk form structure + gated Logistics group"
```

### Task 7: Gated Conditions, Deco & Computer, and Weather groups

Apply the exact `_gatedRow(BulkField.x, <reused control>)` pattern from Task 6 to each row in the table below. Each is a `FormRow` (text/picker/custom) or a gated `DropdownButtonFormField` wrapped in `FormRow.custom`, reusing the normal form's existing selectors. Implement `_buildBulkConditionsSection`, `_buildBulkDecoComputerSection`, `_buildBulkWeatherSection` as `FormSection`s (collapsible: `expanded: _bulkSectionExpanded('conditions')`, `onToggle: () => _toggleBulkSection('conditions')` — add a `Set<String> _bulkExpandedSections` mirroring the site-edit pattern).

**Field table** (BulkField → label l10n key → control to reuse → BulkScalarInputs source):

| Group | BulkField | label key | control | input source |
|---|---|---|---|---|
| Conditions | `waterType` | `diveLog_edit_label_waterType` | water-type dropdown | `_waterType?.name` |
| Conditions | `visibility` | `diveLog_edit_label_visibility` | visibility dropdown | `_selectedVisibility.name` (unknown→null) |
| Conditions | `currentDirection` | `diveLog_edit_label_currentDirection` | current-dir dropdown | `_currentDirection?.name` |
| Conditions | `currentStrength` | `diveLog_edit_label_currentStrength` | current-strength dropdown | `_currentStrength?.name` |
| Conditions | `swellHeight` | `diveLog_edit_label_swell` | `FormRow.text` `_swellHeightController` | depth→m |
| Conditions | `entryMethod` | `diveLog_edit_label_entryMethod` | entry-method dropdown | `_entryMethod?.name` |
| Conditions | `exitMethod` | `diveLog_edit_label_exitMethod` | exit-method dropdown | `_exitMethod?.name` |
| Conditions | `altitude` | `diveLog_edit_label_altitude` | `FormRow.text` `_altitudeController` | altitude→m |
| Conditions | `surfacePressure` | `diveLog_edit_label_surfacePressure` | `FormRow.text` `_surfacePressureController` | mbar/1000 |
| Deco | `gradientFactorLow` | `diveLog_edit_label_gfLow` | `FormRow.text` GF-low controller | int |
| Deco | `gradientFactorHigh` | `diveLog_edit_label_gfHigh` | `FormRow.text` GF-high controller | int |
| Deco | `decoAlgorithm` | `diveLog_edit_label_decoAlgorithm` | deco-algorithm dropdown | `_decoAlgorithm` |
| Deco | `decoConservatism` | `diveLog_edit_label_decoConservatism` | `FormRow.text` conservatism controller | int |
| Deco | `surfaceInterval` | `diveLog_edit_label_surfaceInterval` | `FormRow.text` (minutes) | minutes→seconds |
| Computer | `diveComputerModel` | `diveLog_edit_label_diveComputerModel` | `FormRow.text` model controller | string |
| Weather | `windSpeed` | `diveLog_edit_label_windSpeed` | `FormRow.text` `_windSpeedController` | windSpeed→m/s |
| Weather | `windDirection` | `diveLog_edit_label_windDirection` | wind-dir dropdown | `_windDirection?.name` |
| Weather | `cloudCover` | `diveLog_edit_label_cloudCover` | cloud-cover dropdown | `_cloudCover?.name` |
| Weather | `precipitation` | `diveLog_edit_label_precipitation` | precipitation dropdown | `_precipitation?.name` |
| Weather | `humidity` | `diveLog_edit_label_humidity` | `FormRow.text` `_humidityController` | double |
| Weather | `weatherDescription` | `diveLog_edit_label_weatherDescription` | `FormRow.text` desc controller | string |

For each enum dropdown, reuse the normal form's existing `DropdownButtonFormField` (extract to a small private builder if currently inline) so the bulk form and normal form share one source of truth. Reuse existing label l10n keys where they already exist (most do — grep before adding new ones).

- [ ] **Step 1: Implement the three section methods** following the table, each row via `_gatedRow`.
- [ ] **Step 2: Verify** `flutter analyze` on the page is clean and `dart format` applied.
- [ ] **Step 3: Widget test** — add `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart` that pumps `DiveEditPage(bulkDiveIds: ['a','b'])` (with the needed provider overrides — model on `dive_list_content_test.dart`'s harness) and asserts: toggling the dive-center gate on then saving (Phase 5) produces a request with `diveCenterId` present. (Full save assertion lands after Phase 5; for now assert the gate checkboxes render — `find.byType(Checkbox)` count matches the visible field count.)
- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): gated Conditions, Deco & Computer, and Weather groups"
```

### Task 8: Dive mode + rebreather cascade

**Files:** Modify `dive_edit_page.dart` (`_buildBulkRebreatherSection`).

The rebreather group is always present but collapsed by default. It contains the gated `diveMode` selector plus the rebreather sub-fields, gated individually. Per the approved design: the sub-fields stay reachable even when the mode gate is off (the selection may already contain CCR dives), so DO NOT hide them behind the mode gate — show them collapsed. When the `diveMode` gate is on and set to OC, show a warning at confirm time (Phase 5) if any rebreather sub-field gate is also on.

- [ ] **Step 1: Implement `_buildBulkRebreatherSection`** as a `FormSection` (label `diveLog_bulkEdit_group_rebreather`, collapsible, default collapsed) with gated rows:
  - `BulkField.diveMode` → reuse the dive-mode selector (`_diveMode` state) via `FormRow.custom`.
  - `BulkField.setpointLow` / `setpointHigh` / `setpointDeco` → `FormRow.text` controllers (or the existing setpoint inputs) reused.
  - `BulkField.diluentO2` / `diluentHe` → reuse the diluent gas-mix editor (single gate covering both columns — gate key `diluentO2` controls both; or add a combined `diluentGas` gate that enables both columns. Recommended: one gate `diluentGas` that, when on, sets both `diluentO2` and `diluentHe` from `_diluentGas`). Adjust the `BulkField` enum + `buildScalarCompanion` accordingly (replace `diluentO2`/`diluentHe` with a single `diluentGas` case that sets both columns).
  - `BulkField.scrubberType` / `scrubberDuration` → reuse scrubber inputs.

- [ ] **Step 2: Adjust `buildScalarCompanion`** for the combined `diluentGas` gate (sets `diluentO2` + `diluentHe` together) and update the Task-5 test if the enum changed. Re-run `bulk_edit_field_set_test.dart`.
- [ ] **Step 3: Verify** analyze + format clean.
- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): gated dive-mode + rebreather group"
```

---

## Phase 4 — Collections (Add / Remove / Replace)

### Task 9: Collection mode selector + collections section + tags

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart`
- Modify: `dive_edit_page.dart` (`_buildBulkCollectionsSection`, per-collection mode state, op assembly)
- Test: `test/features/dive_log/presentation/widgets/bulk_collection_mode_selector_test.dart`

**Interfaces:**
- Produces: `BulkCollectionModeSelector({required BulkCollectionMode? mode, required ValueChanged<BulkCollectionMode?> onChanged, required List<BulkCollectionMode> allowed})` — a segmented control with an "off" state (`null`) plus the allowed modes (`add`/`remove`/`replace`). Owned collections pass `allowed: [add, replace]`; reference collections pass all three.
- Produces in the page: `Map<BulkCollectionType, BulkCollectionMode> _collectionModes = {}` and `List<BulkCollectionOp> _collectCollectionOps()`.

- [ ] **Step 1: Write the failing test** for the selector

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';

void main() {
  testWidgets('selecting Replace reports the mode', (tester) async {
    BulkCollectionMode? mode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkCollectionModeSelector(
            mode: null,
            allowed: const [BulkCollectionMode.add, BulkCollectionMode.replace],
            onChanged: (m) => mode = m,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(mode, BulkCollectionMode.replace);
  });
}
```

(The button labels come from l10n keys `diveLog_bulkEdit_mode_add/remove/replace` added in Phase 6; for the test, the selector can render `mode.name` capitalized until l10n lands, then switch to keys.)

- [ ] **Step 2: Run test to verify it fails** — `BulkCollectionModeSelector` not defined.

- [ ] **Step 3: Implement the selector** — a `SegmentedButton<BulkCollectionMode?>` or a `Wrap` of `ChoiceChip`s including an "Off" chip (value `null`) and one per `allowed` mode; `onChanged` reports the selection (toggling the selected chip back to `null` = off).

- [ ] **Step 4: Implement `_buildBulkCollectionsSection` + tags**

Add per-collection mode state and the tags entry. Reuse the existing `TagInputWidget` (it already takes `selectedTags` + `onTagsChanged`). Pattern:
```dart
  final Map<BulkCollectionType, BulkCollectionMode> _collectionModes = {};

  Widget _collectionEntry({
    required BulkCollectionType type,
    required String label,
    required List<BulkCollectionMode> allowed,
    required Widget editor,
  }) {
    final mode = _collectionModes[type];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            BulkCollectionModeSelector(
              mode: mode,
              allowed: allowed,
              onChanged: (m) => setState(() {
                if (m == null) {
                  _collectionModes.remove(type);
                } else {
                  _collectionModes[type] = m;
                }
              }),
            ),
          ],
        ),
        if (mode != null) editor,
      ],
    );
  }
```
(`BulkCollectionType` is a new enum `{ tags, equipment, buddies, tanks, weights, sightings }` — add it next to `BulkField` in `bulk_edit_field_set.dart`.)

The collections section:
```dart
  Widget _buildBulkCollectionsSection(UnitFormatter units) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_bulkEdit_group_collections,
      expanded: _bulkSectionExpanded('collections'),
      onToggle: () => _toggleBulkSection('collections'),
      children: [
        _collectionEntry(
          type: BulkCollectionType.tags,
          label: l10n.diveLog_edit_section_tags,
          allowed: const [
            BulkCollectionMode.add,
            BulkCollectionMode.remove,
            BulkCollectionMode.replace,
          ],
          editor: TagInputWidget(
            selectedTags: _selectedTags,
            onTagsChanged: (tags) => setState(() => _selectedTags = tags),
          ),
        ),
        // equipment, buddies, tanks, weights, sightings added in Task 10
      ],
    );
  }
```

- [ ] **Step 5: Implement `_collectCollectionOps`** turning the mode map + payloads into `BulkCollectionOp`s:
```dart
  List<BulkCollectionOp> _collectCollectionOps() {
    final ops = <BulkCollectionOp>[];
    final tagsMode = _collectionModes[BulkCollectionType.tags];
    if (tagsMode != null) {
      ops.add(TagsOp(mode: tagsMode, tagIds: _selectedTags.map((t) => t.id).toList()));
    }
    // equipment/buddies/tanks/weights/sightings appended in Task 10
    return ops;
  }
```

- [ ] **Step 6: Verify + commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): bulk collection mode selector + tags collection"
```

### Task 10: Remaining collections — equipment, buddies, weights, tanks, sightings

Apply the `_collectionEntry` + op-assembly pattern to the remaining five. Reuse each collection's existing editor widget/builder (from the architecture map). `allowed` modes per the owned-vs-reference rule.

| Collection | type | allowed | editor to reuse | op | payload |
|---|---|---|---|---|---|
| Equipment | `equipment` | add/remove/replace | the `_equipmentChild()` body (extract to a reusable builder taking `_selectedEquipment` + onChanged) | `EquipmentOp` | `_selectedEquipment.map((e) => e.id)` |
| Buddies | `buddies` | add/remove/replace | `BuddyPicker(selectedBuddies: _selectedBuddies, onChanged: ...)` | `BuddiesOp` | `_selectedBuddies` |
| Weights | `weights` | add/replace | the `_weightChild()` rows (extract reusable builder over `_weights`) | `WeightsOp` | `_weights` |
| Tanks | `tanks` | add/replace | a `TankEditor`/`TankCard` list over a bulk `_tanks` list + "add tank"; for Add show the `onlyIfEmpty` checkbox | `TanksOp` (`onlyIfEmpty` from the checkbox) | `_tanks` |
| Sightings | `sightings` | add/replace | the `_sightingsChild()` list (extract reusable builder over `_sightings`) | `SightingsOp` | `_sightings` |

- [ ] **Step 1: Add the five `_collectionEntry` calls** to `_buildBulkCollectionsSection`, reusing each editor. For tanks Add mode, render a `CheckboxListTile` bound to a `bool _bulkTankOnlyIfEmpty = false;`.
- [ ] **Step 2: Extend `_collectCollectionOps`** with the five ops:
```dart
    final equipMode = _collectionModes[BulkCollectionType.equipment];
    if (equipMode != null) {
      ops.add(EquipmentOp(mode: equipMode, equipmentIds: _selectedEquipment.map((e) => e.id).toList()));
    }
    final buddiesMode = _collectionModes[BulkCollectionType.buddies];
    if (buddiesMode != null) {
      ops.add(BuddiesOp(mode: buddiesMode, buddies: _selectedBuddies));
    }
    final tanksMode = _collectionModes[BulkCollectionType.tanks];
    if (tanksMode != null) {
      ops.add(TanksOp(mode: tanksMode, tanks: _tanks, onlyIfEmpty: _bulkTankOnlyIfEmpty));
    }
    final weightsMode = _collectionModes[BulkCollectionType.weights];
    if (weightsMode != null) {
      ops.add(WeightsOp(mode: weightsMode, weights: _weights));
    }
    final sightingsMode = _collectionModes[BulkCollectionType.sightings];
    if (sightingsMode != null) {
      ops.add(SightingsOp(mode: sightingsMode, sightings: _sightings));
    }
```
> `_sightings` is `List<Sighting>` (domain). `SightingsOp.sightings` is `List<Sighting>` — confirm the import is the same `species.dart` `Sighting`. Buddies payload `_selectedBuddies` is `List<BuddyWithRole>` matching `BuddiesOp.buddies`. Tanks `_tanks` is `List<DiveTank>` (domain) matching `TanksOp.tanks`.

- [ ] **Step 3: Verify** analyze + format clean; the bulk form renders all collections.
- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): bulk equipment/buddies/weights/tanks/sightings collections"
```

---

## Phase 5 — Notes Set/Append, confirm dialog, save + undo

### Task 11: Notes with Set/Append mode

**Files:** Modify `dive_edit_page.dart` (`_buildBulkNotesSection`).

- [ ] **Step 1: Add notes-mode state + section**
```dart
  bool _bulkNotesAppend = false; // false = Set (overwrite), true = Append
```
```dart
  Widget _buildBulkNotesSection() {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_section_notes,
      expanded: _bulkSectionExpanded('notes'),
      onToggle: () => _toggleBulkSection('notes'),
      children: [
        _gatedRow(
          BulkField.notes,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.diveLog_bulkEdit_notes_set)),
                  ButtonSegment(value: true, label: Text(l10n.diveLog_bulkEdit_notes_append)),
                ],
                selected: {_bulkNotesAppend},
                onSelectionChanged: (s) => setState(() => _bulkNotesAppend = s.first),
              ),
              const SizedBox(height: 8),
              TextField(controller: _notesController, maxLines: 4),
            ],
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 2: Verify + commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): bulk notes with Set/Append mode"
```

### Task 12: Confirm dialog with contradiction + destructive-replace warnings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/bulk_edit_confirm_dialog.dart`
- Test: `test/features/dive_log/presentation/widgets/bulk_edit_confirm_dialog_test.dart`

**Interfaces:**
- Produces: `Future<bool?> showBulkEditConfirm(BuildContext context, {required int diveCount, required List<String> changeSummaries, required List<String> warnings})` — an `AlertDialog` listing the changes ("N dives", each summary line) and any warnings in an error color, with Cancel / Apply. Returns `true` on Apply.

- [ ] **Step 1: Write the failing test** — pump the dialog via a button, tap Apply, expect it pops `true`; with a warning present, expect the warning text is shown.
- [ ] **Step 2: Run, fail.**
- [ ] **Step 3: Implement** the dialog (a standard `showDialog<bool>` + `AlertDialog`; warnings rendered with `Theme.of(context).colorScheme.error`; Apply is a `FilledButton`).
- [ ] **Step 4: Run, pass.**
- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add bulk-edit confirm dialog"
```

### Task 13: `_saveBulk` — build request, confirm, apply, undo snackbar

**Files:** Modify `dive_edit_page.dart` (`_saveBulk`).

**Interfaces:**
- Consumes: `_collectScalarInputs`, `buildScalarCompanion`, `_collectCollectionOps`, `bulkDiveEditServiceProvider` (Plan 1), `showBulkEditConfirm`.

- [ ] **Step 1: Implement `_saveBulk`**
```dart
  Future<void> _saveBulk(UnitFormatter units) async {
    final l10n = context.l10n;
    final ids = widget.bulkDiveIds!;

    // Notes mode: append excludes notes from the scalar companion.
    final scalarFields = Set<BulkField>.from(_bulkEnabled);
    String? notesAppend;
    if (_bulkEnabled.contains(BulkField.notes) && _bulkNotesAppend) {
      scalarFields.remove(BulkField.notes);
      notesAppend = _notesController.text;
    }

    final scalars = buildScalarCompanion(scalarFields, _collectScalarInputs(units));
    final ops = _collectCollectionOps();

    // Nothing to do?
    final hasScalar = scalars.toColumns(false).isNotEmpty;
    if (!hasScalar && (notesAppend == null || notesAppend.isEmpty) && ops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.diveLog_bulkEdit_nothingSelected)),
      );
      return;
    }

    // Build summary + warnings.
    final summaries = <String>[
      if (hasScalar) l10n.diveLog_bulkEdit_summary_fields(scalars.toColumns(false).length),
      if (notesAppend != null && notesAppend.isNotEmpty) l10n.diveLog_bulkEdit_summary_notesAppend,
      for (final op in ops) _opSummary(op, l10n),
    ];
    final warnings = <String>[
      // Contradiction: setting mode = OC while a rebreather sub-field is enabled.
      if (_bulkEnabled.contains(BulkField.diveMode) &&
          _diveMode == DiveMode.oc &&
          _bulkEnabled.any((f) => const {
                BulkField.setpointLow, BulkField.setpointHigh,
                BulkField.setpointDeco, BulkField.diluentGas,
                BulkField.scrubberType, BulkField.scrubberDuration,
              }.contains(f)))
        l10n.diveLog_bulkEdit_warn_ocWithRebreather,
      // Destructive: Replace tanks deletes existing tank pressure profiles.
      if (_collectionModes[BulkCollectionType.tanks] == BulkCollectionMode.replace)
        l10n.diveLog_bulkEdit_warn_replaceTanks,
    ];

    final confirmed = await showBulkEditConfirm(
      context,
      diveCount: ids.length,
      changeSummaries: summaries,
      warnings: warnings,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final service = ref.read(bulkDiveEditServiceProvider);
      final snapshot = await service.apply(BulkEditRequest(
        diveIds: ids,
        scalars: scalars,
        notesAppend: notesAppend,
        ops: ops,
      ));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (widget.embedded) {
        widget.onSaved?.call(ids.first);
      } else {
        context.go('/dives');
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveLog_bulkEdit_applied(ids.length)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.diveLog_bulkDelete_undo, // reuse existing "Undo"
            onPressed: () => service.undo(snapshot),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.diveLog_edit_snackbar_errorSaving(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _opSummary(BulkCollectionOp op, AppLocalizations l10n) => switch (op) {
        TagsOp(:final mode, :final tagIds) =>
          l10n.diveLog_bulkEdit_summary_collection('Tags', mode.name, tagIds.length),
        EquipmentOp(:final mode, :final equipmentIds) =>
          l10n.diveLog_bulkEdit_summary_collection('Equipment', mode.name, equipmentIds.length),
        BuddiesOp(:final mode, :final buddies) =>
          l10n.diveLog_bulkEdit_summary_collection('Buddies', mode.name, buddies.length),
        TanksOp(:final mode, :final tanks) =>
          l10n.diveLog_bulkEdit_summary_collection('Tanks', mode.name, tanks.length),
        WeightsOp(:final mode, :final weights) =>
          l10n.diveLog_bulkEdit_summary_collection('Weights', mode.name, weights.length),
        SightingsOp(:final mode, :final sightings) =>
          l10n.diveLog_bulkEdit_summary_collection('Sightings', mode.name, sightings.length),
      };
```

> Imports to add to `dive_edit_page.dart`: `bulk_dive_edit_provider.dart`, `bulk_edit_request.dart`, `bulk_edit_field_set.dart`, `bulk_field_gate.dart`, `bulk_collection_mode_selector.dart`, `bulk_edit_confirm_dialog.dart`, and the generated `AppLocalizations` (likely already transitively available via `l10n_extension.dart`; if `AppLocalizations` is needed as a type for `_opSummary`, import `package:submersion/l10n/arb/app_localizations.dart`).

- [ ] **Step 2: Widget test the save flow** — extend `bulk_dive_edit_form_test.dart`: pump the bulk form with 2 dive ids and an overridden `bulkDiveEditServiceProvider` (a fake capturing the `BulkEditRequest`); enable the dive-center gate, pick a center, tap Save, confirm the dialog, and assert the captured request has `diveCenterId` present and `diveIds.length == 2`. Also assert the undo SnackBar appears.
- [ ] **Step 3: Verify** `flutter analyze` clean.
- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): bulk save - build request, confirm, apply via service, undo snackbar"
```

---

## Phase 6 — Localization + final verification

### Task 14: Localize all new bulk-edit strings (11 locales)

**Files:** Modify `lib/l10n/arb/app_en.arb` + all 10 non-English ARBs; run `flutter gen-l10n`.

New keys (extend the existing `diveLog_bulkEdit_*` namespace). Reuse existing keys where they exist (`common_action_cancel`, `diveLog_bulkDelete_undo`, `diveLog_edit_section_notes/tags/rating`, the `diveLog_edit_label_*` and `diveLog_edit_row_*` already used by the normal form, `diveLog_edit_snackbar_errorSaving`). Add these NEW keys:

| key | English value |
|---|---|
| `diveLog_bulkEdit_appBarTitle` | `Edit {count} {count, plural, =1{Dive} other{Dives}}` |
| `diveLog_bulkEdit_group_logistics` | `Logistics` |
| `diveLog_bulkEdit_group_rebreather` | `Rebreather (CCR/SCR)` |
| `diveLog_bulkEdit_group_collections` | `Tags, Gear & Life` |
| `diveLog_bulkEdit_mode_add` | `Add` |
| `diveLog_bulkEdit_mode_remove` | `Remove` |
| `diveLog_bulkEdit_mode_replace` | `Replace` |
| `diveLog_bulkEdit_mode_off` | `Leave` |
| `diveLog_bulkEdit_notes_set` | `Set` |
| `diveLog_bulkEdit_notes_append` | `Append` |
| `diveLog_bulkEdit_onlyIfEmpty` | `Only dives that don't already have one` |
| `diveLog_bulkEdit_nothingSelected` | `Turn on at least one field to apply changes.` |
| `diveLog_bulkEdit_summary_fields` | `{count} {count, plural, =1{field} other{fields}}` |
| `diveLog_bulkEdit_summary_notesAppend` | `Append to notes` |
| `diveLog_bulkEdit_summary_collection` | `{name}: {mode} {count}` |
| `diveLog_bulkEdit_warn_ocWithRebreather` | `You're setting mode to Open Circuit but also changing rebreather fields.` |
| `diveLog_bulkEdit_warn_replaceTanks` | `Replacing tanks deletes existing tank pressure data on dives that have it.` |
| `diveLog_bulkEdit_applied` | `Updated {count} {count, plural, =1{dive} other{dives}}` |
| `diveLog_bulkEdit_confirm_title` | `Apply changes?` |
| `diveLog_bulkEdit_confirm_apply` | `Apply` |

- [ ] **Step 1: Add keys to `app_en.arb`** (with `@`-metadata for the placeholder strings — `count` is `int`, `name`/`mode` are `String`).
- [ ] **Step 2: Add translated values to all 10 non-English ARBs** (`app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb`). Translate, do not leave English fallbacks (project rule). A script over the ARB files (one insertion per key, modeled on the Plan-1 `add_l10n_key.py`) keeps this consistent.
- [ ] **Step 3: Regenerate** — `flutter gen-l10n`. Replace any temporary literal strings used in earlier tasks with the `context.l10n.*` getters.
- [ ] **Step 4: Verify** — `flutter analyze` clean; `flutter test test/features/dive_log/presentation/` green.
- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "i18n(dive-log): localize bulk-edit form strings in all 11 locales"
```

### Task 15: End-to-end integration test + whole-project verification

**Files:** `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart` (extend).

- [ ] **Step 1: Full round-trip widget test** — pump `DiveEditPage(bulkDiveIds: ['d1','d2'])` with a fake `bulkDiveEditServiceProvider` capturing the request; enable a scalar gate (dive center) + a notes-Append gate + a tags `Add` op; tap Save; confirm; assert the captured `BulkEditRequest` has `diveCenterId` present, `notesAppend` non-null, and a `TagsOp(add)` in `ops`, with `diveIds == ['d1','d2']`. Assert the undo SnackBar shows and tapping Undo calls the fake's `undo`.
- [ ] **Step 2: Run the bulk-edit test surface** — `flutter test test/features/dive_log/presentation/` and the Phase 2-5 unit tests.
- [ ] **Step 3: Whole-project gates** — `flutter analyze` (clean), `dart format --set-exit-if-changed .` (clean).
- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "test(dive-log): end-to-end bulk-edit form integration test"
```

---

## Self-Review (run before execution)

This plan was checked against the spec (`docs/superpowers/specs/2026-06-23-bulk-dive-editing-design.md`):
- **Spec coverage:** reuse-the-edit-form (Approach B) ✓ (Task 2 `bulkDiveIds`/`isBulk` mirrors `SiteEditPage`); per-field gate ✓ (`BulkFieldGate`, Task 4); hidden measured fields ✓ (Global Constraints + never added to the bulk path); comprehensive scalars ✓ (Phase 3 table); dive-mode cascade with rebreather fields staying reachable ✓ (Task 8); collections Add/Remove/Replace with owned-vs-reference rule + tank `onlyIfEmpty` ✓ (Phase 4); notes Set/Append ✓ (Task 11); confirm step with contradiction + destructive-replace warnings ✓ (Tasks 12-13); undo ✓ (Task 13 snackbar → `service.undo`); l10n in 11 locales ✓ (Task 14).
- **Known integration risks the implementer must verify against the live `dive_edit_page.dart`** (flagged inline, not placeholders): exact controller field names (`_gfLowController` etc.), extracting currently-inlined `DropdownButtonFormField`s from `_environmentChild`/`_weatherChild` into shared private builders (keep normal-form behavior identical), and the exact `DivesCompanion` column names. Each task says to grep/confirm before wiring.
- **Net-new shared-widget changes:** none (the deliberate design choice). New widgets are additive: `BulkFieldGate`, `BulkCollectionModeSelector`, `BulkEditConfirmDialog`, `BulkDiveEditPage`, `bulk_edit_field_set.dart`.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-23-bulk-dive-editing-form.md`.** This consumes the Plan 1 engine (PR #393) and should be executed on a branch based off (or after the merge of) that PR.

Two execution options:
1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks. Best for this UI-heavy plan where each task touches the large `dive_edit_page.dart` and benefits from a review checkpoint.
2. **Inline Execution** — work the tasks in-session with checkpoints.





