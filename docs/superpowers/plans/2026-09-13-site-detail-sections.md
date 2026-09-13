# Site Detail Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Site Details page the Dive Details display-options dropdown (Detailed/List layout, per-card show/hide and drag order, Show all, Reorder), plus a Settings page with Reset to default.

**Architecture:** Extract the page-neutral parts of the dive implementation (order helpers, the dropdown widget, the fold row) into shared code while the dive classes keep their public APIs. Add site-specific pieces: a `SiteDetailSectionId` enum and config, pair definitions, a section-list widget that assembles the page body, a menu wrapper, a Settings page, and two nullable `diver_settings` columns (schema v216).

**Tech Stack:** Flutter, Riverpod (legacy `StateNotifier` settings), Drift (SQLite), go_router, gen-l10n ARB files (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-13-site-detail-sections-design.md`

**Issue:** #1884

**Executed note:** the rung was renumbered from 216 to **218** after the plan ran, because open PR #1860 moved onto 216 and #1849 holds 217. Read every "216" below as 218.

## Global Constraints

- Never write an em-dash or an en-dash used as punctuation, and never use ` -- ` as prose punctuation, anywhere: code, comments, docs, commit messages, PR text. Rewrite with commas, colons, semicolons or parentheses.
- No mention of Claude, Claude Code or Anthropic in any commit, trailer, PR or comment. No `Co-Authored-By` trailers.
- No emojis in code, comments or docs.
- Schema rung is **216**. `minimumCompatibleSchemaVersion` stays **210**.
- Dive Details behavior must not change. Dive test files keep every assertion; the only dive test edits allowed are the `DiveSectionFold` -> `SectionFold` type rename (Task 3).
- Stage explicit paths only. Never `git add -A` or `git add .`.
- Run `dart format .` (whole project) before every commit.
- Never pipe `flutter test` or `flutter analyze` into `grep`/`tail` when you need the pass/fail result: the pipe hides the exit status.
- A Bash command containing the bare word `build` is refused by a permission rule. Run codegen through the script created in Task 1.
- The Bash tool runs zsh: `for f in $VAR` does not word-split. Use explicit paths.
- Lints that are fatal in CI: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `require_trailing_commas`, `always_use_package_imports`. `flutter analyze` must report "No issues found!".
- Commit messages: Conventional Commits (`feat(sites): ...`), body explains why, last line `Refs #1884`.
- Worktree root (all paths below are relative to it): `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/kind-bouman-871cc8`
- Scratchpad (throwaway scripts): `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-kind-bouman-871cc8/5307b5be-061e-4c1f-bf35-57ee2cb42bf9/scratchpad`

## File Map

**Create**
- `lib/core/constants/detail_section_order.dart`: generic `moveRenderedSection` / `ensureAllSections`.
- `lib/shared/widgets/section_fold.dart`: moved from `dive_log/.../dive_section_fold.dart`, renamed `SectionFold`.
- `lib/shared/widgets/section_properties_menu.dart`: `SectionPropertiesMenu`, `SectionMenuEntry`.
- `lib/core/constants/site_detail_sections.dart`: `SiteDetailSectionId`, `SiteDetailSectionConfig`.
- `lib/core/constants/site_detail_section_pairs.dart`: `SiteDetailSectionPair`, `kSiteDetailSectionPairs`, `siteDetailSectionPairFor`.
- `lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart`: `SiteDetailSectionList`.
- `lib/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart`: `SiteDetailPropertiesMenu`.
- `lib/features/settings/presentation/pages/site_detail_sections_page.dart`: `SiteDetailSectionsPage`.
- Tests: `test/core/constants/detail_section_order_test.dart`, `test/shared/widgets/section_fold_test.dart` (moved), `test/shared/widgets/section_properties_menu_test.dart`, `test/core/constants/site_detail_sections_test.dart`, `test/core/constants/site_detail_section_pairs_test.dart`, `test/core/database/migration_v216_site_detail_sections_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart`, `test/features/settings/presentation/providers/site_detail_settings_setters_test.dart`, `test/core/services/sync/sync_diver_settings_site_detail_test.dart`, `test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart`, `test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart`, `test/features/settings/presentation/pages/site_detail_sections_page_test.dart`.

**Modify**
- `lib/core/constants/dive_detail_sections.dart` (delegate to shared helpers)
- `lib/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart` (thin wrapper)
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (fold import/rename only)
- `lib/l10n/arb/app_*.arb` (11 files) and generated `lib/l10n/arb/app_localizations*.dart`
- `lib/core/database/database.dart` (two columns, v216 rung)
- `lib/features/settings/presentation/providers/settings_providers.dart`
- `lib/features/settings/data/repositories/diver_settings_repository.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- `lib/features/settings/presentation/pages/section_appearance_page.dart`
- `lib/core/router/app_router.dart`
- `test/helpers/mock_providers.dart`, `test/features/statistics/presentation/pages/records_page_test.dart` (fakes gain the site setters)
- `test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart` (type rename only)
- `test/core/database/migration_v215_plan_gas_options_test.dart` (relax the exact-version tripwire)
- `test/features/settings/presentation/pages/section_appearance_page_test.dart` (new Sites row test)

---

### Task 1: Sync the branch with main and initialize the worktree

The branch was cut from main at schema v213; main is now at v215. Rung 216 must sit on top of main's ladder.

**Files:** none edited by hand (merge only).

- [ ] **Step 1: Merge main**

```bash
git fetch origin
```

```bash
git merge origin/main --no-edit
```

Expected: a clean merge (the branch only adds docs). If there is a conflict, stop and report it.

- [ ] **Step 2: Confirm the ladder**

```bash
grep -n "static const int currentSchemaVersion = " lib/core/database/database.dart
```

Expected: `currentSchemaVersion = 215;`. If it is 216 or higher, stop: another PR took the rung, and 216 must be renumbered before continuing.

- [ ] **Step 3: Initialize submodules and packages**

```bash
git submodule update --init --recursive
```

```bash
flutter pub get
```

- [ ] **Step 4: Create the codegen script and run it**

Write `<scratchpad>/codegen.sh` with exactly:

```bash
#!/bin/bash
set -e
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/kind-bouman-871cc8
dart run build_runner build --delete-conflicting-outputs
```

Run:

```bash
bash /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-kind-bouman-871cc8/5307b5be-061e-4c1f-bf35-57ee2cb42bf9/scratchpad/codegen.sh
```

Expected: ends with `Succeeded after ...`.

- [ ] **Step 5: Baseline analyze and dive tests**

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
flutter test test/core/constants/dive_detail_sections_test.dart test/features/dive_log/presentation/widgets/dive_detail_properties_menu_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart
```

Expected: `All tests passed!`

No commit beyond the merge commit Step 1 created.

---

### Task 2: Generic section order helpers

**Files:**
- Create: `lib/core/constants/detail_section_order.dart`
- Modify: `lib/core/constants/dive_detail_sections.dart` (the `moveRenderedSection`, `ensureAllSections` and `_insertionIndex` methods)
- Test: `test/core/constants/detail_section_order_test.dart`

**Interfaces:**
- Produces:
  - `List<C> moveRenderedSection<C, T>(List<C> sections, T Function(C) idOf, List<T> rendered, int oldIndex, int newIndex)`
  - `List<C> ensureAllSections<C, T>(List<C> sections, T Function(C) idOf, List<T> allIds, C Function(T) create)`
  - Both return the input list instance unchanged when there is nothing to do.
  - Import them with a prefix (`as section_order`) inside classes that have static methods of the same names.

- [ ] **Step 1: Write the failing test**

Create `test/core/constants/detail_section_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/detail_section_order.dart';

enum _Id { a, b, c, d, e }

class _Cfg {
  const _Cfg(this.id, {this.visible = true});

  final _Id id;
  final bool visible;
}

_Id _idOf(_Cfg c) => c.id;

List<_Id> _ids(List<_Cfg> list) => [for (final c in list) c.id];

List<_Cfg> _all() => [for (final id in _Id.values) _Cfg(id)];

_Cfg _create(_Id id) => _Cfg(id);

void main() {
  group('moveRenderedSection', () {
    test('moves within a fully rendered list like a plain reorder', () {
      final result = moveRenderedSection(_all(), _idOf, _Id.values, 0, 2);
      expect(_ids(result), [_Id.b, _Id.c, _Id.a, _Id.d, _Id.e]);
    });

    test('hidden sections keep their place when one moves to the end', () {
      // b and d are not rendered; a is dropped after e.
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.a, _Id.c, _Id.e],
        0,
        2,
      );
      expect(_ids(result), [_Id.b, _Id.c, _Id.d, _Id.e, _Id.a]);
    });

    test('a drop lands immediately before the rendered section after it', () {
      // e is dropped between a and c.
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.a, _Id.c, _Id.e],
        2,
        1,
      );
      expect(_ids(result), [_Id.a, _Id.b, _Id.e, _Id.c, _Id.d]);
    });

    test('a drop at the top anchors on the new second section', () {
      final result = moveRenderedSection(
        _all(),
        _idOf,
        const [_Id.b, _Id.c, _Id.d],
        2,
        0,
      );
      expect(_ids(result), [_Id.a, _Id.d, _Id.b, _Id.c, _Id.e]);
    });

    test('equal or out-of-range indices return the same list', () {
      final sections = _all();
      expect(
        identical(moveRenderedSection(sections, _idOf, _Id.values, 1, 1), sections),
        isTrue,
      );
      expect(
        identical(
          moveRenderedSection(sections, _idOf, _Id.values, -1, 2),
          sections,
        ),
        isTrue,
      );
      expect(
        identical(moveRenderedSection(sections, _idOf, _Id.values, 0, 5), sections),
        isTrue,
      );
      expect(
        identical(moveRenderedSection(sections, _idOf, const [_Id.a], 0, 0), sections),
        isTrue,
      );
    });

    test('a rendered id missing from the saved list changes nothing', () {
      final sections = [const _Cfg(_Id.a), const _Cfg(_Id.b)];
      final result = moveRenderedSection(
        sections,
        _idOf,
        const [_Id.c, _Id.a],
        0,
        1,
      );
      expect(identical(result, sections), isTrue);
    });

    test('the moved config is carried over, not recreated', () {
      final sections = [const _Cfg(_Id.a, visible: false), const _Cfg(_Id.b)];
      final result = moveRenderedSection(
        sections,
        _idOf,
        const [_Id.a, _Id.b],
        0,
        1,
      );
      expect(_ids(result), [_Id.b, _Id.a]);
      expect(result.last.visible, isFalse);
    });
  });

  group('ensureAllSections', () {
    test('a complete list comes back as the same instance', () {
      final sections = _all();
      expect(
        identical(
          ensureAllSections(sections, _idOf, _Id.values, _create),
          sections,
        ),
        isTrue,
      );
    });

    test('a missing id lands after its nearest default-order sibling', () {
      final sections = [
        const _Cfg(_Id.e),
        const _Cfg(_Id.b),
        const _Cfg(_Id.a),
        const _Cfg(_Id.d),
      ];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      // c's nearest present predecessor in default order is b.
      expect(_ids(result), [_Id.e, _Id.b, _Id.c, _Id.a, _Id.d]);
    });

    test('a missing first id goes to the top', () {
      final sections = [
        const _Cfg(_Id.c),
        const _Cfg(_Id.b),
        const _Cfg(_Id.d),
        const _Cfg(_Id.e),
      ];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      expect(_ids(result), [_Id.a, _Id.c, _Id.b, _Id.d, _Id.e]);
    });

    test('several missing ids chain behind one another', () {
      final sections = [const _Cfg(_Id.a), const _Cfg(_Id.e)];
      final result = ensureAllSections(sections, _idOf, _Id.values, _create);
      expect(_ids(result), [_Id.a, _Id.b, _Id.c, _Id.d, _Id.e]);
    });

    test('inserted sections come from create', () {
      final result = ensureAllSections(
        [const _Cfg(_Id.a)],
        _idOf,
        _Id.values,
        (id) => _Cfg(id, visible: false),
      );
      expect(result.first.visible, isTrue);
      expect(result.skip(1).every((c) => !c.visible), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/core/constants/detail_section_order_test.dart
```

Expected: FAIL, `detail_section_order.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/constants/detail_section_order.dart`:

```dart
/// Order helpers shared by every detail page whose sections the diver can
/// hide and reorder (Dive Details, Site Details).
///
/// A page stores its sections as a list of configs, one per section id, in
/// the diver's order. These functions see a config only through `idOf`, so
/// they work for any page's config type.
library;

/// [sections] reordered as if [rendered] had its [oldIndex] entry dropped at
/// [newIndex].
///
/// A page renders only the sections that are visible and have content, so a
/// drop index in that subset is not an index into the saved list. The moved
/// section is re-anchored next to the rendered neighbour it was dropped
/// against, which leaves every section outside [rendered] (hidden ones
/// included) where the diver left it.
///
/// Indices follow `ReorderableListView.onReorderItem`: [newIndex] is the
/// final resting index, already adjusted for the removal. Returns
/// [sections] itself when the move is a no-op or out of range.
List<C> moveRenderedSection<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> rendered,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex == newIndex ||
      rendered.length < 2 ||
      oldIndex < 0 ||
      oldIndex >= rendered.length ||
      newIndex < 0 ||
      newIndex >= rendered.length) {
    return sections;
  }

  final movedId = rendered[oldIndex];
  final movedAt = sections.indexWhere((s) => idOf(s) == movedId);
  if (movedAt < 0) return sections;
  final config = sections[movedAt];

  final reordered = List.of(rendered)..removeAt(oldIndex);
  reordered.insert(newIndex, movedId);

  final result = List.of(sections)..removeAt(movedAt);

  // Anchor on the rendered section that now follows the moved one, so it
  // lands immediately before it; at the end of the list, anchor on the one
  // it now follows instead.
  final followingId = newIndex + 1 < reordered.length
      ? reordered[newIndex + 1]
      : null;
  if (followingId != null) {
    final at = result.indexWhere((s) => idOf(s) == followingId);
    if (at >= 0) {
      result.insert(at, config);
      return result;
    }
  }
  final precedingId = newIndex > 0 ? reordered[newIndex - 1] : null;
  if (precedingId != null) {
    final at = result.indexWhere((s) => idOf(s) == precedingId);
    if (at >= 0) {
      result.insert(at + 1, config);
      return result;
    }
  }
  result.insert(0, config);
  return result;
}

/// [sections] with a config from [create] added for every id in [allIds]
/// that it lacks.
///
/// A section added in a later release must not land at the bottom of an
/// order saved before it existed. Each missing id is instead inserted just
/// after its nearest preceding sibling in [allIds] (the default order), or
/// at the top when none of them is present. Returns [sections] itself when
/// nothing is missing.
List<C> ensureAllSections<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> allIds,
  C Function(T) create,
) {
  final presentIds = sections.map(idOf).toSet();
  if (allIds.every(presentIds.contains)) return sections;

  final result = List.of(sections);
  for (var i = 0; i < allIds.length; i++) {
    final id = allIds[i];
    if (presentIds.contains(id)) continue;
    result.insert(_insertionIndex(result, idOf, allIds, i), create(id));
    presentIds.add(id);
  }
  return result;
}

/// Where the id at [defaultIndex] of [allIds] belongs in [sections], by
/// default-order adjacency.
int _insertionIndex<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> allIds,
  int defaultIndex,
) {
  for (var i = defaultIndex - 1; i >= 0; i--) {
    final position = sections.indexWhere((s) => idOf(s) == allIds[i]);
    if (position >= 0) return position + 1;
  }
  return 0;
}
```

- [ ] **Step 4: Run the new test**

```bash
flutter test test/core/constants/detail_section_order_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Make the dive config delegate**

In `lib/core/constants/dive_detail_sections.dart`, add after `import 'package:flutter/material.dart';`:

```dart

import 'package:submersion/core/constants/detail_section_order.dart'
    as section_order;
```

Replace the whole body of `static List<DiveDetailSectionConfig> moveRenderedSection(...)` (keep its doc comment and signature) so the method reads:

```dart
  static List<DiveDetailSectionConfig> moveRenderedSection(
    List<DiveDetailSectionConfig> sections,
    List<DiveDetailSectionId> rendered,
    int oldIndex,
    int newIndex,
  ) => section_order
      .moveRenderedSection<DiveDetailSectionConfig, DiveDetailSectionId>(
        sections,
        (s) => s.id,
        rendered,
        oldIndex,
        newIndex,
      );
```

Replace the `ensureAllSections` method body (keep its doc comment) and delete the `_insertionIndex` method below it, so the end of the class reads:

```dart
  static List<DiveDetailSectionConfig> ensureAllSections(
    List<DiveDetailSectionConfig> sections,
  ) => section_order
      .ensureAllSections<DiveDetailSectionConfig, DiveDetailSectionId>(
        sections,
        (s) => s.id,
        DiveDetailSectionId.values,
        (id) => DiveDetailSectionConfig(id: id, visible: true),
      );
}
```

- [ ] **Step 6: Run the dive tests unchanged**

```bash
flutter test test/core/constants/detail_section_order_test.dart test/core/constants/dive_detail_sections_test.dart test/core/constants/dive_detail_sections_surface_gps_test.dart test/features/dive_log/presentation/widgets/dive_detail_properties_menu_test.dart test/features/settings/data/repositories/diver_settings_repository_dive_detail_layout_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/core/constants/detail_section_order.dart lib/core/constants/dive_detail_sections.dart test/core/constants/detail_section_order_test.dart
```

```bash
git commit -m "refactor(dive-log): share the section order helpers" -m "moveRenderedSection and ensureAllSections only compare ids and positions, so they move to generic top-level functions that any detail page can use. DiveDetailSectionConfig keeps its static methods and delegates; the legacy decoO2 expansion stays in the dive class." -m "Refs #1884"
```

---

### Task 3: Move the fold row to shared code as `SectionFold`

A pure move and rename; no behavior change, so the existing tests are the check.

**Files:**
- Move: `lib/features/dive_log/presentation/widgets/dive_section_fold.dart` -> `lib/shared/widgets/section_fold.dart`
- Move: `test/features/dive_log/presentation/widgets/dive_section_fold_test.dart` -> `test/shared/widgets/section_fold_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (one import, one constructor call)
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart` (import and type references only)

**Interfaces:**
- Produces: `SectionFold({Key? key, required String title, required IconData icon, required bool isExpanded, required ValueChanged<bool> onToggle, required WidgetBuilder contentBuilder})` in `package:submersion/shared/widgets/section_fold.dart`. Same constructor as `DiveSectionFold` had.

- [ ] **Step 1: Move the files**

```bash
mkdir -p test/shared/widgets
```

```bash
git mv lib/features/dive_log/presentation/widgets/dive_section_fold.dart lib/shared/widgets/section_fold.dart
```

```bash
git mv test/features/dive_log/presentation/widgets/dive_section_fold_test.dart test/shared/widgets/section_fold_test.dart
```

- [ ] **Step 2: Rename the class and the import path everywhere it appears**

`perl -pi` keeps each file's existing line endings (some files in this repo are CRLF).

```bash
perl -pi -e 's/\bDiveSectionFold\b/SectionFold/g; s#package:submersion/features/dive_log/presentation/widgets/dive_section_fold\.dart#package:submersion/shared/widgets/section_fold.dart#g' lib/shared/widgets/section_fold.dart test/shared/widgets/section_fold_test.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart
```

```bash
grep -rn "DiveSectionFold\|dive_section_fold" lib test
```

Expected: no output.

- [ ] **Step 3: Update the class doc comment**

In `lib/shared/widgets/section_fold.dart`, replace the line

```dart
/// One folded section row in the dive detail page's list layout.
```

with

```dart
/// One folded section row in a detail page's list layout (Dive Details and
/// Site Details).
```

Leave the rest of the file unchanged. The fold's `ValueKey('diveSectionFold_...')` in `dive_detail_page.dart` is a key string, not the type; leave it alone.

- [ ] **Step 4: Run the affected tests**

```bash
flutter test test/shared/widgets/section_fold_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/shared/widgets/section_fold.dart lib/features/dive_log/presentation/widgets/dive_section_fold.dart test/shared/widgets/section_fold_test.dart test/features/dive_log/presentation/widgets/dive_section_fold_test.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart
```

```bash
git commit -m "refactor(dive-log): move the fold row to shared widgets" -m "DiveSectionFold takes a title, an icon and a content builder and knows nothing about dives. It becomes SectionFold under lib/shared/widgets so the Site Details list layout can use it too. Type rename only; no behavior change." -m "Refs #1884"
```

---

### Task 4: Shared `SectionPropertiesMenu`; dive menu becomes a wrapper

**Files:**
- Create: `lib/shared/widgets/section_properties_menu.dart`
- Modify (rewrite): `lib/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart`
- Test: `test/shared/widgets/section_properties_menu_test.dart`
- Regression: `test/features/dive_log/presentation/widgets/dive_detail_properties_menu_test.dart` (must pass unedited)

**Interfaces:**
- Produces:
  - `SectionMenuEntry({required Object id, required String label, required IconData icon, required bool visible})`
  - `SectionPropertiesMenu({Key? key, required DiveDetailLayout layout, required ValueChanged<DiveDetailLayout> onLayoutChanged, required List<SectionMenuEntry> entries, required ValueChanged<int> onToggle, required void Function(int oldIndex, int newIndex) onReorder, required VoidCallback onShowAll, required VoidCallback onOpenSettings, double? iconSize})`
  - `onToggle` and `onReorder` report indices into `entries`. Show all is disabled by the menu itself while every entry is visible.
- `DiveDetailPropertiesMenu({Key? key, required bool isGauge})` keeps its constructor.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/section_properties_menu_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

enum _Id { alpha, bravo, charlie }

class _Calls {
  final layouts = <DiveDetailLayout>[];
  final toggles = <int>[];
  final reorders = <(int, int)>[];
  int showAll = 0;
  int openSettings = 0;
}

Widget _harness(
  _Calls calls, {
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  List<bool> visible = const [true, true, true],
  double? iconSize,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        actions: [
          SectionPropertiesMenu(
            layout: layout,
            onLayoutChanged: calls.layouts.add,
            entries: [
              for (final id in _Id.values)
                SectionMenuEntry(
                  id: id,
                  label: id.name,
                  icon: Icons.label_outline,
                  visible: visible[id.index],
                ),
            ],
            onToggle: calls.toggles.add,
            onReorder: (oldIndex, newIndex) =>
                calls.reorders.add((oldIndex, newIndex)),
            onShowAll: () => calls.showAll++,
            onOpenSettings: () => calls.openSettings++,
            iconSize: iconSize,
          ),
        ],
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

MenuItemButton _button(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(
      find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton)),
    );

void main() {
  Future<void> sized(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('lists both layouts and checks the current one', (
    tester,
  ) async {
    await sized(tester);
    await tester.pumpWidget(
      _harness(_Calls(), layout: DiveDetailLayout.list),
    );
    await _open(tester);

    expect(find.text('Detailed'), findsOneWidget);
    expect(
      (_button(tester, 'List').leadingIcon as Icon?)!.icon,
      Icons.radio_button_checked,
    );
    expect(
      (_button(tester, 'Detailed').leadingIcon as Icon?)!.icon,
      Icons.radio_button_unchecked,
    );
  });

  testWidgets('choosing a layout reports it and keeps the menu open', (
    tester,
  ) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(calls.layouts, [DiveDetailLayout.list]);
    expect(find.text('Detailed'), findsOneWidget);
  });

  testWidgets('tapping a section reports its index and keeps the menu open', (
    tester,
  ) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('bravo'));
    await tester.pumpAndSettle();

    expect(calls.toggles, [1]);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('a hidden section shows an empty checkbox', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      _harness(_Calls(), visible: const [true, false, true]),
    );
    await _open(tester);

    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
  });

  testWidgets('show all is disabled while every section is visible', (
    tester,
  ) async {
    await sized(tester);
    await tester.pumpWidget(_harness(_Calls()));
    await _open(tester);

    expect(_button(tester, 'Show all sections').onPressed, isNull);
  });

  testWidgets('show all reports when a section is hidden', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(
      _harness(calls, visible: const [true, false, true]),
    );
    await _open(tester);

    await tester.tap(find.text('Show all sections'));
    await tester.pumpAndSettle();

    expect(calls.showAll, 1);
  });

  testWidgets('a drop reports the list indices', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 2);
    await tester.pumpAndSettle();

    expect(calls.reorders, [(0, 2)]);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('the reorder item opens settings', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('Reorder sections...'));
    await tester.pumpAndSettle();

    expect(calls.openSettings, 1);
  });

  testWidgets('iconSize sizes the tune icon', (tester) async {
    await sized(tester);
    await tester.pumpWidget(_harness(_Calls(), iconSize: 20));

    expect(tester.widget<Icon>(find.byIcon(Icons.tune)).size, 20);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/shared/widgets/section_properties_menu_test.dart
```

Expected: FAIL, `section_properties_menu.dart` does not exist.

- [ ] **Step 3: Write the shared menu**

Create `lib/shared/widgets/section_properties_menu.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width of the section list, and so of the menu: wide enough for the longest
/// section name beside its checkbox, icon and drag handle.
const double _kSectionListWidth = 340;

/// Height of one section row.
const double _kSectionRowHeight = 48;

/// Rows the section list shows before it scrolls.
const int _kVisibleSectionRows = 6;

/// One section as a [SectionPropertiesMenu] lists it.
class SectionMenuEntry {
  const SectionMenuEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.visible,
  });

  /// Identifies the row across rebuilds and reorders (a section id enum).
  final Object id;

  /// The section's localized name.
  final String label;

  /// The section's icon, shown trailing the name.
  final IconData icon;

  /// Whether the section is switched on.
  final bool visible;
}

/// A detail page's display-options dropdown: its layout, which sections
/// show, and in what order.
///
/// Shared by Dive Details and Site Details. It holds no settings of its own:
/// each page's wrapper decides which sections to offer and where each choice
/// is written, so the two pages store their configurations separately while
/// presenting them identically.
///
/// Sections are reordered by their drag handles right here, which keeps a
/// page's own section rows down to a single tap target each. The last item
/// opens the page's settings screen for the same list with more room, and
/// its reset to the default order.
class SectionPropertiesMenu extends StatelessWidget {
  const SectionPropertiesMenu({
    super.key,
    required this.layout,
    required this.onLayoutChanged,
    required this.entries,
    required this.onToggle,
    required this.onReorder,
    required this.onShowAll,
    required this.onOpenSettings,
    this.iconSize,
  });

  /// The page's current layout, shown as the checked radio item.
  final DiveDetailLayout layout;

  final ValueChanged<DiveDetailLayout> onLayoutChanged;

  /// The sections offered, in the diver's order.
  final List<SectionMenuEntry> entries;

  /// Called with the index in [entries] of the section tapped.
  final ValueChanged<int> onToggle;

  /// Called with indices into [entries], as
  /// [ReorderableListView.onReorderItem] reports them.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Turns every offered section on. The item is disabled while every entry
  /// is already visible.
  final VoidCallback onShowAll;

  /// Opens the page's section settings screen.
  final VoidCallback onOpenSettings;

  /// Size of the tune icon; null keeps the [IconButton] default. The
  /// embedded master-detail headers use a smaller icon.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(_kSectionListWidth, 640)),
      ),
      menuChildren: [
        _MenuHeading(l10n.diveLog_detail_displayOptions_layout),
        for (final option in DiveDetailLayout.values)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              option == layout
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onPressed: () => onLayoutChanged(option),
            child: Text(option.localizedName(l10n)),
          ),
        const Divider(height: 8),
        _MenuHeading(l10n.diveLog_detail_displayOptions_sections),
        // A fixed box rather than a shrink-wrapped list: the menu panel sizes
        // itself to its children's intrinsic width, which a scrollable cannot
        // report, and a list that scrolls on its own can auto-scroll while a
        // row is dragged past its edge.
        SizedBox(
          width: _kSectionListWidth,
          height:
              math.min(entries.length, _kVisibleSectionRows) *
              _kSectionRowHeight,
          child: ReorderableListView.builder(
            // The menu panel's own scroll view holds the primary controller;
            // a second vertical list must not attach to it too.
            primary: false,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemExtent: _kSectionRowHeight,
            itemCount: entries.length,
            itemBuilder: (context, index) => _SectionRow(
              key: ValueKey<Object>(entries[index].id),
              entry: entries[index],
              index: index,
              onToggle: () => onToggle(index),
            ),
            onReorderItem: onReorder,
          ),
        ),
        const Divider(height: 8),
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: const Icon(Icons.checklist),
          onPressed: entries.every((e) => e.visible) ? null : onShowAll,
          child: Text(l10n.diveLog_detail_displayOptions_showAll),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.reorder),
          onPressed: onOpenSettings,
          child: Text(l10n.diveLog_detail_displayOptions_reorder),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: Icon(Icons.tune, size: iconSize),
        tooltip: l10n.diveLog_detail_displayOptions_tooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// One section's row: its visibility toggle with a drag handle alongside.
///
/// The handle sits outside the button so grabbing it never competes with the
/// tap that toggles the section; a missed grab must not flip visibility.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.entry,
    required this.index,
    required this.onToggle,
  });

  final SectionMenuEntry entry;

  /// This row's index in the enclosing [ReorderableListView].
  final int index;

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              entry.visible ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            trailingIcon: Icon(entry.icon, size: 18),
            onPressed: onToggle,
            child: Text(entry.label),
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A non-interactive group label between runs of menu items.
class _MenuHeading extends StatelessWidget {
  const _MenuHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the new test**

```bash
flutter test test/shared/widgets/section_properties_menu_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Rewrite the dive menu as a wrapper**

Replace the entire contents of `lib/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

/// The dive detail page's display-options dropdown.
///
/// Puts the page-shape choices where the page is (which sections show, in
/// what order, and how much room each one gets) instead of only under
/// Settings. All of them write to the same per-diver settings the Settings
/// page edits, so a choice made here is the choice made there.
///
/// The menu itself is the shared [SectionPropertiesMenu]; this wrapper
/// decides which sections a dive offers and where each choice is written.
class DiveDetailPropertiesMenu extends ConsumerWidget {
  const DiveDetailPropertiesMenu({super.key, required this.isGauge});

  /// Whether the dive is a gauge (bottom-timer) dive.
  ///
  /// Gauge dives never render the gas and decompression sections, so their
  /// toggles are left out rather than shown switched on with nothing behind
  /// them.
  final bool isGauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );
    final offered = [
      for (final section in sections)
        if (!(isGauge && section.id.hiddenInGaugeMode)) section,
    ];

    return SectionPropertiesMenu(
      layout: layout,
      onLayoutChanged: (option) =>
          ref.read(settingsProvider.notifier).setDiveDetailLayout(option),
      entries: [
        for (final section in offered)
          SectionMenuEntry(
            id: section.id,
            label: section.id.localizedDisplayName(l10n),
            icon: section.id.icon,
            visible: section.visible,
          ),
      ],
      onToggle: (index) => _toggle(ref, sections, offered[index]),
      onReorder: (oldIndex, newIndex) => ref
          .read(settingsProvider.notifier)
          .setDiveDetailSections(
            DiveDetailSectionConfig.moveRenderedSection(
              sections,
              [for (final section in offered) section.id],
              oldIndex,
              newIndex,
            ),
          ),
      onShowAll: () => _showAll(ref, sections, offered),
      onOpenSettings: () => context.pushNamed('diveDetailSections'),
    );
  }

  void _toggle(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    DiveDetailSectionConfig section,
  ) {
    final updated = [
      for (final s in sections)
        if (s.id == section.id) s.copyWith(visible: !s.visible) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }

  /// Turns every offered section back on, leaving the diver's order alone.
  ///
  /// Deliberately not `resetDiveDetailSections`, which would also throw away
  /// a custom order the diver never asked to undo. Only the sections the menu
  /// lists are touched: on a gauge dive the gas and deco sections are not
  /// shown here, so switching them on would be a change the diver could
  /// neither see nor expect, surfacing only on their next non-gauge dive.
  void _showAll(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    List<DiveDetailSectionConfig> offered,
  ) {
    final offeredIds = {for (final s in offered) s.id};
    final updated = [
      for (final s in sections)
        if (offeredIds.contains(s.id)) s.copyWith(visible: true) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }
}
```

- [ ] **Step 6: Run the dive regression tests unedited**

```bash
flutter test test/shared/widgets/section_properties_menu_test.dart test/features/dive_log/presentation/widgets/dive_detail_properties_menu_test.dart test/features/dive_log/presentation/pages/dive_detail_page_section_config_test.dart test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart
```

Expected: `All tests passed!` If a dive test fails, fix the shared widget, never the dive test.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/shared/widgets/section_properties_menu.dart lib/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart test/shared/widgets/section_properties_menu_test.dart
```

```bash
git commit -m "refactor(dive-log): extract the display-options menu widget" -m "SectionPropertiesMenu renders the layout radios, the checkbox and drag-handle section list, Show all and Reorder from plain entries and callbacks. DiveDetailPropertiesMenu keeps its constructor and becomes a wrapper that applies the gauge filter and writes to the dive settings, so Site Details can reuse the same menu with its own settings." -m "Refs #1884"
```

---

### Task 5: Strings for the site cards and settings (11 locales)

Card names reuse the keys the cards already use for their titles; only the Map card needs a name key. Menu labels reuse the dive keys (identical text). New keys: 19.

**Files:**
- Modify: `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Throwaway: `<scratchpad>/add_site_detail_l10n.py` (not committed)

**Interfaces:**
- Produces these `AppLocalizations` getters: `siteDetailSection_map_name`, `siteDetailSection_<id>_description` for each id in `map, diveStatistics, description, location, depth, altitude, features, tide, reefHealth, marineLife, media, difficulty, rating, hazards, access, notes`, `settings_siteDetailSections_title`, `settings_appearance_header_siteDetails`.

- [ ] **Step 1: Write the insertion script**

Create `<scratchpad>/add_site_detail_l10n.py`. It inserts the block right after the `diveDetailSection_dataSources_description` line of each file (present in all 11), keeps each file's line endings, escapes values as JSON, and skips keys already present so it is safe to re-run.

```python
import json
import os
import sys

ROOT = "/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/kind-bouman-871cc8/lib/l10n/arb"
ANCHOR = '"diveDetailSection_dataSources_description":'

KEYS = [
    "siteDetailSection_map_name",
    "siteDetailSection_map_description",
    "siteDetailSection_diveStatistics_description",
    "siteDetailSection_description_description",
    "siteDetailSection_location_description",
    "siteDetailSection_depth_description",
    "siteDetailSection_altitude_description",
    "siteDetailSection_features_description",
    "siteDetailSection_tide_description",
    "siteDetailSection_reefHealth_description",
    "siteDetailSection_marineLife_description",
    "siteDetailSection_media_description",
    "siteDetailSection_difficulty_description",
    "siteDetailSection_rating_description",
    "siteDetailSection_hazards_description",
    "siteDetailSection_access_description",
    "siteDetailSection_notes_description",
    "settings_siteDetailSections_title",
    "settings_appearance_header_siteDetails",
]

VALUES = {
    "en": [
        "Map",
        "Map preview of the site location",
        "Dive count, depths reached, longest and latest dives",
        "Your description of the site",
        "Country, region, body of water, GPS coordinates",
        "Rated depth range and depths reached on dives",
        "Altitude and altitude dive category",
        "Features marked on the site map",
        "Tide cycle graph and timing",
        "Satellite water conditions at the site",
        "Species seen at this site",
        "Photos, videos and documents for the site",
        "Difficulty level of the site",
        "Your rating of the site",
        "Hazards and safety notes",
        "Entry and exit, parking, mooring, access notes",
        "Your notes about the site",
        "Site Detail Sections",
        "Site Details",
    ],
    "de": [
        "Karte",
        "Kartenvorschau des Tauchplatzes",
        "Anzahl der Tauchgänge, erreichte Tiefen, längster und letzter Tauchgang",
        "Beschreibung des Tauchplatzes",
        "Land, Region, Gewässer, GPS-Koordinaten",
        "Angegebener Tiefenbereich und bei Tauchgängen erreichte Tiefen",
        "Höhenlage und Kategorie des Höhentauchgangs",
        "Auf der Tauchplatzkarte markierte Merkmale",
        "Gezeitenzyklusdiagramm und Zeiten",
        "Satellitengestützte Wasserbedingungen am Tauchplatz",
        "An diesem Tauchplatz gesichtete Arten",
        "Fotos, Videos und Dokumente zum Tauchplatz",
        "Schwierigkeitsgrad des Tauchplatzes",
        "Bewertung des Tauchplatzes",
        "Gefahren und Sicherheitshinweise",
        "Ein- und Ausstieg, Parken, Boje, Zugangshinweise",
        "Notizen zum Tauchplatz",
        "Tauchplatz-Detailabschnitte",
        "Tauchplatz-Details",
    ],
    "es": [
        "Mapa",
        "Vista previa del mapa de la ubicación del sitio",
        "Número de inmersiones, profundidades alcanzadas, inmersiones más largas y más recientes",
        "Descripción del sitio",
        "País, región, masa de agua, coordenadas GPS",
        "Rango de profundidad indicado y profundidades alcanzadas en las inmersiones",
        "Altitud y categoría de inmersión en altitud",
        "Características marcadas en el mapa del sitio",
        "Gráfico del ciclo de mareas y horarios",
        "Condiciones del agua por satélite en el sitio",
        "Especies vistas en este sitio",
        "Fotos, vídeos y documentos del sitio",
        "Nivel de dificultad del sitio",
        "Tu calificación del sitio",
        "Peligros y notas de seguridad",
        "Entrada y salida, aparcamiento, amarre, notas de acceso",
        "Tus notas sobre el sitio",
        "Secciones del detalle del sitio",
        "Detalles del sitio",
    ],
    "fr": [
        "Carte",
        "Aperçu cartographique de l'emplacement du site",
        "Nombre de plongées, profondeurs atteintes, plongées les plus longues et les plus récentes",
        "Description du site",
        "Pays, région, plan d'eau, coordonnées GPS",
        "Plage de profondeur indiquée et profondeurs atteintes en plongée",
        "Altitude et catégorie de plongée en altitude",
        "Éléments marqués sur la carte du site",
        "Graphique du cycle de marée et horaires",
        "Conditions de l'eau par satellite sur le site",
        "Espèces observées sur ce site",
        "Photos, vidéos et documents du site",
        "Niveau de difficulté du site",
        "Votre évaluation du site",
        "Dangers et consignes de sécurité",
        "Mise à l'eau et sortie, stationnement, mouillage, notes d'accès",
        "Vos notes sur le site",
        "Sections du détail du site",
        "Détails du site",
    ],
    "it": [
        "Mappa",
        "Anteprima della mappa della posizione del sito",
        "Numero di immersioni, profondità raggiunte, immersioni più lunghe e più recenti",
        "Descrizione del sito",
        "Paese, regione, specchio d'acqua, coordinate GPS",
        "Intervallo di profondità indicato e profondità raggiunte nelle immersioni",
        "Altitudine e categoria di immersione in quota",
        "Elementi segnati sulla mappa del sito",
        "Grafico ciclo marea e tempi",
        "Condizioni dell'acqua da satellite presso il sito",
        "Specie avvistate in questo sito",
        "Foto, video e documenti del sito",
        "Livello di difficoltà del sito",
        "La tua valutazione del sito",
        "Pericoli e note di sicurezza",
        "Entrata e uscita, parcheggio, ormeggio, note di accesso",
        "Le tue note sul sito",
        "Sezioni del dettaglio sito",
        "Dettagli sito",
    ],
    "nl": [
        "Kaart",
        "Kaartvoorbeeld van de duikstek",
        "Aantal duiken, bereikte diepten, langste en laatste duiken",
        "Beschrijving van de duikstek",
        "Land, regio, wateroppervlak, GPS-coördinaten",
        "Opgegeven dieptebereik en bij duiken bereikte diepten",
        "Hoogte en categorie hoogteduik",
        "Kenmerken gemarkeerd op de kaart van de duikstek",
        "Getijdecyclusgrafiek en timing",
        "Satellietwateromstandigheden bij de duikstek",
        "Soorten gezien bij deze duikstek",
        "Foto's, video's en documenten van de duikstek",
        "Moeilijkheidsgraad van de duikstek",
        "Jouw beoordeling van de duikstek",
        "Gevaren en veiligheidsnotities",
        "In- en uitstap, parkeren, meerboei, toegangsnotities",
        "Jouw notities over de duikstek",
        "Secties duikstekdetails",
        "Duikstekdetails",
    ],
    "pt": [
        "Mapa",
        "Pré-visualização do mapa da localização do ponto",
        "Número de mergulhos, profundidades alcançadas, mergulhos mais longos e mais recentes",
        "Descrição do ponto",
        "País, região, corpo de água, coordenadas GPS",
        "Faixa de profundidade indicada e profundidades alcançadas nos mergulhos",
        "Altitude e categoria de mergulho em altitude",
        "Elementos marcados no mapa do ponto",
        "Gráfico do ciclo de maré e horários",
        "Condições da água por satélite no ponto",
        "Espécies vistas neste ponto",
        "Fotos, vídeos e documentos do ponto",
        "Nível de dificuldade do ponto",
        "Sua avaliação do ponto",
        "Perigos e notas de segurança",
        "Entrada e saída, estacionamento, amarração, notas de acesso",
        "Suas observações sobre o ponto",
        "Seções de detalhes do ponto",
        "Detalhes do Ponto",
    ],
    "hu": [
        "Térkép",
        "A merülőhely helyének térképes előnézete",
        "Merülések száma, elért mélységek, leghosszabb és legutóbbi merülések",
        "A merülőhely leírása",
        "Ország, régió, víztest, GPS-koordináták",
        "Megadott mélységtartomány és a merüléseken elért mélységek",
        "Tengerszint feletti magasság és magashegyi merülési kategória",
        "A merülőhely térképén jelölt jellemzők",
        "Árapály-ciklus grafikon és időzítés",
        "Műholdas vízviszonyok a merülőhelyen",
        "Ezen a merülőhelyen látott fajok",
        "A merülőhely fotói, videói és dokumentumai",
        "A merülőhely nehézségi szintje",
        "A merülőhely értékelése",
        "Veszélyek és biztonsági megjegyzések",
        "Be- és kiszállás, parkolás, kikötés, megközelítési megjegyzések",
        "Megjegyzések a merülőhelyről",
        "Merülőhely-részletek szekciói",
        "Merülőhely részletei",
    ],
    "he": [
        "מפה",
        "תצוגה מקדימה של מפת מיקום האתר",
        "מספר צלילות, עומקים שהושגו, הצלילות הארוכות והאחרונות",
        "תיאור האתר",
        "מדינה, אזור, מקווה מים, קואורדינטות GPS",
        "טווח עומק מדורג ועומקים שהושגו בצלילות",
        "גובה וקטגוריית צלילת גובה",
        "מאפיינים שסומנו במפת האתר",
        "גרף מחזור גאות ושפל וזמן",
        "תנאי מים לווייניים באתר",
        "מינים שנצפו באתר זה",
        "תמונות, סרטונים ומסמכים של האתר",
        "רמת הקושי של האתר",
        "הדירוג שלך לאתר",
        "סכנות והערות בטיחות",
        "כניסה ויציאה, חניה, עגינה, הערות גישה",
        "ההערות שלך על האתר",
        "סעיפי פרטי האתר",
        "פרטי האתר",
    ],
    "ar": [
        "الخريطة",
        "معاينة خريطة لموقع الغوص",
        "عدد الغوصات، الأعماق التي تم بلوغها، أطول الغوصات وأحدثها",
        "وصف الموقع",
        "الدولة، المنطقة، المسطح المائي، إحداثيات GPS",
        "نطاق العمق المصنف والأعماق التي تم بلوغها في الغوصات",
        "الارتفاع وفئة الغوص على ارتفاع",
        "المعالم المحددة على خريطة الموقع",
        "رسم بياني لدورة المد والجزر والتوقيت",
        "أحوال المياه عبر الأقمار الصناعية في الموقع",
        "الأنواع التي شوهدت في هذا الموقع",
        "صور ومقاطع فيديو ومستندات الموقع",
        "مستوى صعوبة الموقع",
        "تقييمك للموقع",
        "المخاطر وملاحظات السلامة",
        "الدخول والخروج، مواقف السيارات، الرسو، ملاحظات الوصول",
        "ملاحظاتك عن الموقع",
        "أقسام تفاصيل الموقع",
        "تفاصيل الموقع",
    ],
    "zh": [
        "地图",
        "潜水点位置的地图预览",
        "潜水次数、到达深度、最长和最近的潜水",
        "潜水点描述",
        "国家、地区、水域、GPS 坐标",
        "标注深度范围及潜水实际到达深度",
        "海拔及高海拔潜水类别",
        "在潜水点地图上标记的特征",
        "潮汐周期图和时间",
        "潜水点的卫星水况",
        "在此潜水点见到的物种",
        "潜水点的照片、视频和文档",
        "潜水点难度等级",
        "你对潜水点的评分",
        "危险与安全须知",
        "入水与出水、停车、系泊、到达说明",
        "你对潜水点的备注",
        "潜水点详情区块",
        "潜水点详情",
    ],
}


def main():
    for locale, values in VALUES.items():
        if len(values) != len(KEYS):
            sys.exit(f"{locale}: {len(values)} values for {len(KEYS)} keys")
        path = os.path.join(ROOT, f"app_{locale}.arb")
        with open(path, encoding="utf-8", newline="") as f:
            lines = f.readlines()
        text = "".join(lines)
        anchor = next(i for i, line in enumerate(lines) if ANCHOR in line)
        eol = "\r\n" if lines[anchor].endswith("\r\n") else "\n"
        if not lines[anchor].rstrip("\r\n").endswith(","):
            sys.exit(f"{locale}: anchor line has no trailing comma")
        block = [
            f'  "{key}": {json.dumps(value, ensure_ascii=False)},{eol}'
            for key, value in zip(KEYS, values)
            if f'"{key}":' not in text
        ]
        lines[anchor + 1:anchor + 1] = block
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.writelines(lines)
        print(f"{locale}: inserted {len(block)}")


main()
```

- [ ] **Step 2: Run it**

```bash
python3 /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-kind-bouman-871cc8/5307b5be-061e-4c1f-bf35-57ee2cb42bf9/scratchpad/add_site_detail_l10n.py
```

Expected: 11 lines, each `<locale>: inserted 19`.

- [ ] **Step 3: Regenerate and check**

```bash
flutter gen-l10n
```

```bash
git diff --numstat lib/l10n/arb/*.arb
```

Expected: each ARB shows `19  0` (19 added, 0 removed; nonzero removals mean line endings were rewritten, so stop).

```bash
grep -c "siteDetailSection_map_name" lib/l10n/arb/app_localizations_en.dart
```

Expected: `1` or more.

```bash
flutter test test/l10n/arb_parity_test.dart test/l10n/localization_test.dart test/l10n/german_sac_terminology_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_en.dart lib/l10n/arb/app_localizations_ar.dart lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_es.dart lib/l10n/arb/app_localizations_fr.dart lib/l10n/arb/app_localizations_he.dart lib/l10n/arb/app_localizations_hu.dart lib/l10n/arb/app_localizations_it.dart lib/l10n/arb/app_localizations_nl.dart lib/l10n/arb/app_localizations_pt.dart lib/l10n/arb/app_localizations_zh.dart
```

```bash
git commit -m "feat(sites): strings for configurable site detail cards" -m "A name for the Map card, one-line descriptions for all sixteen cards, the Site Detail Sections settings title and a Site Details header, in all eleven locales. The other card names reuse the titles the cards already show, so the menu and the page agree." -m "Refs #1884"
```

---

### Task 6: `SiteDetailSectionId`, `SiteDetailSectionConfig` and the pairs

**Files:**
- Create: `lib/core/constants/site_detail_sections.dart`
- Create: `lib/core/constants/site_detail_section_pairs.dart`
- Test: `test/core/constants/site_detail_sections_test.dart`
- Test: `test/core/constants/site_detail_section_pairs_test.dart`

**Interfaces:**
- Consumes: `section_order.moveRenderedSection` / `section_order.ensureAllSections` (Task 2); l10n getters (Task 5).
- Produces:
  - `enum SiteDetailSectionId { map, diveStatistics, description, location, depth, altitude, features, tide, reefHealth, marineLife, media, difficulty, rating, hazards, access, notes }` with `IconData get icon`, `String localizedDisplayName(AppLocalizations l10n)`, `String localizedDescription(AppLocalizations l10n)`. (No English-fallback getters: a value is named `description`, which a `description` getter would collide with.)
  - `class SiteDetailSectionConfig { final SiteDetailSectionId id; final bool visible; final bool expanded; }` with `copyWith({bool? visible, bool? expanded})`, `toJson()`, `SiteDetailSectionConfig.fromJson(Map<String, dynamic>)`, `static SiteDetailSectionConfig? tryFromJson(Map<String, dynamic>)`, `static const List<SiteDetailSectionConfig> defaultSections`, `static List<SiteDetailSectionConfig> moveRenderedSection(List<SiteDetailSectionConfig> sections, List<SiteDetailSectionId> rendered, int oldIndex, int newIndex)`, `static List<SiteDetailSectionConfig> ensureAllSections(List<SiteDetailSectionConfig> sections)`, `static String sectionsToJson(List<SiteDetailSectionConfig>)`, `static List<SiteDetailSectionConfig> sectionsFromJson(String? json)`.
  - `class SiteDetailSectionPair { final SiteDetailSectionId left; final SiteDetailSectionId right; final double minRowWidth; SiteDetailSectionId? partnerOf(SiteDetailSectionId id); }`, `const List<SiteDetailSectionPair> kSiteDetailSectionPairs`, `SiteDetailSectionPair? siteDetailSectionPairFor(SiteDetailSectionId id)`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/constants/site_detail_sections_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<SiteDetailSectionId> _ids(List<SiteDetailSectionConfig> list) => [
  for (final s in list) s.id,
];

void main() {
  group('SiteDetailSectionId', () {
    test('declares the order the site page shipped with', () {
      expect(SiteDetailSectionId.values, const [
        SiteDetailSectionId.map,
        SiteDetailSectionId.diveStatistics,
        SiteDetailSectionId.description,
        SiteDetailSectionId.location,
        SiteDetailSectionId.depth,
        SiteDetailSectionId.altitude,
        SiteDetailSectionId.features,
        SiteDetailSectionId.tide,
        SiteDetailSectionId.reefHealth,
        SiteDetailSectionId.marineLife,
        SiteDetailSectionId.media,
        SiteDetailSectionId.difficulty,
        SiteDetailSectionId.rating,
        SiteDetailSectionId.hazards,
        SiteDetailSectionId.access,
        SiteDetailSectionId.notes,
      ]);
    });

    test('each card is named with the title the card itself shows', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        {
          for (final id in SiteDetailSectionId.values)
            id: id.localizedDisplayName(l10n),
        },
        const {
          SiteDetailSectionId.map: 'Map',
          SiteDetailSectionId.diveStatistics: 'Dives at this Site',
          SiteDetailSectionId.description: 'Description',
          SiteDetailSectionId.location: 'Location',
          SiteDetailSectionId.depth: 'Depth Range',
          SiteDetailSectionId.altitude: 'Altitude',
          SiteDetailSectionId.features: 'Features',
          SiteDetailSectionId.tide: 'Tides',
          SiteDetailSectionId.reefHealth: 'Ecosystem',
          SiteDetailSectionId.marineLife: 'Species',
          SiteDetailSectionId.media: 'Site Media',
          SiteDetailSectionId.difficulty: 'Difficulty Level',
          SiteDetailSectionId.rating: 'Rating',
          SiteDetailSectionId.hazards: 'Hazards & Safety',
          SiteDetailSectionId.access: 'Access & Logistics',
          SiteDetailSectionId.notes: 'Notes',
        },
      );
    });

    test('every card has a description in every locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final id in SiteDetailSectionId.values) {
          expect(
            id.localizedDescription(l10n),
            isNotEmpty,
            reason: '${locale.languageCode} ${id.name}',
          );
        }
      }
    });

    test('every card has its own icon', () {
      final icons = {for (final id in SiteDetailSectionId.values) id.icon};
      expect(icons.length, SiteDetailSectionId.values.length);
    });
  });

  group('SiteDetailSectionConfig', () {
    test('the defaults list every card visible and folded, in order', () {
      const defaults = SiteDetailSectionConfig.defaultSections;
      expect(_ids(defaults), SiteDetailSectionId.values);
      expect(defaults.every((s) => s.visible && !s.expanded), isTrue);
    });

    test('toJson writes expanded only when a card is unfolded', () {
      expect(
        const SiteDetailSectionConfig(
          id: SiteDetailSectionId.notes,
          visible: false,
        ).toJson(),
        {'id': 'notes', 'visible': false},
      );
      expect(
        const SiteDetailSectionConfig(
          id: SiteDetailSectionId.notes,
          visible: true,
          expanded: true,
        ).toJson(),
        {'id': 'notes', 'visible': true, 'expanded': true},
      );
    });

    test('a custom order round-trips through JSON', () {
      final custom = [
        for (final id in SiteDetailSectionId.values.reversed)
          SiteDetailSectionConfig(
            id: id,
            visible: id != SiteDetailSectionId.notes,
            expanded: id == SiteDetailSectionId.map,
          ),
      ];
      final back = SiteDetailSectionConfig.sectionsFromJson(
        SiteDetailSectionConfig.sectionsToJson(custom),
      );
      expect(_ids(back), _ids(custom));
      expect([for (final s in back) s.visible], [
        for (final s in custom) s.visible,
      ]);
      expect([for (final s in back) s.expanded], [
        for (final s in custom) s.expanded,
      ]);
    });

    test('null, empty and unreadable values read back as the defaults', () {
      for (final json in [null, '', 'not json', '{}', '[]']) {
        expect(
          _ids(SiteDetailSectionConfig.sectionsFromJson(json)),
          SiteDetailSectionId.values,
          reason: '$json',
        );
      }
    });

    test('unknown ids are dropped and known ones kept', () {
      final result = SiteDetailSectionConfig.sectionsFromJson(
        '[{"id":"bogus","visible":false},{"id":"notes","visible":false}]',
      );
      expect(result.length, SiteDetailSectionId.values.length);
      expect(
        result.firstWhere((s) => s.id == SiteDetailSectionId.notes).visible,
        isFalse,
      );
    });

    test('a card missing from a saved order lands after its neighbour', () {
      // A saved order without Altitude, which belongs right after Depth.
      final saved = [
        for (final id in SiteDetailSectionId.values.reversed)
          if (id != SiteDetailSectionId.altitude)
            SiteDetailSectionConfig(id: id, visible: true),
      ];
      final ids = _ids(
        SiteDetailSectionConfig.sectionsFromJson(
          SiteDetailSectionConfig.sectionsToJson(saved),
        ),
      );
      expect(
        ids.indexOf(SiteDetailSectionId.altitude),
        ids.indexOf(SiteDetailSectionId.depth) + 1,
      );
    });

    test('moveRenderedSection leaves unrendered cards in place', () {
      const rendered = [
        SiteDetailSectionId.description,
        SiteDetailSectionId.depth,
        SiteDetailSectionId.notes,
      ];
      final ids = _ids(
        SiteDetailSectionConfig.moveRenderedSection(
          List.of(SiteDetailSectionConfig.defaultSections),
          rendered,
          2,
          0,
        ),
      );
      expect(ids.first, SiteDetailSectionId.map);
      expect(
        ids.indexOf(SiteDetailSectionId.notes),
        ids.indexOf(SiteDetailSectionId.description) - 1,
      );
    });

    test('copyWith keeps the id and changes only what it is given', () {
      const config = SiteDetailSectionConfig(
        id: SiteDetailSectionId.tide,
        visible: true,
      );
      final hidden = config.copyWith(visible: false);
      expect(hidden.id, SiteDetailSectionId.tide);
      expect(hidden.visible, isFalse);
      expect(hidden.expanded, isFalse);
      expect(config.copyWith(expanded: true).visible, isTrue);
    });
  });
}
```

Create `test/core/constants/site_detail_section_pairs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_section_pairs.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';

void main() {
  test('Difficulty pairs with Rating and Hazards with Access', () {
    final difficulty = siteDetailSectionPairFor(SiteDetailSectionId.difficulty);
    expect(difficulty!.left, SiteDetailSectionId.difficulty);
    expect(difficulty.right, SiteDetailSectionId.rating);
    expect(
      identical(siteDetailSectionPairFor(SiteDetailSectionId.rating), difficulty),
      isTrue,
    );

    final hazards = siteDetailSectionPairFor(SiteDetailSectionId.access);
    expect(hazards!.left, SiteDetailSectionId.hazards);
    expect(hazards.right, SiteDetailSectionId.access);

    expect(siteDetailSectionPairFor(SiteDetailSectionId.notes), isNull);
  });

  test('no card belongs to two pairs', () {
    final seen = <SiteDetailSectionId>{};
    for (final pair in kSiteDetailSectionPairs) {
      expect(seen.add(pair.left), isTrue, reason: pair.left.name);
      expect(seen.add(pair.right), isTrue, reason: pair.right.name);
    }
  });

  test('each pair is adjacent and left first in the default order', () {
    const order = SiteDetailSectionId.values;
    for (final pair in kSiteDetailSectionPairs) {
      expect(order.indexOf(pair.right), order.indexOf(pair.left) + 1);
    }
  });

  test('partnerOf answers for both halves and nothing else', () {
    final pair = kSiteDetailSectionPairs.first;
    expect(pair.partnerOf(pair.left), pair.right);
    expect(pair.partnerOf(pair.right), pair.left);
    expect(pair.partnerOf(SiteDetailSectionId.map), isNull);
  });

  test('pairs sit side by side from 700px', () {
    for (final pair in kSiteDetailSectionPairs) {
      expect(pair.minRowWidth, 700);
    }
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

```bash
flutter test test/core/constants/site_detail_sections_test.dart test/core/constants/site_detail_section_pairs_test.dart
```

Expected: FAIL, the two library files do not exist.

- [ ] **Step 3: Write `site_detail_sections.dart`**

Create `lib/core/constants/site_detail_sections.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/detail_section_order.dart'
    as section_order;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Identifies each configurable card on the Site Details page.
///
/// Declaration order is the default display order: the order the page had
/// before it became configurable. Every card is configurable; the site name
/// lives in the app bar, so no part of the body is fixed.
///
/// The two pairs in `kSiteDetailSectionPairs` are declared adjacently, in
/// left-then-right order, so the default order already reads the way the
/// paired layout renders.
enum SiteDetailSectionId {
  map,
  diveStatistics,
  description,
  location,
  depth,
  altitude,
  features,
  tide,
  reefHealth,
  marineLife,
  media,
  difficulty,
  rating,
  hazards,
  access,
  notes;

  /// Icon standing in for the card in the display-options menu and, in the
  /// list layout, on the card's folded header row.
  IconData get icon {
    return switch (this) {
      map => Icons.map_outlined,
      diveStatistics => Icons.scuba_diving,
      description => Icons.description_outlined,
      location => Icons.public,
      depth => Icons.vertical_align_bottom,
      altitude => Icons.terrain,
      features => Icons.place_outlined,
      tide => Icons.waves,
      reefHealth => Icons.water_outlined,
      marineLife => Icons.pets,
      media => Icons.photo_library_outlined,
      difficulty => Icons.pool,
      rating => Icons.star_outline,
      hazards => Icons.warning_amber,
      access => Icons.directions,
      notes => Icons.notes,
    };
  }

  /// The title the card itself shows, so the menu and the page agree.
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (this) {
      map => l10n.siteDetailSection_map_name,
      diveStatistics => l10n.diveSites_detail_section_divesAtSite,
      description => l10n.diveSites_detail_section_description,
      location => l10n.diveSites_detail_section_location,
      depth => l10n.diveSites_detail_section_depthRange,
      altitude => l10n.diveSites_detail_section_altitude,
      features => l10n.siteFeature_sectionTitle,
      tide => l10n.tides_title,
      reefHealth => l10n.reef_section_title,
      marineLife => l10n.marineLife_siteSection_title,
      media => l10n.media_siteMediaSection_title,
      difficulty => l10n.diveSites_detail_section_difficultyLevel,
      rating => l10n.diveSites_detail_section_rating,
      hazards => l10n.diveSites_detail_section_hazards,
      access => l10n.diveSites_detail_section_access,
      notes => l10n.diveSites_detail_section_notes,
    };
  }

  /// One-line description shown below the name on the settings page.
  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      map => l10n.siteDetailSection_map_description,
      diveStatistics => l10n.siteDetailSection_diveStatistics_description,
      description => l10n.siteDetailSection_description_description,
      location => l10n.siteDetailSection_location_description,
      depth => l10n.siteDetailSection_depth_description,
      altitude => l10n.siteDetailSection_altitude_description,
      features => l10n.siteDetailSection_features_description,
      tide => l10n.siteDetailSection_tide_description,
      reefHealth => l10n.siteDetailSection_reefHealth_description,
      marineLife => l10n.siteDetailSection_marineLife_description,
      media => l10n.siteDetailSection_media_description,
      difficulty => l10n.siteDetailSection_difficulty_description,
      rating => l10n.siteDetailSection_rating_description,
      hazards => l10n.siteDetailSection_hazards_description,
      access => l10n.siteDetailSection_access_description,
      notes => l10n.siteDetailSection_notes_description,
    };
  }
}

/// Visibility, order and fold state for one Site Details card.
///
/// Stored as a JSON list in `diver_settings.site_detail_sections`, in the
/// same shape as the Dive Details list.
class SiteDetailSectionConfig {
  final SiteDetailSectionId id;
  final bool visible;

  /// Whether the list layout shows this card unfolded. Ignored by the
  /// detailed layout. Kept here rather than in page state so a site reopens
  /// the way the diver left it.
  final bool expanded;

  const SiteDetailSectionConfig({
    required this.id,
    required this.visible,
    this.expanded = false,
  });

  SiteDetailSectionConfig copyWith({bool? visible, bool? expanded}) {
    return SiteDetailSectionConfig(
      id: id,
      visible: visible ?? this.visible,
      expanded: expanded ?? this.expanded,
    );
  }

  /// Folded is the default, so the flag is written only when set: a diver
  /// who never unfolds anything stores, and syncs, no fold state at all.
  Map<String, dynamic> toJson() => {
    'id': id.name,
    'visible': visible,
    if (expanded) 'expanded': true,
  };

  factory SiteDetailSectionConfig.fromJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final id = SiteDetailSectionId.values.firstWhere((e) => e.name == idStr);
    return SiteDetailSectionConfig(
      id: id,
      visible: json['visible'] as bool? ?? true,
      expanded: json['expanded'] as bool? ?? false,
    );
  }

  static SiteDetailSectionConfig? tryFromJson(Map<String, dynamic> json) {
    try {
      return SiteDetailSectionConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static const List<SiteDetailSectionConfig> defaultSections = [
    SiteDetailSectionConfig(id: SiteDetailSectionId.map, visible: true),
    SiteDetailSectionConfig(
      id: SiteDetailSectionId.diveStatistics,
      visible: true,
    ),
    SiteDetailSectionConfig(id: SiteDetailSectionId.description, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.location, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.depth, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.altitude, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.features, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.tide, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.reefHealth, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.marineLife, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.media, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.difficulty, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.rating, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.hazards, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.access, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.notes, visible: true),
  ];

  /// [sections] reordered as if [rendered] had its [oldIndex] entry dropped
  /// at [newIndex]; cards outside [rendered] keep their place. See
  /// `section_order.moveRenderedSection`.
  static List<SiteDetailSectionConfig> moveRenderedSection(
    List<SiteDetailSectionConfig> sections,
    List<SiteDetailSectionId> rendered,
    int oldIndex,
    int newIndex,
  ) => section_order
      .moveRenderedSection<SiteDetailSectionConfig, SiteDetailSectionId>(
        sections,
        (s) => s.id,
        rendered,
        oldIndex,
        newIndex,
      );

  /// [sections] with every missing card added, visible, where the default
  /// order puts it. See `section_order.ensureAllSections`.
  static List<SiteDetailSectionConfig> ensureAllSections(
    List<SiteDetailSectionConfig> sections,
  ) => section_order
      .ensureAllSections<SiteDetailSectionConfig, SiteDetailSectionId>(
        sections,
        (s) => s.id,
        SiteDetailSectionId.values,
        (id) => SiteDetailSectionConfig(id: id, visible: true),
      );

  static String sectionsToJson(List<SiteDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  /// The saved list, or the defaults when [json] is null, empty or
  /// unreadable. Unknown ids are dropped; missing ones are added.
  static List<SiteDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return List.of(defaultSections);
    try {
      final decoded = jsonDecode(json) as List;
      final sections = decoded
          .whereType<Map<String, dynamic>>()
          .map(tryFromJson)
          .whereType<SiteDetailSectionConfig>()
          .toList();
      if (sections.isEmpty) return List.of(defaultSections);
      return ensureAllSections(sections);
    } catch (_) {
      return List.of(defaultSections);
    }
  }
}
```

- [ ] **Step 4: Write `site_detail_section_pairs.dart`**

Create `lib/core/constants/site_detail_section_pairs.dart`:

```dart
import 'package:submersion/core/constants/site_detail_sections.dart';

/// Two Site Details cards that render side by side when the pane is wide
/// enough.
///
/// [left] and [right] fix the on-screen arrangement independently of where
/// each card sits in the diver's order.
class SiteDetailSectionPair {
  const SiteDetailSectionPair(this.left, this.right, {this.minRowWidth = 700});

  /// The card in the left column (top card when stacked).
  final SiteDetailSectionId left;

  /// The card in the right column (bottom card when stacked).
  final SiteDetailSectionId right;

  /// At or above this available width the two cards sit side by side.
  final double minRowWidth;

  /// The other half of the pair, or null when [id] is not part of it.
  SiteDetailSectionId? partnerOf(SiteDetailSectionId id) {
    if (id == left) return right;
    if (id == right) return left;
    return null;
  }
}

/// Every Site Details card pair: four short cards that waste most of a wide
/// pane on their own. A card belongs to at most one pair.
const List<SiteDetailSectionPair> kSiteDetailSectionPairs = [
  SiteDetailSectionPair(SiteDetailSectionId.difficulty, SiteDetailSectionId.rating),
  SiteDetailSectionPair(SiteDetailSectionId.hazards, SiteDetailSectionId.access),
];

/// The pair [id] belongs to, or null when the card never pairs.
SiteDetailSectionPair? siteDetailSectionPairFor(SiteDetailSectionId id) {
  for (final pair in kSiteDetailSectionPairs) {
    if (pair.partnerOf(id) != null) return pair;
  }
  return null;
}
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/core/constants/site_detail_sections_test.dart test/core/constants/site_detail_section_pairs_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/core/constants/site_detail_sections.dart lib/core/constants/site_detail_section_pairs.dart test/core/constants/site_detail_sections_test.dart test/core/constants/site_detail_section_pairs_test.dart
```

```bash
git commit -m "feat(sites): model the site detail cards and their pairs" -m "SiteDetailSectionId lists the sixteen Site Details cards in the order the page shipped with. SiteDetailSectionConfig carries visibility, order and fold state in the dive JSON shape and reuses the shared order helpers. Difficulty + Rating and Hazards + Access are the two side-by-side pairs." -m "Refs #1884"
```

---

### Task 7: Schema v216, two nullable `diver_settings` columns

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `test/core/database/migration_v215_plan_gas_options_test.dart` (relax the tripwire)
- Test: `test/core/database/migration_v216_site_detail_sections_test.dart`

**Interfaces:**
- Produces: `diver_settings.site_detail_sections TEXT NULL`, `diver_settings.site_detail_layout TEXT NULL`; Drift getters `siteDetailSections` / `siteDetailLayout` on `DiverSetting` rows and `Value<String?>` fields of the same names on `DiverSettingsCompanion`; `AppDatabase.currentSchemaVersion == 216`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v216_site_detail_sections_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _columns = ['site_detail_sections', 'site_detail_layout'];

void main() {
  test('v216 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 216);
    expect(AppDatabase.migrationVersions, contains(216));
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('a fresh database has both site detail columns, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    for (final name in _columns) {
      expect(byName, contains(name));
      expect(byName[name]!.read<int>('notnull'), 0, reason: name);
    }
  });

  test(
    'a database stranded before v216 gains both columns via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, containsAll(_columns));
    },
  );

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/core/database/migration_v216_site_detail_sections_test.dart
```

Expected: FAIL (`currentSchemaVersion` is 215; columns missing).

- [ ] **Step 3: Declare the columns on the table**

In `lib/core/database/database.dart`, find in the `DiverSettings` table:

```dart
  TextColumn get diveDetailLayout => text().nullable()();
```

Insert directly after it:

```dart
  // Site detail page card order, visibility and fold state (v216): JSON
  // array in the dive_detail_sections format. Null reads as the defaults.
  TextColumn get siteDetailSections => text().nullable()();
  // Site detail page layout: detailed | list (v216). Null reads as detailed.
  TextColumn get siteDetailLayout => text().nullable()();
```

- [ ] **Step 4: Bump the version and the ladder list**

Change `static const int currentSchemaVersion = 215;` to:

```dart
  static const int currentSchemaVersion = 216;
```

In `static const List<int> migrationVersions = [`, after the entry `215,` (and its comment) and before `];`, add:

```dart
    // v216: diver_settings.site_detail_sections and site_detail_layout, the
    // Site Details page's card order, visibility, fold state and layout
    // (issue #1884). Additive nullable columns, no backfill.
    216,
```

- [ ] **Step 5: Add the idempotent helper**

Directly after the closing `}` of `Future<void> _assertDiveDetailLayoutColumn() async { ... }`, add:

```dart

  /// v216: diver_settings.site_detail_sections and site_detail_layout (issue
  /// #1884). Idempotent, so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop, and a no-op when the table does not exist yet.
  Future<void> _assertSiteDetailColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('site_detail_sections')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN site_detail_sections TEXT',
      );
    }
    if (!names.contains('site_detail_layout')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN site_detail_layout TEXT',
      );
    }
  }
```

- [ ] **Step 6: Run it from onUpgrade**

In `onUpgrade`, find:

```dart
        if (from < 215) await reportProgress();
```

Insert directly after it:

```dart
        // v216: diver_settings site detail columns. Column-only rung, no
        // backfill: null reads back as the default order and layout.
        if (from < 216) {
          await _assertSiteDetailColumns();
        }
        if (from < 216) await reportProgress();
```

- [ ] **Step 7: Add the beforeOpen backstop**

Inside `beforeOpen`, find the v185 backstop:

```dart
        // v185 backstop: re-assert diver_settings.dive_detail_layout. Every
        // settings read selects the whole row, so a database that skipped the
        // rung would throw on the first read instead of falling back to the
        // default layout.
        await _assertDiveDetailLayoutColumn();
```

Insert directly after that `await` line:

```dart

        // v216 backstop: re-assert the diver_settings site detail columns.
        // Every settings read selects the whole row, so a database that
        // arrives by restore or sync-adopt without them would throw on the
        // first read.
        await _assertSiteDetailColumns();
```

- [ ] **Step 8: Regenerate Drift code**

```bash
bash /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-kind-bouman-871cc8/5307b5be-061e-4c1f-bf35-57ee2cb42bf9/scratchpad/codegen.sh
```

Expected: `Succeeded after ...`.

- [ ] **Step 9: Relax the v215 tripwire**

In `test/core/database/migration_v215_plan_gas_options_test.dart`, replace:

```dart
    expect(AppDatabase.currentSchemaVersion, 215);
```

with:

```dart
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(215));
```

and replace the comment sentence `The newest rung owns the exact assertion; relax it to greaterThanOrEqualTo when the next one lands.` (it may wrap over two lines) with `Relaxed once v216 (site detail sections) landed on top; the newest rung owns the exact assertion.`

Then look for other tests that use 215 to mean "the ladder finished":

```bash
git grep -n "215" -- test
```

For every hit other than `migration_v215_plan_gas_options_test.dart` and comments that merely list rung history, if it asserts the current version (`currentSchemaVersion`, `user_version`, a stored version) as `215`, change it to `AppDatabase.currentSchemaVersion`. Leave assertions that are about rung 215 specifically.

- [ ] **Step 10: Run the migration tests**

```bash
flutter test test/core/database/migration_v216_site_detail_sections_test.dart test/core/database/migration_v215_plan_gas_options_test.dart test/core/database/migration_v211_auto_tag_imports_test.dart test/core/database/migration_v185_dive_detail_layout_test.dart
```

Expected: `All tests passed!`

```bash
flutter test test/core/database
```

Expected: `All tests passed!`

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/core/database/database.dart test/core/database/migration_v216_site_detail_sections_test.dart test/core/database/migration_v215_plan_gas_options_test.dart
```

Also `git add` any other test file Step 9 changed, by explicit path.

```bash
git commit -m "feat(sites): schema v216 for site detail sections" -m "Adds nullable diver_settings.site_detail_sections (JSON, dive_detail_sections format) and site_detail_layout. The rung and the beforeOpen backstop share one PRAGMA-guarded, idempotent helper. Additive and nullable, so minimumCompatibleSchemaVersion stays at 210 and older peers still sync." -m "Refs #1884"
```

---

### Task 8: Settings model, setters, repository, fakes and sync

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier`)
- Modify: `test/features/statistics/presentation/pages/records_page_test.dart` (`_MockSettingsNotifier`)
- Test: `test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart`
- Test: `test/features/settings/presentation/providers/site_detail_settings_setters_test.dart`
- Test: `test/core/services/sync/sync_diver_settings_site_detail_test.dart`

**Interfaces:**
- Consumes: `SiteDetailSectionConfig`, `SiteDetailSectionId` (Task 6); the Drift columns (Task 7).
- Produces:
  - `AppSettings.siteDetailSections` (`List<SiteDetailSectionConfig>`, default `SiteDetailSectionConfig.defaultSections`) and `AppSettings.siteDetailLayout` (`DiveDetailLayout`, default `DiveDetailLayout.detailed`).
  - `AppSettings.copyWith({List<SiteDetailSectionConfig>? siteDetailSections, bool clearSiteDetailSections = false, DiveDetailLayout? siteDetailLayout, ...})`
  - `SettingsNotifier`: `Future<void> setSiteDetailSections(List<SiteDetailSectionConfig> sections)`, `Future<void> resetSiteDetailSections()`, `Future<void> setSiteDetailLayout(DiveDetailLayout layout)`, `Future<void> setSiteDetailSectionExpanded(SiteDetailSectionId id, bool expanded)`.
  - `MockSettingsNotifier` implements all four in memory (used by every later widget test through `getBaseOverrides`).

- [ ] **Step 1: Write the failing repository test**

Create `test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings site detail fields', () {
    test('default to every card visible and the detailed layout', () {
      const settings = AppSettings();
      expect(settings.siteDetailLayout, DiveDetailLayout.detailed);
      expect(
        [for (final s in settings.siteDetailSections) s.id],
        SiteDetailSectionId.values,
      );
    });

    test('copyWith carries them and leaves the dive fields alone', () {
      const settings = AppSettings();
      const hidden = [
        SiteDetailSectionConfig(id: SiteDetailSectionId.notes, visible: false),
      ];
      final updated = settings.copyWith(
        siteDetailSections: hidden,
        siteDetailLayout: DiveDetailLayout.list,
      );
      expect(updated.siteDetailSections, hidden);
      expect(updated.siteDetailLayout, DiveDetailLayout.list);
      expect(updated.diveDetailLayout, DiveDetailLayout.detailed);
      expect(updated.diveDetailSections, settings.diveDetailSections);
    });

    test('clearSiteDetailSections restores the defaults', () {
      const settings = AppSettings(
        siteDetailSections: [
          SiteDetailSectionConfig(id: SiteDetailSectionId.notes, visible: false),
        ],
      );
      final cleared = settings.copyWith(clearSiteDetailSections: true);
      expect(cleared.siteDetailSections, SiteDetailSectionConfig.defaultSections);
    });
  });

  group('DiverSettingsRepository site detail persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start at the defaults', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.detailed);
      expect(
        [for (final s in loaded.siteDetailSections) s.id],
        SiteDetailSectionId.values,
      );
    });

    test('the order, visibility, fold state and layout round-trip', () async {
      final custom = [
        for (final id in SiteDetailSectionId.values.reversed)
          SiteDetailSectionConfig(
            id: id,
            visible: id != SiteDetailSectionId.tide,
            expanded: id == SiteDetailSectionId.depth,
          ),
      ];
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(
          siteDetailSections: custom,
          siteDetailLayout: DiveDetailLayout.list,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.list);
      expect(
        [for (final s in loaded.siteDetailSections) s.id],
        [for (final s in custom) s.id],
      );
      final tide = loaded.siteDetailSections.firstWhere(
        (s) => s.id == SiteDetailSectionId.tide,
      );
      expect(tide.visible, isFalse);
      final depth = loaded.siteDetailSections.firstWhere(
        (s) => s.id == SiteDetailSectionId.depth,
      );
      expect(depth.expanded, isTrue);
    });

    test('null columns read back as the defaults', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        'UPDATE diver_settings SET site_detail_sections = NULL, '
        "site_detail_layout = NULL WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.siteDetailLayout, DiveDetailLayout.detailed);
      expect(
        [for (final s in loaded.siteDetailSections) s.id],
        SiteDetailSectionId.values,
      );
    });

    test('writing the site fields leaves the dive fields alone', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          diveDetailLayout: DiveDetailLayout.list,
          siteDetailLayout: DiveDetailLayout.detailed,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.diveDetailLayout, DiveDetailLayout.list);
      expect(loaded.siteDetailLayout, DiveDetailLayout.detailed);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart
```

Expected: FAIL to compile (`siteDetailSections` is not a member of `AppSettings`).

- [ ] **Step 3: Add the fields to `AppSettings`**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

a) After `import 'package:submersion/core/constants/map_style.dart';` add:

```dart
import 'package:submersion/core/constants/site_detail_sections.dart';
```

b) After the field

```dart
  /// How the dive detail page arranges the sections it shows.
  final DiveDetailLayout diveDetailLayout;
```

add:

```dart

  /// Ordered list of Site Details card visibility and fold preferences.
  final List<SiteDetailSectionConfig> siteDetailSections;

  /// How the Site Details page arranges the cards it shows.
  final DiveDetailLayout siteDetailLayout;
```

c) In the `AppSettings` constructor, after `this.diveDetailLayout = DiveDetailLayout.detailed,` add:

```dart
    this.siteDetailSections = SiteDetailSectionConfig.defaultSections,
    this.siteDetailLayout = DiveDetailLayout.detailed,
```

d) In the `copyWith` parameter list, after `DiveDetailLayout? diveDetailLayout,` add:

```dart
    List<SiteDetailSectionConfig>? siteDetailSections,
    bool clearSiteDetailSections = false,
    DiveDetailLayout? siteDetailLayout,
```

e) In the `copyWith` body, after `diveDetailLayout: diveDetailLayout ?? this.diveDetailLayout,` add:

```dart
      siteDetailSections: clearSiteDetailSections
          ? SiteDetailSectionConfig.defaultSections
          : (siteDetailSections ?? this.siteDetailSections),
      siteDetailLayout: siteDetailLayout ?? this.siteDetailLayout,
```

- [ ] **Step 4: Add the notifier setters**

In `SettingsNotifier`, directly after the closing `}` of `setDiveDetailSectionExpanded`, add:

```dart

  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async {
    state = state.copyWith(siteDetailSections: sections);
    await _saveSettings();
  }

  Future<void> resetSiteDetailSections() async {
    state = state.copyWith(clearSiteDetailSections: true);
    await _saveSettings();
  }

  Future<void> setSiteDetailLayout(DiveDetailLayout layout) async {
    state = state.copyWith(siteDetailLayout: layout);
    await _saveSettings();
  }

  /// Record whether Site Details card [id] shows unfolded in the list
  /// layout. Fold state rides in the card list, so this rewrites that list
  /// with the one entry changed, and does nothing when it already matches.
  Future<void> setSiteDetailSectionExpanded(
    SiteDetailSectionId id,
    bool expanded,
  ) async {
    final sections = state.siteDetailSections;
    if (!sections.any((s) => s.id == id && s.expanded != expanded)) return;
    state = state.copyWith(
      siteDetailSections: [
        for (final section in sections)
          section.id == id ? section.copyWith(expanded: expanded) : section,
      ],
    );
    await _saveSettings();
  }
```

- [ ] **Step 5: Persist in the repository**

In `lib/features/settings/data/repositories/diver_settings_repository.dart`:

a) After `import 'package:submersion/core/constants/dive_detail_sections.dart';` add:

```dart
import 'package:submersion/core/constants/site_detail_sections.dart';
```

b) In the insert companion, after `diveDetailLayout: Value(s.diveDetailLayout.name),` add:

```dart
              siteDetailSections: Value(
                SiteDetailSectionConfig.sectionsToJson(s.siteDetailSections),
              ),
              siteDetailLayout: Value(s.siteDetailLayout.name),
```

c) In the update companion, after `diveDetailLayout: Value(settings.diveDetailLayout.name),` add:

```dart
          siteDetailSections: Value(
            SiteDetailSectionConfig.sectionsToJson(settings.siteDetailSections),
          ),
          siteDetailLayout: Value(settings.siteDetailLayout.name),
```

d) In the row-to-`AppSettings` mapping, after `diveDetailLayout: DiveDetailLayout.fromName(row.diveDetailLayout),` add:

```dart
      siteDetailSections: SiteDetailSectionConfig.sectionsFromJson(
        row.siteDetailSections,
      ),
      siteDetailLayout: DiveDetailLayout.fromName(row.siteDetailLayout),
```

- [ ] **Step 6: Teach the two strict fakes the new setters**

`MockSettingsNotifier` in `test/helpers/mock_providers.dart` and `_MockSettingsNotifier` in `test/features/statistics/presentation/pages/records_page_test.dart` implement `SettingsNotifier` without `noSuchMethod`, so they stop compiling until they implement the new methods. In each, add `import 'package:submersion/core/constants/site_detail_sections.dart';` to the imports, and directly after that class's `setDiveDetailSectionExpanded` override add:

```dart

  @override
  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async => state = state.copyWith(siteDetailSections: sections);

  @override
  Future<void> resetSiteDetailSections() async =>
      state = state.copyWith(clearSiteDetailSections: true);

  @override
  Future<void> setSiteDetailLayout(DiveDetailLayout layout) async =>
      state = state.copyWith(siteDetailLayout: layout);

  @override
  Future<void> setSiteDetailSectionExpanded(
    SiteDetailSectionId id,
    bool expanded,
  ) async {
    state = state.copyWith(
      siteDetailSections: [
        for (final section in state.siteDetailSections)
          section.id == id ? section.copyWith(expanded: expanded) : section,
      ],
    );
  }
```

- [ ] **Step 7: Run the repository test**

```bash
flutter test test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart test/features/settings/data/repositories/diver_settings_repository_dive_detail_layout_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 8: Write the setter and sync tests**

Create `test/features/settings/presentation/providers/site_detail_settings_setters_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(settingsProvider.notifier).initialLoad;
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  SettingsNotifier notifier() => container.read(settingsProvider.notifier);

  Future<AppSettings> stored() async =>
      (await DiverSettingsRepository().getSettingsForDiver(diverId))!;

  test('setSiteDetailLayout applies and persists', () async {
    await notifier().setSiteDetailLayout(DiveDetailLayout.list);

    expect(
      container.read(settingsProvider).siteDetailLayout,
      DiveDetailLayout.list,
    );
    expect((await stored()).siteDetailLayout, DiveDetailLayout.list);
    expect((await stored()).diveDetailLayout, DiveDetailLayout.detailed);
  });

  test('setSiteDetailSections applies and persists the order', () async {
    final reversed = [
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(id: id, visible: id != SiteDetailSectionId.map),
    ];
    await notifier().setSiteDetailSections(reversed);

    final saved = (await stored()).siteDetailSections;
    expect([for (final s in saved) s.id], SiteDetailSectionId.values.reversed);
    expect(
      saved.firstWhere((s) => s.id == SiteDetailSectionId.map).visible,
      isFalse,
    );
  });

  test('resetSiteDetailSections restores the default order', () async {
    await notifier().setSiteDetailSections([
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(id: id, visible: false),
    ]);
    await notifier().resetSiteDetailSections();

    final saved = (await stored()).siteDetailSections;
    expect([for (final s in saved) s.id], SiteDetailSectionId.values);
    expect(saved.every((s) => s.visible), isTrue);
  });

  test('setSiteDetailSectionExpanded persists the fold state', () async {
    await notifier().setSiteDetailSectionExpanded(
      SiteDetailSectionId.depth,
      true,
    );

    final depth = (await stored()).siteDetailSections.firstWhere(
      (s) => s.id == SiteDetailSectionId.depth,
    );
    expect(depth.expanded, isTrue);
  });

  test('an unchanged fold state leaves the list instance alone', () async {
    final before = container.read(settingsProvider).siteDetailSections;
    await notifier().setSiteDetailSectionExpanded(
      SiteDetailSectionId.depth,
      false,
    );

    expect(
      identical(container.read(settingsProvider).siteDetailSections, before),
      isTrue,
    );
  });
}
```

Create `test/core/services/sync/sync_diver_settings_site_detail_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The site detail columns (v216) ride the generic diverSettings row, so
/// they reach other devices with no serializer change, and a payload from a
/// peer that predates them still applies.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  const sectionsJson = '[{"id":"notes","visible":false}]';

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // A placeholder diver_id need not reference a real diver here.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertRow(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-1',
            createdAt: now,
            updatedAt: now,
            siteDetailSections: const Value(sectionsJson),
            siteDetailLayout: const Value('list'),
          ),
        );
  }

  Future<DiverSetting> readRow(String id) => (db.select(
    db.diverSettings,
  )..where((t) => t.id.equals(id))).getSingle();

  test('both columns export and re-import unchanged', () async {
    await insertRow('ds-216');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-216');
    expect(exported!['siteDetailSections'], sectionsJson);
    expect(exported['siteDetailLayout'], 'list');

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-216'))).go();
    await serializer.upsertRecord('diverSettings', exported);

    final row = await readRow('ds-216');
    expect(row.siteDetailSections, sectionsJson);
    expect(row.siteDetailLayout, 'list');
  });

  test('a pre-v216 payload without the columns still applies', () async {
    await insertRow('ds-215');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-215');
    final legacy = Map<String, dynamic>.from(exported!)
      ..remove('siteDetailSections')
      ..remove('siteDetailLayout');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-215'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await readRow('ds-215');
    expect(row.siteDetailSections, isNull);
    expect(row.siteDetailLayout, isNull);
  });
}
```

- [ ] **Step 9: Run the new tests and the settings suites**

```bash
flutter test test/features/settings/presentation/providers/site_detail_settings_setters_test.dart test/core/services/sync/sync_diver_settings_site_detail_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart
```

Expected: `All tests passed!`

```bash
flutter test test/features/settings test/features/statistics/presentation/pages/records_page_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart test/helpers/mock_providers.dart test/features/statistics/presentation/pages/records_page_test.dart test/features/settings/data/repositories/diver_settings_repository_site_detail_test.dart test/features/settings/presentation/providers/site_detail_settings_setters_test.dart test/core/services/sync/sync_diver_settings_site_detail_test.dart
```

```bash
git commit -m "feat(sites): store the site detail card order and layout per diver" -m "AppSettings gains siteDetailSections and siteDetailLayout, with setters that mirror the Dive Details ones (the fold setter skips the save when nothing changes). DiverSettingsRepository writes and reads both v216 columns, and they sync on the diverSettings row with no serializer change." -m "Refs #1884"
```

---

### Task 9: `SiteDetailSectionList`, the page body assembler

A plain widget with no providers: it takes the diver's configuration and the already-built cards, so pairing, ordering and folding are tested without a database.

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart`

**Interfaces:**
- Consumes: `SiteDetailSectionConfig`, `SiteDetailSectionId` (Task 6); `siteDetailSectionPairFor` (Task 6); `SectionFold` (Task 3); `ResponsiveSectionPair` (existing, `lib/features/dive_log/presentation/widgets/responsive_section_pair.dart`); `DiveDetailLayout.foldsSections`.
- Produces:
  - `const double kSiteDetailCardGap = 12;`
  - `SiteDetailSectionList({Key? key, required List<SiteDetailSectionConfig> sections, required DiveDetailLayout layout, required Map<SiteDetailSectionId, Widget?> cards, required void Function(SiteDetailSectionId id, bool expanded) onFoldChanged})`. A card missing from `cards`, or mapped to null, is treated as having nothing to show.
  - Fold keys: `ValueKey('siteSectionFold_<id.name>')`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

Widget _card(SiteDetailSectionId id) =>
    Card(child: SizedBox(height: 40, child: Text('CARD_${id.name}')));

Map<SiteDetailSectionId, Widget?> _allCards() => {
  for (final id in SiteDetailSectionId.values) id: _card(id),
};

List<SiteDetailSectionConfig> _config({
  Set<SiteDetailSectionId> hidden = const {},
  Set<SiteDetailSectionId> expanded = const {},
  List<SiteDetailSectionId>? order,
}) => [
  for (final id in order ?? SiteDetailSectionId.values)
    SiteDetailSectionConfig(
      id: id,
      visible: !hidden.contains(id),
      expanded: expanded.contains(id),
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required List<SiteDetailSectionConfig> sections,
  Map<SiteDetailSectionId, Widget?>? cards,
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  void Function(SiteDetailSectionId id, bool expanded)? onFoldChanged,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 4000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SiteDetailSectionList(
            sections: sections,
            layout: layout,
            cards: cards ?? _allCards(),
            onFoldChanged: onFoldChanged ?? (id, expanded) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rectOf(WidgetTester tester, SiteDetailSectionId id) => tester.getRect(
  find.ancestor(of: find.text('CARD_${id.name}'), matching: find.byType(Card)),
);

void main() {
  group('detailed layout', () {
    testWidgets('renders the visible cards in the saved order', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(order: SiteDetailSectionId.values.reversed.toList()),
      );

      expect(
        _rectOf(tester, SiteDetailSectionId.notes).top,
        lessThan(_rectOf(tester, SiteDetailSectionId.map).top),
      );
    });

    testWidgets('a hidden card is not rendered', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(hidden: {SiteDetailSectionId.notes}),
      );

      expect(find.text('CARD_notes'), findsNothing);
      expect(find.text('CARD_description'), findsOneWidget);
    });

    testWidgets('a card with nothing to show is skipped', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        cards: {..._allCards(), SiteDetailSectionId.altitude: null}
          ..remove(SiteDetailSectionId.tide),
      );

      expect(find.text('CARD_altitude'), findsNothing);
      expect(find.text('CARD_tide'), findsNothing);
      expect(find.text('CARD_depth'), findsOneWidget);
    });

    testWidgets('consecutive cards are 12px apart', (tester) async {
      await _pump(tester, width: 600, sections: _config());

      final description = _rectOf(tester, SiteDetailSectionId.description);
      final location = _rectOf(tester, SiteDetailSectionId.location);
      expect(location.top - description.bottom, kSiteDetailCardGap);
    });

    testWidgets('Difficulty and Rating sit side by side on a wide pane', (
      tester,
    ) async {
      await _pump(tester, width: 1400, sections: _config());

      final pair = find.ancestor(
        of: find.text('CARD_difficulty'),
        matching: find.byType(ResponsiveSectionPair),
      );
      expect(pair, findsOneWidget);
      expect(
        find.descendant(of: pair, matching: find.text('CARD_rating')),
        findsOneWidget,
      );
      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      expect(rating.top, difficulty.top);
      expect(difficulty.left, lessThan(rating.left));
    });

    testWidgets('the pair stacks on a narrow pane', (tester) async {
      await _pump(tester, width: 390, sections: _config());

      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      expect(rating.top, greaterThanOrEqualTo(difficulty.bottom));
    });

    testWidgets('a pair split by other cards forms at its first half', (
      tester,
    ) async {
      const tail = [
        SiteDetailSectionId.rating,
        SiteDetailSectionId.notes,
        SiteDetailSectionId.difficulty,
      ];
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          order: [
            for (final id in SiteDetailSectionId.values)
              if (!tail.contains(id)) id,
            ...tail,
          ],
        ),
      );

      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      final notes = _rectOf(tester, SiteDetailSectionId.notes);
      expect(rating.top, difficulty.top);
      expect(difficulty.left, lessThan(rating.left));
      expect(notes.top, greaterThan(rating.bottom));
    });

    testWidgets('a pair with an empty half falls back to single cards', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(),
        cards: {
          ..._allCards(),
          SiteDetailSectionId.difficulty: null,
          SiteDetailSectionId.hazards: null,
        },
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_rating'), findsOneWidget);
      expect(find.text('CARD_access'), findsOneWidget);
    });

    testWidgets('a hidden half does not pair', (tester) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          hidden: {SiteDetailSectionId.rating, SiteDetailSectionId.access},
        ),
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_difficulty'), findsOneWidget);
    });
  });

  group('list layout', () {
    testWidgets('folds every card and builds none of them', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        layout: DiveDetailLayout.list,
      );

      expect(
        find.byType(SectionFold),
        findsNWidgets(SiteDetailSectionId.values.length),
      );
      expect(find.textContaining('CARD_'), findsNothing);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('an unfolded card shows its content', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(expanded: {SiteDetailSectionId.notes}),
        layout: DiveDetailLayout.list,
      );

      expect(find.text('CARD_notes'), findsOneWidget);
      expect(find.text('CARD_map'), findsNothing);
    });

    testWidgets('tapping a header reports the new fold state', (tester) async {
      final calls = <(SiteDetailSectionId, bool)>[];
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        layout: DiveDetailLayout.list,
        onFoldChanged: (id, expanded) => calls.add((id, expanded)),
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(calls, [(SiteDetailSectionId.notes, true)]);
    });

    testWidgets('never pairs cards', (tester) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          expanded: {SiteDetailSectionId.difficulty, SiteDetailSectionId.rating},
        ),
        layout: DiveDetailLayout.list,
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_difficulty'), findsOneWidget);
      expect(find.text('CARD_rating'), findsOneWidget);
    });

    testWidgets('a card with nothing to show gets no header', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        cards: {..._allCards(), SiteDetailSectionId.altitude: null},
        layout: DiveDetailLayout.list,
      );

      expect(find.text('Altitude'), findsNothing);
      expect(
        find.byType(SectionFold),
        findsNWidgets(SiteDetailSectionId.values.length - 1),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart
```

Expected: FAIL, `site_detail_section_list.dart` does not exist.

- [ ] **Step 3: Write the widget**

Create `lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_section_pairs.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

/// Gap between two consecutive cards in the detailed layout. Tighter than
/// Dive Details because a site stacks well over a dozen short cards.
const double kSiteDetailCardGap = 12;

/// The Site Details body: the diver's cards, in the diver's order, laid out
/// the diver's way.
///
/// [cards] holds every card the site can show right now, already built. A
/// card that is missing or null has nothing to show for this site and is
/// skipped as if hidden, and never forms half of a pair (a pair with an
/// empty half would lay out a blank column beside a half-width card).
///
/// Building the cards up front is cheap: a card widget is only a
/// description. In the list layout a folded card's subtree is never
/// mounted, so the map, tide chart and water-conditions lookup behind a
/// closed header cost nothing.
///
/// In the detailed layout, a pair from [kSiteDetailSectionPairs] renders
/// side by side whenever both halves are shown, wherever they sit in the
/// order: the row takes the slot of whichever half comes first. Left and
/// right come from the pair definition.
class SiteDetailSectionList extends StatelessWidget {
  const SiteDetailSectionList({
    super.key,
    required this.sections,
    required this.layout,
    required this.cards,
    required this.onFoldChanged,
  });

  /// The diver's card configuration, in order.
  final List<SiteDetailSectionConfig> sections;

  final DiveDetailLayout layout;

  /// The built cards, keyed by id; missing or null means nothing to show.
  final Map<SiteDetailSectionId, Widget?> cards;

  /// Called when a folded header is tapped in the list layout, with the
  /// requested new state.
  final void Function(SiteDetailSectionId id, bool expanded) onFoldChanged;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final section in sections)
        if (section.visible && cards[section.id] != null) section.id,
    ];
    final shownIds = shown.toSet();
    final unfolded = {
      for (final section in sections)
        if (section.expanded) section.id,
    };

    final children = <Widget>[];
    final consumed = <SiteDetailSectionId>{};

    for (final id in shown) {
      // The trailing half of a pair already rendered at the leading half's
      // slot.
      if (consumed.contains(id)) continue;

      if (layout.foldsSections) {
        // Each folded row draws its own divider, so rows take no gap.
        children.add(
          SectionFold(
            key: ValueKey('siteSectionFold_${id.name}'),
            title: id.localizedDisplayName(context.l10n),
            icon: id.icon,
            isExpanded: unfolded.contains(id),
            onToggle: (expanded) => onFoldChanged(id, expanded),
            contentBuilder: (_) => cards[id]!,
          ),
        );
        continue;
      }

      if (children.isNotEmpty) {
        children.add(const SizedBox(height: kSiteDetailCardGap));
      }

      final pair = layout.pairsSections ? siteDetailSectionPairFor(id) : null;
      if (pair != null && shownIds.contains(pair.partnerOf(id))) {
        children.add(
          ResponsiveSectionPair(
            first: cards[pair.left]!,
            second: cards[pair.right]!,
            minRowWidth: pair.minRowWidth,
            stackGap: kSiteDetailCardGap,
          ),
        );
        consumed.addAll([pair.left, pair.right]);
        continue;
      }

      children.add(cards[id]!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart test/features/dive_sites/presentation/widgets/site_detail_section_list_test.dart
```

```bash
git commit -m "feat(sites): assemble the site detail body from the diver's layout" -m "SiteDetailSectionList renders the shown cards in the diver's order with one even gap between them, pairs Difficulty + Rating and Hazards + Access wherever they sit (the row takes the first half's slot), and in the list layout folds every card behind a header whose content is only mounted once unfolded." -m "Refs #1884"
```

---

### Task 10: `SiteDetailPropertiesMenu`, the site wrapper

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart`

**Interfaces:**
- Consumes: `SectionPropertiesMenu`, `SectionMenuEntry` (Task 4); `SiteDetailSectionConfig` (Task 6); settings setters (Task 8). The route name `siteDetailSections` (registered in Task 12; the test registers its own stub route).
- Produces: `SiteDetailPropertiesMenu({Key? key, double? iconSize})`, a `ConsumerWidget`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Keeps settings in memory so the menu's writes show on the next pump.
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.initial);

  @override
  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async => state = state.copyWith(siteDetailSections: sections);

  @override
  Future<void> setSiteDetailLayout(DiveDetailLayout layout) async =>
      state = state.copyWith(siteDetailLayout: layout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeSettingsNotifier notifier) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          appBar: AppBar(actions: const [SiteDetailPropertiesMenu()]),
        ),
      ),
      GoRoute(
        path: '/settings/site-detail-sections',
        name: 'siteDetailSections',
        builder: (context, state) =>
            const Scaffold(body: Text('SITE_SECTIONS_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

List<SiteDetailSectionId> _order(AppSettings settings) => [
  for (final section in settings.siteDetailSections) section.id,
];

void main() {
  testWidgets('offers every site card', (tester) async {
    await tester.pumpWidget(_harness(_FakeSettingsNotifier(const AppSettings())));
    await _open(tester);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.itemCount, SiteDetailSectionId.values.length);
    expect(find.text('Dives at this Site'), findsOneWidget);
  });

  testWidgets('choosing a layout writes the site layout only', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(notifier.state.siteDetailLayout, DiveDetailLayout.list);
    expect(notifier.state.diveDetailLayout, DiveDetailLayout.detailed);
  });

  testWidgets('toggling a card flips only that card', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('Description'));
    await tester.pumpAndSettle();

    final sections = notifier.state.siteDetailSections;
    expect(
      sections.firstWhere((s) => s.id == SiteDetailSectionId.description).visible,
      isFalse,
    );
    expect(
      sections
          .where((s) => s.id != SiteDetailSectionId.description)
          .every((s) => s.visible),
      isTrue,
    );
    expect(notifier.state.diveDetailSections, DiveDetailSectionConfig.defaultSections);
  });

  testWidgets('show all restores every card and keeps the order', (
    tester,
  ) async {
    final custom = [
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(
          id: id,
          visible: id != SiteDetailSectionId.map && id != SiteDetailSectionId.tide,
        ),
    ];
    final notifier = _FakeSettingsNotifier(
      AppSettings(siteDetailSections: custom),
    );
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('Show all sections'));
    await tester.pumpAndSettle();

    expect(notifier.state.siteDetailSections.every((s) => s.visible), isTrue);
    expect(_order(notifier.state), SiteDetailSectionId.values.reversed);
  });

  testWidgets('a drop writes the new order', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    final before = _order(notifier.state);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 1);
    await tester.pumpAndSettle();

    final after = _order(notifier.state);
    expect(after[0], before[1]);
    expect(after[1], before[0]);
    expect(after.sublist(2), before.sublist(2));
  });

  testWidgets('Reorder sections opens the site settings page', (tester) async {
    await tester.pumpWidget(_harness(_FakeSettingsNotifier(const AppSettings())));
    await _open(tester);

    await tester.tap(find.text('Reorder sections...'));
    await tester.pumpAndSettle();

    expect(find.text('SITE_SECTIONS_PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart
```

Expected: FAIL, `site_detail_properties_menu.dart` does not exist.

- [ ] **Step 3: Write the wrapper**

Create `lib/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

/// The Site Details page's display-options dropdown.
///
/// The same menu as Dive Details ([SectionPropertiesMenu]), writing to the
/// diver's site settings instead, so the two pages are configured
/// independently. Every card is offered, including ones with nothing to show
/// for the current site: a site can gain coordinates or hazards later.
class SiteDetailPropertiesMenu extends ConsumerWidget {
  const SiteDetailPropertiesMenu({super.key, this.iconSize});

  /// Size of the tune icon; the embedded header uses a smaller one.
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.siteDetailLayout),
    );

    void write(List<SiteDetailSectionConfig> updated) =>
        ref.read(settingsProvider.notifier).setSiteDetailSections(updated);

    return SectionPropertiesMenu(
      layout: layout,
      iconSize: iconSize,
      onLayoutChanged: (option) =>
          ref.read(settingsProvider.notifier).setSiteDetailLayout(option),
      entries: [
        for (final section in sections)
          SectionMenuEntry(
            id: section.id,
            label: section.id.localizedDisplayName(l10n),
            icon: section.id.icon,
            visible: section.visible,
          ),
      ],
      onToggle: (index) {
        final id = sections[index].id;
        write([
          for (final s in sections)
            if (s.id == id) s.copyWith(visible: !s.visible) else s,
        ]);
      },
      onReorder: (oldIndex, newIndex) => write(
        SiteDetailSectionConfig.moveRenderedSection(
          sections,
          [for (final s in sections) s.id],
          oldIndex,
          newIndex,
        ),
      ),
      // Turns every card back on without touching the diver's order.
      onShowAll: () =>
          write([for (final s in sections) s.copyWith(visible: true)]),
      onOpenSettings: () => context.pushNamed('siteDetailSections'),
    );
  }
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart test/features/dive_sites/presentation/widgets/site_detail_properties_menu_test.dart
```

```bash
git commit -m "feat(sites): display-options menu for site details" -m "SiteDetailPropertiesMenu wraps the shared menu around the diver's site settings: layout, per-card visibility, drag order, Show all, and a link to the site sections settings page. Every card is offered, even ones empty for the current site." -m "Refs #1884"
```

---

### Task 11: Wire the Site Details page

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_SiteDetailContentState.build`, `_pairOrSingle`, `_buildEmbeddedHeader`, imports)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart`
- Regression: every existing test in `test/features/dive_sites/presentation/pages/`

**Interfaces:**
- Consumes: `SiteDetailSectionList`, `SiteDetailPropertiesMenu`, settings fields and `setSiteDetailSectionExpanded`, `MockSettingsNotifier` (Task 8) through `getBaseOverrides(settingsNotifier: ...)`.

- [ ] **Step 1: Write the failing page test**

Create `test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const site = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    minDepth: 5,
    maxDepth: 30,
    rating: 4,
    difficulty: SiteDifficulty.intermediate,
  );

  const stats = SiteDiveStatistics(
    diveCount: 4,
    maxDepthReached: 42,
    minDepthReached: 8,
    longestDiveSeconds: 4500,
    averageDurationSeconds: 2250,
    deepestDiveId: 'dive-deepest',
    shallowestDiveId: 'dive-shallowest',
    longestDiveId: 'dive-longest',
    firstDiveId: 'dive-first',
    lastDiveId: 'dive-last',
  );

  Future<MockSettingsNotifier> pumpPage(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    bool embedded = true,
    Size surface = const Size(600, 1400),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surface;
    addTearDown(tester.view.reset);

    final notifier = MockSettingsNotifier(settings);
    final overrides = await getBaseOverrides(settingsNotifier: notifier);
    final router = GoRouter(
      initialLocation: '/sites/site-1',
      routes: [
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) => SiteDetailPage(
            siteId: state.pathParameters['id']!,
            embedded: embedded,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 4),
          siteDiveStatisticsProvider(site.id).overrideWith((_) async => stats),
        ].cast<Override>(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  List<SiteDetailSectionConfig> hide(SiteDetailSectionId id) => [
    for (final s in SiteDetailSectionConfig.defaultSections)
      s.id == id ? s.copyWith(visible: false) : s,
  ];

  testWidgets('the tune button sits in the embedded header', (tester) async {
    await pumpPage(tester);

    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('the tune button sits in the standalone app bar', (
    tester,
  ) async {
    await pumpPage(tester, embedded: false);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.tune),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a hidden card is not on the page', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(siteDetailSections: hide(SiteDetailSectionId.notes)),
    );

    expect(find.text('Notes'), findsNothing);
    expect(find.text('Dives at this Site'), findsOneWidget);
  });

  testWidgets('the saved order is the page order', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(
        siteDetailSections: [
          const SiteDetailSectionConfig(
            id: SiteDetailSectionId.notes,
            visible: true,
          ),
          for (final s in SiteDetailSectionConfig.defaultSections)
            if (s.id != SiteDetailSectionId.notes) s,
        ],
      ),
    );

    expect(
      tester.getTopLeft(find.text('Notes')).dy,
      lessThan(tester.getTopLeft(find.text('Dives at this Site')).dy),
    );
  });

  testWidgets('the list layout folds every card this site has', (
    tester,
  ) async {
    await pumpPage(
      tester,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );

    // No coordinates, altitude, hazards or access info on this site, so
    // Map, Site Features, Tides, Ecosystem, Altitude, Hazards and Access
    // have nothing to show; the other nine cards fold.
    expect(find.byType(SectionFold), findsNWidgets(9));
    // Inside the folded depth card, so not built.
    expect(find.text('Deepest Dive'), findsNothing);
  });

  testWidgets('unfolding a card shows it and remembers it', (tester) async {
    final notifier = await pumpPage(
      tester,
      settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
    );

    await tester.tap(find.text('Depth Range'));
    await tester.pumpAndSettle();

    expect(
      notifier.state.siteDetailSections
          .firstWhere((s) => s.id == SiteDetailSectionId.depth)
          .expanded,
      isTrue,
    );
    expect(find.text('Deepest Dive'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart
```

Expected: FAIL (no tune icon; settings ignored).

- [ ] **Step 3: Update the imports**

In `lib/features/dive_sites/presentation/pages/site_detail_page.dart`:

- Remove `import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';` (its only use, `_pairOrSingle`, goes away in Step 5).
- Add:

```dart
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
```

- [ ] **Step 4: Replace `build()`**

In `_SiteDetailContentState`, replace the whole `build` method (from `@override` / `Widget build(BuildContext context) {` down to its closing `}` just before the `_pairOrSingle` doc comment) with:

```dart
  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final siteId = widget.siteId;
    final embedded = widget.embedded;
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.siteDetailLayout),
    );

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: EdgeInsets.all(layout.foldsSections ? 8 : 16),
      child: SiteDetailSectionList(
        sections: sections,
        layout: layout,
        cards: _sectionCards(context, site, sections),
        onFoldChanged: (id, expanded) => ref
            .read(settingsProvider.notifier)
            .setSiteDetailSectionExpanded(id, expanded),
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, site),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          if (site.hasCoordinates)
            IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
            ),
          const SiteDetailPropertiesMenu(),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.diveSites_detail_editTooltip,
            onPressed: () => context.push('/sites/$siteId/edit'),
          ),
        ],
      ),
      body: body,
    );
  }

  /// The cards the diver has switched on, built, keyed by id; null where a
  /// card has nothing to show for this site. [SiteDetailSectionList] decides
  /// their order and layout.
  ///
  /// Built here rather than inside the list because several cards watch
  /// providers, and `ref.watch` only works during this state's own build.
  /// Hidden cards are never built, so a diver who hides a card also skips
  /// the lookups behind it.
  Map<SiteDetailSectionId, Widget?> _sectionCards(
    BuildContext context,
    DiveSite site,
    List<SiteDetailSectionConfig> sections,
  ) {
    final hasHazards = site.hazards != null && site.hazards!.isNotEmpty;
    final builders = <SiteDetailSectionId, Widget? Function()>{
      SiteDetailSectionId.map: () =>
          site.hasCoordinates ? _buildMapSection(context, ref, site) : null,
      // The count and the aggregates derived from the dives at this site.
      SiteDetailSectionId.diveStatistics: () =>
          _buildDiveStatisticsSection(context, ref, site),
      SiteDetailSectionId.description: () =>
          _buildDescriptionSection(context, site),
      SiteDetailSectionId.location: () =>
          _buildLocationSection(context, ref, site),
      SiteDetailSectionId.depth: () => _buildDepthSection(context, ref, site),
      SiteDetailSectionId.altitude: () => site.altitude != null
          ? _buildAltitudeSection(context, ref, site)
          : null,
      // Diver-placed annotations. Placement happens on the map, so the add
      // action opens the fullscreen scape armed to place.
      SiteDetailSectionId.features: () => site.hasCoordinates
          ? SiteFeaturesSection(
              siteId: site.id,
              onAddFeature: () =>
                  _showFullscreenMap(context, ref, site, startPlacing: true),
            )
          : null,
      // A quarry or lake has no tides, and a nearby ocean station must not
      // leak in.
      SiteDetailSectionId.tide: () =>
          site.hasCoordinates && site.waterType != WaterType.fresh
          ? TideSection(location: site.location!)
          : null,
      SiteDetailSectionId.reefHealth: () => site.hasCoordinates
          ? ReefSection(location: site.location!, waterType: site.waterType)
          : null,
      SiteDetailSectionId.marineLife: () => SiteMarineLifeSection(
        siteId: site.id,
        location: site.location,
        waterType: site.waterType,
      ),
      // Attachments and dive photos.
      SiteDetailSectionId.media: () => SiteMediaSection(
        siteId: site.id,
        onAddPhotosPressed: () => SiteMediaImportHelper.importPhotosForSite(
          context: context,
          ref: ref,
          siteId: site.id,
        ),
        onAddDocumentPressed: () => DocumentOpenHelper.pickAndAttach(
          context: context,
          ref: ref,
          siteId: site.id,
        ),
        onOpenDocument: (item) => DocumentOpenHelper.open(context, ref, item),
      ),
      SiteDetailSectionId.difficulty: () => site.difficulty != null
          ? _buildDifficultySection(context, site)
          : null,
      SiteDetailSectionId.rating: () => _buildRatingSection(context, site),
      SiteDetailSectionId.hazards: () =>
          hasHazards ? _buildHazardsSection(context, site) : null,
      SiteDetailSectionId.access: () =>
          _hasAccessInfo(site) ? _buildAccessSection(context, site) : null,
      SiteDetailSectionId.notes: () => _buildNotesSection(context, site),
    };
    return {
      for (final section in sections)
        if (section.visible) section.id: builders[section.id]!(),
    };
  }
```

- [ ] **Step 5: Delete `_pairOrSingle`**

Delete the `_pairOrSingle` method and its doc comment (the block beginning `/// Puts two short cards side by side when both have content and the pane is` and ending with `return first ?? second;` and its closing `}`).

- [ ] **Step 6: Add the menu to the embedded header**

In `_buildEmbeddedHeader`, directly before the `IconButton` whose icon is `const Icon(Icons.edit, size: 20)`, add:

```dart
          const SiteDetailPropertiesMenu(iconSize: 20),
```

- [ ] **Step 7: Run the new and existing site page tests**

```bash
flutter test test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart
```

Expected: `All tests passed!`

```bash
flutter test test/features/dive_sites
```

Expected: `All tests passed!` (the density test's "difficulty and rating share a row" and "stack on a narrow pane" now exercise `SiteDetailSectionList` and must still pass).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!` (in particular no `unused_import` for `responsive_section_pair.dart`).

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart
```

```bash
git commit -m "feat(sites): configurable cards and layout on the site details page" -m "The page builds the cards the diver has switched on, applies each card's existing presence rule, and hands them to SiteDetailSectionList, which orders, pairs and folds them. The tune button opens the display-options menu from both the standalone app bar and the embedded header. The hand-built Difficulty + Rating and Hazards + Access pairs are gone; the section list forms them now." -m "Refs #1884"
```

---

### Task 12: Site sections Settings page, route and appearance link

**Files:**
- Create: `lib/features/settings/presentation/pages/site_detail_sections_page.dart`
- Modify: `lib/core/router/app_router.dart` (import + one `GoRoute`)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (`_SectionConfig.hasSiteDetails`, the `'sites'` entry, the body, `_buildSiteDetailsSettings`)
- Test: `test/features/settings/presentation/pages/site_detail_sections_page_test.dart`
- Modify (add tests): `test/features/settings/presentation/pages/section_appearance_page_test.dart`

**Interfaces:**
- Consumes: `SiteDetailSectionConfig` (Task 6), settings setters (Task 8), l10n keys (Task 5).
- Produces: `SiteDetailSectionsPage()`; route path `/settings/site-detail-sections`, name `siteDetailSections` (used by Task 10's menu).

- [ ] **Step 1: Write the failing page test**

Create `test/features/settings/presentation/pages/site_detail_sections_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/settings/presentation/pages/site_detail_sections_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings initial = const AppSettings()])
    : super(initial);

  @override
  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async => state = state.copyWith(siteDetailSections: sections);

  @override
  Future<void> resetSiteDetailSections() async =>
      state = state.copyWith(clearSiteDetailSections: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _FakeSettingsNotifier notifier) async {
  await tester.binding.setSurfaceSize(const Size(400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SiteDetailSectionsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<SiteDetailSectionId> _order(AppSettings settings) => [
  for (final s in settings.siteDetailSections) s.id,
];

void main() {
  testWidgets('shows its title and every card with its description', (
    tester,
  ) async {
    await _pump(tester, _FakeSettingsNotifier());

    expect(find.text('Site Detail Sections'), findsOneWidget);
    expect(find.text('Dives at this Site'), findsOneWidget);
    expect(find.text('Map preview of the site location'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(SiteDetailSectionId.values.length));
    expect(
      find.byIcon(Icons.drag_handle),
      findsNWidgets(SiteDetailSectionId.values.length),
    );
  });

  testWidgets('switching a card off hides only that card', (tester) async {
    final notifier = _FakeSettingsNotifier();
    await _pump(tester, notifier);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final sections = notifier.state.siteDetailSections;
    expect(sections.first.id, SiteDetailSectionId.map);
    expect(sections.first.visible, isFalse);
    expect(sections.skip(1).every((s) => s.visible), isTrue);
  });

  testWidgets('a drop writes the new order', (tester) async {
    final notifier = _FakeSettingsNotifier();
    await _pump(tester, notifier);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 2);
    await tester.pumpAndSettle();

    expect(_order(notifier.state).take(3), [
      SiteDetailSectionId.diveStatistics,
      SiteDetailSectionId.description,
      SiteDetailSectionId.map,
    ]);
  });

  testWidgets('reset to default restores the order and visibility', (
    tester,
  ) async {
    final notifier = _FakeSettingsNotifier(
      AppSettings(
        siteDetailSections: [
          for (final id in SiteDetailSectionId.values.reversed)
            SiteDetailSectionConfig(id: id, visible: false),
        ],
      ),
    );
    await _pump(tester, notifier);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to Default'));
    await tester.pumpAndSettle();

    expect(_order(notifier.state), SiteDetailSectionId.values);
    expect(notifier.state.siteDetailSections.every((s) => s.visible), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/settings/presentation/pages/site_detail_sections_page_test.dart
```

Expected: FAIL, `site_detail_sections_page.dart` does not exist.

- [ ] **Step 3: Write the page**

Create `lib/features/settings/presentation/pages/site_detail_sections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings for which Site Details cards show, and in what order.
///
/// The same list the page's display-options menu edits, with room for each
/// card's description, and the reset to the default order.
class SiteDetailSectionsPage extends ConsumerWidget {
  const SiteDetailSectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_siteDetailSections_title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                ref.read(settingsProvider.notifier).resetSiteDetailSections();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(
                  context.l10n.settings_diveDetailSections_resetToDefault,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.settings_diveDetailSections_configurableSections,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: sections.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(settingsProvider.notifier)
                  .setSiteDetailSections(
                    SiteDetailSectionConfig.moveRenderedSection(
                      sections,
                      [for (final s in sections) s.id],
                      oldIndex,
                      newIndex,
                    ),
                  ),
              itemBuilder: (context, index) {
                final section = sections[index];
                return _SectionTile(
                  key: ValueKey(section.id),
                  section: section,
                  index: index,
                  onToggle: (visible) => ref
                      .read(settingsProvider.notifier)
                      .setSiteDetailSections([
                        for (final s in sections)
                          if (s.id == section.id)
                            s.copyWith(visible: visible)
                          else
                            s,
                      ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
  });

  final SiteDetailSectionConfig section;
  final int index;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: section.visible ? 1.0 : 0.5,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          section.id.localizedDisplayName(context.l10n),
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          section.id.localizedDescription(context.l10n),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(value: section.visible, onChanged: onToggle),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the page test**

```bash
flutter test test/features/settings/presentation/pages/site_detail_sections_page_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Register the route**

In `lib/core/router/app_router.dart`, after `import 'package:submersion/features/settings/presentation/pages/dive_detail_sections_page.dart';` add:

```dart
import 'package:submersion/features/settings/presentation/pages/site_detail_sections_page.dart';
```

Directly after this existing route:

```dart
              GoRoute(
                path: 'dive-detail-sections',
                name: 'diveDetailSections',
                builder: (context, state) => const DiveDetailSectionsPage(),
              ),
```

add:

```dart
              GoRoute(
                path: 'site-detail-sections',
                name: 'siteDetailSections',
                builder: (context, state) => const SiteDetailSectionsPage(),
              ),
```

- [ ] **Step 6: Write the failing appearance tests**

In `test/features/settings/presentation/pages/section_appearance_page_test.dart`, add inside `group('SectionAppearancePage - Sites section', () { ... })`:

```dart
    testWidgets('shows a Site Details group linking to the card settings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('sites'));
      await tester.pumpAndSettle();

      expect(find.text('Site Details'), findsOneWidget);
      expect(find.text('Section Order & Visibility'), findsOneWidget);
    });

    testWidgets('the Site Details row opens the site sections page', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const SectionAppearancePage(sectionKey: 'sites'),
          ),
          GoRoute(
            path: '/settings/site-detail-sections',
            builder: (context, state) =>
                const Scaffold(body: Text('SITE_SECTIONS_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Section Order & Visibility'));
      await tester.pumpAndSettle();

      expect(find.text('SITE_SECTIONS_PAGE'), findsOneWidget);
    });
```

If `go_router` is not already imported in that file, add `import 'package:go_router/go_router.dart';` (the file's current imports include it).

```bash
flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart
```

Expected: the two new tests FAIL (no Site Details group yet); the others pass.

- [ ] **Step 7: Add the Sites group to the appearance page**

In `lib/features/settings/presentation/pages/section_appearance_page.dart`:

a) In `_SectionConfig`, add the field after `final bool hasDiveDetails;`:

```dart
  final bool hasSiteDetails;
```

and the constructor parameter after `this.hasDiveDetails = false,`:

```dart
    this.hasSiteDetails = false,
```

b) In the `'sites'` entry of `_sectionConfigs`, after `hasSiteCards: true,` add:

```dart
    hasSiteDetails: true,
```

c) In the body `ListView` children, directly after the `if (config.hasDiveDetails) ...[ ... ],` block, add:

```dart

        // -- Site Details section (sites only) --
        if (config.hasSiteDetails) ...[
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_siteDetails,
          ),
          ..._buildSiteDetailsSettings(context),
        ],
```

d) Directly after the closing `}` of `_buildDiveDetailsSettings`, add:

```dart

  // ---------------------------------------------------------------------------
  // Site Details section
  // ---------------------------------------------------------------------------

  List<Widget> _buildSiteDetailsSettings(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.reorder),
        title: Text(
          context.l10n.settings_appearance_diveDetails_sectionOrderVisibility,
        ),
        subtitle: Text(
          context
              .l10n
              .settings_appearance_diveDetails_sectionOrderVisibility_subtitle,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/site-detail-sections'),
      ),
    ];
  }
```

- [ ] **Step 8: Run the settings page tests**

```bash
flutter test test/features/settings/presentation/pages
```

Expected: `All tests passed!` (including the existing "Sites section ... NOT Dive Details" test: the new header reads "Site Details").

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
```

```bash
flutter analyze
```

Expected: `No issues found!`

```bash
git add lib/features/settings/presentation/pages/site_detail_sections_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/section_appearance_page.dart test/features/settings/presentation/pages/site_detail_sections_page_test.dart test/features/settings/presentation/pages/section_appearance_page_test.dart
```

```bash
git commit -m "feat(sites): settings page for site detail card order and visibility" -m "Settings > Appearance > Sites gains a Site Details group whose Section Order & Visibility row opens the new Site Detail Sections page: the same toggle-and-drag list the page's menu edits, with each card's description and Reset to Default. The menu's Reorder item opens it by the siteDetailSections route name." -m "Refs #1884"
```

---

### Task 13: Final verification and hand-off

- [ ] **Step 1: Whole-project format and analyze**

```bash
dart format .
```

```bash
git status --short
```

Expected: nothing unstaged from formatting. If `dart format` changed files, commit them: `git add <paths>` then `git commit -m "style: format" -m "Refs #1884"`.

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Scan the diff for forbidden punctuation and attribution**

```bash
git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|\x{2013}| -- )"
```

Expected: no output. (A numeric range such as `2020-2024` written with a hyphen is fine.)

```bash
git log origin/main..HEAD --format=%B | grep -niE "claude|anthropic|co-authored-by"
```

Expected: no output.

- [ ] **Step 3: One full test run**

Run once, not in parallel with any other test run, and without a pipe:

```bash
flutter test
```

Expected: `All tests passed!` If something fails outside the files this plan touched, check whether main itself is red before changing anything.

- [ ] **Step 4: Throwaway screenshots (not committed)**

Create `test/features/dive_sites/presentation/pages/tmp_site_detail_shots_test.dart`, reusing the harness from `site_detail_page_section_config_test.dart` (copy its `site`, `stats` and `pumpPage`; give the site `hazards: 'Strong current at the point'` and `accessNotes: 'Shore entry from the car park'` so both pairs appear). Load a real font in `setUpAll`, never in a test body:

```dart
  setUpAll(() async {
    final bytes = File(
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    ).readAsBytesSync();
    for (final family in ['Roboto', '.SF Pro Text']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });
```

(imports: `dart:io`, `package:flutter/services.dart`). Add three tests at surface `Size(900, 1400)` that end with `await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/<name>.png'));`: `site_detailed` (default settings), `site_list` (`AppSettings(siteDetailLayout: DiveDetailLayout.list)`), and `site_menu_open` (default settings, then tap `find.byIcon(Icons.tune)` and `pumpAndSettle` before the golden). Run:

```bash
flutter test test/features/dive_sites/presentation/pages/tmp_site_detail_shots_test.dart --update-goldens
```

Copy the three PNGs from `test/features/dive_sites/presentation/pages/goldens/` to the scratchpad, then delete the temp test file and that `goldens/` directory. Confirm `git status --short` shows neither.

- [ ] **Step 5: Re-scan the schema ladder right before any push**

```bash
git fetch origin
```

```bash
git show origin/main:lib/core/database/database.dart | grep -n "static const int currentSchemaVersion = "
```

Expected: `215`. If main moved past 215, merge main and renumber this rung above it (scalar, `migrationVersions`, onUpgrade guard, comments, the v216 test) before pushing.

```bash
bash -c 'for n in $(gh api "repos/submersion-app/submersion/pulls?state=open&per_page=100" --jq ".[].number"); do v=$(gh api "repos/submersion-app/submersion/pulls/$n/files?per_page=100" --jq ".[] | select(.filename==\"lib/core/database/database.dart\") | .patch" 2>/dev/null | grep -E "^\+.*currentSchemaVersion = [0-9]+" | grep -oE "[0-9]+;" | tr -d ";"); [ -n "$v" ] && echo "PR #$n claims $v"; done; true'
```

Expected: no other open PR claims 216.

- [ ] **Step 6: Stop and ask**

Do not push or open a PR without the user's go-ahead. Report: the commits, the full-suite result, the three screenshots, and the ladder scan. When approved, the PR body must contain `Closes #1884` and no attribution of any kind.
