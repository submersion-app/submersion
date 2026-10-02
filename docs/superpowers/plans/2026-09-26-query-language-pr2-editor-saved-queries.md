# Query Language PR 2: Editor, Chips and Saved Queries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give divers the two editors of the query tree (a typed field and a rule builder) with every error in their language, chips for the advanced part of the dive filter, and synced saved queries with a Settings > Manage page, on top of the engine PR 1 shipped.

**Architecture:** The engine (`lib/core/query/`) stays pure Dart. This PR adds `lib/core/query/presentation/` (widgets and pure tree-editing helpers that know only the registry, `UnitPrefs`, a `NameResolver` and a `QueryLabels` interface) and `lib/features/query/` (the adapters that build those from the running app: unit settings, a database-backed name index, the ARB label lookup, the saved-query table, repository, sync arms, providers and the Manage page). `DiveFilterState.query` is the one slot both editors write; `toQuery()` already ANDs it with every other axis, so nothing in the compiler or the three dive paths changes.

**Tech Stack:** Flutter, Riverpod 3 (hand-written providers, `StateProvider` from the legacy export), Drift (schema rung 232), go_router, the ARB localisation pipeline (`flutter gen-l10n`, generated files committed).

**Spec:** `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`, Units 2 (printer, errors), 5 (chips), 6 (the surfaces) and 7 (saved queries), plus the sections "Amendments recorded while planning PR 1" and "Deviations recorded during implementation (PR 1)", which are authoritative where the body differs. Program issue: #2365 (`Refs #2365` in the PR body; PR 5 closes it).

## Global Constraints

- Branch `ericgriffin/query-editor-saved-queries` in worktree `.claude/worktrees/query-editor-saved-queries`, off `origin/main` at `ed8edb208b7`. Run every command from that directory. It is initialised (submodules, `flutter pub get`, codegen).
- No em-dashes anywhere (code, comments, docs, commits, PR text). No emojis. No mention of the tool or its vendor in anything written to the repository or GitHub.
- TDD: each task writes its failing test first, runs it red, then implements.
- Every value the user types reaches SQL only through the compiler's bound parameters (PR 1 guarantees this; nothing here builds SQL from text). The saved-query table stores the versioned AST JSON (`queryNodeToJson`), never printed text.
- Anything displaying a number with a unit shows it in the active diver's unit (`UnitPrefs` built from `settingsProvider`) and stores the storage unit (`groundToStorage`).
- Schema rung: `currentSchemaVersion` becomes **232**. Main is at 230; 231 is claimed by four open PRs (#2411, #2407, #2387, #2331). Re-scan open PR diffs right before every push (Task 12 Step 1) and renumber if 232 was taken.
- New ARB keys go in `app_en.arb` (with `@` metadata) and in all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh). Plurals in fr and pt write `=1{{count} ...}`, never a literal 1. `app_de.arb` must not contain "SAC". After editing ARBs run `flutter gen-l10n` and commit the generated `lib/l10n/arb/app_localizations*.dart`.
- Files stay under 800 lines; split by responsibility. Imports grouped dart, flutter, packages, local; `always_use_package_imports` in `lib/`.
- After each task: `dart format .` on the whole project, `flutter analyze --fatal-infos` clean, the task's tests green. Run `flutter test test/architecture/ test/l10n/` after any new `lib/` file or ARB change.
- Local `flutter test` runs: `TMPDIR=/tmp flutter test <paths>`; never pipe the command into `grep` (the pipe hides the exit status). Never run two suites at once.
- Commit only at the plan's commit steps, staging explicit paths. Push with the hooks (`git push`); if the hook's affected-test run hangs for more than 15 minutes, kill it, run the flagged files alone, then `SKIP_TESTS=1 git push`.
- The PR touches `presentation/`, so its description needs screenshots (Task 18). Open it with `Refs #2365`, then `gh pr edit <n> --add-reviewer "@copilot"`.

## Review Focus

Inputs the spec implies but no task's tests would otherwise exercise, most likely to bite first. Each line names the task whose tests now pin it.

1. **A half-typed query must not clear the applied filter.** Typing `depth >` in the text tab is a parse failure; the field shows the error and keeps the last valid tree as the committed value, never commits null. (Task 6, "a parse failure keeps the previous committed value".)
2. **A saved query written by a newer app** (`version` above `kQueryJsonVersion`) loads as a flagged row that the Manage page can delete, with no exception reaching the UI. (Task 14, "a newer JSON version is unreadable, not a crash".)
3. **Changing the unit setting after typing.** A query typed as `depth > 100` under feet, shown later under metres, prints `depth > 30.48` and the chip agrees; nothing is stored in the typed unit. (Task 11, "the chip prints in the current unit setting".)
4. **A saved query whose site was deleted** applies its other conditions and shows the row flagged; the condition is not dropped silently. (Task 14, "an unresolved ref flags the load but keeps the tree" and Task 15's chip test.)
5. **Applying the quick sheet after typing a query on the search page** keeps the query: both surfaces write through `copyWith`, never a fresh `DiveFilterState`. (Task 10, "Apply keeps an advanced query it does not edit".)

## File structure

Created:

| File | Responsibility |
| --- | --- |
| `lib/core/query/units/unit_prefs.dart` (modify) | `==`, `hashCode`, `unitForDimension` |
| `lib/core/query/presentation/query_labels.dart` | `QueryLabels` interface the core widgets read labels through; `MapQueryLabels` for tests |
| `lib/core/query/presentation/query_editor_context.dart` | `QueryEditorContext`: registry, root, prefs, names, labels, clock; parser and printer factories |
| `lib/core/query/presentation/query_tree_edit.dart` | pure functions over the immutable tree: paths, replace, remove, append, negate, group op, normalise, top-level conjuncts |
| `lib/core/query/presentation/query_completions.dart` | `completionsAt`: what to offer at the caret |
| `lib/core/query/presentation/query_error_controller.dart` | `QueryErrorHighlightController`, a `TextEditingController` that underlines one span |
| `lib/core/query/presentation/query_text_field.dart` | the text tab |
| `lib/core/query/presentation/query_field_picker_sheet.dart` | the searchable field tree |
| `lib/core/query/presentation/query_ref_picker_sheet.dart` | the ref (and multi-ref) picker over `NameEntries` |
| `lib/core/query/presentation/query_builder_strings.dart` | the builder's strings, supplied by the caller |
| `lib/core/query/presentation/query_value_editor.dart` | the per-type value editor, `opsFor`, `defaultValueFor` |
| `lib/core/query/presentation/query_condition_row.dart` | one builder row: field, operator, value; `pickCondition` |
| `lib/core/query/presentation/query_builder_group.dart` | a group card: AND/OR toggle, rows, nested groups |
| `lib/core/query/presentation/query_editor.dart` | the two tabs over one tree, `onSave` hook |
| `lib/features/query/presentation/providers/query_unit_prefs_provider.dart` | `UnitPrefs` from `settingsProvider` |
| `lib/features/query/presentation/query_label_lookup.dart` | generated: ARB key to getter switch |
| `lib/features/query/presentation/app_query_labels.dart` | `AppQueryLabels implements QueryLabels` over `AppLocalizations` and the enum display extensions |
| `lib/features/query/data/query_name_index.dart` | `QueryNameIndex implements NameResolver, NameEntries` snapshot, `QueryNameIndexLoader` |
| `lib/features/query/presentation/providers/query_name_index_provider.dart` | `queryNameIndexProvider` |
| `lib/features/query/presentation/dive_query_editor.dart` | `DiveQueryEditor`: assembles the context from providers and renders `QueryEditor` |
| `lib/features/query/presentation/dive_query_chips.dart` | chip labels and chip removal for the dive filter |
| `lib/features/query/domain/entities/saved_query.dart` | `SavedQuery` entity with `copyWith` |
| `lib/features/query/domain/saved_query_load.dart` | `SavedQueryLoad`, `loadSavedQuery`, `unresolvedRefPaths` |
| `lib/features/query/data/repositories/saved_query_repository.dart` | `SavedQueryRepository` |
| `lib/features/query/presentation/providers/saved_query_providers.dart` | repository, list and load providers |
| `lib/features/query/presentation/widgets/save_query_dialog.dart` | the name prompt |
| `lib/features/query/presentation/widgets/saved_query_chip_row.dart` | the "Saved" chip row |
| `lib/features/query/presentation/pages/saved_queries_page.dart` | Settings > Manage > Saved queries |
| `scripts/gen_query_label_lookup.py` | regenerates `query_label_lookup.dart` from `app_en.arb` |

Modified: `lib/core/query/syntax/query_parser.dart` (`NameEntries`), `lib/core/database/database.dart` (table, rung 232), `lib/core/database/performance_indexes.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/features/divers/data/repositories/diver_owned_rows.dart`, `lib/features/dive_log/presentation/pages/dive_search_page.dart`, `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, `lib/core/router/app_router.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, the 11 ARB files and their generated Dart, the spec's deviations section.

---

### Task 1: Unit preferences from settings

**Files:**
- Modify: `lib/core/query/units/unit_prefs.dart`
- Create: `lib/features/query/presentation/providers/query_unit_prefs_provider.dart`
- Test: `test/core/query/units/unit_prefs_equality_test.dart`, `test/features/query/presentation/providers/query_unit_prefs_provider_test.dart`

**Interfaces:**
- Consumes: `UnitPrefs`, `FieldDimension`, `QueryUnit` (PR 1); `settingsProvider`, `AppSettings` (`lib/features/settings/presentation/providers/settings_providers.dart`).
- Produces: `UnitPrefs ==`/`hashCode`; `QueryUnit? unitForDimension(FieldDimension dimension, UnitPrefs prefs)`; `UnitPrefs unitPrefsFromSettings(AppSettings settings)`; `final queryUnitPrefsProvider = Provider<UnitPrefs>`.

- [ ] **Step 1: Write the failing tests**

`test/core/query/units/unit_prefs_equality_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

void main() {
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  test('two prefs with the same units are equal', () {
    expect(
      const UnitPrefs(
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
        weight: WeightUnit.kilograms,
        volume: VolumeUnit.liters,
      ),
      equals(kMetricPrefs),
    );
    expect(imperial, isNot(equals(kMetricPrefs)));
    expect(imperial.hashCode, isNot(kMetricPrefs.hashCode));
  });

  test('unitForDimension names the unit the diver sees', () {
    expect(unitForDimension(FieldDimension.depth, kMetricPrefs), QueryUnit.m);
    expect(unitForDimension(FieldDimension.depth, imperial), QueryUnit.ft);
    expect(
      unitForDimension(FieldDimension.temperature, imperial),
      QueryUnit.f,
    );
    expect(unitForDimension(FieldDimension.pressure, imperial), QueryUnit.psi);
    expect(unitForDimension(FieldDimension.weight, imperial), QueryUnit.lb);
    expect(unitForDimension(FieldDimension.volume, imperial), QueryUnit.cuft);
    expect(unitForDimension(FieldDimension.minutes, imperial), QueryUnit.min);
    expect(unitForDimension(FieldDimension.percent, imperial), isNull);
    expect(unitForDimension(FieldDimension.count, imperial), isNull);
    expect(unitForDimension(FieldDimension.none, imperial), isNull);
  });

  test('a value grounded in the display unit round-trips', () {
    final unit = unitForDimension(FieldDimension.depth, imperial);
    final storage = groundToStorage(100, unit, FieldDimension.depth, imperial);
    final (shown, _) = storageToDisplay(
      storage,
      unit,
      FieldDimension.depth,
      imperial,
    );
    expect(storage, closeTo(30.48, 0.001));
    expect(shown, closeTo(100, 0.0001));
  });
}
```

`test/features/query/presentation/providers/query_unit_prefs_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('queryUnitPrefsProvider mirrors every unit setting', () {
    const settings = AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(queryUnitPrefsProvider),
      const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
    );
  });

  test('the default settings are metric', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(queryUnitPrefsProvider), kMetricPrefs);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/core/query/units/unit_prefs_equality_test.dart test/features/query/presentation/providers/query_unit_prefs_provider_test.dart`
Expected: FAIL. The first file fails on `unitForDimension` undefined and on `equals(kMetricPrefs)` (no `==`); the second fails to compile (`query_unit_prefs_provider.dart` missing).

- [ ] **Step 3: Add equality and `unitForDimension` to `UnitPrefs`**

In `lib/core/query/units/unit_prefs.dart`, inside `class UnitPrefs` after the constructor, add:

```dart
  @override
  bool operator ==(Object other) =>
      other is UnitPrefs &&
      other.depth == depth &&
      other.temperature == temperature &&
      other.pressure == pressure &&
      other.weight == weight &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(depth, temperature, pressure, weight, volume);
```

After `dimensionOfUnit`, add a top-level function:

```dart
/// The unit the diver sees for [dimension] under [prefs]: what a number
/// field's suffix shows and what a typed number without a suffix means.
/// Null for the unitless dimensions (percent, count, none).
QueryUnit? unitForDimension(FieldDimension dimension, UnitPrefs prefs) {
  switch (dimension) {
    case FieldDimension.depth:
      return prefs.depth == DepthUnit.feet ? QueryUnit.ft : QueryUnit.m;
    case FieldDimension.temperature:
      return prefs.temperature == TemperatureUnit.fahrenheit
          ? QueryUnit.f
          : QueryUnit.c;
    case FieldDimension.pressure:
      return prefs.pressure == PressureUnit.psi ? QueryUnit.psi : QueryUnit.bar;
    case FieldDimension.weight:
      return prefs.weight == WeightUnit.pounds ? QueryUnit.lb : QueryUnit.kg;
    case FieldDimension.volume:
      return prefs.volume == VolumeUnit.cubicFeet ? QueryUnit.cuft : QueryUnit.l;
    case FieldDimension.minutes:
      return QueryUnit.min;
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return null;
  }
}
```

- [ ] **Step 4: Create the provider**

`lib/features/query/presentation/providers/query_unit_prefs_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The query engine's view of the diver's unit settings (#2365).
UnitPrefs unitPrefsFromSettings(AppSettings settings) => UnitPrefs(
  depth: settings.depthUnit,
  temperature: settings.temperatureUnit,
  pressure: settings.pressureUnit,
  weight: settings.weightUnit,
  volume: settings.volumeUnit,
);

/// The parser grounds bare numbers and the printer renders them in these
/// units; the value editor shows their suffix. Rebuilds with the settings.
final queryUnitPrefsProvider = Provider<UnitPrefs>(
  (ref) => unitPrefsFromSettings(ref.watch(settingsProvider)),
);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/core/query/units/unit_prefs_equality_test.dart test/features/query/presentation/providers/query_unit_prefs_provider_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/units/unit_prefs.dart lib/features/query/presentation/providers/query_unit_prefs_provider.dart test/core/query/units/unit_prefs_equality_test.dart test/features/query/presentation/providers/query_unit_prefs_provider_test.dart
git commit -m "feat(query): unit prefs from the diver's settings, with value equality and the display unit per dimension"
```

---

### Task 2: Labels: the interface, the generated lookup, operators and enum values

**Files:**
- Create: `lib/core/query/presentation/query_labels.dart`, `lib/features/query/presentation/query_label_lookup.dart` (generated), `lib/features/query/presentation/app_query_labels.dart`, `scripts/gen_query_label_lookup.py`
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locales (the `query_op_*` keys only; every other key of this PR lands in Task 18)
- Test: `test/features/query/presentation/query_labels_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (`package:submersion/l10n/arb/app_localizations.dart`), `l10nForLocaleTag` (`package:submersion/l10n/l10n_extension.dart`), `QueryField`, `QueryRelation`, `QueryOp`, `QuerySubject`, the enum display extensions `CurrentStrengthDisplay`, `WaterTypeDisplay`, `EntryMethodDisplay` (`lib/features/dive_log/presentation/widgets/environment_enum_display.dart`), `DiveModeDisplay` (`.../tank_enum_display.dart`), `WeightTypeDisplay` (`lib/features/weight_planner/presentation/widgets/weight_enum_display.dart`), `EquipmentTypeDisplay`, `EquipmentStatusDisplay` (`lib/features/equipment/presentation/utils/equipment_enum_display.dart`), `weekdayAbbreviation` (`lib/features/dive_log/presentation/widgets/weekday_filter_selector.dart`).
- Produces:

```dart
abstract class QueryLabels {
  String field(QueryField field);
  String relation(QueryRelation relation);
  String entity(QuerySubject subject);
  String op(QueryOp op);
  String enumValue(QueryField field, String value);
}
class MapQueryLabels implements QueryLabels { const MapQueryLabels({fields /* by field key */, relations /* by relation key */, entities, ops, enums /* field key -> value -> label */}); }
String queryLabelForKey(AppLocalizations l10n, String key); // generated; unknown key returns the key
class AppQueryLabels implements QueryLabels { AppQueryLabels(BuildContext context); }
```

The fixture registry's label keys are all `x`, so the map implementation keys on field and relation keys, not label keys; the app implementation reads the label key.

- [ ] **Step 1: Write the failing test**

`test/features/query/presentation/query_labels_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/query_label_lookup.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_app.dart';

void main() {
  final en = l10nForLocaleTag('en');

  test('every query_ key in app_en.arb resolves through the lookup', () {
    final arb =
        jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where(
      (k) => k.startsWith('query_') && !k.startsWith('@'),
    );
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        queryLabelForKey(en, key),
        isNot(key),
        reason: '$key is missing from query_label_lookup.dart; '
            'run python3 scripts/gen_query_label_lookup.py',
      );
    }
  });

  test('every registry label key resolves, an unknown key returns itself', () {
    for (final entity in appQueryRegistry.entities) {
      for (final f in entity.fields) {
        expect(queryLabelForKey(en, f.labelKey), isNot(f.labelKey));
      }
      for (final r in entity.relations) {
        expect(queryLabelForKey(en, r.labelKey), isNot(r.labelKey));
      }
      final entityKey = 'query_entity_${entity.subject.name}';
      expect(queryLabelForKey(en, entityKey), isNot(entityKey));
    }
    expect(queryLabelForKey(en, 'query_no_such_key'), 'query_no_such_key');
  });

  testWidgets('AppQueryLabels localises fields, entities, ops and enums', (
    tester,
  ) async {
    late AppQueryLabels labels;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) {
            labels = AppQueryLabels(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final dives = appQueryRegistry.entityFor(QuerySubject.dives);
    expect(labels.field(dives.field('depth')!), 'Max depth');
    expect(labels.relation(dives.relation('site')!), 'Site');
    expect(labels.entity(QuerySubject.sites), 'Dive sites');
    expect(labels.op(QueryOp.gte), 'at least');
    expect(labels.op(QueryOp.isEmpty), 'is not set');
    expect(labels.enumValue(dives.field('waterType')!, 'salt'), 'Salt water');
    expect(labels.enumValue(dives.field('weekday')!, 'monday'), 'Mon');
    // An unknown enum value falls back to its stored name.
    expect(labels.enumValue(dives.field('waterType')!, 'brine'), 'brine');
  });
}
```

If `WaterType.salt.localizedName(en)` is not the string `Salt water`, read `environment_enum_display.dart` and use the real string; the test pins the extension, not this plan's guess.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/query_labels_test.dart`
Expected: FAIL to compile (`query_label_lookup.dart`, `app_query_labels.dart` missing).

- [ ] **Step 3: Add the operator keys to every ARB**

In `lib/l10n/arb/app_en.arb`, directly after the last `@query_weights_type` entry (the `query_*` block near line 26462 onward), add:

```json
  "query_op_eq": "is",
  "@query_op_eq": {"description": "Operator label in the query builder"},
  "query_op_neq": "is not",
  "@query_op_neq": {"description": "Operator label in the query builder"},
  "query_op_lt": "less than",
  "@query_op_lt": {"description": "Operator label in the query builder"},
  "query_op_lte": "at most",
  "@query_op_lte": {"description": "Operator label in the query builder"},
  "query_op_gt": "more than",
  "@query_op_gt": {"description": "Operator label in the query builder"},
  "query_op_gte": "at least",
  "@query_op_gte": {"description": "Operator label in the query builder"},
  "query_op_contains": "contains",
  "@query_op_contains": {"description": "Operator label in the query builder"},
  "query_op_inList": "is one of",
  "@query_op_inList": {"description": "Operator label in the query builder"},
  "query_op_between": "between",
  "@query_op_between": {"description": "Operator label in the query builder"},
  "query_op_isEmpty": "is not set",
  "@query_op_isEmpty": {"description": "Operator label in the query builder"},
  "query_op_isSet": "is set",
  "@query_op_isSet": {"description": "Operator label in the query builder"},
```

Add the same eleven keys, translated, next to each locale's `query_*` block in `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh` (values only, no `@` entries, matching those files' convention). Suggested translations (adjust to the file's register):

| key | de | es | fr | it | nl | pt |
| --- | --- | --- | --- | --- | --- | --- |
| eq | ist | es | est | è | is | é |
| neq | ist nicht | no es | n'est pas | non è | is niet | não é |
| lt | kleiner als | menor que | inférieur à | minore di | kleiner dan | menor que |
| lte | höchstens | como máximo | au plus | al massimo | hoogstens | no máximo |
| gt | größer als | mayor que | supérieur à | maggiore di | groter dan | maior que |
| gte | mindestens | como mínimo | au moins | almeno | minstens | pelo menos |
| contains | enthält | contiene | contient | contiene | bevat | contém |
| inList | ist eines von | es uno de | est parmi | è uno di | is een van | é um de |
| between | zwischen | entre | entre | tra | tussen | entre |
| isEmpty | nicht gesetzt | sin valor | non renseigné | non impostato | niet ingesteld | não definido |
| isSet | gesetzt | con valor | renseigné | impostato | ingesteld | definido |

For ar, he, hu and zh write the equivalents in those languages (hu: "egyenlő", "nem egyenlő", "kisebb mint", "legfeljebb", "nagyobb mint", "legalább", "tartalmazza", "egyike", "között", "nincs megadva", "meg van adva"; zh: "是", "不是", "小于", "至多", "大于", "至少", "包含", "是其中之一", "介于", "未设置", "已设置"; ar and he in the same sense). Then:

```bash
flutter gen-l10n
TMPDIR=/tmp flutter test test/l10n/
```

Expected: the l10n guard tests pass (parity across locales, no duplicate keys, no "SAC" in German).

- [ ] **Step 4: Write the generator and generate the lookup**

`scripts/gen_query_label_lookup.py`:

```python
#!/usr/bin/env python3
"""Regenerates lib/features/query/presentation/query_label_lookup.dart.

The query registry names labels by ARB key (query_<subject>_<field>); Dart
has no reflection, so this switch maps each key to its AppLocalizations
getter. Run after adding a query_* key to app_en.arb; the guard test
test/features/query/presentation/query_labels_test.dart fails until you do.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ARB = ROOT / "lib" / "l10n" / "arb" / "app_en.arb"
OUT = ROOT / "lib" / "features" / "query" / "presentation" / "query_label_lookup.dart"

keys = sorted(
    k for k, v in json.loads(ARB.read_text(encoding="utf-8")).items()
    if k.startswith("query_") and isinstance(v, str) and "{" not in v
)
lines = [
    "// GENERATED by scripts/gen_query_label_lookup.py from app_en.arb.",
    "// Do not edit by hand; rerun the script after adding a query_* key.",
    "",
    "import 'package:submersion/l10n/arb/app_localizations.dart';",
    "",
    "/// The localized label for a registry label key, or the key itself when",
    "/// no such string exists (a registry guard test keeps that from shipping).",
    "/// Keys with placeholders are getters with arguments and are not listed.",
    "String queryLabelForKey(AppLocalizations l10n, String key) {",
    "  switch (key) {",
]
for k in keys:
    lines.append(f"    case '{k}':")
    lines.append(f"      return l10n.{k};")
lines += [
    "    default:",
    "      return key;",
    "  }",
    "}",
    "",
]
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)} with {len(keys)} keys")
```

Keys whose English value carries a `{placeholder}` generate a method, not a getter, so the script skips them; the Task 2 guard test therefore also skips them (`&& !(arb[k] as String).contains('{')` in its `where`). Add that clause to the test's first case now.

Run: `python3 scripts/gen_query_label_lookup.py` (system python 3.9 is fine for this script). Expected: `wrote lib/features/query/presentation/query_label_lookup.dart with 149 keys` (138 field and entity keys plus the 11 operator keys).

- [ ] **Step 5: Write the interface and the app implementation**

`lib/core/query/presentation/query_labels.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// What the editor widgets need to show a registry item to a person. The
/// core widgets never touch AppLocalizations; the feature layer implements
/// this over it (AppQueryLabels), tests over maps.
abstract class QueryLabels {
  String field(QueryField field);

  String relation(QueryRelation relation);

  /// The label for an entity, used for breadcrumbs in the field picker.
  String entity(QuerySubject subject);

  String op(QueryOp op);

  /// The label for one stored enum value of [field]; the stored name when
  /// the value is unknown.
  String enumValue(QueryField field, String value);
}

/// A [QueryLabels] over maps, for tests and previews. Keyed by field and
/// relation KEY (not label key), so a fixture whose label keys are all the
/// same can still name its fields; an unmapped item shows its key.
class MapQueryLabels implements QueryLabels {
  const MapQueryLabels({
    this.fields = const {},
    this.relations = const {},
    this.entities = const {},
    this.ops = const {},
    this.enums = const {},
  });

  final Map<String, String> fields;
  final Map<String, String> relations;
  final Map<QuerySubject, String> entities;
  final Map<QueryOp, String> ops;

  /// field key -> stored value -> label.
  final Map<String, Map<String, String>> enums;

  @override
  String field(QueryField field) => fields[field.key] ?? field.key;

  @override
  String relation(QueryRelation relation) =>
      relations[relation.key] ?? relation.key;

  @override
  String entity(QuerySubject subject) => entities[subject] ?? subject.name;

  @override
  String op(QueryOp op) => ops[op] ?? op.name;

  @override
  String enumValue(QueryField field, String value) =>
      enums[field.key]?[value] ?? value;
}
```

`lib/features/query/presentation/app_query_labels.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/query/presentation/query_label_lookup.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [QueryLabels] over the app's ARB strings and enum display extensions.
///
/// Enum values are matched by the registry field's label key, which names
/// the subject and field (`query_dives_waterType`), so the same stored name
/// on two entities cannot be confused.
class AppQueryLabels implements QueryLabels {
  AppQueryLabels(this._context) : _l10n = _context.l10n;

  final BuildContext _context;
  final AppLocalizations _l10n;

  static const _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  String field(QueryField field) => queryLabelForKey(_l10n, field.labelKey);

  @override
  String relation(QueryRelation relation) =>
      queryLabelForKey(_l10n, relation.labelKey);

  @override
  String entity(QuerySubject subject) =>
      queryLabelForKey(_l10n, 'query_entity_${subject.name}');

  @override
  String op(QueryOp op) => queryLabelForKey(_l10n, 'query_op_${op.name}');

  @override
  String enumValue(QueryField field, String value) {
    T? byName<T extends Enum>(List<T> values) {
      for (final v in values) {
        if (v.name == value) return v;
      }
      return null;
    }

    switch (field.labelKey) {
      case 'query_dives_waterType':
        return byName(WaterType.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_currentStrength':
        return byName(CurrentStrength.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_entryMethod':
      case 'query_dives_exitMethod':
        return byName(EntryMethod.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_diveMode':
        return byName(DiveMode.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_weekday':
        final i = _weekdays.indexOf(value);
        return i < 0 ? value : weekdayAbbreviation(_context, i + 1);
      case 'query_weights_type':
        return byName(WeightType.values)?.localizedName(_l10n) ?? value;
      case 'query_equipment_type':
        return byName(EquipmentType.values)?.localizedName(_l10n) ?? value;
      case 'query_equipment_status':
        return byName(EquipmentStatus.values)?.localizedName(_l10n) ?? value;
      default:
        return value;
    }
  }
}
```

If any of the display extensions is named differently or takes a `BuildContext`, open the file named in "Consumes" and match its real signature; the test in Step 1 is the arbiter. If an enum lives in another import than `core/constants/enums.dart`, follow the import the display file itself uses.

- [ ] **Step 6: Run the test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/query_labels_test.dart test/features/query/`
Expected: PASS, including PR 1's `query_registry_guards_test.dart` ("every label key exists in every locale").

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/features/query/presentation/app_query_labels.dart scripts/gen_query_label_lookup.py lib/l10n/arb/ test/features/query/presentation/query_labels_test.dart
git commit -m "feat(query): label lookup for registry keys, operator labels in every locale, enum value labels"
```

---

### Task 3: The name index: refs by label from the database

**Files:**
- Create: `lib/features/query/data/query_name_index.dart`, `lib/features/query/presentation/providers/query_name_index_provider.dart`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (one case)
- Test: `test/features/query/data/query_name_index_test.dart`, `test/features/query/presentation/providers/query_name_index_provider_test.dart`

**Interfaces:**
- Consumes: `NameResolver`, `RefValue`, `QuerySubject`, `appQueryRegistry` (entity `table`, `idColumn`, `diverScopeColumn`, the `name` field's `sql`), `suggestNames`, `AppDatabase`, `DiveRepository.watchTables(Set<String>)`, `currentDiverIdProvider`, `diveRepositoryProvider`.
- Produces:

```dart
class QueryNameIndex implements NameResolver {   // Task 5 adds NameEntries
  const QueryNameIndex(Map<QuerySubject, List<RefValue>> entries);
  static const empty = QueryNameIndex({});
  List<RefValue> entries(QuerySubject kind);
  String? labelOf(QuerySubject kind, String id);
  RefValue? resolve(QuerySubject kind, String text);       // exact, case-insensitive, trimmed
  List<String> candidates(QuerySubject kind, String text); // suggestNames over labels
}
class QueryNameIndexLoader {
  QueryNameIndexLoader(AppDatabase db);
  static const refSubjects = [sites, trips, centers, computers, courses, buddies, tags, diveTypes, equipment, species];
  static Set<String> get tables;                           // the ten tables
  Future<QueryNameIndex> load({String? diverId});
}
final queryNameIndexProvider = FutureProvider<QueryNameIndex>;
```

- [ ] **Step 1: Write the failing tests**

`test/features/query/data/query_name_index_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/features/query/data/query_name_index.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

void main() {
  group('QueryNameIndex', () {
    const index = QueryNameIndex({
      QuerySubject.sites: [
        RefValue('s1', 'Salt Pier'),
        RefValue('s2', 'Hilma Hooker'),
      ],
    });

    test('resolve is exact, trimmed and case-insensitive', () {
      expect(
        index.resolve(QuerySubject.sites, 'salt pier'),
        const RefValue('s1', 'Salt Pier'),
      );
      expect(index.resolve(QuerySubject.sites, '  Hilma Hooker '), isNotNull);
      expect(index.resolve(QuerySubject.sites, 'Salt'), isNull);
      expect(index.resolve(QuerySubject.buddies, 'Salt Pier'), isNull);
    });

    test('candidates rank by similarity and labelOf finds by id', () {
      expect(index.candidates(QuerySubject.sites, 'salt peer'), ['Salt Pier']);
      expect(index.labelOf(QuerySubject.sites, 's2'), 'Hilma Hooker');
      expect(index.labelOf(QuerySubject.sites, 'nope'), isNull);
      expect(index.entries(QuerySubject.trips), isEmpty);
    });
  });

  group('QueryNameIndexLoader', () {
    late AppDatabase db;
    setUp(() async {
      db = await setUpTestDatabase();
      await seedQueryFixture(db);
    });
    tearDown(tearDownTestDatabase);

    test('loads every ref subject, scoped to the diver plus unowned rows', () async {
      final index = await QueryNameIndexLoader(db).load(diverId: 'me');
      expect(
        index.entries(QuerySubject.sites).map((r) => r.label),
        containsAll(['Salt Pier', 'Hilma Hooker', 'Cenote']),
      );
      expect(
        index.entries(QuerySubject.buddies).map((r) => r.id),
        containsAll(['b1', 'b2']),
      );
      expect(index.resolve(QuerySubject.sites, 'cenote')?.id, 's3');
      // Every subject answers, even with no rows.
      for (final s in QueryNameIndexLoader.refSubjects) {
        expect(index.entries(s), isA<List<RefValue>>());
      }
    });

    test('another diver\'s private rows stay out of the index', () async {
      final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
        "VALUES ('b-other', 'other', 'Zed', $now, $now)",
      );
      final index = await QueryNameIndexLoader(db).load(diverId: 'me');
      expect(index.labelOf(QuerySubject.buddies, 'b-other'), isNull);
      final all = await QueryNameIndexLoader(db).load(diverId: 'other');
      expect(all.labelOf(QuerySubject.buddies, 'b-other'), 'Zed');
    });

    test('the tables it reads are the ten ref tables', () {
      expect(QueryNameIndexLoader.tables, {
        'dive_sites',
        'trips',
        'dive_centers',
        'dive_computers',
        'courses',
        'buddies',
        'tags',
        'dive_types',
        'equipment',
        'species',
      });
    });
  });
}
```

Read `dive_query_fixture.dart` lines 51-62 before running: if the fixture's buddies carry `diver_id = 'me'` both loader tests hold as written; if they carry a null `diver_id` they are "unowned" and still visible, which the first test also accepts. Adjust the raw INSERT's column list to the buddies table's NOT NULL columns.

`test/features/query/presentation/providers/query_name_index_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  test('reloads when a ref table changes', () async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('me');

    final first = await container.read(queryNameIndexProvider.future);
    expect(first.labelOf(QuerySubject.sites, 's9'), isNull);

    final now = DateTime(2025, 6, 2).millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s9', 'New Wall', $now, $now)",
    );
    // The tick is debounced; give it a moment.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final second = await container.read(queryNameIndexProvider.future);
    expect(second.labelOf(QuerySubject.sites, 's9'), 'New Wall');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/query/data/query_name_index_test.dart test/features/query/presentation/providers/query_name_index_provider_test.dart`
Expected: FAIL to compile (both `lib` files missing).

- [ ] **Step 3: Write the index and loader**

`lib/features/query/data/query_name_index.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// A snapshot of every referenceable row's id and label (#2365).
///
/// The parser resolves `site = "Salt Pier"` through [resolve]; the builder's
/// ref picker lists [entries]; a saved query checks its ids through
/// [labelOf]. A snapshot, not a live query, so parsing stays synchronous;
/// the provider reloads it when any of its tables changes.
class QueryNameIndex implements NameResolver {
  const QueryNameIndex(this._entries);

  static const empty = QueryNameIndex({});

  final Map<QuerySubject, List<RefValue>> _entries;

  List<RefValue> entries(QuerySubject kind) => _entries[kind] ?? const [];

  String? labelOf(QuerySubject kind, String id) {
    for (final r in entries(kind)) {
      if (r.id == id) return r.label;
    }
    return null;
  }

  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final wanted = text.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final r in entries(kind)) {
      if (r.label.trim().toLowerCase() == wanted) return r;
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, entries(kind).map((r) => r.label));
}

/// Loads a [QueryNameIndex] from the registry's ref-target tables.
class QueryNameIndexLoader {
  QueryNameIndexLoader(this._db);

  final AppDatabase _db;

  /// The subjects a relation can point at by name.
  static const refSubjects = [
    QuerySubject.sites,
    QuerySubject.trips,
    QuerySubject.centers,
    QuerySubject.computers,
    QuerySubject.courses,
    QuerySubject.buddies,
    QuerySubject.tags,
    QuerySubject.diveTypes,
    QuerySubject.equipment,
    QuerySubject.species,
  ];

  /// The tables a change tick must follow.
  static Set<String> get tables => {
    for (final s in refSubjects) appQueryRegistry.entityFor(s).table,
  };

  /// Every row the diver can see: their own plus rows with no owner. A
  /// subject with no diver column (species) is global.
  Future<QueryNameIndex> load({String? diverId}) async {
    final out = <QuerySubject, List<RefValue>>{};
    for (final subject in refSubjects) {
      final entity = appQueryRegistry.entityFor(subject);
      final nameSql = entity.field('name')!.sql.replaceAll('{r}', 't');
      final scope = entity.diverScopeColumn;
      final where = scope == null
          ? ''
          : diverId == null
          ? 'WHERE t.$scope IS NULL'
          : 'WHERE (t.$scope = ? OR t.$scope IS NULL)';
      final rows = await _db
          .customSelect(
            'SELECT t.${entity.idColumn} AS id, $nameSql AS label '
            'FROM ${entity.table} t $where ORDER BY label',
            variables: [
              if (scope != null && diverId != null) Variable<String>(diverId),
            ],
          )
          .get();
      out[subject] = [
        for (final r in rows)
          if (r.read<String?>('label') case final label? when label.isNotEmpty)
            RefValue(r.read<String>('id'), label),
      ];
    }
    return QueryNameIndex(out);
  }
}
```

The table and column names come from the registry (declared string constants), never from user input; the diver id is bound.

`lib/features/query/presentation/providers/query_name_index_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/query_name_index.dart';

/// The ref names the parser, the builder's pickers and saved-query loading
/// resolve against (#2365). Reloads when any ref table changes, through the
/// dive repository's table tick, so a synced site or a renamed buddy shows
/// up without a restart.
final queryNameIndexProvider = FutureProvider<QueryNameIndex>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTables(QueryNameIndexLoader.tables));
  return QueryNameIndexLoader(
    DatabaseService.instance.database,
  ).load(diverId: diverId);
});
```

- [ ] **Step 4: Register the provider in the tick smoke test**

In `test/architecture/provider_tick_build_smoke_test.dart`, add a group beside the existing `_tickGroup(...)` calls:

```dart
  _tickGroup('query', [
    (
      name: 'queryNameIndexProvider',
      read: (c) => c.read(queryNameIndexProvider.future),
    ),
  ]);
```

with the import `package:submersion/features/query/presentation/providers/query_name_index_provider.dart`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/features/query/data/query_name_index_test.dart test/features/query/presentation/providers/query_name_index_provider_test.dart test/architecture/provider_change_tick_test.dart test/architecture/provider_tick_build_smoke_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/data/query_name_index.dart lib/features/query/presentation/providers/query_name_index_provider.dart test/features/query/data/query_name_index_test.dart test/features/query/presentation/providers/query_name_index_provider_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(query): database-backed name index for refs, reloaded on any ref table change"
```

---

### Task 4: Pure tree editing helpers

**Files:**
- Create: `lib/core/query/presentation/query_tree_edit.dart`
- Test: `test/core/query/presentation/query_tree_edit_test.dart`

**Interfaces:**
- Consumes: the node classes (PR 1).
- Produces:

```dart
typedef NodePath = List<int>;   // child index per level; NotNode and ScopedNode have one child at index 0
QueryNode? nodeAt(QueryNode root, NodePath path);
QueryNode replaceAt(QueryNode root, NodePath path, QueryNode replacement);
QueryNode? removeAt(QueryNode root, NodePath path);       // emptied groups collapse upward; one-child groups stay; null when nothing is left
QueryNode appendChild(QueryNode root, NodePath groupPath, QueryNode child);
QueryNode toggleNegation(QueryNode root, NodePath path);
QueryNode setGroupOp(QueryNode root, NodePath groupPath, {required bool and});
QueryNode? normalizeQuery(QueryNode? node);               // empty groups go, NOT NOT x is x, one-child groups stay (the builder needs its card)
List<QueryNode> topLevelConjuncts(QueryNode? node);
QueryNode? removeTopLevelConjunct(QueryNode? node, int index);  // a single survivor is unwrapped (chips have no card to keep)
```

One-child groups are kept on purpose: a diver who just added a group with its first row must see the card, and the compiler and printer accept a one-child group like any other. The parser never produces one, so a tree typed in the text tab is unchanged by `normalizeQuery`.

- [ ] **Step 1: Write the failing test**

`test/core/query/presentation/query_tree_edit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';

void main() {
  ConditionNode cond(String key, double v) =>
      ConditionNode(FieldPath([key]), QueryOp.gt, NumberValue(v, null));
  final a = cond('depth', 30);
  final b = cond('rating', 3);
  final c = cond('otu', 1);

  test('nodeAt walks groups, NOT and scoped nodes', () {
    final root = AndNode([a, NotNode(OrNode([b, c]))]);
    expect(nodeAt(root, []), root);
    expect(nodeAt(root, [1, 0, 1]), c);
    expect(nodeAt(root, [1, 0]), OrNode([b, c]));
    expect(nodeAt(root, [5]), isNull);
    expect(nodeAt(ScopedNode(FieldPath(['gear']), a), [0]), a);
  });

  test('replaceAt returns a new tree and leaves the old one intact', () {
    final root = AndNode([a, b]);
    final out = replaceAt(root, [1], c);
    expect(out, AndNode([a, c]));
    expect(root, AndNode([a, b]));
    expect(replaceAt(root, [], c), c);
  });

  test('removeAt keeps a one-child group, drops an emptied one', () {
    // A group with one row left stays a group: the builder shows a card
    // the diver can keep adding to. Only an emptied group, NOT or scope
    // disappears, and that collapses upward.
    expect(removeAt(AndNode([a, b]), [0]), AndNode([b]));
    expect(
      removeAt(AndNode([a, OrNode([b, c])]), [1, 0]),
      AndNode([a, OrNode([c])]),
    );
    expect(removeAt(AndNode([a, OrNode([b])]), [1, 0]), AndNode([a]));
    expect(removeAt(a, []), isNull);
    expect(removeAt(NotNode(a), [0]), isNull);
    expect(removeAt(AndNode([a, NotNode(b)]), [1, 0]), AndNode([a]));
    expect(removeAt(AndNode([a]), [0]), isNull);
  });

  test('appendChild adds to the group at the path', () {
    expect(appendChild(AndNode([a]), [], b), AndNode([a, b]));
    expect(
      appendChild(AndNode([a, OrNode([b])]), [1], c),
      AndNode([a, OrNode([b, c])]),
    );
    expect(() => appendChild(a, [], b), throwsArgumentError);
  });

  test('toggleNegation wraps and unwraps', () {
    expect(toggleNegation(AndNode([a, b]), [0]), AndNode([NotNode(a), b]));
    expect(toggleNegation(AndNode([NotNode(a), b]), [0]), AndNode([a, b]));
  });

  test('setGroupOp swaps AND and OR keeping the children', () {
    expect(setGroupOp(AndNode([a, b]), [], and: false), OrNode([a, b]));
    expect(setGroupOp(AndNode([a, b]), [], and: true), AndNode([a, b]));
    expect(
      setGroupOp(NotNode(OrNode([a, b])), [0], and: true),
      NotNode(AndNode([a, b])),
    );
  });

  test('normalizeQuery drops empty groups and double NOT, keeps nesting', () {
    expect(normalizeQuery(AndNode([a])), AndNode([a]));
    expect(normalizeQuery(OrNode([AndNode([a])])), OrNode([AndNode([a])]));
    expect(normalizeQuery(NotNode(NotNode(a))), a);
    expect(normalizeQuery(AndNode([])), isNull);
    expect(normalizeQuery(AndNode([a, OrNode([])])), AndNode([a]));
    expect(normalizeQuery(AndNode([a, OrNode([b])])), AndNode([a, OrNode([b])]));
    expect(normalizeQuery(null), isNull);
    expect(normalizeQuery(NotNode(AndNode([]))), isNull);
  });

  test('top-level conjuncts are the AND children or the node itself', () {
    expect(topLevelConjuncts(null), isEmpty);
    expect(topLevelConjuncts(a), [a]);
    expect(topLevelConjuncts(AndNode([a, b])), [a, b]);
    expect(topLevelConjuncts(OrNode([a, b])), [OrNode([a, b])]);
    expect(removeTopLevelConjunct(AndNode([a, b, c]), 1), AndNode([a, c]));
    expect(removeTopLevelConjunct(AndNode([a, b]), 0), b);
    expect(removeTopLevelConjunct(a, 0), isNull);
    expect(removeTopLevelConjunct(OrNode([a, b]), 0), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_tree_edit_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the helpers**

`lib/core/query/presentation/query_tree_edit.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';

/// Where a node sits in a tree: one child index per level. Group children
/// are indexed in order; a [NotNode]'s child and a [ScopedNode]'s inner tree
/// are index 0.
typedef NodePath = List<int>;

/// Pure edits over the immutable tree (#2365). Every function returns a new
/// tree and never touches the input; the builder holds the result and hands
/// it to the filter, which hashes it.

QueryNode? nodeAt(QueryNode root, NodePath path) {
  var node = root;
  for (final i in path) {
    final children = _children(node);
    if (i < 0 || i >= children.length) return null;
    node = children[i];
  }
  return node;
}

QueryNode replaceAt(QueryNode root, NodePath path, QueryNode replacement) {
  if (path.isEmpty) return replacement;
  final children = _children(root);
  final i = path.first;
  if (i < 0 || i >= children.length) {
    throw ArgumentError('no child $i under ${root.runtimeType}');
  }
  final updated = [
    for (var k = 0; k < children.length; k++)
      k == i ? replaceAt(children[k], path.sublist(1), replacement) : children[k],
  ];
  return _withChildren(root, updated);
}

/// Removes the node at [path]. A group left with one child stays a group
/// (the builder keeps showing its card); a group, NOT or scope left empty
/// is removed in turn. Null when the whole tree is gone.
QueryNode? removeAt(QueryNode root, NodePath path) {
  if (path.isEmpty) return null;
  final children = _children(root);
  final i = path.first;
  if (i < 0 || i >= children.length) {
    throw ArgumentError('no child $i under ${root.runtimeType}');
  }
  final replaced = path.length == 1
      ? null
      : removeAt(children[i], path.sublist(1));
  final updated = [
    for (var k = 0; k < children.length; k++)
      if (k != i) children[k] else if (replaced != null) replaced,
  ];
  if (updated.isEmpty) return null;
  return _withChildren(root, updated);
}

QueryNode appendChild(QueryNode root, NodePath groupPath, QueryNode child) {
  final group = nodeAt(root, groupPath);
  return switch (group) {
    AndNode(:final children) => replaceAt(
      root,
      groupPath,
      AndNode([...children, child]),
    ),
    OrNode(:final children) => replaceAt(
      root,
      groupPath,
      OrNode([...children, child]),
    ),
    _ => throw ArgumentError('$groupPath is not a group'),
  };
}

QueryNode toggleNegation(QueryNode root, NodePath path) {
  final node = nodeAt(root, path);
  if (node == null) throw ArgumentError('no node at $path');
  return replaceAt(
    root,
    path,
    node is NotNode ? node.child : NotNode(node),
  );
}

QueryNode setGroupOp(QueryNode root, NodePath groupPath, {required bool and}) {
  final group = nodeAt(root, groupPath);
  final children = switch (group) {
    AndNode(:final children) => children,
    OrNode(:final children) => children,
    _ => throw ArgumentError('$groupPath is not a group'),
  };
  return replaceAt(
    root,
    groupPath,
    and ? AndNode(children) : OrNode(children),
  );
}

/// A builder-made tree with no empty groups and no NOT NOT. One-child
/// groups are kept on purpose: a diver who just added a group with its
/// first row must see the card, and the compiler and printer take a
/// one-child group as they take any other.
QueryNode? normalizeQuery(QueryNode? node) {
  switch (node) {
    case null:
      return null;
    case AndNode(:final children):
      final kept = [for (final c in children) ?normalizeQuery(c)];
      return kept.isEmpty ? null : AndNode(kept);
    case OrNode(:final children):
      final kept = [for (final c in children) ?normalizeQuery(c)];
      return kept.isEmpty ? null : OrNode(kept);
    case NotNode(:final child):
      final inner = normalizeQuery(child);
      if (inner == null) return null;
      return inner is NotNode ? inner.child : NotNode(inner);
    case ScopedNode(:final path, :final inner):
      final kept = normalizeQuery(inner);
      return kept == null ? null : ScopedNode(path, kept);
    case ConditionNode():
    case TextNode():
      return node;
  }
}

/// The chips: one per top-level AND child, or the node itself.
List<QueryNode> topLevelConjuncts(QueryNode? node) => switch (node) {
  null => const [],
  AndNode(:final children) => children,
  _ => [node],
};

/// The tree without the chip at [index]. A single survivor is unwrapped:
/// a chip bar has no group card to keep.
QueryNode? removeTopLevelConjunct(QueryNode? node, int index) {
  final parts = topLevelConjuncts(node);
  if (index < 0 || index >= parts.length) return node;
  final kept = [
    for (var i = 0; i < parts.length; i++)
      if (i != index) parts[i],
  ];
  if (kept.isEmpty) return null;
  return kept.length == 1 ? kept.single : AndNode(kept);
}

List<QueryNode> _children(QueryNode node) => switch (node) {
  AndNode(:final children) => children,
  OrNode(:final children) => children,
  NotNode(:final child) => [child],
  ScopedNode(:final inner) => [inner],
  ConditionNode() || TextNode() => const [],
};

QueryNode _withChildren(QueryNode node, List<QueryNode> children) =>
    switch (node) {
      AndNode() => AndNode(children),
      OrNode() => OrNode(children),
      NotNode() => NotNode(children.single),
      ScopedNode(:final path) => ScopedNode(path, children.single),
      ConditionNode() || TextNode() => node,
    };
```

The null-aware element `?normalizeQuery(c)` in a list literal needs Dart 3.8 or later, which `pubspec.yaml` allows; if the analyzer rejects it, map and `whereType<QueryNode>()` instead.

- [ ] **Step 4: Run the test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_tree_edit_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_tree_edit.dart test/core/query/presentation/query_tree_edit_test.dart
git commit -m "feat(query): pure tree edits for the builder and the chips"
```

---

### Task 5: The editor context and completions at the caret

**Files:**
- Create: `lib/core/query/presentation/query_editor_context.dart`, `lib/core/query/presentation/query_completions.dart`
- Modify: `lib/core/query/syntax/query_parser.dart` (`NameEntries`, `MapNameResolver implements NameEntries`), `lib/features/query/data/query_name_index.dart` (`implements NameEntries`)
- Test: `test/core/query/presentation/query_completions_test.dart`

**Interfaces:**
- Consumes: `QueryRegistry`, `QueryEntity`, `UnitPrefs`, `NameResolver`, `QueryLabels`, `QueryParser`, `ParseContext`, `QueryPrinter`, `tokenize`, `Token`, `TokenKind`, `TokenizeException`, `resolvePath`.
- Produces:

```dart
abstract class NameEntries { Iterable<String> entryLabels(QuerySubject kind); }   // in query_parser.dart, beside NameResolver
class QueryEditorContext {
  const QueryEditorContext({required registry, required root, required prefs, required names, required labels, required now});
  QueryParser get parser;     // fresh, anchored on now()
  QueryPrinter get printer;
  QueryEditorContext copyWith({UnitPrefs? prefs, NameResolver? names, QueryLabels? labels});
}
class Completion { final String text; final int replaceStart; final int replaceLength; }
List<Completion> completionsAt(String text, int caret, QueryEditorContext context);
```

- [ ] **Step 1: Write the failing test**

`test/core/query/presentation/query_completions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1', 'Sand Slope': 's2'},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );

  List<String> texts(String text, [int? caret]) =>
      completionsAt(text, caret ?? text.length, context)
          .map((c) => c.text)
          .toList();

  test('a partial word at the start offers field and relation keys', () {
    expect(texts('dep'), ['depth']);
    expect(texts('w'), containsAll(['waterTemp', 'waterType', 'weekday', 'weights']));
    expect(texts(''), isEmpty);
  });

  test('after a dot the keys of the related entity are offered', () {
    expect(texts('buddies.'), containsAll(['name', 'certifications']));
    expect(texts('buddies.cert'), ['certifications']);
    expect(texts('buddies.certifications.lev'), ['level']);
    expect(texts('nope.'), isEmpty);
  });

  test('after a colon: none, any and the enum values', () {
    expect(texts('waterType:'), ['none', 'any', 'salt', 'fresh', 'brackish']);
    expect(texts('waterType:fr'), ['fresh']);
    expect(texts('depth:'), ['none', 'any']);
  });

  test('after an operator on an enum field the values are offered', () {
    expect(texts('waterType = '), ['salt', 'fresh', 'brackish']);
    expect(texts('waterType in [salt, '), ['salt', 'fresh', 'brackish']);
  });

  test('after an operator on a relation the ref names are offered, quoted', () {
    expect(texts('site = '), ['"Salt Pier"', '"Sand Slope"']);
    expect(texts('site = Sa'), ['"Salt Pier"', '"Sand Slope"']);
    expect(texts('site = "Sal'), ['"Salt Pier"']);
  });

  test('a completion knows what span it replaces', () {
    final c = completionsAt('depth > 30 AND wat', 18, context);
    expect(c.map((x) => x.text), ['waterTemp', 'waterType']);
    expect(c.first.replaceStart, 15);
    expect(c.first.replaceLength, 3);
    // In the middle of the text, the word under the caret is completed.
    final mid = completionsAt('dep AND depth > 3', 3, context).single;
    expect(mid.replaceStart, 0);
    expect(mid.replaceLength, 3);
  });

  test('keywords are offered after a complete condition', () {
    expect(texts('depth > 30 a'), ['and']);
    expect(texts('depth > 30 '), isEmpty);
  });

  test('an unterminated quote offers nothing', () {
    expect(texts('notes ~ "night'), isEmpty);
  });
}
```

The expected enum order is the fixture registry's declared order (`salt, fresh, brackish`), and the field order is the fixture's declaration order; both are what the test pins.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_completions_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: `NameEntries` in the parser file**

In `lib/core/query/syntax/query_parser.dart`, directly after `abstract class NameResolver { ... }` add:

```dart
/// Implemented by resolvers that can list every name of a subject, which
/// the completions and the builder's ref pickers use; the parser itself
/// needs only [NameResolver].
abstract class NameEntries {
  Iterable<String> entryLabels(QuerySubject kind);
}
```

Change `class MapNameResolver implements NameResolver` to `class MapNameResolver implements NameResolver, NameEntries` and add:

```dart
  @override
  Iterable<String> entryLabels(QuerySubject kind) =>
      labelsToIds[kind]?.keys ?? const [];
```

In `lib/features/query/data/query_name_index.dart` change `class QueryNameIndex implements NameResolver` to `implements NameResolver, NameEntries` and add:

```dart
  @override
  Iterable<String> entryLabels(QuerySubject kind) =>
      entries(kind).map((r) => r.label);
```

- [ ] **Step 4: Write the context**

`lib/core/query/presentation/query_editor_context.dart`:

```dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Everything the editor widgets need that is not the tree itself (#2365):
/// the registry and the entity being queried, the diver's units, how refs
/// resolve, how things are labelled, and the clock the date grammar uses.
///
/// The feature layer builds one from providers; tests build one from the
/// fixture registry and maps.
@immutable
class QueryEditorContext {
  const QueryEditorContext({
    required this.registry,
    required this.root,
    required this.prefs,
    required this.names,
    required this.labels,
    required this.now,
  });

  final QueryRegistry registry;
  final QueryEntity root;
  final UnitPrefs prefs;
  final NameResolver names;
  final QueryLabels labels;
  final DateTime Function() now;

  /// A parser for this moment: `last 7 days` is anchored on [now] when the
  /// text is parsed, not when the editor opened.
  QueryParser get parser => QueryParser(
    registry,
    root,
    ParseContext(prefs: prefs, now: now(), names: names),
  );

  QueryPrinter get printer => QueryPrinter(registry, root, prefs);

  QueryEditorContext copyWith({
    UnitPrefs? prefs,
    NameResolver? names,
    QueryLabels? labels,
  }) => QueryEditorContext(
    registry: registry,
    root: root,
    prefs: prefs ?? this.prefs,
    names: names ?? this.names,
    labels: labels ?? this.labels,
    now: now,
  );
}
```

- [ ] **Step 5: Write the completions**

`lib/core/query/presentation/query_completions.dart`:

```dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';

/// One thing the diver can insert at the caret.
@immutable
class Completion {
  const Completion(
    this.text, {
    required this.replaceStart,
    required this.replaceLength,
  });

  /// What to insert, already quoted when a name needs it.
  final String text;

  /// The span of the host string it replaces (the partial word).
  final int replaceStart;
  final int replaceLength;
}

const _valueOperators = {'=', '!=', '<', '<=', '>', '>=', '~'};
const _maxCompletions = 8;

/// What the editor offers at [caret] in [text] (#2365):
///
/// * at a word boundary, the field and relation keys of the entity the
///   dotted path so far reaches;
/// * after `:`, `none`, `any` and the enum values of the field;
/// * after an operator (or inside `in [...]`), the enum values of the field
///   or the ref names of the relation, quoted;
/// * after a complete condition, the keywords.
///
/// Pure: the widget decides how to show them.
List<Completion> completionsAt(
  String text,
  int caret,
  QueryEditorContext context,
) {
  final head = text.substring(0, caret.clamp(0, text.length));
  final List<Token> tokens;
  try {
    tokens = tokenize(head);
  } on TokenizeException {
    return const [];
  }
  final body = tokens.where((t) => t.kind != TokenKind.end).toList();
  if (body.isEmpty) return const [];

  // The word being typed, if the caret sits right at the end of a word or
  // quoted token; otherwise the caret follows whitespace or a symbol.
  final last = body.last;
  final touching = last.offset + last.length == head.length;
  final partial =
      touching &&
          (last.kind == TokenKind.word || last.kind == TokenKind.quoted)
      ? last
      : null;
  final prior = partial == null ? body : body.sublist(0, body.length - 1);
  final typed = partial?.text ?? '';
  final replaceStart = partial?.offset ?? head.length;
  final replaceLength = partial?.length ?? 0;

  List<Completion> emit(Iterable<String> options, {bool quote = false}) {
    final lower = typed.toLowerCase();
    final out = <Completion>[];
    for (final o in options) {
      if (lower.isNotEmpty && !o.toLowerCase().startsWith(lower)) continue;
      out.add(
        Completion(
          quote ? '"${o.replaceAll('"', r'\"')}"' : o,
          replaceStart: replaceStart,
          replaceLength: replaceLength,
        ),
      );
      if (out.length == _maxCompletions) break;
    }
    return out;
  }

  // A dotted path being typed: complete the last segment against the
  // entity the earlier segments reach.
  if (partial != null &&
      partial.kind == TokenKind.word &&
      partial.text.contains('.')) {
    final segments = partial.text.split('.');
    final entity = _entityAtEnd(
      context,
      segments.sublist(0, segments.length - 1),
    );
    if (entity == null) return const [];
    final start = partial.offset + partial.text.length - segments.last.length;
    return [
      for (final k in _keysOf(entity, segments.last))
        Completion(k, replaceStart: start, replaceLength: segments.last.length),
    ];
  }

  final before = prior.isEmpty ? null : prior.last;

  // `path:` or `path:val`.
  if (before != null && _isSymbol(before, ':')) {
    final field = _fieldAt(context, prior, prior.length - 2);
    return emit(['none', 'any', ...?field?.enumValues]);
  }

  // `path op`, `path in [`, `path in [a, `.
  if (before != null &&
      before.kind == TokenKind.symbol &&
      (_valueOperators.contains(before.text) ||
          before.text == '[' ||
          before.text == ',')) {
    final anchor = _pathIndexBeforeValue(prior);
    if (anchor == null) return const [];
    final resolved = _resolveWord(context, prior[anchor].text);
    if (resolved?.field?.enumValues case final values?) return emit(values);
    if (resolved?.terminalRelation case final rel?) {
      final names = context.names;
      if (names is! NameEntries) return const [];
      return emit(names.entryLabels(rel.target), quote: true);
    }
    return const [];
  }

  // A bare word: a key of the root at the start of a term, or a keyword
  // after a complete condition.
  if (partial != null && partial.kind == TokenKind.word) {
    final atTermStart =
        before == null ||
        _isSymbol(before, '(') ||
        _isKeyword(before, 'and') ||
        _isKeyword(before, 'or') ||
        _isKeyword(before, 'not');
    if (atTermStart) return emit(_keysOf(context.root, typed));
    return emit(const ['and', 'or']);
  }
  return const [];
}

bool _isKeyword(Token t, String kw) =>
    t.kind == TokenKind.word && t.text.toLowerCase() == kw;

bool _isSymbol(Token t, String s) => t.kind == TokenKind.symbol && t.text == s;

/// Keys (fields then relations, declared order) starting with [prefix].
List<String> _keysOf(QueryEntity entity, String prefix) {
  final lower = prefix.toLowerCase();
  return [
    for (final f in entity.fields)
      if (f.key.toLowerCase().startsWith(lower)) f.key,
    for (final r in entity.relations)
      if (r.key.toLowerCase().startsWith(lower)) r.key,
  ].take(_maxCompletions).toList();
}

QueryEntity? _entityAtEnd(QueryEditorContext context, List<String> segments) {
  if (segments.isEmpty) return context.root;
  final res = resolvePath(context.registry, context.root, FieldPath(segments));
  return res.terminalRelation == null ? null : res.entities.last;
}

PathResolution? _resolveWord(QueryEditorContext context, String pathText) {
  if (pathText.isEmpty) return null;
  final res = resolvePath(
    context.registry,
    context.root,
    FieldPath(pathText.split('.')),
  );
  return res.error == null ? res : null;
}

QueryField? _fieldAt(QueryEditorContext context, List<Token> tokens, int i) {
  if (i < 0 || i >= tokens.length) return null;
  final t = tokens[i];
  if (t.kind != TokenKind.word) return null;
  return _resolveWord(context, t.text)?.field;
}

/// The index of the path token that owns the value being typed: the word
/// before a value operator, or before `in [` (skipping earlier list items).
int? _pathIndexBeforeValue(List<Token> tokens) {
  for (var i = tokens.length - 1; i >= 0; i--) {
    final t = tokens[i];
    if (t.kind != TokenKind.symbol) continue;
    if (_valueOperators.contains(t.text)) {
      return i >= 1 && tokens[i - 1].kind == TokenKind.word ? i - 1 : null;
    }
    if (t.text == '[') {
      final ok =
          i >= 2 &&
          _isKeyword(tokens[i - 1], 'in') &&
          tokens[i - 2].kind == TokenKind.word;
      return ok ? i - 2 : null;
    }
  }
  return null;
}
```

The ref-name branch offers every entry label filtered by the typed prefix through `emit`, so `site = Sa` lists both `Salt Pier` and `Sand Slope`. `_fieldAt(prior, prior.length - 2)` reads the word before the colon.

- [ ] **Step 6: Run the test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_completions_test.dart test/core/query/ test/features/query/data/`
Expected: PASS (the parser suite is unaffected by the `NameEntries` addition). If `waterType in [salt, ` offers values differently from the test (the tokenizer may fold `[salt,` into one word), print `tokenize('waterType in [salt, ')` once and adjust `_pathIndexBeforeValue` to the real token stream; the test's expectation stands.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_editor_context.dart lib/core/query/presentation/query_completions.dart lib/core/query/syntax/query_parser.dart lib/features/query/data/query_name_index.dart test/core/query/presentation/query_completions_test.dart
git commit -m "feat(query): editor context and caret completions over the registry and the name index"
```

---

### Task 6: The text tab

**Files:**
- Create: `lib/core/query/presentation/query_error_controller.dart`, `lib/core/query/presentation/query_text_field.dart`
- Test: `test/core/query/presentation/query_text_field_test.dart`

**Interfaces:**
- Consumes: `QueryEditorContext`, `completionsAt`, `validateQuery`, `ParseOk`, `ParseFailure`, `QueryError`, `normalizeQuery`.
- Produces:

```dart
class QueryErrorHighlightController extends TextEditingController {
  QueryErrorHighlightController({String? text});
  Color errorColor;                                  // settable; Colors.red by default
  int? get errorOffset; int? get errorLength;
  void setError({int? offset, int? length});         // null clears
}
class QueryTextField extends StatefulWidget {
  const QueryTextField({
    required QueryEditorContext context,
    required QueryNode? value,                       // the committed tree; printed into the field when it changes from outside
    required ValueChanged<QueryNode?> onChanged,     // called only with a valid, normalised tree, or null for empty text
    String hintText = '',
    String Function(QueryError error)? describeError, // defaults to error.message
    Key? fieldKey, bool autofocus = false, Key? key,
  });
}
```

Behaviour: the field parses on every change. A `ParseOk` that validates commits through `onChanged`; a failure underlines the span, shows the message under the field and, when the error carries suggestions, an `ActionChip` per suggestion that replaces the span. Completions from `completionsAt` show as chips under the field while it has focus. When `value` changes from outside (a chip removed, a saved query applied) and differs from the last committed tree, the field text is reset to `context.printer.print(value)`.

- [ ] **Step 1: Write the failing test**

`test/core/query/presentation/query_text_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_error_controller.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1'},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );
  const fieldKey = Key('query-text');

  Widget host({
    required QueryNode? value,
    required ValueChanged<QueryNode?> onChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: QueryTextField(
        context: context,
        value: value,
        onChanged: onChanged,
        fieldKey: fieldKey,
      ),
    ),
  );

  QueryErrorHighlightController controllerOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(fieldKey)).controller!
          as QueryErrorHighlightController;

  testWidgets('a valid query is committed', (tester) async {
    QueryNode? committed;
    await tester.pumpWidget(host(value: null, onChanged: (n) => committed = n));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    expect(
      committed,
      ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
    );
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a parse failure keeps the previous committed value', (
    tester,
  ) async {
    final calls = <QueryNode?>[];
    await tester.pumpWidget(host(value: null, onChanged: calls.add));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    await tester.enterText(find.byKey(fieldKey), 'depth >');
    await tester.pump();
    expect(calls.length, 1);
    expect(find.textContaining('expected a value'), findsOneWidget);
    expect(controllerOf(tester).errorOffset, 7);
  });

  testWidgets('a misspelt field shows suggestions that replace the span', (
    tester,
  ) async {
    QueryNode? committed;
    await tester.pumpWidget(host(value: null, onChanged: (n) => committed = n));
    await tester.enterText(find.byKey(fieldKey), 'dpeth > 30');
    await tester.pump();
    expect(find.widgetWithText(ActionChip, 'depth'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'depth'));
    await tester.pump();
    expect(controllerOf(tester).text, 'depth > 30');
    expect(committed, isNotNull);
  });

  testWidgets('empty text commits null', (tester) async {
    final calls = <QueryNode?>[];
    await tester.pumpWidget(host(value: null, onChanged: calls.add));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    await tester.enterText(find.byKey(fieldKey), '   ');
    await tester.pump();
    expect(calls, [isNotNull, isNull]);
  });

  testWidgets('a value set from outside is printed into the field', (
    tester,
  ) async {
    final tree = ConditionNode(
      FieldPath(['site']),
      QueryOp.eq,
      const RefValue('s1', 'Salt Pier'),
    );
    await tester.pumpWidget(host(value: null, onChanged: (_) {}));
    await tester.pumpWidget(host(value: tree, onChanged: (_) {}));
    await tester.pump();
    expect(controllerOf(tester).text, 'site = "Salt Pier"');
  });

  testWidgets('completions appear while typing and insert on tap', (
    tester,
  ) async {
    await tester.pumpWidget(host(value: null, onChanged: (_) {}));
    await tester.enterText(find.byKey(fieldKey), 'dep');
    await tester.pump();
    expect(find.widgetWithText(ActionChip, 'depth'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'depth'));
    await tester.pump();
    expect(controllerOf(tester).text, 'depth');
  });

  test('QueryErrorHighlightController underlines the error span only', () {
    final c = QueryErrorHighlightController(text: 'depth >> 30')
      ..setError(offset: 6, length: 2);
    final span = c.buildTextSpan(
      context: _FakeContext(),
      style: const TextStyle(),
      withComposing: false,
    );
    final children = span.children!.cast<TextSpan>();
    expect(children.map((s) => s.text), ['depth ', '>>', ' 30']);
    expect(children[1].style?.decoration, TextDecoration.underline);
    expect(children[0].style?.decoration, isNull);
    c.setError();
    expect(
      c
          .buildTextSpan(
            context: _FakeContext(),
            style: const TextStyle(),
            withComposing: false,
          )
          .children,
      isNull,
    );
  });
}

class _FakeContext extends Fake implements BuildContext {}
```

`buildTextSpan` must not read the context: the error colour comes from the controller's own field.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the controller**

`lib/core/query/presentation/query_error_controller.dart`:

```dart
import 'package:flutter/material.dart';

/// A text controller that paints one span with an error underline: the
/// token the parser could not read. The span is set from a QueryError's
/// offset and length and cleared on the next successful parse.
class QueryErrorHighlightController extends TextEditingController {
  QueryErrorHighlightController({super.text});

  /// The underline colour; the widget sets the theme's error colour.
  Color errorColor = Colors.red;

  int? _offset;
  int? _length;

  int? get errorOffset => _offset;
  int? get errorLength => _length;

  void setError({int? offset, int? length}) {
    if (_offset == offset && _length == length) return;
    _offset = offset;
    _length = length;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final offset = _offset;
    final length = _length;
    final value = text;
    if (offset == null || length == null || offset >= value.length) {
      return TextSpan(text: value, style: style);
    }
    final end = (offset + length).clamp(offset, value.length);
    final errorStyle = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: errorColor,
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: value.substring(0, offset)),
        TextSpan(text: value.substring(offset, end), style: errorStyle),
        TextSpan(text: value.substring(end)),
      ],
    );
  }
}
```

- [ ] **Step 4: Write the field**

`lib/core/query/presentation/query_text_field.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_error_controller.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';

/// The typed editor of a query tree (#2365, spec Unit 6 "Text").
///
/// Every keystroke is parsed and validated. Only a clean tree reaches
/// [onChanged]; a failure underlines its span, names it under the field and
/// offers the parser's suggestions as chips. Completions for the word at the
/// caret show as chips too. A [value] set from outside (a chip removed, a
/// saved query applied) is printed back into the field.
class QueryTextField extends StatefulWidget {
  const QueryTextField({
    super.key,
    required this.context,
    required this.value,
    required this.onChanged,
    this.hintText = '',
    this.describeError,
    this.fieldKey,
    this.autofocus = false,
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final String hintText;
  final String Function(QueryError error)? describeError;
  final Key? fieldKey;
  final bool autofocus;

  @override
  State<QueryTextField> createState() => _QueryTextFieldState();
}

class _QueryTextFieldState extends State<QueryTextField> {
  late final QueryErrorHighlightController _controller;
  final _focus = FocusNode();
  QueryError? _error;
  List<Completion> _completions = const [];

  /// The last tree this field committed, so an outside [widget.value] equal
  /// to it does not rewrite the text under the diver's cursor.
  QueryNode? _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.value;
    _controller = QueryErrorHighlightController(
      text: widget.context.printer.print(widget.value),
    );
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(QueryTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _committed) {
      _committed = widget.value;
      _controller
        ..text = widget.context.printer.print(widget.value)
        ..setError();
      _error = null;
      _completions = const [];
    } else if (widget.context.prefs != old.context.prefs && _error == null) {
      // The unit setting changed: the same tree reads differently now.
      _controller.text = widget.context.printer.print(_committed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final caret = _controller.selection.isValid
        ? _controller.selection.extentOffset
        : text.length;
    final completions = completionsAt(text, caret, widget.context);
    if (text.trim().isEmpty) {
      _commit(null);
      _controller.setError();
      setState(() {
        _error = null;
        _completions = completions;
      });
      return;
    }
    switch (widget.context.parser.parse(text)) {
      case ParseOk(:final node):
        final errors = validateQuery(
          node,
          widget.context.root,
          widget.context.registry,
        );
        if (errors.isEmpty) {
          _commit(normalizeQuery(node));
          _controller.setError();
          setState(() {
            _error = null;
            _completions = completions;
          });
        } else {
          _showError(errors.first, completions);
        }
      case ParseFailure(:final error):
        _showError(error, completions);
    }
  }

  void _commit(QueryNode? node) {
    if (node == _committed) return;
    _committed = node;
    widget.onChanged(node);
  }

  void _showError(QueryError error, List<Completion> completions) {
    _controller.setError(offset: error.offset, length: error.length);
    setState(() {
      _error = error;
      _completions = completions;
    });
  }

  void _replace(int start, int length, String text) {
    final current = _controller.text;
    final end = (start + length).clamp(start, current.length);
    final next = current.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _onTextChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final theme = Theme.of(context);
    _controller.errorColor = theme.colorScheme.error;
    final describe = widget.describeError ?? (QueryError e) => e.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _replace(0, _controller.text.length, ''),
                  ),
            errorText: error == null ? null : describe(error),
          ),
          onChanged: _onTextChanged,
        ),
        if (error != null && error.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in error.suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: Text(s),
                    onPressed: () =>
                        _replace(error.offset ?? 0, error.length ?? 0, s),
                  ),
              ],
            ),
          )
        else if (_completions.isNotEmpty && (_focus.hasFocus || error == null))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in _completions)
                  ActionChip(
                    label: Text(c.text),
                    onPressed: () =>
                        _replace(c.replaceStart, c.replaceLength, c.text),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
```

The suggestion chip's avatar icon distinguishes it from a completion chip, so the first test's `findsNothing` on `Icons.error_outline` holds.

- [ ] **Step 5: Run the test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: PASS (7 tests). If "a parse failure keeps the previous committed value" reports a different offset, print the `ParseFailure` for `depth >` once and pin that number; the parser is the arbiter.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_error_controller.dart lib/core/query/presentation/query_text_field.dart test/core/query/presentation/query_text_field_test.dart
git commit -m "feat(query): the text tab: live parse, positioned error underline, suggestions and completions"
```

---

### Task 7: The field picker and the ref picker

**Files:**
- Create: `lib/core/query/presentation/query_field_picker_sheet.dart`, `lib/core/query/presentation/query_ref_picker_sheet.dart`
- Test: `test/core/query/presentation/query_field_picker_sheet_test.dart`, `test/core/query/presentation/query_ref_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `QueryEditorContext`, `QueryEntity.fields/relations`, `kMaxPathHops`, `resolvePath`, `NameEntries`, `RefValue`, `QueryLabels`.
- Produces:

```dart
typedef FieldPick = ({FieldPath path, bool isRelation});   // a path ending in a field, or a relation used as a ref
class QueryFieldPickerStrings { const QueryFieldPickerStrings({required title, required searchHint, required useRelation /* "Use {name} itself" */, required fieldsOf /* "Fields of {name}" */}); }
Future<FieldPick?> showQueryFieldPicker(BuildContext context, {required QueryEditorContext editor, required QueryFieldPickerStrings strings, int hopsUsed = 0});
Future<RefValue?> showQueryRefPicker(BuildContext context, {required QueryEditorContext editor, required QuerySubject kind, required String title, required String searchHint, RefValue? selected});
Future<List<RefValue>?> showQueryRefMultiPicker(BuildContext context, {required QueryEditorContext editor, required QuerySubject kind, required String title, required String searchHint, required String doneLabel, List<RefValue> selected = const []});
```

The strings are passed in (not looked up) because the core widgets do not import `AppLocalizations`; the feature layer fills them from `context.l10n` (Task 9).

- [ ] **Step 1: Write the failing tests**

`test/core/query/presentation/query_field_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_field_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'level': 'Level'},
      relations: {'buddies': 'Buddies', 'certifications': 'Certifications'},
      entities: {QuerySubject.dives: 'Dives', QuerySubject.buddies: 'Buddies'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  const strings = QueryFieldPickerStrings(
    title: 'Choose a field',
    searchHint: 'Search fields',
    useRelation: 'Use {name} itself',
    fieldsOf: 'Fields of {name}',
  );

  Widget host(void Function(FieldPick?) onPicked) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => onPicked(
            await showQueryFieldPicker(ctx, editor: context, strings: strings),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('tapping a field returns its path', (tester) async {
    FieldPick? picked;
    await tester.pumpWidget(host((p) => picked = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a field'), findsOneWidget);
    await tester.tap(find.text('Max depth'));
    await tester.pumpAndSettle();
    expect(picked, (path: FieldPath(['depth']), isRelation: false));
  });

  testWidgets('descending a relation walks the tree and returns the full path', (
    tester,
  ) async {
    FieldPick? picked;
    await tester.pumpWidget(host((p) => picked = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The chevron descends; the row itself would pick the relation.
    await tester.tap(find.byKey(const ValueKey('descend-buddies')));
    await tester.pumpAndSettle();
    expect(find.text('Fields of Buddies'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('descend-certifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    expect(
      picked,
      (path: FieldPath(['buddies', 'certifications', 'level']), isRelation: false),
    );
  });

  testWidgets('tapping a relation row uses the relation itself', (tester) async {
    FieldPick? picked;
    await tester.pumpWidget(host((p) => picked = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buddies'));
    await tester.pumpAndSettle();
    expect(picked, (path: FieldPath(['buddies']), isRelation: true));
  });

  testWidgets('search narrows by label and key', (tester) async {
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dep');
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Buddies'), findsNothing);
  });
}
```

`FieldPath` has value equality (PR 1), so the record comparisons hold.

`test/core/query/presentation/query_ref_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1', 'Sand Slope': 's2', 'Cenote': 's3'},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );

  Widget host(Future<void> Function(BuildContext ctx) onOpen) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => onOpen(ctx),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('lists names, filters, returns the tapped ref', (tester) async {
    RefValue? picked;
    await tester.pumpWidget(
      host((ctx) async {
        picked = await showQueryRefPicker(
          ctx,
          editor: context,
          kind: QuerySubject.sites,
          title: 'Choose site',
          searchHint: 'Search',
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cenote'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sa');
    await tester.pumpAndSettle();
    expect(find.text('Cenote'), findsNothing);
    await tester.tap(find.text('Sand Slope'));
    await tester.pumpAndSettle();
    expect(picked, const RefValue('s2', 'Sand Slope'));
  });

  testWidgets('the multi picker toggles and returns the selection', (
    tester,
  ) async {
    List<RefValue>? picked;
    await tester.pumpWidget(
      host((ctx) async {
        picked = await showQueryRefMultiPicker(
          ctx,
          editor: context,
          kind: QuerySubject.sites,
          title: 'Choose sites',
          searchHint: 'Search',
          doneLabel: 'Done',
          selected: const [RefValue('s1', 'Salt Pier')],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cenote'));
    await tester.tap(find.text('Salt Pier'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked, const [RefValue('s3', 'Cenote')]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_field_picker_sheet_test.dart test/core/query/presentation/query_ref_picker_sheet_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the field picker**

`lib/core/query/presentation/query_field_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// What the picker hands back: a dotted path ending in a field, or ending in
/// a relation the row will compare as a ref (`site = X`, `buddies:none`).
typedef FieldPick = ({FieldPath path, bool isRelation});

/// The picker's strings, supplied by the caller (the core widgets do not
/// read AppLocalizations). `{name}` in [useRelation] and [fieldsOf] is
/// replaced with the entity or relation label.
class QueryFieldPickerStrings {
  const QueryFieldPickerStrings({
    required this.title,
    required this.searchHint,
    required this.useRelation,
    required this.fieldsOf,
  });

  final String title;
  final String searchHint;
  final String useRelation;
  final String fieldsOf;
}

/// The searchable field tree of spec Unit 6: the root entity's fields and
/// relations, a chevron on each relation walking into its entity
/// (Dives > Buddies > Certifications > Level), a back arrow up. Depth is
/// capped at [kMaxPathHops] minus [hopsUsed] (hops already spent by an
/// enclosing scoped group).
Future<FieldPick?> showQueryFieldPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QueryFieldPickerStrings strings,
  int hopsUsed = 0,
}) => showModalBottomSheet<FieldPick>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _FieldPickerSheet(
    editor: editor,
    strings: strings,
    hopsUsed: hopsUsed,
  ),
);

class _FieldPickerSheet extends StatefulWidget {
  const _FieldPickerSheet({
    required this.editor,
    required this.strings,
    required this.hopsUsed,
  });

  final QueryEditorContext editor;
  final QueryFieldPickerStrings strings;
  final int hopsUsed;

  @override
  State<_FieldPickerSheet> createState() => _FieldPickerSheetState();
}

class _FieldPickerSheetState extends State<_FieldPickerSheet> {
  /// The relation keys walked so far.
  final List<String> _segments = [];
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  QueryEntity get _entity => _segments.isEmpty
      ? widget.editor.root
      : resolvePath(
          widget.editor.registry,
          widget.editor.root,
          FieldPath(_segments),
        ).entities.last;

  bool get _canDescend =>
      widget.hopsUsed + _segments.length + 1 < kMaxPathHops;

  bool _matches(String key, String label) {
    final s = _search.text.trim().toLowerCase();
    if (s.isEmpty) return true;
    return key.toLowerCase().contains(s) || label.toLowerCase().contains(s);
  }

  void _descend(String key) => setState(() {
    _segments.add(key);
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final entity = _entity;
    final labels = widget.editor.labels;
    final theme = Theme.of(context);
    final title = _segments.isEmpty
        ? widget.strings.title
        : widget.strings.fieldsOf.replaceAll(
            '{name}',
            labels.entity(entity.subject),
          );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          ListTile(
            leading: _segments.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _segments.removeLast()),
                  ),
            title: Text(title, style: theme.textTheme.titleMedium),
            subtitle: _segments.isEmpty ? null : Text(_segments.join(' > ')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.strings.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                for (final f in entity.fields)
                  if (_matches(f.key, labels.field(f)))
                    ListTile(
                      leading: const Icon(Icons.short_text),
                      title: Text(labels.field(f)),
                      subtitle: Text(f.key),
                      onTap: () => Navigator.of(context).pop((
                        path: FieldPath([..._segments, f.key]),
                        isRelation: false,
                      )),
                    ),
                for (final r in entity.relations)
                  if (_matches(r.key, labels.relation(r)))
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(labels.relation(r)),
                      subtitle: Text(
                        widget.strings.useRelation.replaceAll(
                          '{name}',
                          labels.relation(r),
                        ),
                      ),
                      trailing: _canDescend
                          ? IconButton(
                              key: ValueKey('descend-${r.key}'),
                              icon: const Icon(Icons.chevron_right),
                              tooltip: widget.strings.fieldsOf.replaceAll(
                                '{name}',
                                labels.relation(r),
                              ),
                              onPressed: () => _descend(r.key),
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop((
                        path: FieldPath([..._segments, r.key]),
                        isRelation: true,
                      )),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write the ref pickers**

`lib/core/query/presentation/query_ref_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';

/// The rows a ref picker can offer: the resolver's entries when it can list
/// them, otherwise nothing (the text tab still resolves typed names).
List<RefValue> _entriesOf(QueryEditorContext editor, QuerySubject kind) {
  final names = editor.names;
  if (names is! NameEntries) return const [];
  return [
    for (final label in names.entryLabels(kind))
      if (names.resolve(kind, label) case final ref?) ref,
  ];
}

/// Pick one row of [kind] by name (spec Unit 6, "a ref type-ahead").
Future<RefValue?> showQueryRefPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QuerySubject kind,
  required String title,
  required String searchHint,
  RefValue? selected,
}) => showModalBottomSheet<RefValue>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RefPickerSheet(
    entries: _entriesOf(editor, kind),
    title: title,
    searchHint: searchHint,
    selected: selected == null ? const {} : {selected.id},
    multi: false,
    doneLabel: null,
  ),
);

/// Pick several rows of [kind]; returns null when dismissed.
Future<List<RefValue>?> showQueryRefMultiPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QuerySubject kind,
  required String title,
  required String searchHint,
  required String doneLabel,
  List<RefValue> selected = const [],
}) => showModalBottomSheet<List<RefValue>>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RefPickerSheet(
    entries: _entriesOf(editor, kind),
    title: title,
    searchHint: searchHint,
    selected: {for (final r in selected) r.id},
    multi: true,
    doneLabel: doneLabel,
  ),
);

class _RefPickerSheet extends StatefulWidget {
  const _RefPickerSheet({
    required this.entries,
    required this.title,
    required this.searchHint,
    required this.selected,
    required this.multi,
    required this.doneLabel,
  });

  final List<RefValue> entries;
  final String title;
  final String searchHint;
  final Set<String> selected;
  final bool multi;
  final String? doneLabel;

  @override
  State<_RefPickerSheet> createState() => _RefPickerSheetState();
}

class _RefPickerSheetState extends State<_RefPickerSheet> {
  late final Set<String> _selected = {...widget.selected};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final search = _search.toLowerCase();
    final shown = [
      for (final r in widget.entries)
        if (search.isEmpty || r.label.toLowerCase().contains(search)) r,
    ];
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          ListTile(
            title: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: widget.multi
                ? FilledButton(
                    onPressed: () => Navigator.of(context).pop([
                      for (final r in widget.entries)
                        if (_selected.contains(r.id)) r,
                    ]),
                    child: Text(widget.doneLabel!),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final r = shown[i];
                final on = _selected.contains(r.id);
                return widget.multi
                    ? CheckboxListTile(
                        value: on,
                        title: Text(r.label),
                        onChanged: (_) => setState(() {
                          if (!_selected.remove(r.id)) _selected.add(r.id);
                        }),
                      )
                    : ListTile(
                        title: Text(r.label),
                        trailing: on ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(r),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_field_picker_sheet_test.dart test/core/query/presentation/query_ref_picker_sheet_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_field_picker_sheet.dart lib/core/query/presentation/query_ref_picker_sheet.dart test/core/query/presentation/query_field_picker_sheet_test.dart test/core/query/presentation/query_ref_picker_sheet_test.dart
git commit -m "feat(query): the builder's field tree and ref pickers"
```

---

### Task 8: The value editor, the condition row and the group card

**Files:**
- Create: `lib/core/query/presentation/query_value_editor.dart`, `lib/core/query/presentation/query_condition_row.dart`, `lib/core/query/presentation/query_builder_group.dart`, `lib/core/query/presentation/query_builder_strings.dart`
- Test: `test/core/query/presentation/query_value_editor_test.dart`, `test/core/query/presentation/query_builder_group_test.dart`

**Interfaces:**
- Consumes: `QueryEditorContext`, `FieldPick`, `showQueryFieldPicker`, `showQueryRefPicker`, `showQueryRefMultiPicker`, `unitForDimension`, `groundToStorage`, `storageToDisplay`, `formatQueryNumber`, the tree edit helpers, `resolvePath`, `NameEntries`, `showAppDatePicker` (`lib/shared/widgets/app_date_picker.dart`: `{required context, required initialDate, required firstDate, required lastDate}`).
- Produces:

```dart
class QueryBuilderStrings {   // every string the builder shows, supplied by the caller
  const QueryBuilderStrings({required allOf, required anyOf, required addCondition, required addGroup, required negate, required remove,
    required pickField, required pickFieldSearch, required useRelation, required fieldsOf, required pickRef /* "Choose {name}" */,
    required pickRefSearch, required done, required unresolvedRef, required scopedRow /* "Group over {name}: edit in the Text tab" */,
    required textRow, required betweenAnd, required valueTrue, required valueFalse});
}
List<QueryOp> opsFor(PathResolution target);                       // the ops a row offers, menu order
QueryValue? defaultValueFor(PathResolution target, QueryOp op, QueryEditorContext context); // null for a ref or a valueless op
Future<ConditionNode?> pickCondition(BuildContext buildContext, {required QueryEditorContext context, required QueryBuilderStrings strings, int hopsUsed = 0});
class QueryValueEditor extends StatelessWidget {
  const QueryValueEditor({required context, required target, required op, required value, required onChanged /* ValueChanged<QueryValue> */, required strings, Key? key});
}
class QueryConditionRow extends StatelessWidget {   // negation and removal live on the group
  const QueryConditionRow({required context, required condition, required onChanged /* ValueChanged<ConditionNode> */, required strings, hopsUsed = 0, Key? key});
}
class QueryBuilderGroup extends StatelessWidget {
  const QueryBuilderGroup({required context, required root /* QueryNode? */, required onChanged /* ValueChanged<QueryNode?> */, required strings, Key? key});
}
```

`QueryBuilderGroup` renders `root` (a null root is an empty AND card with the two add buttons). Groups render as cards with a segmented AND/OR toggle; a `NotNode` renders its child with the negate toggle on; a `ConditionNode` renders a `QueryConditionRow`; a `TextNode` renders a text field row; a `ScopedNode` renders read-only, showing `context.printer.print(node)` and the `scopedRow` hint (the text tab edits it). Every edit goes through the Task 4 helpers and `normalizeQuery`, then `onChanged`.

- [ ] **Step 1: Write the failing tests**

`test/core/query/presentation/query_value_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

const kTestBuilderStrings = QueryBuilderStrings(
  allOf: 'All of',
  anyOf: 'Any of',
  addCondition: 'Add condition',
  addGroup: 'Add group',
  negate: 'Not',
  remove: 'Remove',
  pickField: 'Choose a field',
  pickFieldSearch: 'Search fields',
  useRelation: 'Use {name} itself',
  fieldsOf: 'Fields of {name}',
  pickRef: 'Choose {name}',
  pickRefSearch: 'Search',
  done: 'Done',
  unresolvedRef: 'No longer exists',
  scopedRow: 'Group over {name}: edit in the Text tab',
  textRow: 'Text search',
  betweenAnd: 'and',
  valueTrue: 'Yes',
  valueFalse: 'No',
);

void main() {
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );
  QueryEditorContext ctx([UnitPrefs prefs = kMetricPrefs]) =>
      QueryEditorContext(
        registry: fixtureRegistry,
        root: fixtureDives,
        prefs: prefs,
        names: const MapNameResolver({
          QuerySubject.sites: {'Salt Pier': 's1'},
        }),
        labels: const MapQueryLabels(
          enums: {
            'waterType': {'salt': 'Salt water', 'fresh': 'Fresh water'},
          },
        ),
        now: () => DateTime(2026, 9, 25),
      );
  PathResolution target(String path) =>
      resolvePath(fixtureRegistry, fixtureDives, FieldPath(path.split('.')));

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  test('opsFor follows the target type and the none ambiguity rule', () {
    expect(opsFor(target('depth')), [
      QueryOp.eq, QueryOp.neq, QueryOp.lt, QueryOp.lte, QueryOp.gt,
      QueryOp.gte, QueryOp.between, QueryOp.isEmpty, QueryOp.isSet,
    ]);
    expect(opsFor(target('notes')), [
      QueryOp.eq, QueryOp.neq, QueryOp.contains, QueryOp.isEmpty, QueryOp.isSet,
    ]);
    expect(opsFor(target('favorite')), [QueryOp.eq]);
    expect(opsFor(target('waterType')), [
      QueryOp.eq, QueryOp.neq, QueryOp.inList, QueryOp.isEmpty, QueryOp.isSet,
    ]);
    // `current` stores a value named none: no :none / :any.
    expect(opsFor(target('current')), [QueryOp.eq, QueryOp.neq, QueryOp.inList]);
    expect(opsFor(target('date')), [
      QueryOp.eq, QueryOp.neq, QueryOp.lt, QueryOp.lte, QueryOp.gt,
      QueryOp.gte, QueryOp.between, QueryOp.inList, QueryOp.isEmpty, QueryOp.isSet,
    ]);
    expect(opsFor(target('site')), [
      QueryOp.eq, QueryOp.neq, QueryOp.inList, QueryOp.isEmpty, QueryOp.isSet,
    ]);
  });

  test('defaultValueFor gives a usable value or null for a ref', () {
    final c = ctx();
    expect(defaultValueFor(target('depth'), QueryOp.gt, c), const NumberValue(0, null));
    expect(defaultValueFor(target('depth'), QueryOp.isEmpty, c), isNull);
    expect(defaultValueFor(target('waterType'), QueryOp.eq, c), const EnumValue('salt'));
    expect(
      defaultValueFor(target('waterType'), QueryOp.inList, c),
      ListValue([const EnumValue('salt')]),
    );
    expect(defaultValueFor(target('favorite'), QueryOp.eq, c), const BoolValue(true));
    expect(defaultValueFor(target('notes'), QueryOp.contains, c), const StringValue(''));
    expect(defaultValueFor(target('date'), QueryOp.eq, c), DateValue(DateTime(2026, 9, 25)));
    expect(
      defaultValueFor(target('date'), QueryOp.inList, c),
      DateRangeValue(DateTime(2026, 1, 1), DateTime(2026, 9, 25)),
    );
    expect(
      defaultValueFor(target('depth'), QueryOp.between, c),
      ListValue([const NumberValue(0, null), const NumberValue(0, null)]),
    );
    expect(defaultValueFor(target('site'), QueryOp.eq, c), isNull);
  });

  testWidgets('a number field shows the diver unit and stores storage units', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(imperial),
          target: target('depth'),
          op: QueryOp.gt,
          value: const NumberValue(30.48, null),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.text('ft'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '100');
    await tester.enterText(find.byType(TextField), '50');
    await tester.pump();
    expect((out! as NumberValue).value, closeTo(15.24, 0.001));
    expect((out! as NumberValue).typedUnit, isNull);
  });

  testWidgets('an enum field offers localized values and stores the name', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('waterType'),
          op: QueryOp.eq,
          value: const EnumValue('salt'),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.text('Salt water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fresh water').last);
    await tester.pumpAndSettle();
    expect(out, const EnumValue('fresh'));
  });

  testWidgets('an enum in-list uses chips', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('waterType'),
          op: QueryOp.inList,
          value: ListValue([const EnumValue('salt')]),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Fresh water'));
    await tester.pump();
    expect(out, ListValue([const EnumValue('salt'), const EnumValue('fresh')]));
  });

  testWidgets('a bool field is a yes/no toggle', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('favorite'),
          op: QueryOp.eq,
          value: const BoolValue(true),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.text('No'));
    await tester.pump();
    expect(out, const BoolValue(false));
  });

  testWidgets('a ref shows its label, flags an unknown id, opens the picker', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('site'),
          op: QueryOp.eq,
          value: const RefValue('gone', 'Old Wall'),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.text('Old Wall'), findsOneWidget);
    expect(find.byTooltip('No longer exists'), findsOneWidget);
    await tester.tap(find.text('Old Wall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(out, const RefValue('s1', 'Salt Pier'));
  });

  testWidgets('an op without a value renders nothing', (tester) async {
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('depth'),
          op: QueryOp.isEmpty,
          value: null,
          onChanged: (_) {},
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
  });
}
```

`test/core/query/presentation/query_builder_group_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_group.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';
import 'query_value_editor_test.dart' show kTestBuilderStrings;

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1'},
    }),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'rating': 'Rating'},
      relations: {'site': 'Site', 'weights': 'Weights'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  ConditionNode depth(double v) =>
      ConditionNode(FieldPath(['depth']), QueryOp.gt, NumberValue(v, null));
  ConditionNode rating(double v) =>
      ConditionNode(FieldPath(['rating']), QueryOp.gte, NumberValue(v, null));
  final defaultRating =
      ConditionNode(FieldPath(['rating']), QueryOp.eq, const NumberValue(0, null));

  Widget host(QueryNode? root, ValueChanged<QueryNode?> onChanged) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QueryBuilderGroup(
              context: context,
              root: root,
              onChanged: onChanged,
              strings: kTestBuilderStrings,
            ),
          ),
        ),
      );

  testWidgets('renders a nested tree and toggles a group op', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(
      host(AndNode([depth(30), OrNode([rating(3), NotNode(rating(5))])]), (n) => out = n),
    );
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Rating'), findsNWidgets(2));
    // Two group cards: the root AND and the nested OR.
    expect(find.byKey(const ValueKey('group-')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-1')), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('group-1')),
      matching: find.text('All of'),
    ));
    await tester.pump();
    expect(out, AndNode([depth(30), AndNode([rating(3), NotNode(rating(5))])]));
  });

  testWidgets('removing a row and negating a row edit the tree', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(host(AndNode([depth(30), rating(3)]), (n) => out = n));
    await tester.tap(find.byKey(const ValueKey('negate-1')));
    await tester.pump();
    expect(out, AndNode([depth(30), NotNode(rating(3))]));
    await tester.pumpWidget(host(out, (n) => out = n));
    await tester.tap(find.byKey(const ValueKey('remove-0')));
    await tester.pump();
    // The root card keeps its one remaining row rather than collapsing.
    expect(out, AndNode([NotNode(rating(3))]));
  });

  testWidgets('add condition opens the picker and appends a default row', (
    tester,
  ) async {
    QueryNode? out;
    await tester.pumpWidget(host(null, (n) => out = n));
    expect(find.text('Add condition'), findsOneWidget);
    await tester.tap(find.text('Add condition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max depth'));
    await tester.pumpAndSettle();
    expect(
      out,
      AndNode([
        ConditionNode(FieldPath(['depth']), QueryOp.eq, const NumberValue(0, null)),
      ]),
    );
  });

  testWidgets('adding a ref condition opens the ref picker first', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(host(null, (n) => out = n));
    await tester.tap(find.text('Add condition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(
      out,
      AndNode([
        ConditionNode(FieldPath(['site']), QueryOp.eq, const RefValue('s1', 'Salt Pier')),
      ]),
    );
  });

  testWidgets('add group nests an OR under the root', (tester) async {
    QueryNode? out;
    await tester.pumpWidget(host(depth(30), (n) => out = n));
    await tester.tap(find.text('Add group'));
    await tester.pumpAndSettle();
    // A new group needs a first condition; the picker opens for it.
    await tester.tap(find.text('Rating'));
    await tester.pumpAndSettle();
    expect(out, AndNode([depth(30), OrNode([defaultRating])]));
  });

  testWidgets('a scoped node is shown read-only', (tester) async {
    await tester.pumpWidget(
      host(ScopedNode(FieldPath(['weights']), rating(1)), (_) {}),
    );
    expect(find.textContaining('edit in the Text tab'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_value_editor_test.dart test/core/query/presentation/query_builder_group_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the strings holder**

`lib/core/query/presentation/query_builder_strings.dart`:

```dart
import 'package:meta/meta.dart';

/// Every string the builder shows, supplied by the caller: the core widgets
/// do not read AppLocalizations. `{name}` is replaced where documented.
@immutable
class QueryBuilderStrings {
  const QueryBuilderStrings({
    required this.allOf,
    required this.anyOf,
    required this.addCondition,
    required this.addGroup,
    required this.negate,
    required this.remove,
    required this.pickField,
    required this.pickFieldSearch,
    required this.useRelation,
    required this.fieldsOf,
    required this.pickRef,
    required this.pickRefSearch,
    required this.done,
    required this.unresolvedRef,
    required this.scopedRow,
    required this.textRow,
    required this.betweenAnd,
    required this.valueTrue,
    required this.valueFalse,
  });

  final String allOf;
  final String anyOf;
  final String addCondition;
  final String addGroup;
  final String negate;
  final String remove;
  final String pickField;
  final String pickFieldSearch;

  /// `{name}` is the relation label.
  final String useRelation;

  /// `{name}` is the entity or relation label.
  final String fieldsOf;

  /// `{name}` is the relation label.
  final String pickRef;
  final String pickRefSearch;
  final String done;
  final String unresolvedRef;

  /// `{name}` is the relation label.
  final String scopedRow;
  final String textRow;
  final String betweenAnd;
  final String valueTrue;
  final String valueFalse;
}
```

- [ ] **Step 4: Write the value editor**

`lib/core/query/presentation/query_value_editor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

const _relationOps = [
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
];

const _scalarOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.lt,
  QueryOp.lte,
  QueryOp.gt,
  QueryOp.gte,
  QueryOp.contains,
};

/// The operators a row offers for [target], in menu order: the registry's
/// per-type set minus what the builder does not edit (in-list on a number
/// or text, `!=` on a bool), and minus `:none` / `:any` on an enum that
/// stores a value named `none` (the validator refuses them, PR 1
/// deviations).
List<QueryOp> opsFor(PathResolution target) {
  final field = target.field;
  if (field == null) return _relationOps;
  final ops = <QueryOp>[];
  for (final op in QueryOp.values) {
    if (!field.ops.contains(op)) continue;
    if (op == QueryOp.inList &&
        field.type != FieldType.enumName &&
        field.type != FieldType.date) {
      continue;
    }
    if (field.type == FieldType.bool && op == QueryOp.neq) continue;
    if ((op == QueryOp.isEmpty || op == QueryOp.isSet) &&
        (field.enumValues?.contains('none') ?? false)) {
      continue;
    }
    ops.add(op);
  }
  return ops;
}

/// The value a fresh row holds for [op] on [target]; null when [op] takes
/// no value or the row cannot exist without a pick (a ref).
QueryValue? defaultValueFor(
  PathResolution target,
  QueryOp op,
  QueryEditorContext context,
) {
  if (!op.takesValue) return null;
  final field = target.field;
  if (field == null) return null;
  final now = context.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (field.type) {
    case FieldType.number:
      return op == QueryOp.between
          ? ListValue([const NumberValue(0, null), const NumberValue(0, null)])
          : const NumberValue(0, null);
    case FieldType.id:
    case FieldType.text:
      return const StringValue('');
    case FieldType.bool:
      return const BoolValue(true);
    case FieldType.enumName:
      final first = EnumValue(field.enumValues!.first);
      return op == QueryOp.inList ? ListValue([first]) : first;
    case FieldType.date:
      return switch (op) {
        QueryOp.inList => DateRangeValue(DateTime(today.year, 1, 1), today),
        QueryOp.between => ListValue([DateValue(today), DateValue(today)]),
        _ => DateValue(today),
      };
  }
}

/// Scalar comparisons share one value shape; between, in-list and the
/// presence ops each have their own.
bool sameValueShape(QueryOp a, QueryOp b) =>
    _scalarOps.contains(a) && _scalarOps.contains(b);

/// ISO day text, the form the text tab accepts, so both tabs read alike. A
/// query literal, not a displayed date, so the diver's date format does
/// not apply.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The per-type value editor of spec Unit 6: a unit-aware number field, a
/// text field, a yes/no toggle, an enum dropdown or chip set, date buttons,
/// a ref button opening the picker; nothing for `:none` and `:any`.
class QueryValueEditor extends StatelessWidget {
  const QueryValueEditor({
    super.key,
    required this.context,
    required this.target,
    required this.op,
    required this.value,
    required this.onChanged,
    required this.strings,
  });

  final QueryEditorContext context;
  final PathResolution target;
  final QueryOp op;
  final QueryValue? value;
  final ValueChanged<QueryValue> onChanged;
  final QueryBuilderStrings strings;

  @override
  Widget build(BuildContext buildContext) {
    if (!op.takesValue) return const SizedBox.shrink();
    final rel = target.terminalRelation;
    if (rel != null) return _ref(buildContext, rel);
    final field = target.field!;
    switch (field.type) {
      case FieldType.number:
        return op == QueryOp.between
            ? _betweenNumbers(field)
            : _number(field, value as NumberValue?, onChanged);
      case FieldType.id:
      case FieldType.text:
        return _TextValueField(
          initialText: (value as StringValue?)?.value ?? '',
          onChanged: (t) => onChanged(StringValue(t)),
        );
      case FieldType.bool:
        return _bool();
      case FieldType.enumName:
        return op == QueryOp.inList ? _enumChips(field) : _enumDropdown(field);
      case FieldType.date:
        return _date(buildContext);
    }
  }

  Widget _number(
    QueryField field,
    NumberValue? current,
    ValueChanged<QueryValue> onValue, {
    Key? key,
  }) {
    final unit = unitForDimension(field.dimension, context.prefs);
    final shown = current == null
        ? ''
        : formatQueryNumber(
            storageToDisplay(
              current.value,
              unit,
              field.dimension,
              context.prefs,
            ).$1,
          );
    return _NumberField(
      key: key,
      initialText: shown,
      suffix: field.dimension == FieldDimension.percent ? '%' : unit?.suffix,
      onChanged: (text) {
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null) return;
        onValue(
          NumberValue(
            groundToStorage(parsed, unit, field.dimension, context.prefs),
            null,
          ),
        );
      },
    );
  }

  Widget _betweenNumbers(QueryField field) {
    final items = (value as ListValue?)?.items ?? const <QueryValue>[];
    final lo = items.isNotEmpty
        ? items[0] as NumberValue
        : const NumberValue(0, null);
    final hi = items.length > 1 ? items[1] as NumberValue : lo;
    return Row(
      children: [
        Expanded(
          child: _number(
            field,
            lo,
            (v) => onChanged(ListValue([v, hi])),
            key: const ValueKey('between-lo'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(strings.betweenAnd),
        ),
        Expanded(
          child: _number(
            field,
            hi,
            (v) => onChanged(ListValue([lo, v])),
            key: const ValueKey('between-hi'),
          ),
        ),
      ],
    );
  }

  Widget _bool() {
    final on = (value as BoolValue?)?.value ?? true;
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text(strings.valueTrue)),
        ButtonSegment(value: false, label: Text(strings.valueFalse)),
      ],
      selected: {on},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(BoolValue(s.single)),
    );
  }

  Widget _enumDropdown(QueryField field) {
    final values = field.enumValues!;
    final current = (value as EnumValue?)?.name ?? values.first;
    return DropdownButton<String>(
      value: values.contains(current) ? current : values.first,
      isExpanded: true,
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(context.labels.enumValue(field, v)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(EnumValue(v));
      },
    );
  }

  Widget _enumChips(QueryField field) {
    final selected = {
      for (final item in (value as ListValue?)?.items ?? const <QueryValue>[])
        if (item is EnumValue) item.name,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final v in field.enumValues!)
          FilterChip(
            label: Text(context.labels.enumValue(field, v)),
            selected: selected.contains(v),
            onSelected: (on) {
              final next = [
                for (final e in field.enumValues!)
                  if (e == v ? on : selected.contains(e)) EnumValue(e),
              ];
              if (next.isNotEmpty) onChanged(ListValue(next));
            },
          ),
      ],
    );
  }

  Widget _date(BuildContext buildContext) {
    Future<DateTime?> pick(DateTime initial) => showAppDatePicker(
      context: buildContext,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(context.now().year + 1, 12, 31),
    );
    Widget dayButton(DateTime day, ValueChanged<DateTime> onPicked) =>
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          onPressed: () async {
            final d = await pick(day);
            if (d != null) onPicked(d);
          },
          label: Text(isoDay(day)),
        );
    Widget pair(DateTime lo, DateTime hi, ValueChanged<(DateTime, DateTime)> onPicked) => Row(
      children: [
        dayButton(lo, (d) => onPicked((d, hi.isBefore(d) ? d : hi))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(strings.betweenAnd),
        ),
        dayButton(hi, (d) => onPicked((lo.isAfter(d) ? d : lo, d))),
      ],
    );
    switch (value) {
      case DateRangeValue(:final start, :final end):
        return pair(start, end, (r) => onChanged(DateRangeValue(r.$1, r.$2)));
      case ListValue(:final items) when items.isNotEmpty:
        final lo = (items[0] as DateValue).day;
        final hi = items.length > 1 ? (items[1] as DateValue).day : lo;
        return pair(
          lo,
          hi,
          (r) => onChanged(ListValue([DateValue(r.$1), DateValue(r.$2)])),
        );
      case DateValue(:final day):
        return dayButton(day, (d) => onChanged(DateValue(d)));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _ref(BuildContext buildContext, QueryRelation rel) {
    final kind = rel.target;
    final label = context.labels.relation(rel);
    final title = strings.pickRef.replaceAll('{name}', label);
    Widget warn() => Tooltip(
      message: strings.unresolvedRef,
      child: const Icon(Icons.warning_amber, size: 16),
    );
    if (op == QueryOp.inList) {
      final refs = [
        for (final item in (value as ListValue?)?.items ?? const <QueryValue>[])
          if (item is RefValue) item,
      ];
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final r in refs)
            Chip(
              label: Text(r.label),
              avatar: _known(kind, r.id) ? null : warn(),
            ),
          ActionChip(
            avatar: const Icon(Icons.edit, size: 16),
            label: Text(title),
            onPressed: () async {
              final picked = await showQueryRefMultiPicker(
                buildContext,
                editor: context,
                kind: kind,
                title: title,
                searchHint: strings.pickRefSearch,
                doneLabel: strings.done,
                selected: refs,
              );
              if (picked != null && picked.isNotEmpty) {
                onChanged(ListValue(picked));
              }
            },
          ),
        ],
      );
    }
    final current = value as RefValue?;
    return OutlinedButton.icon(
      icon: current != null && !_known(kind, current.id)
          ? warn()
          : const Icon(Icons.link, size: 16),
      onPressed: () async {
        final picked = await showQueryRefPicker(
          buildContext,
          editor: context,
          kind: kind,
          title: title,
          searchHint: strings.pickRefSearch,
          selected: current,
        );
        if (picked != null) onChanged(picked);
      },
      label: Text(current?.label ?? title),
    );
  }

  bool _known(QuerySubject kind, String id) {
    final names = context.names;
    if (names is! NameEntries) return true;
    for (final label in names.entryLabels(kind)) {
      if (names.resolve(kind, label)?.id == id) return true;
    }
    return false;
  }
}

/// A number field with its own controller, so a rebuild with the same
/// value does not move the caret.
class _NumberField extends StatefulWidget {
  const _NumberField({
    super.key,
    required this.initialText,
    required this.suffix,
    required this.onChanged,
  });

  final String initialText;
  final String? suffix;
  final ValueChanged<String> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
    decoration: InputDecoration(suffixText: widget.suffix, isDense: true),
    onChanged: widget.onChanged,
  );
}

class _TextValueField extends StatefulWidget {
  const _TextValueField({required this.initialText, required this.onChanged});

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_TextValueField> createState() => _TextValueFieldState();
}

class _TextValueFieldState extends State<_TextValueField> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: const InputDecoration(isDense: true),
    onChanged: widget.onChanged,
  );
}
```

`_known` returns true for a resolver that cannot list entries (the parser-only `NameResolver`), so the warning icon appears only when the app's index is in hand and the id is absent from it. If profiling later shows the linear scan slow on the species list, add `String? labelOf(kind, id)` to `NameEntries`; the app's `QueryNameIndex` already has it.

- [ ] **Step 5: Write the row and the group**

`lib/core/query/presentation/query_condition_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_field_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// Opens the field picker and, for a relation, the ref picker, and returns
/// a complete default condition, or null when the diver backed out. Shared
/// by "Add condition", "Add group" and a row's field button.
Future<ConditionNode?> pickCondition(
  BuildContext buildContext, {
  required QueryEditorContext context,
  required QueryBuilderStrings strings,
  int hopsUsed = 0,
}) async {
  final pick = await showQueryFieldPicker(
    buildContext,
    editor: context,
    strings: QueryFieldPickerStrings(
      title: strings.pickField,
      searchHint: strings.pickFieldSearch,
      useRelation: strings.useRelation,
      fieldsOf: strings.fieldsOf,
    ),
    hopsUsed: hopsUsed,
  );
  if (pick == null || !buildContext.mounted) return null;
  final target = resolvePath(context.registry, context.root, pick.path);
  final op = opsFor(target).first;
  if (pick.isRelation) {
    final rel = target.terminalRelation!;
    final ref = await showQueryRefPicker(
      buildContext,
      editor: context,
      kind: rel.target,
      title: strings.pickRef.replaceAll(
        '{name}',
        context.labels.relation(rel),
      ),
      searchHint: strings.pickRefSearch,
    );
    if (ref == null) return null;
    return ConditionNode(pick.path, op, ref);
  }
  return ConditionNode(pick.path, op, defaultValueFor(target, op, context));
}

/// One condition: the field button (reopens the picker), the operator menu
/// and the value editor. Negation and removal are the group's affordances.
class QueryConditionRow extends StatelessWidget {
  const QueryConditionRow({
    super.key,
    required this.context,
    required this.condition,
    required this.onChanged,
    required this.strings,
    this.hopsUsed = 0,
  });

  final QueryEditorContext context;
  final ConditionNode condition;
  final ValueChanged<ConditionNode> onChanged;
  final QueryBuilderStrings strings;
  final int hopsUsed;

  @override
  Widget build(BuildContext buildContext) {
    final target = resolvePath(context.registry, context.root, condition.path);
    final field = target.field;
    final rel = target.terminalRelation;
    final label = field != null
        ? context.labels.field(field)
        : rel != null
        ? context.labels.relation(rel)
        : condition.path.toString();
    // The relations walked before the terminal field or relation.
    final crumbHops = field != null
        ? target.hops
        : target.hops.sublist(0, target.hops.length - 1);
    final crumbs = [for (final h in crumbHops) context.labels.relation(h)];
    final ops = opsFor(target);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () async {
            final next = await pickCondition(
              buildContext,
              context: context,
              strings: strings,
              hopsUsed: hopsUsed,
            );
            if (next != null) onChanged(next);
          },
          child: Text(
            crumbs.isEmpty ? label : '${crumbs.join(' > ')} > $label',
          ),
        ),
        DropdownButton<QueryOp>(
          value: ops.contains(condition.op) ? condition.op : ops.first,
          items: [
            for (final op in ops)
              DropdownMenuItem(value: op, child: Text(context.labels.op(op))),
          ],
          onChanged: (op) {
            if (op == null || op == condition.op) return;
            final next = _valueFor(op, target);
            if (op.takesValue && next == null) return;
            onChanged(ConditionNode(condition.path, op, next));
          },
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 320),
          child: QueryValueEditor(
            context: context,
            target: target,
            op: condition.op,
            value: condition.value,
            onChanged: (v) =>
                onChanged(ConditionNode(condition.path, condition.op, v)),
            strings: strings,
          ),
        ),
      ],
    );
  }

  /// The value the row keeps when its operator changes to [op]: the same
  /// value across scalar comparisons, a ref carried into or out of a list,
  /// otherwise the type's default. Null when [op] takes none, or when a
  /// relation would need a pick the diver has not made.
  QueryValue? _valueFor(QueryOp op, PathResolution target) {
    if (!op.takesValue) return null;
    final current = condition.value;
    if (condition.op.takesValue && sameValueShape(condition.op, op)) {
      return current;
    }
    if (target.terminalRelation != null) {
      return switch ((op, current)) {
        (QueryOp.inList, final RefValue r) => ListValue([r]),
        (QueryOp.inList, final ListValue l) when l.items.isNotEmpty => l,
        (_, final ListValue l) when l.items.isNotEmpty => l.items.first,
        (_, final RefValue r) => r,
        _ => null,
      };
    }
    return defaultValueFor(target, op, context);
  }
}
```

`lib/core/query/presentation/query_builder_group.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_condition_row.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// The rule builder of spec Unit 6: a group is a card with an AND/OR
/// toggle; rows are field, operator, value; a row can be negated; "Add
/// group" nests. Renders [root] and reports every edit as a new, normalised
/// tree through [onChanged]. A null root is an empty AND card.
class QueryBuilderGroup extends StatelessWidget {
  const QueryBuilderGroup({
    super.key,
    required this.context,
    required this.root,
    required this.onChanged,
    required this.strings,
  });

  final QueryEditorContext context;
  final QueryNode? root;
  final ValueChanged<QueryNode?> onChanged;
  final QueryBuilderStrings strings;

  @override
  Widget build(BuildContext buildContext) {
    final tree = root ?? AndNode(const []);
    // A bare condition or NOT at the root is shown inside an AND card so
    // the add buttons and the negate toggle have a home.
    final shown = tree is AndNode || tree is OrNode ? tree : AndNode([tree]);
    return _Group(
      context: context,
      strings: strings,
      root: shown,
      path: const [],
      hopsUsed: 0,
      onTree: (next) => onChanged(normalizeQuery(next)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.context,
    required this.strings,
    required this.root,
    required this.path,
    required this.hopsUsed,
    required this.onTree,
  });

  final QueryEditorContext context;
  final QueryBuilderStrings strings;
  final QueryNode root;
  final NodePath path;
  final int hopsUsed;
  final ValueChanged<QueryNode> onTree;

  Future<void> _add(BuildContext buildContext, {required bool asGroup}) async {
    final cond = await pickCondition(
      buildContext,
      context: context,
      strings: strings,
      hopsUsed: hopsUsed,
    );
    if (cond == null) return;
    final group = nodeAt(root, path);
    // A new group starts with the opposite op, the usual reason to nest.
    final child = !asGroup
        ? cond
        : group is AndNode
        ? OrNode([cond])
        : AndNode([cond]);
    onTree(appendChild(root, path, child));
  }

  @override
  Widget build(BuildContext buildContext) {
    final group = nodeAt(root, path)!;
    final isAnd = group is AndNode;
    final children = switch (group) {
      AndNode(:final children) => children,
      OrNode(:final children) => children,
      _ => throw StateError('not a group at $path'),
    };
    final theme = Theme.of(buildContext);
    return Card(
      key: ValueKey('group-${path.join('.')}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(strings.allOf)),
                    ButtonSegment(value: false, label: Text(strings.anyOf)),
                  ],
                  selected: {isAnd},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      onTree(setGroupOp(root, path, and: s.single)),
                ),
                const Spacer(),
                if (path.isNotEmpty)
                  IconButton(
                    key: ValueKey('remove-${path.join('.')}'),
                    icon: const Icon(Icons.close),
                    tooltip: strings.remove,
                    onPressed: () =>
                        onTree(removeAt(root, path) ?? AndNode(const [])),
                  ),
              ],
            ),
            for (var i = 0; i < children.length; i++)
              _child(buildContext, children[i], [...path, i], theme),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(strings.addCondition),
                  onPressed: () => _add(buildContext, asGroup: false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(strings.addGroup),
                  onPressed: () => _add(buildContext, asGroup: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _child(
    BuildContext buildContext,
    QueryNode node,
    NodePath at,
    ThemeData theme,
  ) {
    final negated = node is NotNode;
    final inner = negated ? node.child : node;
    final innerPath = negated ? [...at, 0] : at;
    final key = at.join('.');
    final Widget body;
    switch (inner) {
      case AndNode() || OrNode():
        body = _Group(
          context: context,
          strings: strings,
          root: root,
          path: innerPath,
          hopsUsed: hopsUsed,
          onTree: onTree,
        );
      case ConditionNode():
        body = QueryConditionRow(
          context: context,
          condition: inner,
          strings: strings,
          hopsUsed: hopsUsed,
          onChanged: (c) => onTree(replaceAt(root, innerPath, c)),
        );
      case TextNode(:final words):
        body = _TextRow(
          label: strings.textRow,
          initial: words.join(' '),
          onChanged: (t) {
            final w = t
                .trim()
                .split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty)
                .toList();
            if (w.isNotEmpty) onTree(replaceAt(root, innerPath, TextNode(w)));
          },
        );
      case ScopedNode(:final path):
        final rel = resolvePath(
          context.registry,
          context.root,
          path,
        ).terminalRelation;
        body = ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline),
          title: Text(
            context.printer.print(inner),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          subtitle: Text(
            strings.scopedRow.replaceAll(
              '{name}',
              rel == null ? path.toString() : context.labels.relation(rel),
            ),
          ),
        );
      case NotNode():
        // NOT NOT is normalised away before it gets here.
        body = _child(buildContext, inner, innerPath, theme);
    }
    final isGroup = inner is AndNode || inner is OrNode;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: ValueKey('negate-$key'),
            isSelected: negated,
            tooltip: strings.negate,
            icon: const Icon(Icons.block_outlined),
            selectedIcon: Icon(Icons.block, color: theme.colorScheme.error),
            onPressed: () => onTree(toggleNegation(root, at)),
          ),
          Expanded(child: body),
          if (!isGroup)
            IconButton(
              key: ValueKey('remove-$key'),
              icon: const Icon(Icons.close),
              tooltip: strings.remove,
              onPressed: () => onTree(removeAt(root, at) ?? AndNode(const [])),
            ),
        ],
      ),
    );
  }
}

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label, isDense: true),
    onChanged: widget.onChanged,
  );
}
```

The root card's `ValueKey('group-')` and the nested `ValueKey('group-1')` are what the group test finds. `removeAt` returning null (the last row gone) shows an empty AND card, which `normalizeQuery` turns into null for `onChanged`. A bare condition at the root is wrapped in an AND for display, and the first edit reports the wrapped form (`AndNode([...])`), which the compiler and printer accept like any group; the text tab shows it without parentheses.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/ test/architecture/preference_aware_date_format_test.dart test/shared/widgets/app_date_picker_adoption_test.dart`
Expected: PASS. `isoDay` interpolates `d.month.toString()`, which the date-format guard's `.month}` pattern does not match; if the guard still flags the file, allowlist it there with the reason "query literals print ISO days".

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_builder_strings.dart lib/core/query/presentation/query_value_editor.dart lib/core/query/presentation/query_condition_row.dart lib/core/query/presentation/query_builder_group.dart test/core/query/presentation/query_value_editor_test.dart test/core/query/presentation/query_builder_group_test.dart
git commit -m "feat(query): the rule builder: typed value editors, condition rows, nested groups"
```

---

### Task 9: The editor widget and its dive wrapper

**Files:**
- Create: `lib/core/query/presentation/query_editor.dart`, `lib/features/query/presentation/dive_query_editor.dart`
- Modify: `lib/l10n/arb/app_en.arb` (the editor strings; the other locales come in Task 18)
- Test: `test/core/query/presentation/query_editor_test.dart`, `test/features/query/presentation/dive_query_editor_test.dart`

**Interfaces:**
- Consumes: `QueryTextField`, `QueryBuilderGroup`, `QueryBuilderStrings`, `QueryEditorContext`, `queryUnitPrefsProvider`, `queryNameIndexProvider`, `AppQueryLabels`, `appQueryRegistry`, `diveQueryEntity`.
- Produces:

```dart
class QueryEditorStrings { const QueryEditorStrings({required tabText, required tabBuilder, required hint, required save, required builder /* QueryBuilderStrings */}); }
class QueryEditor extends StatefulWidget {
  const QueryEditor({required context, required value, required onChanged, required strings, VoidCallback? onSave /* null hides Save */, Key? key});
}
class DiveQueryEditor extends ConsumerWidget {
  const DiveQueryEditor({required value, required onChanged, VoidCallback? onSave, Key? key});
}
QueryBuilderStrings queryBuilderStringsOf(AppLocalizations l10n);
QueryEditorStrings queryEditorStringsOf(AppLocalizations l10n);
```

Behaviour: a `TabBar` (Text, Builder) over one `value`; the shown tab's widget renders `value`, so an edit on one tab is visible on the other. Save is a `FilledButton.tonalIcon`, enabled when `value != null`.

- [ ] **Step 1: Write the failing tests**

`test/core/query/presentation/query_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_editor.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';
import 'query_value_editor_test.dart' show kTestBuilderStrings;

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'rating': 'Rating'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  const strings = QueryEditorStrings(
    tabText: 'Text',
    tabBuilder: 'Builder',
    hint: 'Type a query',
    save: 'Save query',
    builder: kTestBuilderStrings,
  );

  Widget host(
    QueryNode? value,
    ValueChanged<QueryNode?> onChanged, {
    VoidCallback? onSave,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: QueryEditor(
          context: context,
          value: value,
          onChanged: onChanged,
          strings: strings,
          onSave: onSave,
        ),
      ),
    ),
  );

  testWidgets('the builder round-trips a nested group typed in the text tab', (
    tester,
  ) async {
    QueryNode? value;
    await tester.pumpWidget(host(null, (n) => value = n));
    await tester.enterText(
      find.byType(TextField).first,
      'depth > 30 AND (rating >= 4 OR NOT rating:any)',
    );
    await tester.pump();
    expect(value, isNotNull);
    await tester.pumpWidget(host(value, (n) => value = n));
    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Rating'), findsNWidgets(2));
    // Flip the nested group to AND and check the text tab prints it.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('group-1')),
        matching: find.text('All of'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(host(value, (n) => value = n));
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'depth > 30 AND (rating >= 4 AND NOT rating:any)',
    );
  });

  testWidgets('save is enabled only with a query and calls back', (
    tester,
  ) async {
    var saved = 0;
    await tester.pumpWidget(host(null, (_) {}, onSave: () => saved++));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save query'))
          .enabled,
      isFalse,
    );
    final tree = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    );
    await tester.pumpWidget(host(tree, (_) {}, onSave: () => saved++));
    await tester.tap(find.text('Save query'));
    expect(saved, 1);
  });

  testWidgets('no onSave hides the button', (tester) async {
    await tester.pumpWidget(host(null, (_) {}));
    expect(find.text('Save query'), findsNothing);
  });
}
```

The printed text pins the printer's parenthesisation of a nested same-op group (`normalizeQuery` does not flatten nesting, Task 4). If the printer emits it without parentheses, pin what it prints; PR 1's round-trip property is the real guard.

`test/features/query/presentation/dive_query_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('parses in the diver units against the app registry and names', (
    tester,
  ) async {
    QueryNode? value;
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(depthUnit: DepthUnit.feet),
            ),
          ),
          queryNameIndexProvider.overrideWith(
            (ref) async => const QueryNameIndex({
              QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
            }),
          ),
        ],
        child: SingleChildScrollView(
          child: DiveQueryEditor(value: null, onChanged: (n) => value = n),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'depth > 100 site = "Salt Pier"',
    );
    await tester.pump();
    final and = value! as AndNode;
    expect(and.children, hasLength(2));
    final depth = and.children[0] as ConditionNode;
    expect(depth.path, FieldPath(['depth']));
    expect((depth.value! as NumberValue).value, closeTo(30.48, 0.001));
    expect(
      and.children[1],
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s1', 'Salt Pier'),
      ),
    );
    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_editor_test.dart test/features/query/presentation/dive_query_editor_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the editor**

`lib/core/query/presentation/query_editor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_group.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';

@immutable
class QueryEditorStrings {
  const QueryEditorStrings({
    required this.tabText,
    required this.tabBuilder,
    required this.hint,
    required this.save,
    required this.builder,
  });

  final String tabText;
  final String tabBuilder;
  final String hint;
  final String save;
  final QueryBuilderStrings builder;
}

/// The shared editor of spec Unit 6: two tabs over one tree. The text tab
/// and the builder each write [onChanged]; both render [value], so an edit
/// on one is what the other shows.
class QueryEditor extends StatefulWidget {
  const QueryEditor({
    super.key,
    required this.context,
    required this.value,
    required this.onChanged,
    required this.strings,
    this.onSave,
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final QueryEditorStrings strings;

  /// Shown as a Save button when set; enabled while [value] is not null.
  final VoidCallback? onSave;

  @override
  State<QueryEditor> createState() => _QueryEditorState();
}

class _QueryEditorState extends State<QueryEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: strings.tabText),
                  Tab(text: strings.tabBuilder),
                ],
              ),
            ),
            if (widget.onSave != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(strings.save),
                  onPressed: widget.value == null ? null : widget.onSave,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Not a TabBarView: that needs a bounded height, which a section
        // inside a ListView does not give it. Swapping the child takes the
        // height of whichever tab is showing.
        AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => _tabs.index == 0
              ? QueryTextField(
                  context: widget.context,
                  value: widget.value,
                  onChanged: widget.onChanged,
                  hintText: strings.hint,
                )
              : QueryBuilderGroup(
                  context: widget.context,
                  root: widget.value,
                  onChanged: widget.onChanged,
                  strings: strings.builder,
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add the English strings and the dive wrapper**

In `lib/l10n/arb/app_en.arb`, after the `query_op_*` block, add:

```json
  "query_editor_tabText": "Text",
  "@query_editor_tabText": {"description": "Query editor tab: the typed field"},
  "query_editor_tabBuilder": "Builder",
  "@query_editor_tabBuilder": {"description": "Query editor tab: the rule builder"},
  "query_editor_hint": "e.g. weights:none AND depth > 30",
  "@query_editor_hint": {"description": "Placeholder in the typed query field; the example is query syntax and stays in English in every locale"},
  "query_editor_save": "Save query",
  "@query_editor_save": {"description": "Button that saves the current query under a name"},
  "query_editor_allOf": "All of",
  "@query_editor_allOf": {"description": "Group toggle: every row must match (AND)"},
  "query_editor_anyOf": "Any of",
  "@query_editor_anyOf": {"description": "Group toggle: one row must match (OR)"},
  "query_editor_addCondition": "Add condition",
  "@query_editor_addCondition": {"description": "Builder button"},
  "query_editor_addGroup": "Add group",
  "@query_editor_addGroup": {"description": "Builder button that nests a group"},
  "query_editor_negate": "Not",
  "@query_editor_negate": {"description": "Tooltip of the toggle that negates a row"},
  "query_editor_remove": "Remove",
  "@query_editor_remove": {"description": "Tooltip of the button that removes a row or group"},
  "query_editor_pickField": "Choose a field",
  "@query_editor_pickField": {"description": "Field picker title"},
  "query_editor_pickFieldSearch": "Search fields",
  "@query_editor_pickFieldSearch": {"description": "Field picker search hint"},
  "query_editor_useRelation": "Use {name} itself",
  "@query_editor_useRelation": {"description": "Field picker: pick the relation as a value rather than one of its fields", "placeholders": {"name": {"type": "String"}}},
  "query_editor_fieldsOf": "Fields of {name}",
  "@query_editor_fieldsOf": {"description": "Field picker: heading after walking into a relation", "placeholders": {"name": {"type": "String"}}},
  "query_editor_pickRef": "Choose {name}",
  "@query_editor_pickRef": {"description": "Ref picker title, name is the relation label", "placeholders": {"name": {"type": "String"}}},
  "query_editor_pickRefSearch": "Search",
  "@query_editor_pickRefSearch": {"description": "Ref picker search hint"},
  "query_editor_done": "Done",
  "@query_editor_done": {"description": "Multi-ref picker confirm button"},
  "query_editor_unresolvedRef": "No longer exists",
  "@query_editor_unresolvedRef": {"description": "Tooltip on a saved reference whose row was deleted"},
  "query_editor_scopedRow": "Group over {name}: edit in the Text tab",
  "@query_editor_scopedRow": {"description": "Builder row for a scoped group the builder cannot edit", "placeholders": {"name": {"type": "String"}}},
  "query_editor_textRow": "Text search",
  "@query_editor_textRow": {"description": "Builder row label for a free-text term"},
  "query_editor_betweenAnd": "and",
  "@query_editor_betweenAnd": {"description": "Between two bounds: 'between X and Y'"},
  "query_editor_valueTrue": "Yes",
  "@query_editor_valueTrue": {"description": "Boolean value editor"},
  "query_editor_valueFalse": "No",
  "@query_editor_valueFalse": {"description": "Boolean value editor"},
```

Then `flutter gen-l10n` so the getters exist. `test/l10n/arb_parity_test.dart` stays red until Task 18 adds the other locales; do not run the l10n suite in this task's gate. Rerun `python3 scripts/gen_query_label_lookup.py` (the keys start with `query_`, so the lookup gains them; harmless, and the guard test in Task 2 expects it).

`lib/features/query/presentation/dive_query_editor.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The placeholder strings pass a literal `{name}` through the ARB getter
/// so the core widgets substitute the label themselves.
QueryBuilderStrings queryBuilderStringsOf(AppLocalizations l10n) =>
    QueryBuilderStrings(
      allOf: l10n.query_editor_allOf,
      anyOf: l10n.query_editor_anyOf,
      addCondition: l10n.query_editor_addCondition,
      addGroup: l10n.query_editor_addGroup,
      negate: l10n.query_editor_negate,
      remove: l10n.query_editor_remove,
      pickField: l10n.query_editor_pickField,
      pickFieldSearch: l10n.query_editor_pickFieldSearch,
      useRelation: l10n.query_editor_useRelation('{name}'),
      fieldsOf: l10n.query_editor_fieldsOf('{name}'),
      pickRef: l10n.query_editor_pickRef('{name}'),
      pickRefSearch: l10n.query_editor_pickRefSearch,
      done: l10n.query_editor_done,
      unresolvedRef: l10n.query_editor_unresolvedRef,
      scopedRow: l10n.query_editor_scopedRow('{name}'),
      textRow: l10n.query_editor_textRow,
      betweenAnd: l10n.query_editor_betweenAnd,
      valueTrue: l10n.query_editor_valueTrue,
      valueFalse: l10n.query_editor_valueFalse,
    );

QueryEditorStrings queryEditorStringsOf(AppLocalizations l10n) =>
    QueryEditorStrings(
      tabText: l10n.query_editor_tabText,
      tabBuilder: l10n.query_editor_tabBuilder,
      hint: l10n.query_editor_hint,
      save: l10n.query_editor_save,
      builder: queryBuilderStringsOf(l10n),
    );

/// The dive query editor: [QueryEditor] over the app registry, the diver's
/// units, the live name index and the ARB labels (#2365). Until the name
/// index arrives the editor parses against an empty index, so a typed ref
/// name fails with suggestions rather than blocking the field.
class DiveQueryEditor extends ConsumerWidget {
  const DiveQueryEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSave,
  });

  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(queryUnitPrefsProvider);
    final names =
        ref.watch(queryNameIndexProvider).value ?? QueryNameIndex.empty;
    final editorContext = QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: prefs,
      names: names,
      labels: AppQueryLabels(context),
      now: DateTime.now,
    );
    return QueryEditor(
      context: editorContext,
      value: value,
      onChanged: onChanged,
      strings: queryEditorStringsOf(context.l10n),
      onSave: onSave,
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/core/query/presentation/query_editor_test.dart test/features/query/presentation/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/presentation/query_editor.dart lib/features/query/presentation/dive_query_editor.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb/ test/core/query/presentation/query_editor_test.dart test/features/query/presentation/dive_query_editor_test.dart
git commit -m "feat(query): QueryEditor with Text and Builder tabs, and the dive wrapper over the app registry"
```

---

### Task 10: Placement: the search page's Query section and the quick sheet's Query row, both applying through copyWith

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_search_page.dart`, `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`, `lib/core/router/app_router.dart` (lines 389-402), `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_log/presentation/pages/dive_search_page_query_test.dart`, `test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart`

**Interfaces:**
- Consumes: `DiveQueryEditor`, `DiveFilterState.copyWith` (every `clearX` flag), `diveFilterProvider`, `insightsFilterProvider`, `GoRouterState.uri.queryParameters`.
- Produces: `DiveSearchPage({filterProvider, String? initialSection})`; the route `/dives/search?section=query`; the sheet's Query row.

Today both editors build a brand-new `DiveFilterState` on Apply, which drops `query` and every axis the surface does not edit (the sheet drops `tripId`, `diveCenterId`, `equipmentIds`, `buddyId`, `diveIds`, the custom field pair and `decoOnly`; the search page drops `excludedFromStatsOnly`, `buddyId`, `diveIds`, `computerId` and `equipmentAttrConditions`). This task makes both write through `copyWith` from the provider's current state: an axis the surface edits is set (or cleared with its flag when the local value is empty); an axis it does not edit is kept.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The quick sheet neither shows nor edits the advanced query; applying it
/// must keep the query (and every other axis it does not edit) rather than
/// replace the whole state (#2365).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final query = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );
  final seeded = StateProvider<DiveFilterState>(
    (ref) => DiveFilterState(
      query: query,
      tripId: 'trip-1',
      decoOnly: true,
      favoritesOnly: true,
    ),
  );

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    late ProviderContainer container;
    String? pushed;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        DiveFilterSheet(ref: ref, filterProvider: seeded),
                  ),
                  child: const Text('Open filter'),
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: '/dives/search',
          builder: (context, state) {
            pushed = state.uri.toString();
            return const Scaffold(body: Text('search page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open filter'));
    await tester.pumpAndSettle();
    addTearDown(() => pushed = null);
    return container;
  }

  testWidgets('Apply keeps an advanced query it does not edit', (tester) async {
    final container = await pumpSheet(tester);
    // Turn favorites off in the sheet, the one axis this test edits.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('filter-favorites-only')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('filter-favorites-only')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final applied = container.read(seeded);
    expect(applied.query, query);
    expect(applied.tripId, 'trip-1');
    expect(applied.decoOnly, isTrue);
    expect(applied.favoritesOnly, isNull);
  });

  testWidgets('the Query row opens the search page on its query section', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(find.text('search page'), findsOneWidget);
  });
}
```

Find the favorites switch's key in `dive_filter_sheet.dart` (grep `SwitchListTile` near "favorites"); if it has none, give it `key: const ValueKey('filter-favorites-only')` in Step 3. The `pushed` capture asserts the URL when you need it: `expect(pushed, '/dives/search?section=query')`. Add that line to the second test after the `find.text('search page')` assertion.

`test/features/dive_log/presentation/pages/dive_search_page_query_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The search page hosts the query editor above its sections and applies
/// through copyWith, so axes it does not edit survive (#2365).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<Override>> overrides(DiveFilterState seed) async => [
    ...await getBaseOverrides(),
    diveFilterProvider.overrideWith((ref) => seed),
    queryNameIndexProvider.overrideWith(
      (ref) async => const QueryNameIndex({
        QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
      }),
    ),
  ].cast<Override>();

  Future<ProviderContainer> pumpPage(
    WidgetTester tester,
    DiveFilterState seed, {
    String? section,
  }) async {
    late ProviderContainer container;
    final router = GoRouter(
      initialLocation: section == null ? '/dives/search' : '/dives/search?section=$section',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, _) {
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: Text('dive list'));
          },
          routes: [
            GoRoute(
              path: 'search',
              builder: (context, state) {
                container = ProviderScope.containerOf(context);
                return DiveSearchPage(
                  initialSection: state.uri.queryParameters['section'],
                );
              },
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: await overrides(seed),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a typed query is applied and a computer id is kept', (
    tester,
  ) async {
    final container = await pumpPage(
      tester,
      const DiveFilterState(computerId: 'dc-1', excludedFromStatsOnly: true),
      section: 'query',
    );
    // The query section is expanded by the route parameter.
    expect(find.byType(TextField).first, findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'depth > 30');
    await tester.pump();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final applied = container.read(diveFilterProvider);
    expect(
      applied.query,
      ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
    );
    expect(applied.computerId, 'dc-1');
    expect(applied.excludedFromStatsOnly, isTrue);
  });

  testWidgets('an existing query expands the section and prints into the field', (
    tester,
  ) async {
    await pumpPage(
      tester,
      DiveFilterState(
        query: ConditionNode(
          FieldPath(['site']),
          QueryOp.eq,
          const RefValue('s1', 'Salt Pier'),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'site = "Salt Pier"',
    );
  });

  testWidgets('Clear all clears the query too', (tester) async {
    final container = await pumpPage(
      tester,
      DiveFilterState(
        query: ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
      ),
    );
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).query, isNull);
  });
}
```

If `find.text('Clear all')` matches the app bar action's exact string differently (it is `diveLog_search_clearAll`), read its English value from `app_en.arb` and pin that.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart test/features/dive_log/presentation/pages/dive_search_page_query_test.dart`
Expected: FAIL (`initialSection` undefined; the sheet has no "Query" text; Apply drops the query).

- [ ] **Step 3: The sheet: Query row and copyWith apply**

In `dive_filter_sheet.dart`, after the "Advanced search" `Align(...)` block (ends near line 269) and before `const SizedBox(height: 16)`, add a second link:

```dart
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () {
                            // Same push-not-go reasoning as the link above.
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push(
                              '/dives/search?section=query',
                              extra: widget.filterProvider,
                            );
                          },
                          icon: const Icon(Icons.code, size: 18),
                          label: Text(context.l10n.diveLog_filter_queryRow),
                        ),
                      ),
```

Replace `_applyFilters` (lines 1257-1288) with:

```dart
  /// Writes the sheet's axes over the current state with copyWith, so the
  /// axes this sheet does not edit (the advanced query, trip, centre, gear
  /// ids, buddy id, the Insights dive-id seam, custom fields, deco) survive
  /// an Apply (#2365). An axis the sheet edits is set, or cleared with its
  /// flag when the sheet's value is empty.
  void _applyFilters() {
    final current = widget.ref.read(widget.filterProvider);
    final computerId = _resolveComputerId();
    widget.ref.read(widget.filterProvider.notifier).state = current.copyWith(
      startDate: _startDate,
      clearStartDate: _startDate == null,
      endDate: _endDate,
      clearEndDate: _endDate == null,
      diveTypeId: _diveTypeId,
      clearDiveType: _diveTypeId == null,
      siteId: _siteId,
      clearSiteId: _siteId == null,
      minDepth: _minDepth,
      clearMinDepth: _minDepth == null,
      maxDepth: _maxDepth,
      clearMaxDepth: _maxDepth == null,
      favoritesOnly: _favoritesOnly ? true : null,
      clearFavoritesOnly: !_favoritesOnly,
      excludedFromStatsOnly: _excludedFromStatsOnly ? true : null,
      clearExcludedFromStatsOnly: !_excludedFromStatsOnly,
      tagIds: _selectedTagIds,
      weekdays: _selectedWeekdays,
      buddyNameFilter: _buddyNameFilter,
      clearBuddyNameFilter: _buddyNameFilter == null || _buddyNameFilter!.isEmpty,
      noBuddyOnly: _noBuddyOnly ? true : null,
      clearNoBuddyOnly: !_noBuddyOnly,
      minO2Percent: _minO2Percent,
      clearMinO2Percent: _minO2Percent == null,
      maxO2Percent: _maxO2Percent,
      clearMaxO2Percent: _maxO2Percent == null,
      minRating: _minRating,
      clearMinRating: _minRating == null,
      minBottomTimeMinutes: _minDurationMinutes,
      clearMinBottomTimeMinutes: _minDurationMinutes == null,
      maxBottomTimeMinutes: _maxDurationMinutes,
      clearMaxBottomTimeMinutes: _maxDurationMinutes == null,
      computerId: computerId,
      clearComputerId: computerId == null,
      equipmentAttrConditions: [
        if (_suitThicknessMin != null || _suitThicknessMax != null)
          EquipmentAttrCondition.suitThickness(
            min: _suitThicknessMin,
            max: _suitThicknessMax,
          ),
        ..._gearConditions,
      ],
    );
    Navigator.of(context).pop();
  }
```

Check `copyWith`'s implementation for the precedence of `clearX` over a non-null value: the pattern is `x: clearX ? null : (x ?? this.x)`, so passing both a null value and `clearX: true` clears, and a non-null value with `clearX: false` sets. Both are what the code above relies on.

Add to `app_en.arb` next to the other `diveLog_filter_*` keys:

```json
  "diveLog_filter_queryRow": "Query",
  "@diveLog_filter_queryRow": {"description": "Quick filter sheet row that opens the advanced search on its query editor"},
  "diveLog_search_section_query": "Query",
  "@diveLog_search_section_query": {"description": "Advanced search section that hosts the query editor"},
```

- [ ] **Step 4: The search page: Query section, initialSection, copyWith apply**

In `dive_search_page.dart`:

1. Constructor: add `final String? initialSection;` and `const DiveSearchPage({super.key, this.filterProvider, this.initialSection});`.
2. State: add `QueryNode? _query;` beside the other locals, `'query': false` to `_expanded`, and in `initState` after `_customFieldValueController.text = ...`:

```dart
    _query = filter.query;
    if (_query != null || widget.initialSection == 'query') {
      _expanded['query'] = true;
    }
```

3. In `build`, as the first entry of the `ListView` children, before the Date Range section:

```dart
            // Query section: the typed field and the rule builder over the
            // advanced part of the filter (#2365).
            _buildSection(
              key: 'query',
              title: context.l10n.diveLog_search_section_query,
              icon: Icons.code,
              child: DiveQueryEditor(
                value: _query,
                onChanged: (node) => setState(() => _query = node),
              ),
            ),
```

with the import `package:submersion/features/query/presentation/dive_query_editor.dart` and `package:submersion/core/query/domain/query_node.dart`.

4. `_clearAll`: add `_query = null;` inside the `setState`.
5. Replace the body of `_applyAndSearch` up to the navigation with:

```dart
    final current = ref.read(_filterProvider);
    ref.read(_filterProvider.notifier).state = current.copyWith(
      startDate: _startDate,
      clearStartDate: _startDate == null,
      endDate: _endDate,
      clearEndDate: _endDate == null,
      weekdays: _selectedWeekdays,
      siteId: _siteId,
      clearSiteId: _siteId == null,
      tripId: _tripId,
      clearTripId: _tripId == null,
      diveCenterId: _diveCenterId,
      clearDiveCenterId: _diveCenterId == null,
      minDepth: _minDepth,
      clearMinDepth: _minDepth == null,
      maxDepth: _maxDepth,
      clearMaxDepth: _maxDepth == null,
      minBottomTimeMinutes: _minDurationMinutes,
      clearMinBottomTimeMinutes: _minDurationMinutes == null,
      maxBottomTimeMinutes: _maxDurationMinutes,
      clearMaxBottomTimeMinutes: _maxDurationMinutes == null,
      decoOnly: _decoOnly,
      clearDecoOnly: _decoOnly == null,
      diveTypeId: _diveTypeId,
      clearDiveType: _diveTypeId == null,
      minO2Percent: _minO2Percent,
      clearMinO2Percent: _minO2Percent == null,
      maxO2Percent: _maxO2Percent,
      clearMaxO2Percent: _maxO2Percent == null,
      equipmentIds: _equipmentIds,
      buddyNameFilter: _buddyNameFilter,
      clearBuddyNameFilter: _buddyNameFilter == null || _buddyNameFilter!.isEmpty,
      noBuddyOnly: _noBuddyOnly ? true : null,
      clearNoBuddyOnly: !_noBuddyOnly,
      tagIds: _selectedTagIds,
      minRating: _minRating,
      clearMinRating: _minRating == null,
      favoritesOnly: _favoritesOnly ? true : null,
      clearFavoritesOnly: !_favoritesOnly,
      customFieldKey: _customFieldKey,
      clearCustomFieldKey: _customFieldKey == null || _customFieldKey!.isEmpty,
      customFieldValue: _customFieldValue,
      clearCustomFieldValue: _customFieldValue == null || _customFieldValue!.isEmpty,
      query: _query,
      clearQuery: _query == null,
    );
```

6. Router, `lib/core/router/app_router.dart` lines 389-402: pass `initialSection: state.uri.queryParameters['section']` to the `DiveSearchPage` constructor.

The existing tests `dive_search_page_filter_target_test.dart`, `dive_search_page_test.dart`, `dive_filter_sheet_test.dart` and `dive_filter_sheet_interactions_test.dart` seed states and assert what Apply writes; run them all in Step 5 and read any failure closely: a test that asserted an unedited axis was dropped is asserting the old defect, and its expectation changes to "kept" (say so in the test's comment). A test that fails for any other reason is a regression to fix.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter gen-l10n && TMPDIR=/tmp flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart test/features/dive_log/presentation/pages/dive_search_page_query_test.dart test/features/dive_log/presentation/pages/ test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart test/features/insights/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/dive_log/presentation/pages/dive_search_page.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/core/router/app_router.dart lib/l10n/arb/ test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart test/features/dive_log/presentation/pages/dive_search_page_query_test.dart
git commit -m "feat(query): query section on the search page, a Query row on the quick sheet, both applying through copyWith"
```

---

### Task 11: Chips for the advanced query

**Files:**
- Create: `lib/features/query/presentation/dive_query_chips.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildActiveFiltersBar`, lines 2088-2291)
- Test: `test/features/query/presentation/dive_query_chips_test.dart`, `test/features/dive_log/presentation/widgets/dive_list_content_query_chip_test.dart`

**Interfaces:**
- Consumes: `topLevelConjuncts`, `removeTopLevelConjunct`, `QueryPrinter`, `appQueryRegistry`, `diveQueryEntity`, `queryUnitPrefsProvider`, `UnitPrefs`.
- Produces:

```dart
/// One label per top-level AND child of [query], printed in [prefs].
List<String> diveQueryChipLabels(QueryNode? query, UnitPrefs prefs);
/// The filter after removing the chip at [index]; clears `query` when nothing is left.
DiveFilterState removeDiveQueryChip(DiveFilterState filter, int index);
```

- [ ] **Step 1: Write the failing tests**

`test/features/query/presentation/dive_query_chips_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/query/presentation/dive_query_chips.dart';

void main() {
  final depth = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30.48, null),
  );
  final noWeights = ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null);
  final either = OrNode([
    ConditionNode(FieldPath(['waterTemp']), QueryOp.isEmpty, null),
    noWeights,
  ]);

  test('one chip per top-level AND child, printed in the diver unit', () {
    expect(
      diveQueryChipLabels(AndNode([depth, noWeights]), kMetricPrefs),
      ['depth > 30.48', 'weights:none'],
    );
    const feet = UnitPrefs(
      depth: DepthUnit.feet,
      temperature: TemperatureUnit.celsius,
      pressure: PressureUnit.bar,
      weight: WeightUnit.kilograms,
      volume: VolumeUnit.liters,
    );
    expect(diveQueryChipLabels(AndNode([depth]), feet), ['depth > 100']);
  });

  test('an OR at the top is one chip; null is none', () {
    expect(diveQueryChipLabels(either, kMetricPrefs), ['waterTemp:none OR weights:none']);
    expect(diveQueryChipLabels(null, kMetricPrefs), isEmpty);
  });

  test('removing a chip removes exactly its child', () {
    final filter = DiveFilterState(query: AndNode([depth, noWeights]), siteId: 's1');
    final one = removeDiveQueryChip(filter, 0);
    expect(one.query, noWeights);
    expect(one.siteId, 's1');
    expect(removeDiveQueryChip(one, 0).query, isNull);
    expect(removeDiveQueryChip(one, 0).hasActiveFilters, isTrue);
  });
}
```

`test/features/dive_log/presentation/widgets/dive_list_content_query_chip_test.dart` follows `dive_list_content_no_buddy_chip_test.dart` exactly (copy its `_MockPaginatedNotifier` and `buildContent`), with these three tests:

```dart
  final query = AndNode([
    ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
    ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null),
  ]);

  testWidgets('each top-level AND child renders its own chip', (tester) async {
    await tester.pumpWidget(await buildContent(DiveFilterState(query: query)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'depth > 30'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'weights:none'), findsOneWidget);
  });

  testWidgets('the chip prints in the current unit setting', (tester) async {
    // The seed stores 30 m; under feet the chip must read 98.43, so the
    // chip can never claim a strictness the filter does not apply.
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(depthUnit: DepthUnit.feet),
      ),
    );
    ...same pump as buildContent but with these overrides...
    expect(find.widgetWithText(Chip, 'depth > 98.4252'), findsOneWidget);
  });

  testWidgets('deleting a chip removes only its child', (tester) async {
    await tester.pumpWidget(await buildContent(DiveFilterState(query: query)));
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(Chip, 'depth > 30');
    await tester.tap(find.descendant(of: chip, matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(find.widgetWithText(Chip, 'weights:none'), findsOneWidget);
  });
```

Write the second test in full by parameterising `buildContent` with an optional `MockSettingsNotifier`. The printed feet value is `formatQueryNumber(30 / 0.3048)` at four decimals; run the printer once to pin the exact string.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/dive_query_chips_test.dart test/features/dive_log/presentation/widgets/dive_list_content_query_chip_test.dart`
Expected: FAIL to compile, then (after the helper exists) no query chips found.

- [ ] **Step 3: Write the helper**

`lib/features/query/presentation/dive_query_chips.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The chips of spec Unit 5: one per top-level AND child of the advanced
/// query, labelled by the printer in the diver's units. Printing from the
/// tree the compiler consumes is what guarantees a chip never claims a
/// strictness the filter does not apply.
List<String> diveQueryChipLabels(QueryNode? query, UnitPrefs prefs) {
  final printer = QueryPrinter(appQueryRegistry, diveQueryEntity, prefs);
  return [for (final part in topLevelConjuncts(query)) printer.print(part)];
}

/// [filter] with the chip at [index] removed; `query` is cleared when the
/// last one goes.
DiveFilterState removeDiveQueryChip(DiveFilterState filter, int index) {
  final next = removeTopLevelConjunct(filter.query, index);
  return next == null
      ? filter.copyWith(clearQuery: true)
      : filter.copyWith(query: next);
}
```

- [ ] **Step 4: Render the chips**

In `dive_list_content.dart`, `_buildActiveFiltersBar`, after the buddy-name chip block (before `return Container(`):

```dart
    // The advanced query: one chip per top-level AND child (#2365).
    final queryLabels = diveQueryChipLabels(
      filter.query,
      ref.watch(queryUnitPrefsProvider),
    );
    for (var i = 0; i < queryLabels.length; i++) {
      chips.add(
        _buildFilterChip(context, queryLabels[i], () {
          ref.read(diveFilterProvider.notifier).state = removeDiveQueryChip(
            filter,
            i,
          );
        }),
      );
    }
```

Imports: `package:submersion/features/query/presentation/dive_query_chips.dart` and `package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart`. Give the chip's `Text` a monospace style only if the design reviewer asks; the existing chips are plain text and the query chips match them.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/dive_query_chips_test.dart test/features/dive_log/presentation/widgets/dive_list_content_query_chip_test.dart test/features/dive_log/presentation/widgets/dive_list_content_no_buddy_chip_test.dart test/features/dive_log/presentation/widgets/dive_list_content_dive_type_chip_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/presentation/dive_query_chips.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/query/presentation/dive_query_chips_test.dart test/features/dive_log/presentation/widgets/dive_list_content_query_chip_test.dart
git commit -m "feat(query): one chip per top-level condition of the advanced query, printed in the diver's units"
```

---

### Task 12: Schema rung 232: the saved_queries table

**Files:**
- Modify: `lib/core/database/database.dart` (table class near the `CylinderFills` table at line 3344; the `@DriftDatabase(tables: [...])` list ending near line 4447; `currentSchemaVersion` at 4457; `migrationVersions` near 5117; an `_assertSavedQueriesSchema` helper near `_assertCylinderFillsSchema` at 8723; the onUpgrade step after the v230 step near 12804; the beforeOpen backstop near 12835), `lib/core/database/performance_indexes.dart` (near line 410), `test/core/database/migration_v230_nav_tracks_test.dart` (relax the exact pins)
- Test: `test/core/database/migration_v232_saved_queries_test.dart`

**Interfaces:**
- Produces: Drift table `SavedQueries` (`@DataClassName('SavedQueryRow')`, companion `SavedQueriesCompanion`, accessor `db.savedQueries`, table name `saved_queries`), `AppDatabase.currentSchemaVersion == 232`.

- [ ] **Step 1: Re-scan the ladder**

```bash
python3.14 - <<'EOF'
import json, re, subprocess
prs = json.loads(subprocess.run(["gh","pr","list","--state","open","--limit","100","--json","number,title"],capture_output=True,text=True).stdout)
for pr in prs:
    files = json.loads(subprocess.run(["gh","api","--paginate",f"repos/submersion-app/submersion/pulls/{pr['number']}/files"],capture_output=True,text=True).stdout or "[]")
    for f in files:
        if f.get("filename")=="lib/core/database/database.dart":
            m = re.findall(r"^\+\s*static const int currentSchemaVersion = (\d+);", f.get("patch",""), re.M)
            if m: print(pr["number"], m, pr["title"])
EOF
git fetch -q origin main && git show origin/main:lib/core/database/database.dart | grep -n "static const int currentSchemaVersion"
```

Expected on 2026-09-26: main at 230, four PRs at 231, nobody at 232. If a PR now claims 232, take the next free number and use it everywhere this task says 232.

- [ ] **Step 2: Write the failing test**

`test/core/database/migration_v232_saved_queries_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v232 adds saved_queries: a diver's named query trees (#2365, spec
/// Unit 7). Table-only rung, additive, floor stays at 224.

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v232 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 232);
    expect(AppDatabase.migrationVersions, contains(232));
    expect(AppDatabase.migrationStepCount(230), 1);
  });

  test('a fresh database has saved_queries, its columns and its index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _tables(db), contains('saved_queries'));
    expect(
      await _columns(db, 'saved_queries'),
      {
        'id',
        'diver_id',
        'subject',
        'name',
        'query_json',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      },
    );
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'saved_queries'",
        )
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      contains('idx_saved_queries_diver'),
    );
  });

  test('a database stranded before v232 gains the table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 230');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('saved_queries'));
    // Idempotent: opening again re-asserts without error.
    await db.customStatement('SELECT 1');
  });

  test('the backstop skips a fixture with no divers table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 230'),
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    // No throw; the helper returns early when the parent is missing.
    await db.customStatement('SELECT 1');
  });
}
```

Read the `divers` table's NOT NULL columns in `database.dart` before running the stranded test; the CREATE TABLE above must satisfy `createTable(savedQueries)`'s foreign key, which only needs `divers(id)` to exist, so the minimal columns are fine.

Also in `test/core/database/migration_v230_nav_tracks_test.dart` change `expect(AppDatabase.currentSchemaVersion, 230);` to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(230));` and `expect(AppDatabase.migrationStepCount(228), 1);` to `greaterThanOrEqualTo(1)`, as its own comment instructs.

- [ ] **Step 3: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/core/database/migration_v232_saved_queries_test.dart`
Expected: FAIL (version is 230; no table).

- [ ] **Step 4: Add the table, the rung and the index**

In `database.dart`, after the `CylinderFills` class:

```dart
/// A named query a diver saved (entity query language #2365, v232, spec
/// Unit 7). [queryJson] is the versioned AST from `queryNodeToJson`, never
/// the printed text, so a grammar change cannot break stored rows; the
/// printer regenerates the text on load. [subject] is the root entity's
/// `QuerySubject.name` (`dives`, `sites`, ...). Synced with its own hlc,
/// registered like [CylinderFills]; per diver, tombstoned with the diver.
@DataClassName('SavedQueryRow')
class SavedQueries extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get subject => text()();
  TextColumn get name => text()();
  TextColumn get queryJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add `SavedQueries,` to the `tables:` list after `CylinderFills,` with the comment `// Saved queries (v232, issue #2365)`.

Set `static const int currentSchemaVersion = 232;`.

Append to `migrationVersions` after `230,`:

```dart
    // v232: saved_queries, a diver's named query trees (issue #2365, spec
    // Unit 7). Table-only rung, additive, floor stays at 224. 231 was held
    // by four open PRs when this rung was taken (2026-09-26).
    232,
```

Add the helper after `_assertCylinderFillsSchema`:

```dart
  /// Idempotent creation of the v232 `saved_queries` table and its lookup
  /// index (issue #2365). Called from the v232 rung and the beforeOpen
  /// backstop. Skipped on a partial migration-test fixture that lacks the
  /// divers table the foreign key points at.
  Future<void> _assertSavedQueriesSchema() async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'divers'",
    ).get();
    if (rows.isEmpty) return;
    await createMigrator().createTable(savedQueries);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_saved_queries_diver '
      'ON saved_queries(diver_id, subject, sort_order)',
    );
  }
```

In onUpgrade after the v230 block:

```dart
        // v232: saved_queries (issue #2365). A new synced table, so
        // onUpgrade need only create it; idempotent and re-asserted in the
        // beforeOpen backstop against parallel-branch version collisions.
        if (from < 232) {
          await _assertSavedQueriesSchema();
        }
        if (from < 232) await reportProgress();
```

In beforeOpen after the v230 backstop:

```dart
        // v232 backstop: re-assert the saved_queries table. A database that
        // arrives by restore or sync-adopt never runs onUpgrade.
        await _assertSavedQueriesSchema();
```

In `performance_indexes.dart` after the cylinder fills entries:

```dart
  // Saved queries (v232, issue #2365): one diver's queries for one subject,
  // in display order.
  (
    name: 'idx_saved_queries_diver',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_saved_queries_diver '
        'ON saved_queries(diver_id, subject, sort_order)',
  ),
```

Regenerate Drift: `bash scripts/setup.sh` (the plain `dart run build_runner build` form can be refused by the harness; the script runs the same codegen). Check `lib/core/database/database.g.dart` now defines `SavedQueryRow` and `SavedQueriesCompanion`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/core/database/migration_v232_saved_queries_test.dart test/core/database/migration_v230_nav_tracks_test.dart test/core/database/ test/core/services/sync/sync_hlc_target_registration_test.dart`
Expected: the migration tests PASS; `sync_hlc_target_registration_test.dart` FAILS ("every table with an hlc column must be in hlcTargets"), which Task 13 fixes. If `test/core/database/` has a test pinning `migrationStepCount` or the ladder's last element, relax it the way the v230 test says.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v232_saved_queries_test.dart test/core/database/migration_v230_nav_tracks_test.dart
git commit -m "feat(query): schema v232, the saved_queries table"
```

---

### Task 13: SavedQuery entity, repository and sync registration

**Files:**
- Create: `lib/features/query/domain/entities/saved_query.dart`, `lib/features/query/data/repositories/saved_query_repository.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/features/divers/data/repositories/diver_owned_rows.dart`, `test/core/services/sync/sync_parent_refs_completeness_test.dart`, `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`, `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`, `test/architecture/repository_tick_stream_test.dart`
- Test: `test/features/query/domain/entities/saved_query_test.dart`, `test/features/query/data/repositories/saved_query_repository_test.dart`, `test/core/services/sync/saved_queries_sync_round_trip_test.dart`

**Interfaces:**
- Consumes: `queryNodeToJson`, `SavedQueriesCompanion`, `SavedQueryRow`, `SyncRepository.markRecordPending/logDeletion`, `SyncEventBus.notifyLocalChange`, `Uuid`.
- Produces:

```dart
class SavedQuery {   // immutable, value equality, copyWith
  const SavedQuery({required id, diverId, required subject /* String, QuerySubject.name */, required name, required queryJson, sortOrder = 0, required createdAt, required updatedAt});
  QuerySubject? get querySubject;   // null for a subject this build does not know
}
class SavedQueryRepository {
  Stream<void> watchSavedQueriesChanges();
  Future<List<SavedQuery>> getAll({String? subject, String? diverId});   // (diver_id = ? OR diver_id IS NULL), by sort_order then name
  Future<SavedQuery?> getById(String id);
  Future<SavedQuery> create({required QuerySubject subject, required String name, required QueryNode node, required String diverId});
  Future<void> rename(String id, String name);
  Future<void> updateQuery(String id, QueryNode node);
  Future<void> reorder(List<String> orderedIds);
  Future<void> delete(String id);
}
```

Sync entity type: `savedQueries`, table `saved_queries`, `hasUpdatedAt: true`, no `parentRefs` entry (its only FK is `diverId`, which `parentRefs` excludes by design).

- [ ] **Step 1: Write the failing tests**

`test/features/query/domain/entities/saved_query_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

void main() {
  final q = SavedQuery(
    id: 'q1',
    diverId: 'me',
    subject: 'dives',
    name: 'Deep',
    queryJson: '{"version":1,"node":{}}',
    createdAt: DateTime(2026, 9, 26),
    updatedAt: DateTime(2026, 9, 26),
  );

  test('value equality and copyWith', () {
    expect(q, q.copyWith());
    expect(q.copyWith(name: 'Deeper').name, 'Deeper');
    expect(q.copyWith(name: 'Deeper'), isNot(q));
    expect(q.copyWith(clearDiverId: true).diverId, isNull);
  });

  test('querySubject parses known names and tolerates unknown ones', () {
    expect(q.querySubject, QuerySubject.dives);
    expect(q.copyWith(subject: 'starships').querySubject, isNull);
  });
}
```

`test/features/query/data/repositories/saved_query_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SavedQueryRepository repo;
  final node = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime(2026, 9, 26).millisecondsSinceEpoch;
    for (final id in ['me', 'other']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$id', '$id', $now, $now)",
      );
    }
    repo = SavedQueryRepository();
  });
  tearDown(tearDownTestDatabase);

  test('create stores the versioned JSON and stamps sync state', () async {
    final saved = await repo.create(
      subject: QuerySubject.dives,
      name: ' Deep ',
      node: node,
      diverId: 'me',
    );
    expect(saved.name, 'Deep');
    expect(saved.subject, 'dives');
    expect(queryNodeFromJson(jsonDecode(saved.queryJson) as Map<String, Object?>), node);
    final row = await (db.select(db.savedQueries)..where((t) => t.id.equals(saved.id))).getSingle();
    expect(row.hlc, isNotNull);
    final pending = await db.customSelect(
      "SELECT 1 FROM sync_pending WHERE entity_type = 'savedQueries' AND record_id = ?",
      variables: [Variable<String>(saved.id)],
    ).get();
    expect(pending, isNotEmpty);
  });

  test('getAll is scoped to the diver plus unowned rows, ordered', () async {
    final a = await repo.create(subject: QuerySubject.dives, name: 'B', node: node, diverId: 'me');
    final b = await repo.create(subject: QuerySubject.dives, name: 'A', node: node, diverId: 'me');
    await repo.create(subject: QuerySubject.dives, name: 'Theirs', node: node, diverId: 'other');
    await repo.create(subject: QuerySubject.sites, name: 'Sites', node: node, diverId: 'me');
    final mine = await repo.getAll(subject: 'dives', diverId: 'me');
    expect(mine.map((q) => q.name), ['B', 'A']); // creation order = sort order
    await repo.reorder([b.id, a.id]);
    expect((await repo.getAll(subject: 'dives', diverId: 'me')).map((q) => q.name), ['A', 'B']);
    expect((await repo.getAll(diverId: 'me')).map((q) => q.subject), containsAll(['dives', 'sites']));
  });

  test('rename, updateQuery and delete', () async {
    final saved = await repo.create(subject: QuerySubject.dives, name: 'Deep', node: node, diverId: 'me');
    await repo.rename(saved.id, 'Deeper');
    expect((await repo.getById(saved.id))!.name, 'Deeper');
    final other = ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null);
    await repo.updateQuery(saved.id, other);
    expect(
      queryNodeFromJson(jsonDecode((await repo.getById(saved.id))!.queryJson) as Map<String, Object?>),
      other,
    );
    await repo.delete(saved.id);
    expect(await repo.getById(saved.id), isNull);
    final tomb = await db.customSelect(
      "SELECT 1 FROM deletion_log WHERE entity_type = 'savedQueries' AND record_id = ?",
      variables: [Variable<String>(saved.id)],
    ).get();
    expect(tomb, isNotEmpty);
  });

  test('the tick fires on a write', () async {
    var fired = false;
    final sub = repo.watchSavedQueriesChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);
    await repo.create(subject: QuerySubject.dives, name: 'x', node: node, diverId: 'me');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fired, isTrue);
  });
}
```

Check the sync tables' names before running: grep `database.dart` for the pending-record table (`SyncPending`? `sync_records`?) and the deletion log (`DeletionLog`); pin the real names and columns in the two raw SELECTs, or drop those two assertions and rely on the round-trip test below plus the existing repository pattern.

`test/core/services/sync/saved_queries_sync_round_trip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A saved query travels through every per-record sync arm unchanged
/// (#2365).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {String name = 'Deep'}) => {
    'id': id,
    'diverId': null,
    'subject': 'dives',
    'name': name,
    'queryJson': '{"version":1,"node":{"t":"cond","path":["depth"],"op":"gt","value":{"k":"num","v":30.0}}}',
    'sortOrder': 0,
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch and delete one saved query', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('savedQueries', row('q1'));
    final fetched = await s.fetchRecord('savedQueries', 'q1');
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Deep');
    expect(fetched['queryJson'], contains('"t":"cond"'));

    await s.upsertRecord('savedQueries', row('q1', name: 'Deeper'));
    expect((await s.fetchRecord('savedQueries', 'q1'))!['name'], 'Deeper');

    await s.deleteRecord('savedQueries', 'q1');
    expect(await s.fetchRecord('savedQueries', 'q1'), isNull);
  });

  test('batch upsert and fetch keep every saved query', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('savedQueries', [row('a'), row('b', name: 'Shallow')]);
    final fetched = await s.fetchRecords('savedQueries', ['a', 'b', 'x']);
    expect(fetched.keys, unorderedEquals(['a', 'b']));
    expect(fetched['b']!['name'], 'Shallow');
    expect(await s.recordIdsFor('savedQueries'), unorderedEquals(['a', 'b']));
  });
}
```

Check `recordIdsFor`'s exact return type in the serializer (a `Set<String>` or a list) and match the matcher.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/query/domain/entities/saved_query_test.dart test/features/query/data/repositories/saved_query_repository_test.dart test/core/services/sync/saved_queries_sync_round_trip_test.dart`
Expected: FAIL (compile errors for the entity and repository; the round trip throws `ArgumentError: upsertRecords: unknown entityType savedQueries`).

- [ ] **Step 3: Write the entity**

`lib/features/query/domain/entities/saved_query.dart`:

```dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';

/// A named query a diver saved (#2365, spec Unit 7). [queryJson] is the
/// versioned AST; [subject] is the root entity's `QuerySubject.name`, kept
/// as text so a row from a newer build with a subject this one lacks still
/// loads (flagged) instead of failing to map.
@immutable
class SavedQuery {
  const SavedQuery({
    required this.id,
    this.diverId,
    required this.subject,
    required this.name,
    required this.queryJson,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? diverId;
  final String subject;
  final String name;
  final String queryJson;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuerySubject? get querySubject {
    for (final s in QuerySubject.values) {
      if (s.name == subject) return s;
    }
    return null;
  }

  SavedQuery copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? subject,
    String? name,
    String? queryJson,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedQuery(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    subject: subject ?? this.subject,
    name: name ?? this.name,
    queryJson: queryJson ?? this.queryJson,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SavedQuery &&
      other.id == id &&
      other.diverId == diverId &&
      other.subject == subject &&
      other.name == name &&
      other.queryJson == queryJson &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    diverId,
    subject,
    name,
    queryJson,
    sortOrder,
    createdAt,
    updatedAt,
  );
}
```

- [ ] **Step 4: Write the repository**

`lib/features/query/data/repositories/saved_query_repository.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

/// Saved queries (#2365, spec Unit 7): create, rename, replace the tree,
/// reorder, delete, each stamped for sync like [DiveRoleRepository]. Reads
/// are scoped to one diver plus rows with no owner.
class SavedQueryRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SavedQueryRepository);

  static const entityType = 'savedQueries';

  /// Emits whenever the `saved_queries` table changes, so the chip rows
  /// and the Manage page refresh after a sync or any other write.
  Stream<void> watchSavedQueriesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.savedQueries));

  Future<List<SavedQuery>> getAll({String? subject, String? diverId}) async {
    final query = _db.select(_db.savedQueries)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]);
    if (subject != null) query.where((t) => t.subject.equals(subject));
    query.where(
      (t) => diverId == null
          ? t.diverId.isNull()
          : t.diverId.equals(diverId) | t.diverId.isNull(),
    );
    return (await query.get()).map(_fromRow).toList();
  }

  Future<SavedQuery?> getById(String id) async {
    final row = await (_db.select(
      _db.savedQueries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<SavedQuery> create({
    required QuerySubject subject,
    required String name,
    required QueryNode node,
    required String diverId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSort = await _maxSortOrder(subject.name, diverId);
      await _db
          .into(_db.savedQueries)
          .insert(
            SavedQueriesCompanion(
              id: Value(id),
              diverId: Value(diverId),
              subject: Value(subject.name),
              name: Value(name.trim()),
              queryJson: Value(jsonEncode(queryNodeToJson(node))),
              sortOrder: Value(maxSort + 1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _stamp(id, now);
      _log.info('Saved query $id (${name.trim()}) for diver $diverId');
      return (await getById(id))!;
    } catch (e, st) {
      _log.error('Failed to save query', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> rename(String id, String name) => _update(
    id,
    SavedQueriesCompanion(name: Value(name.trim())),
  );

  Future<void> updateQuery(String id, QueryNode node) => _update(
    id,
    SavedQueriesCompanion(queryJson: Value(jsonEncode(queryNodeToJson(node)))),
  );

  /// Rewrites sort_order so [orderedIds] run 0..n-1, in one transaction,
  /// then marks each row pending once.
  Future<void> reorder(List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.savedQueries)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(
              SavedQueriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
            );
      }
    });
    for (final id in orderedIds) {
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    try {
      await (_db.delete(_db.savedQueries)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted saved query $id');
    } catch (e, st) {
      _log.error('Failed to delete saved query $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _update(String id, SavedQueriesCompanion patch) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.savedQueries)..where((t) => t.id.equals(id))).write(
      patch.copyWith(updatedAt: Value(now)),
    );
    await _stamp(id, now);
  }

  Future<void> _stamp(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<int> _maxSortOrder(String subject, String diverId) async {
    final result = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS max_order FROM saved_queries '
          'WHERE subject = ? AND diver_id = ?',
          variables: [Variable<String>(subject), Variable<String>(diverId)],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? -1;
  }

  SavedQuery _fromRow(SavedQueryRow row) => SavedQuery(
    id: row.id,
    diverId: row.diverId,
    subject: row.subject,
    name: row.name,
    queryJson: row.queryJson,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
```

- [ ] **Step 5: Register the entity for sync**

Every edit mirrors the `cylinderFills` entry beside it; the line numbers are from the survey and may have drifted, so locate each by its `cylinderFills` neighbour.

`lib/core/data/repositories/sync_repository.dart`, `hlcTargets` (after `'cylinderFills'` at line 99):

```dart
    'savedQueries': (table: 'saved_queries', pk: 'id'),
```

`lib/core/services/sync/sync_service.dart`:
- `mergeOrder` (after the `cylinderFills` tuple near 1465):

```dart
          // Saved queries reference sites and buddies only inside their
          // JSON (by id, resolved at load), so they carry no FK but the
          // diver and can apply anywhere in the order.
          (
            type: 'savedQueries',
            records: data.savedQueries,
            hasUpdatedAt: true,
          ),
```

- `entityHasUpdatedAt` (after `'cylinderFills': true,` near 2392): `'savedQueries': true,`.
- `parentRefs`: no entry (only `diverId`, excluded by design; the completeness test's `syncedTables` map documents that).

`lib/core/services/sync/sync_data_serializer.dart`:
- `SyncData` field (after line 315): `final List<Map<String, dynamic>> savedQueries;`
- constructor (after 413): `this.savedQueries = const [],`
- `toJson` (after 506): `'savedQueries': savedQueries,`
- `fromJson` (after 602): `savedQueries: _parseList(json['savedQueries']),`
- `_baseTables` (after 1024): `(key: 'savedQueries', table: _db.savedQueries, blob: false, full: null),`
- incremental export (after 2044):

```dart
      savedQueries: await _safeExport(
        'savedQueries',
        () => _exportSavedQueries(hlcSince),
      ),
```

- `fetchRecord` (after the `cylinderFills` case at 2663):

```dart
      case 'savedQueries':
        final row = await (_db.select(
          _db.savedQueries,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

- `fetchRecords` (after 3059):

```dart
      case 'savedQueries':
        final rows = await (_db.select(
          _db.savedQueries,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

- `upsertRecord` (after 4031):

```dart
      case 'savedQueries':
        await _db
            .into(_db.savedQueries)
            .insertOnConflictUpdate(
              SavedQueryRow.fromJson(data).toCompanion(false),
            );
        return;
```

- `upsertRecords` (after 5109):

```dart
      case 'savedQueries':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.savedQueries,
            records
                .map((r) => SavedQueryRow.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```

- `recordIdsFor` (after 5546): `case 'savedQueries': return plain(_db.savedQueries, _db.savedQueries.id);`
- `_syncTableFor` (after 5927): `case 'savedQueries': return _db.savedQueries;`
- `deleteRecord` (after 6371):

```dart
      case 'savedQueries':
        await (_db.delete(
          _db.savedQueries,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- exporter (after `_exportCylinderFills`):

```dart
  Future<List<Map<String, dynamic>>> _exportSavedQueries(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.savedQueries);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

`lib/features/divers/data/repositories/diver_owned_rows.dart`, after the `cylinder_fills` entry:

```dart
  (
    table: 'saved_queries',
    entityType: 'savedQueries',
    hasBuiltIns: false,
    children: [],
  ),
```

Tests that enumerate tables by hand:
- `test/core/services/sync/sync_parent_refs_completeness_test.dart`: add `'saved_queries': 'savedQueries',` to `syncedTables` (after `'cylinder_fills'`); not to `deletableParents`.
- `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`: add `(type: 'savedQueries', table: db.savedQueries.actualTableName),` after the `cylinderFills` entry.
- `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`: add a fixture after `'a cylinder fill'`:

```dart
    'a saved query': () async {
      await db
          .into(db.savedQueries)
          .insert(
            SavedQueriesCompanion.insert(
              id: 'sq-a',
              subject: 'dives',
              name: 'Deep',
              queryJson: '{"version":1,"node":{"t":"text","words":["x"]}}',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('saved_queries', 'savedQueries', 'sq-a')];
    },
```

and `'saved_queries',` to the `_clearedByDelete` set.
- `test/architecture/repository_tick_stream_test.dart`: add `'SavedQueryRepository.watchSavedQueriesChanges': SavedQueryRepository().watchSavedQueriesChanges,` to the `ticks` map and a firing group modelled on `cylinder fills` that inserts a `SavedQueriesCompanion.insert(id: 'sq-tick', subject: 'dives', name: 'x', queryJson: '{}', createdAt: now, updatedAt: now)`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/features/query/ test/core/services/sync/ test/features/divers/data/repositories/diver_delete_owned_tables_test.dart test/architecture/repository_tick_stream_test.dart test/architecture/provider_change_tick_test.dart`
Expected: PASS, including `sync_hlc_target_registration_test.dart`, `sync_base_streaming_parity_test.dart`, `base_publish_streaming_parity_test.dart` and `sync_data_serializer_record_ids_test.dart`, which check the registrations against the live schema and the `SyncData` keys.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/domain/entities/saved_query.dart lib/features/query/data/repositories/saved_query_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/core/data/repositories/sync_repository.dart lib/features/divers/data/repositories/diver_owned_rows.dart test/features/query/domain/entities/saved_query_test.dart test/features/query/data/repositories/saved_query_repository_test.dart test/core/services/sync/saved_queries_sync_round_trip_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart test/architecture/repository_tick_stream_test.dart
git commit -m "feat(query): SavedQuery entity and repository, synced per diver like cylinder fills"
```

---

### Task 14: Loading a saved query: readable, flagged or unreadable

**Files:**
- Create: `lib/features/query/domain/saved_query_load.dart`, `lib/features/query/presentation/providers/saved_query_providers.dart`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart`
- Test: `test/features/query/domain/saved_query_load_test.dart`, `test/features/query/presentation/providers/saved_query_providers_test.dart`

**Interfaces:**
- Consumes: `queryNodeFromJson`, `QueryJsonException`, `validateQuery`, `resolvePath`, `QueryNameIndex.labelOf`, `SavedQueryRepository`, `validatedCurrentDiverIdProvider`, `queryNameIndexProvider`.
- Produces:

```dart
enum SavedQueryProblem { unreadable, invalid, unknownSubject, unresolvedRef }
class SavedQueryLoad {
  final SavedQuery saved; final QueryNode? node; final SavedQueryProblem? problem; final String? detail;
  bool get isApplicable;   // node != null (unresolvedRef still applies, flagged)
}
List<FieldPath> unresolvedRefPaths(QueryNode node, QueryEntity root, QueryRegistry registry, QueryNameIndex names);
SavedQueryLoad loadSavedQuery(SavedQuery saved, QueryRegistry registry, QueryNameIndex names);
final savedQueryRepositoryProvider = Provider<SavedQueryRepository>;
final savedQueriesProvider = FutureProvider.family<List<SavedQuery>, String? /* subject name, null = all */>;
final savedQueryLoadsProvider = FutureProvider.family<List<SavedQueryLoad>, String?>;
```

- [ ] **Step 1: Write the failing tests**

`test/features/query/domain/saved_query_load_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

void main() {
  const names = QueryNameIndex({
    QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
  });
  SavedQuery saved(String json, {String subject = 'dives'}) => SavedQuery(
    id: 'q',
    subject: subject,
    name: 'n',
    queryJson: json,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  String encode(QueryNode n) => jsonEncode(queryNodeToJson(n));
  final depth = ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null));

  test('a clean tree loads with no problem', () {
    final load = loadSavedQuery(saved(encode(depth)), appQueryRegistry, names);
    expect(load.node, depth);
    expect(load.problem, isNull);
    expect(load.isApplicable, isTrue);
  });

  test('a newer JSON version is unreadable, not a crash', () {
    final load = loadSavedQuery(
      saved('{"version":99,"node":{}}'),
      appQueryRegistry,
      names,
    );
    expect(load.node, isNull);
    expect(load.problem, SavedQueryProblem.unreadable);
    expect(load.detail, isNotEmpty);
    expect(load.isApplicable, isFalse);
  });

  test('corrupt text is unreadable', () {
    final load = loadSavedQuery(saved('not json'), appQueryRegistry, names);
    expect(load.problem, SavedQueryProblem.unreadable);
  });

  test('a tree naming a field this build lacks is invalid', () {
    final ghost = ConditionNode(FieldPath(['warpFactor']), QueryOp.gt, const NumberValue(9, null));
    final load = loadSavedQuery(saved(encode(ghost)), appQueryRegistry, names);
    expect(load.node, isNull);
    expect(load.problem, SavedQueryProblem.invalid);
    expect(load.detail, contains('warpFactor'));
  });

  test('an unknown subject is flagged', () {
    final load = loadSavedQuery(saved(encode(depth), subject: 'starships'), appQueryRegistry, names);
    expect(load.problem, SavedQueryProblem.unknownSubject);
    expect(load.isApplicable, isFalse);
  });

  test('an unresolved ref flags the load but keeps the tree', () {
    final gone = AndNode([
      depth,
      ConditionNode(FieldPath(['site']), QueryOp.eq, const RefValue('s-gone', 'Old Wall')),
    ]);
    final load = loadSavedQuery(saved(encode(gone)), appQueryRegistry, names);
    expect(load.node, gone);
    expect(load.problem, SavedQueryProblem.unresolvedRef);
    expect(load.isApplicable, isTrue);
    expect(
      unresolvedRefPaths(gone, appQueryRegistry.entityFor(QuerySubject.dives), appQueryRegistry, names),
      [FieldPath(['site'])],
    );
  });

  test('refs inside a scoped group and a list are checked too', () {
    final tree = ScopedNode(
      FieldPath(['buddies']),
      ConditionNode(
        FieldPath(['certifications']),
        QueryOp.inList,
        ListValue([const RefValue('c-gone', 'Rescue')]),
      ),
    );
    final paths = unresolvedRefPaths(
      tree,
      appQueryRegistry.entityFor(QuerySubject.dives),
      appQueryRegistry,
      names,
    );
    expect(paths, [FieldPath(['buddies', 'certifications'])]);
  });
}
```

`test/features/query/presentation/providers/saved_query_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  test('loads the diver\'s queries for a subject and refreshes on a write', () async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('me');

    expect(await container.read(savedQueryLoadsProvider('dives').future), isEmpty);

    await SavedQueryRepository().create(
      subject: QuerySubject.dives,
      name: 'Deep',
      node: ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
      diverId: 'me',
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final loads = await container.read(savedQueryLoadsProvider('dives').future);
    expect(loads.map((l) => l.saved.name), ['Deep']);
    expect(loads.single.problem, isNull);
    expect(await container.read(savedQueriesProvider(null).future), hasLength(1));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/query/domain/saved_query_load_test.dart test/features/query/presentation/providers/saved_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the load logic**

`lib/features/query/domain/saved_query_load.dart`:

```dart
import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

/// Why a saved row cannot be used as saved (spec Unit 7): unreadable JSON
/// (corrupt, or a newer version), a tree this build's registry rejects, a
/// subject this build lacks, or a ref whose row is gone. Only the last one
/// still applies; it opens with the row flagged rather than dropping the
/// condition.
enum SavedQueryProblem { unreadable, invalid, unknownSubject, unresolvedRef }

@immutable
class SavedQueryLoad {
  const SavedQueryLoad(this.saved, {this.node, this.problem, this.detail});

  final SavedQuery saved;
  final QueryNode? node;
  final SavedQueryProblem? problem;
  final String? detail;

  bool get isApplicable => node != null;
}

/// Every condition whose ref (or list of refs) names an id the index does
/// not know, as its path from [root]. Walks scoped groups against the
/// relation's entity.
List<FieldPath> unresolvedRefPaths(
  QueryNode node,
  QueryEntity root,
  QueryRegistry registry,
  QueryNameIndex names,
) {
  final out = <FieldPath>[];
  void walk(QueryNode n, QueryEntity scope, List<String> prefix) {
    switch (n) {
      case AndNode(:final children) || OrNode(:final children):
        for (final c in children) {
          walk(c, scope, prefix);
        }
      case NotNode(:final child):
        walk(child, scope, prefix);
      case ScopedNode(:final path, :final inner):
        final res = resolvePath(registry, scope, path);
        if (res.terminalRelation == null) return;
        walk(inner, res.entities.last, [...prefix, ...path.segments]);
      case ConditionNode(:final path, :final value):
        final res = resolvePath(registry, scope, path);
        final rel = res.terminalRelation;
        if (rel == null) return;
        final refs = switch (value) {
          RefValue() => [value],
          ListValue(:final items) => items.whereType<RefValue>().toList(),
          _ => const <RefValue>[],
        };
        if (refs.any((r) => names.labelOf(rel.target, r.id) == null)) {
          out.add(FieldPath([...prefix, ...path.segments]));
        }
      case TextNode():
        return;
    }
  }

  walk(node, root, const []);
  return out;
}

SavedQueryLoad loadSavedQuery(
  SavedQuery saved,
  QueryRegistry registry,
  QueryNameIndex names,
) {
  final subject = saved.querySubject;
  final root = subject == null ? null : registry.maybeEntityFor(subject);
  if (root == null) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unknownSubject,
      detail: saved.subject,
    );
  }
  final QueryNode node;
  try {
    final decoded = jsonDecode(saved.queryJson);
    if (decoded is! Map<String, Object?>) {
      throw const QueryJsonException('not an object');
    }
    node = queryNodeFromJson(decoded);
  } on QueryJsonException catch (e) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unreadable,
      detail: e.message,
    );
  } on FormatException catch (e) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unreadable,
      detail: e.message,
    );
  }
  final errors = validateQuery(node, root, registry);
  if (errors.isNotEmpty) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.invalid,
      detail: errors.first.message,
    );
  }
  final missing = unresolvedRefPaths(node, root, registry, names);
  if (missing.isNotEmpty) {
    return SavedQueryLoad(
      saved,
      node: node,
      problem: SavedQueryProblem.unresolvedRef,
      detail: missing.map((p) => p.toString()).join(', '),
    );
  }
  return SavedQueryLoad(saved, node: node);
}
```

`jsonDecode` returns `Map<String, dynamic>`, which `is Map<String, Object?>` accepts at runtime; if the analyzer complains about the cast in `queryNodeFromJson`'s parameter, pass `Map<String, Object?>.from(decoded)`.

- [ ] **Step 4: Write the providers**

`lib/features/query/presentation/providers/saved_query_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

final savedQueryRepositoryProvider = Provider<SavedQueryRepository>(
  (ref) => SavedQueryRepository(),
);

/// The current diver's saved queries for [subject] (a `QuerySubject.name`),
/// or every subject when null (the Manage page). Refreshes when the table
/// changes, including a sync applying a remote row.
final savedQueriesProvider = FutureProvider.family<List<SavedQuery>, String?>(
  (ref, subject) async {
    final repository = ref.watch(savedQueryRepositoryProvider);
    final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
    ref.invalidateSelfWhen(repository.watchSavedQueriesChanges());
    return repository.getAll(subject: subject, diverId: diverId);
  },
);

/// The same rows decoded against this build's registry and the live name
/// index, so a chip row or the Manage page can show each one readable,
/// flagged or unreadable (spec Unit 7).
final savedQueryLoadsProvider =
    FutureProvider.family<List<SavedQueryLoad>, String?>((ref, subject) async {
      final rows = await ref.watch(savedQueriesProvider(subject).future);
      final names = await ref.watch(queryNameIndexProvider.future);
      return [for (final r in rows) loadSavedQuery(r, appQueryRegistry, names)];
    });
```

Add both to `test/architecture/provider_tick_build_smoke_test.dart`'s `query` group: `(name: 'savedQueriesProvider', read: (c) => c.read(savedQueriesProvider('dives').future))` and the loads provider likewise.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TMPDIR=/tmp flutter test test/features/query/ test/architecture/provider_change_tick_test.dart test/architecture/provider_tick_build_smoke_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/domain/saved_query_load.dart lib/features/query/presentation/providers/saved_query_providers.dart test/features/query/domain/saved_query_load_test.dart test/features/query/presentation/providers/saved_query_providers_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(query): load saved queries as readable, flagged or unreadable, with list providers"
```

---

### Task 15: Save from the editor, apply from a Saved chip row

**Files:**
- Create: `lib/features/query/presentation/widgets/save_query_dialog.dart`, `lib/features/query/presentation/widgets/saved_query_chip_row.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_search_page.dart` (the Query section), `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (top of the list), `lib/l10n/arb/app_en.arb`
- Test: `test/features/query/presentation/widgets/save_query_dialog_test.dart`, `test/features/query/presentation/widgets/saved_query_chip_row_test.dart`, plus two cases added to Task 10's page and sheet tests

**Interfaces:**
- Consumes: `savedQueryRepositoryProvider`, `savedQueryLoadsProvider`, `validatedCurrentDiverIdProvider`, `DiveQueryEditor.onSave`.
- Produces:

```dart
Future<String?> showSaveQueryDialog(BuildContext context, {String? initialName});   // trimmed name or null
class SavedQueryChipRow extends ConsumerWidget {
  const SavedQueryChipRow({required QuerySubject subject, required ValueChanged<SavedQueryLoad> onApply, Key? key});
}
```

The row renders nothing when the diver has no saved queries for the subject. A readable load is an `ActionChip` with a bookmark icon; an `unresolvedRef` load carries a warning icon and still applies; `unreadable`, `invalid` and `unknownSubject` loads render disabled with an error icon and show their `detail` in a SnackBar on tap.

- [ ] **Step 1: Write the failing tests**

`test/features/query/presentation/widgets/save_query_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('returns the trimmed name, refuses an empty one', (tester) async {
    String? result;
    await tester.pumpWidget(
      testAppInShell(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSaveQueryDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  Deep ones ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Deep ones');
  });
}
```

`test/features/query/presentation/widgets/saved_query_chip_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';

import '../../../../helpers/test_app.dart';

void main() {
  SavedQuery saved(String id, String name) => SavedQuery(
    id: id,
    subject: 'dives',
    name: name,
    queryJson: '{}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final depth = ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null));

  Widget host(List<SavedQueryLoad> loads, ValueChanged<SavedQueryLoad> onApply) => testApp(
    overrides: [
      savedQueryLoadsProvider('dives').overrideWith((ref) async => loads),
    ],
    child: SavedQueryChipRow(subject: QuerySubject.dives, onApply: onApply),
  );

  testWidgets('renders nothing with no saved queries', (tester) async {
    await tester.pumpWidget(host(const [], (_) {}));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('a readable query applies on tap', (tester) async {
    SavedQueryLoad? applied;
    await tester.pumpWidget(
      host([SavedQueryLoad(saved('a', 'Deep'), node: depth)], (l) => applied = l),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Deep'));
    expect(applied?.node, depth);
  });

  testWidgets('a flagged query applies and shows the warning; an unreadable one does not apply', (
    tester,
  ) async {
    final applied = <SavedQueryLoad>[];
    await tester.pumpWidget(
      host([
        SavedQueryLoad(saved('a', 'Old site'), node: depth, problem: SavedQueryProblem.unresolvedRef, detail: 'site'),
        SavedQueryLoad(saved('b', 'Future'), problem: SavedQueryProblem.unreadable, detail: 'version 99'),
      ], applied.add),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Old site'));
    await tester.tap(find.widgetWithText(ActionChip, 'Future'));
    await tester.pump();
    expect(applied.map((l) => l.saved.id), ['a']);
    expect(find.textContaining('version 99'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/widgets/`
Expected: FAIL to compile.

- [ ] **Step 3: Add the strings and write the dialog**

`app_en.arb`, after the `query_editor_*` block:

```json
  "query_saveDialog_title": "Save query",
  "@query_saveDialog_title": {"description": "Dialog that names a query being saved"},
  "query_saveDialog_nameLabel": "Name",
  "@query_saveDialog_nameLabel": {"description": "Save query dialog field label"},
  "query_saveDialog_nameValidation": "Enter a name",
  "@query_saveDialog_nameValidation": {"description": "Save query dialog validation"},
  "query_saved_snackbar": "Saved \"{name}\"",
  "@query_saved_snackbar": {"description": "Confirmation after saving a query", "placeholders": {"name": {"type": "String"}}},
  "query_savedRow_title": "Saved",
  "@query_savedRow_title": {"description": "Heading of the saved-query chip row"},
  "query_savedRow_unreadable": "Cannot read \"{name}\": {detail}",
  "@query_savedRow_unreadable": {"description": "Snackbar when tapping a saved query this build cannot read", "placeholders": {"name": {"type": "String"}, "detail": {"type": "String"}}},
  "query_savedRow_unresolved": "\"{name}\" refers to something that no longer exists",
  "@query_savedRow_unresolved": {"description": "Tooltip on a saved query with a deleted reference", "placeholders": {"name": {"type": "String"}}},
```

`lib/features/query/presentation/widgets/save_query_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The name prompt of spec Unit 7's "Save". Returns the trimmed name, or
/// null when dismissed. Modelled on the dive roles name dialog.
Future<String?> showSaveQueryDialog(
  BuildContext context, {
  String? initialName,
}) {
  final controller = TextEditingController(text: initialName);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.query_saveDialog_title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: dialogContext.l10n.query_saveDialog_nameLabel,
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => value == null || value.trim().isEmpty
              ? dialogContext.l10n.query_saveDialog_nameValidation
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(dialogContext).pop(controller.text.trim());
            }
          },
          child: Text(dialogContext.l10n.common_action_save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
```

If `common_action_save` renders as something other than `Save` in English, pin the test to the ARB value.

- [ ] **Step 4: Write the chip row**

`lib/features/query/presentation/widgets/saved_query_chip_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "Saved" chip row of spec Unit 7: one chip per saved query of
/// [subject]; tapping a readable one applies it. A query with a deleted
/// reference applies flagged; one this build cannot read is disabled and
/// explains itself on tap. Renders nothing when there is nothing saved.
class SavedQueryChipRow extends ConsumerWidget {
  const SavedQueryChipRow({
    super.key,
    required this.subject,
    required this.onApply,
  });

  final QuerySubject subject;
  final ValueChanged<SavedQueryLoad> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loads = ref.watch(savedQueryLoadsProvider(subject.name)).value;
    if (loads == null || loads.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.query_savedRow_title,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [for (final l in loads) _chip(context, l, theme)],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, SavedQueryLoad load, ThemeData theme) {
    final name = load.saved.name;
    switch (load.problem) {
      case null:
        return ActionChip(
          avatar: const Icon(Icons.bookmark_outline, size: 16),
          label: Text(name),
          onPressed: () => onApply(load),
        );
      case SavedQueryProblem.unresolvedRef:
        return Tooltip(
          message: context.l10n.query_savedRow_unresolved(name),
          child: ActionChip(
            avatar: Icon(
              Icons.warning_amber,
              size: 16,
              color: theme.colorScheme.tertiary,
            ),
            label: Text(name),
            onPressed: () => onApply(load),
          ),
        );
      case SavedQueryProblem.unreadable:
      case SavedQueryProblem.invalid:
      case SavedQueryProblem.unknownSubject:
        return ActionChip(
          avatar: Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.error,
          ),
          label: Text(name),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.query_savedRow_unreadable(name, load.detail ?? ''),
              ),
            ),
          ),
        );
    }
  }
}
```

- [ ] **Step 5: Wire Save and the chip rows into the two surfaces**

`dive_search_page.dart`, the Query section's child becomes:

```dart
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SavedQueryChipRow(
                    subject: QuerySubject.dives,
                    onApply: (load) => setState(() => _query = load.node),
                  ),
                  const SizedBox(height: 8),
                  DiveQueryEditor(
                    value: _query,
                    onChanged: (node) => setState(() => _query = node),
                    onSave: _saveQuery,
                  ),
                ],
              ),
```

with the method:

```dart
  Future<void> _saveQuery() async {
    final node = _query;
    if (node == null) return;
    final name = await showSaveQueryDialog(context);
    if (name == null || !mounted) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    try {
      await ref
          .read(savedQueryRepositoryProvider)
          .create(
            subject: QuerySubject.dives,
            name: name,
            node: node,
            diverId: diverId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.query_saved_snackbar(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.common_label_error}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
```

Imports: `query_subject.dart`, `saved_query_chip_row.dart`, `save_query_dialog.dart`, `saved_query_providers.dart`, `diver_providers.dart`.

`dive_filter_sheet.dart`, as the first child of the `ListView` (before the "Advanced search" link):

```dart
                      // Saved queries apply at once: the sheet's own axes
                      // are untouched, the advanced part is replaced.
                      SavedQueryChipRow(
                        subject: QuerySubject.dives,
                        onApply: (load) {
                          final current = widget.ref.read(widget.filterProvider);
                          widget.ref.read(widget.filterProvider.notifier).state =
                              current.copyWith(query: load.node);
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(height: 8),
```

Add to Task 10's `dive_search_page_query_test.dart`:

```dart
  testWidgets('a saved chip applies its tree into the editor', (tester) async {
    final depth = ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null));
    final container = await pumpPage(
      tester,
      const DiveFilterState(),
      section: 'query',
      extraOverrides: [
        savedQueryLoadsProvider('dives').overrideWith(
          (ref) async => [
            SavedQueryLoad(
              SavedQuery(id: 'a', subject: 'dives', name: 'Deep', queryJson: '{}', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
              node: depth,
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Deep'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'depth > 30',
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).query, depth);
  });
```

(extend `pumpPage` with an `extraOverrides` parameter appended to the list). And to `dive_filter_sheet_query_test.dart`:

```dart
  testWidgets('a saved chip applies at once and keeps the sheet axes', (tester) async {
    // Override savedQueryLoadsProvider('dives') the same way, seed a filter with tripId 'trip-1',
    // tap the chip, then:
    final applied = container.read(seeded);
    expect(applied.query, depth);
    expect(applied.tripId, 'trip-1');
    expect(find.byType(DiveFilterSheet), findsNothing);
  });
```

Write that test in full following the file's `pumpSheet` helper, adding an `extraOverrides` parameter to it.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter gen-l10n && python3 scripts/gen_query_label_lookup.py && TMPDIR=/tmp flutter test test/features/query/ test/features/dive_log/presentation/pages/dive_search_page_query_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/presentation/widgets/ lib/features/query/presentation/query_label_lookup.dart lib/features/dive_log/presentation/pages/dive_search_page.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/l10n/arb/ test/features/query/presentation/widgets/ test/features/dive_log/presentation/pages/dive_search_page_query_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart
git commit -m "feat(query): save a query from the editor, apply one from the Saved chip row"
```

---

### Task 16: Settings > Manage > Saved queries

**Files:**
- Create: `lib/features/query/presentation/pages/saved_queries_page.dart`
- Modify: `lib/core/router/app_router.dart` (after the `/dive-roles` route near line 1423), `lib/features/settings/presentation/pages/settings_page.dart` (after the Tags entry near line 2556), `lib/l10n/arb/app_en.arb`
- Test: `test/features/query/presentation/pages/saved_queries_page_test.dart`

**Interfaces:**
- Consumes: `savedQueryLoadsProvider(null)`, `savedQueryRepositoryProvider`, `showSaveQueryDialog` (as the rename prompt), `kFabListPadding`, `ReorderableListView` with `onReorderItem` and `ReorderableDragStartListener` (the `components_card.dart` pattern).
- Produces: `SavedQueriesPage` at route `/saved-queries` (name `savedQueries`), a Manage menu entry.

The page lists every subject's saved queries (grouped by subject when more than one subject has rows), each tile with a drag handle, the printed query as subtitle (or the problem, in the error colour), inline rename and delete icons. Reorder persists at once through `reorder`, per subject. No FAB: a query is created from the editor, not here (recorded as a deviation in Task 18).

- [ ] **Step 1: Write the failing test**

`test/features/query/presentation/pages/saved_queries_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/presentation/pages/saved_queries_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  late SavedQueryRepository repo;
  final depth = ConditionNode(FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null));

  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = SavedQueryRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: overrides,
        child: const SavedQueriesPage(),
      ),
    );
    final element = tester.element(find.byType(SavedQueriesPage));
    await ProviderScope.containerOf(element)
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('me');
    await tester.pumpAndSettle();
  }

  testWidgets('lists queries with their printed text and renames one', (tester) async {
    await repo.create(subject: QuerySubject.dives, name: 'Deep', node: depth, diverId: 'me');
    await pump(tester);
    expect(find.text('Deep'), findsOneWidget);
    expect(find.text('depth > 30'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Deeper');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Deeper'), findsOneWidget);
  });

  testWidgets('an unreadable row is flagged and can be deleted', (tester) async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO saved_queries (id, diver_id, subject, name, query_json, sort_order, created_at, updated_at) "
      "VALUES ('bad', 'me', 'dives', 'Future', '{\"version\":99,\"node\":{}}', 0, $now, $now)",
    );
    await pump(tester);
    expect(find.text('Future'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Future'), findsNothing);
    expect(await repo.getById('bad'), isNull);
  });

  testWidgets('dragging a row persists the new order', (tester) async {
    final a = await repo.create(subject: QuerySubject.dives, name: 'A', node: depth, diverId: 'me');
    final b = await repo.create(subject: QuerySubject.dives, name: 'B', node: depth, diverId: 'me');
    await pump(tester);
    final handle = find.descendant(
      of: find.widgetWithText(ListTile, 'A'),
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.drag(handle, const Offset(0, 120));
    await tester.pumpAndSettle();
    final order = (await repo.getAll(subject: 'dives', diverId: 'me')).map((q) => q.id);
    expect(order, [b.id, a.id]);
  });
}
```

`ReorderableListView` needs a long press to start a drag on touch; with `ReorderableDragStartListener` a plain drag works. If the drag test is flaky, use `tester.timedDrag(handle, const Offset(0, 120), const Duration(milliseconds: 500))`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/query/presentation/pages/saved_queries_page_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Strings, route and menu entry**

`app_en.arb`:

```json
  "savedQueries_appBar_title": "Saved Queries",
  "@savedQueries_appBar_title": {"description": "Settings > Manage > Saved queries page title"},
  "savedQueries_empty": "No saved queries yet. Save one from the dive search page.",
  "@savedQueries_empty": {"description": "Empty state of the saved queries page"},
  "savedQueries_renameTooltip": "Rename",
  "@savedQueries_renameTooltip": {"description": "Tooltip"},
  "savedQueries_deleteTooltip": "Delete",
  "@savedQueries_deleteTooltip": {"description": "Tooltip"},
  "savedQueries_deleteDialog_title": "Delete query?",
  "@savedQueries_deleteDialog_title": {"description": "Confirm dialog title"},
  "savedQueries_deleteDialog_content": "Delete \"{name}\"? This cannot be undone.",
  "@savedQueries_deleteDialog_content": {"description": "Confirm dialog body", "placeholders": {"name": {"type": "String"}}},
  "savedQueries_problem_unreadable": "Cannot be read on this version of the app",
  "@savedQueries_problem_unreadable": {"description": "Subtitle of a saved query whose JSON is newer or corrupt"},
  "savedQueries_problem_invalid": "Uses a field this version does not have: {detail}",
  "@savedQueries_problem_invalid": {"description": "Subtitle of a saved query the registry rejects", "placeholders": {"detail": {"type": "String"}}},
  "savedQueries_problem_unknownSubject": "For a list this version does not have: {detail}",
  "@savedQueries_problem_unknownSubject": {"description": "Subtitle of a saved query whose subject is unknown", "placeholders": {"detail": {"type": "String"}}},
  "savedQueries_problem_unresolved": "Refers to something that no longer exists: {detail}",
  "@savedQueries_problem_unresolved": {"description": "Subtitle of a saved query with a deleted reference", "placeholders": {"detail": {"type": "String"}}},
  "savedQueries_snackbar_deleted": "Deleted \"{name}\"",
  "@savedQueries_snackbar_deleted": {"description": "Snackbar after deleting a saved query", "placeholders": {"name": {"type": "String"}}},
  "settings_manage_savedQueries": "Saved Queries",
  "@settings_manage_savedQueries": {"description": "Settings > Manage entry"},
  "settings_manage_savedQueries_subtitle": "Rename, reorder and delete saved queries",
  "@settings_manage_savedQueries_subtitle": {"description": "Settings > Manage entry subtitle"},
```

`app_router.dart`, after the `/dive-roles` route:

```dart
          // Saved queries management (#2365)
          GoRoute(
            path: '/saved-queries',
            name: 'savedQueries',
            builder: (context, state) => const SavedQueriesPage(),
          ),
```

with the import `package:submersion/features/query/presentation/pages/saved_queries_page.dart`.

`settings_page.dart`, after the Tags `ListTile`:

```dart
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(context.l10n.settings_manage_savedQueries),
                    subtitle: Text(
                      context.l10n.settings_manage_savedQueries_subtitle,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/saved-queries'),
                  ),
```

- [ ] **Step 4: Write the page**

`lib/features/query/presentation/pages/saved_queries_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

/// Settings > Manage > Saved queries (spec Unit 7): rename, reorder and
/// delete. Rows this build cannot read are flagged, never hidden, so they
/// can be deleted. Queries are created from the editor, so there is no add
/// button here.
class SavedQueriesPage extends ConsumerWidget {
  const SavedQueriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsAsync = ref.watch(savedQueryLoadsProvider(null));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.savedQueries_appBar_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: context.l10n.common_action_back,
        ),
      ),
      body: loadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${context.l10n.common_label_error}: $e')),
        data: (loads) => loads.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.l10n.savedQueries_empty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _SavedQueryList(loads: loads),
      ),
    );
  }
}

class _SavedQueryList extends ConsumerStatefulWidget {
  const _SavedQueryList({required this.loads});

  final List<SavedQueryLoad> loads;

  @override
  ConsumerState<_SavedQueryList> createState() => _SavedQueryListState();
}

class _SavedQueryListState extends ConsumerState<_SavedQueryList> {
  /// A local copy so a dropped row does not snap back while the write and
  /// the tick catch up (the components card pattern).
  late List<SavedQueryLoad> _loads = List.of(widget.loads);

  @override
  void didUpdateWidget(_SavedQueryList old) {
    super.didUpdateWidget(old);
    if (old.loads != widget.loads) _loads = List.of(widget.loads);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(queryUnitPrefsProvider);
    return ReorderableListView.builder(
      padding: kFabListPadding,
      buildDefaultDragHandles: false,
      itemCount: _loads.length,
      onReorderItem: (oldIndex, newIndex) {
        // Reordering across subjects is meaningless; the list is per
        // subject in practice (only dives saves today) and the repository
        // rewrites sort_order for the ids it is given.
        setState(() {
          final moved = _loads.removeAt(oldIndex);
          _loads.insert(newIndex, moved);
        });
        ref
            .read(savedQueryRepositoryProvider)
            .reorder([for (final l in _loads) l.saved.id]);
      },
      itemBuilder: (context, i) {
        final load = _loads[i];
        return _tile(context, load, i, prefs);
      },
    );
  }

  Widget _tile(BuildContext context, SavedQueryLoad load, int index, prefs) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subject = load.saved.querySubject;
    final subtitle = switch (load.problem) {
      null => Text(
        QueryPrinter(
          appQueryRegistry,
          appQueryRegistry.entityFor(subject!),
          prefs,
        ).print(load.node),
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      SavedQueryProblem.unresolvedRef => Text(
        l10n.savedQueries_problem_unresolved(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.tertiary),
      ),
      SavedQueryProblem.unreadable => Text(
        l10n.savedQueries_problem_unreadable,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      SavedQueryProblem.invalid => Text(
        l10n.savedQueries_problem_invalid(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.error),
      ),
      SavedQueryProblem.unknownSubject => Text(
        l10n.savedQueries_problem_unknownSubject(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.error),
      ),
    };
    final flagged =
        load.problem != null && load.problem != SavedQueryProblem.unresolvedRef;
    return ListTile(
      key: ValueKey(load.saved.id),
      leading: Icon(
        flagged ? Icons.error_outline : Icons.bookmark_outline,
        color: flagged ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
      title: Text(load.saved.name),
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.savedQueries_renameTooltip,
            onPressed: () => _rename(context, load),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.savedQueries_deleteTooltip,
            onPressed: () => _confirmDelete(context, load),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, SavedQueryLoad load) async {
    final name = await showSaveQueryDialog(
      context,
      initialName: load.saved.name,
    );
    if (name == null || name == load.saved.name) return;
    await ref.read(savedQueryRepositoryProvider).rename(load.saved.id, name);
  }

  Future<void> _confirmDelete(BuildContext context, SavedQueryLoad load) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.savedQueries_deleteDialog_title),
        content: Text(l10n.savedQueries_deleteDialog_content(load.saved.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(savedQueryRepositoryProvider).delete(load.saved.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.savedQueries_snackbar_deleted(load.saved.name)),
        ),
      );
    }
  }
}
```

Type the `prefs` parameter as `UnitPrefs` (import `lib/core/query/units/unit_prefs.dart`). If `common_action_delete` is not the English `Delete`, pin the test's button finder to the ARB value.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter gen-l10n && python3 scripts/gen_query_label_lookup.py && TMPDIR=/tmp flutter test test/features/query/presentation/pages/saved_queries_page_test.dart test/features/settings/ test/core/router/`
Expected: PASS (if `test/core/router/` does not exist, drop it from the command).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/query/presentation/pages/saved_queries_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart lib/l10n/arb/ lib/features/query/presentation/query_label_lookup.dart test/features/query/presentation/pages/saved_queries_page_test.dart
git commit -m "feat(query): Settings > Manage > Saved queries: rename, reorder, delete, flagged rows"
```

---

### Task 17: Localised parser, validator and path errors

**Files:**
- Create: `lib/core/query/domain/query_error_code.dart`, `lib/features/query/presentation/query_error_text.dart`
- Modify: `lib/core/query/domain/query_errors.dart`, `lib/core/query/syntax/query_tokenizer.dart`, `lib/core/query/syntax/query_parser.dart`, `lib/core/query/compiler/query_validator.dart`, `lib/core/query/registry/query_registry.dart`, `lib/core/query/presentation/query_editor.dart`, `lib/features/query/presentation/dive_query_editor.dart`, `lib/features/query/domain/saved_query_load.dart`, `lib/features/query/presentation/pages/saved_queries_page.dart`, `lib/l10n/arb/app_en.arb` (the other locales in Task 18)
- Test: `test/core/query/domain/query_error_code_test.dart`, `test/features/query/presentation/query_error_text_test.dart`, one case added to `test/features/query/presentation/dive_query_editor_test.dart`, plus the PR 1 suites unchanged

**Interfaces:**
- Consumes: every `QueryError(...)`, `_err(...)` and `TokenizeException(...)` site (tokenizer 2, parser 39, validator 25, registry 4), `AppLocalizations`.
- Produces:

```dart
enum QueryErrorCode { ...; const QueryErrorCode(this.argNames); final List<String> argNames; }   // the table below
String englishQueryMessage(QueryErrorCode code, Map<String, String> args);  // today's exact English text
class QueryError {
  const QueryError(this.code, {this.args = const {}, this.offset, this.length, this.path, this.suggestions = const []});
  final QueryErrorCode code; final Map<String, String> args;
  String get message => englishQueryMessage(code, args);   // unchanged text: PR 1's 40 message assertions stay green
  // == and hashCode over code, args, offset, length, path (message is derived; suggestions still excluded)
}
class TokenizeException { const TokenizeException(this.code, this.offset, {this.args = const {}}); String get message; }
String describeQueryError(AppLocalizations l10n, QueryError error);   // exhaustive switch, one ARB key per code
class QueryEditor { ... final String Function(QueryError error)? describeError; }   // passed to QueryTextField
class SavedQueryLoad { ... final QueryError? error; }   // set for SavedQueryProblem.invalid
```

The rule that keeps this safe: every call site passes the SAME words it formats today, and `englishQueryMessage` returns today's text byte for byte. Two sites share a code only where their texts are already identical. Args are the tokens and keys the diver typed (`depth`, `ft`, `Salt Pier`); they render verbatim in every locale because they are query syntax. The `dimension` arg (`depth`, `temperature`) is the registry's dimension name and also renders verbatim; Task 18 records that as a deviation.

The codes, their args and their English text (`{x}` is an arg):

| code | args | English |
| --- | --- | --- |
| unterminatedQuote | | `unterminated quote` |
| unexpectedCharacter | text | `unexpected character "{text}"` |
| unexpectedToken | text | `unexpected "{text}"` |
| expectedCloseParen | | `expected ")"` |
| expectedCloseBracket | | `expected "]"` |
| expectedOpenBracketAfterIn | | `expected "[" after "in"` |
| expectedAnd | | `expected "and"` |
| expectedOperator | | `expected an operator` |
| expectedConditionOrText | | `expected a condition or text` |
| expectedName | | `expected a name` |
| expectedDate | | `expected a date` |
| expectedDateValue | | `expected a date value` |
| expectedValue | | `expected a value` |
| expectedNumber | | `expected a number` |
| expectedText | | `expected text` |
| expectedBool | | `expected true or false` |
| emptyText | | `empty text` |
| emptyList | | `the list is empty` |
| emptyGroup | | `an empty group matches nothing` |
| emptyPath | | `empty path` |
| notSingleDay | text | `"{text}" is not a single day` |
| notADate | text | `"{text}" is not a date` |
| openEndedDate | text, field, symbol, day | `"{text}" is open-ended; write {field} {symbol} {day} instead` |
| unknownUnit | unit | `unknown unit "{unit}"` |
| noUnitAllowed | field | `{field} takes no unit` |
| wrongUnitDimension | unit, dimension | `"{unit}" is not a {dimension} unit` |
| wrongUnitForField | unit, dimension, field | `"{unit}" is not a {dimension} unit; {field} is measured in {dimension}` |
| decimalComma | | `use "." for decimals, not ","` |
| scopeNeedsRelationQuoted | path | `"[...]" needs a relation, "{path}" is a field` |
| scopeNeedsRelation | path | `[...] needs a relation, "{path}" is a field` |
| relationNeedsRefOp | path | `"{path}" is a relation; use =, in, :none, :any or [...]` |
| relationOpNotAllowed | op | `"{op}" cannot be used with a relation; use =, !=, in, :none, :any or [...]` |
| opNotForFieldQuoted | op, field | `"{op}" cannot be used with {field}` |
| opNotForField | op, field | `{op} cannot be used with {field}` |
| noneAmbiguous | field | `"{field}:none" is ambiguous: write "{field} = none" for the value none, or "NOT {field}:any" for unrecorded` |
| noRefNamed | relation, text | `no {relation} named "{text}"` |
| notEnumValue | text, field | `"{text}" is not a {field} value` |
| unknownField | name | `unknown field "{name}"` |
| fieldNotPath | name, next | `"{name}" is a field and cannot be followed by ".{next}"` |
| tooManyHops | max | `a query may cross at most {max} relations, counting nested groups` |
| pathTooLong | max | `a path may cross at most {max} relations` |
| textNotSearchable | table | `free text cannot be searched inside {table}` |
| expectsReference | name | `{name} expects a reference` |
| expectsReferences | name | `{name} expects references` |
| betweenNeedsTwo | | `between needs two values` |
| inNeedsList | | `in needs a list` |
| expectsNumber | field | `{field} expects a number` |
| outOfRange | field | `{field} value is out of range` |
| expectsText | field | `{field} expects text` |
| expectsBool | field | `{field} expects true or false` |
| expectsEnumValue | field | `{field} expects one of its values` |
| expectsSingleDay | field | `{field} expects a single day here` |
| expectsDate | field | `{field} expects a date` |

Before writing the enum, reconcile the table with the sources: for every `_err(`, `QueryError(` and `TokenizeException(` site (parser lines 103 to 602, validator 37 to 241, registry 68 to 112, tokenizer 84 and 117), confirm the site's text matches one row exactly. A site whose text differs from every row gets its own row with its exact text; never reword a message in this task.

- [ ] **Step 1: Write the failing tests**

`test/core/query/domain/query_error_code_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  Map<String, String> sample(QueryErrorCode c) => {
    for (final a in c.argNames) a: '<$a>',
  };

  test('every code has English text that uses every arg and no other', () {
    for (final c in QueryErrorCode.values) {
      final text = englishQueryMessage(c, sample(c));
      expect(text, isNotEmpty, reason: c.name);
      for (final a in c.argNames) {
        expect(text, contains('<$a>'), reason: '${c.name} drops {$a}');
      }
      expect(text, isNot(contains('{')), reason: '${c.name} left a brace');
    }
  });

  test('message is the English text of the code and args', () {
    const e = QueryError(
      QueryErrorCode.noUnitAllowed,
      args: {'field': 'rating'},
    );
    expect(e.message, 'rating takes no unit');
  });

  test('equality follows code, args and position, not suggestions', () {
    const a = QueryError(
      QueryErrorCode.unknownField,
      args: {'name': 'dpeth'},
      offset: 0,
      length: 5,
      suggestions: ['depth'],
    );
    const b = QueryError(
      QueryErrorCode.unknownField,
      args: {'name': 'dpeth'},
      offset: 0,
      length: 5,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        QueryError(
          QueryErrorCode.unknownField,
          args: const {'name': 'dpeth'},
          path: FieldPath(['dpeth']),
        ),
      ),
    );
  });
}
```

`test/features/query/presentation/query_error_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

void main() {
  Map<String, String> sample(QueryErrorCode c) => {
    for (final a in c.argNames) a: '<$a>',
  };

  test('the English ARB renders exactly the engine English for every code', () {
    final en = l10nForLocaleTag('en');
    for (final c in QueryErrorCode.values) {
      final e = QueryError(c, args: sample(c));
      expect(describeQueryError(en, e), e.message, reason: c.name);
    }
  });

  test('every locale renders every code with every arg', () {
    for (final tag in ['ar', 'de', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']) {
      final l10n = l10nForLocaleTag(tag);
      for (final c in QueryErrorCode.values) {
        final text = describeQueryError(l10n, QueryError(c, args: sample(c)));
        for (final a in c.argNames) {
          expect(text, contains('<$a>'), reason: '$tag ${c.name} drops {$a}');
        }
      }
    }
  });
}
```

The second test needs the translations of Task 18; this task's gate runs only the first (`--plain-name 'the English ARB'`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=/tmp flutter test test/core/query/domain/query_error_code_test.dart test/features/query/presentation/query_error_text_test.dart`
Expected: FAIL to compile (`query_error_code.dart` and `query_error_text.dart` missing; `QueryError` takes a message).

- [ ] **Step 3: The code enum and the English text**

`lib/core/query/domain/query_error_code.dart` holds the enum (one value per table row, `argNames` in table order) and:

```dart
/// Today's exact English text for [code], with [args] substituted. The
/// ARB's English strings must render the same (a guard test checks every
/// code), so the engine, its tests and the English UI read alike.
String englishQueryMessage(QueryErrorCode code, Map<String, String> args) {
  String a(String name) => args[name] ?? '';
  switch (code) {
    case QueryErrorCode.unterminatedQuote:
      return 'unterminated quote';
    case QueryErrorCode.unexpectedCharacter:
      return 'unexpected character "${a('text')}"';
    case QueryErrorCode.noRefNamed:
      return 'no ${a('relation')} named "${a('text')}"';
    // One case per remaining row, the text copied exactly from the table.
  }
}
```

The switch is exhaustive, so the analyzer names any row left out.

- [ ] **Step 4: Move every site onto codes**

`query_errors.dart`: `QueryError` becomes

```dart
@immutable
class QueryError {
  const QueryError(
    this.code, {
    this.args = const {},
    this.offset,
    this.length,
    this.path,
    this.suggestions = const [],
  });

  final QueryErrorCode code;

  /// The words the message quotes: typed tokens and field keys, shown
  /// verbatim in every language because they are query syntax.
  final Map<String, String> args;
  final int? offset;
  final int? length;
  final FieldPath? path;
  final List<String> suggestions;

  /// The English text, for logs and tests; the UI shows
  /// `describeQueryError` in the diver's language.
  String get message => englishQueryMessage(code, args);

  @override
  bool operator ==(Object other) =>
      other is QueryError &&
      other.code == code &&
      _mapEquals(other.args, args) &&
      other.offset == offset &&
      other.length == length &&
      other.path == path;

  @override
  int get hashCode => Object.hash(
    code,
    Object.hashAllUnordered(
      args.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    offset,
    length,
    path,
  );
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
```

`lib/core/query` stays pure Dart with `meta`, hence the private `_mapEquals` rather than Flutter's `mapEquals`. Keep `toString` returning the English message plus the position, as today.

`query_tokenizer.dart`: `TokenizeException(this.code, this.offset, {this.args = const {}})` with `String get message => englishQueryMessage(code, args)`; line 84 becomes `TokenizeException(QueryErrorCode.unterminatedQuote, i)` and line 117 `TokenizeException(QueryErrorCode.unexpectedCharacter, i, args: {'text': c})`.

`query_parser.dart`: `_err(String message, Token at, {suggestions})` becomes `_err(QueryErrorCode code, Token at, {Map<String, String> args = const {}, List<String> suggestions = const []})`. Rewrite each site; for example:

```dart
throw _Abort(
  _err(QueryErrorCode.unexpectedToken, _peek, args: {'text': _peek.text}),
);
throw _Abort(
  _err(QueryErrorCode.noUnitAllowed, tok, args: {'field': field.key}),
);
throw _Abort(
  _err(
    QueryErrorCode.noRefNamed,
    tok,
    args: {'relation': rel.key, 'text': tok.text},
    suggestions: context.names.candidates(rel.target, tok.text),
  ),
);
```

Line 103 becomes `QueryError(e.code, args: e.args, offset: e.offset, length: 1)`; line 226 copies `res.error!.code` and `res.error!.args` into the positioned error. `openEndedDate`'s `symbol` arg is `op == QueryOp.lt || op == QueryOp.lte ? '<' : '>='` and its `day` arg is the formatted day the site builds today.

`query_validator.dart` and `query_registry.dart`: the same shape, `QueryError(QueryErrorCode.x, args: {...}, path: path)`. The validator's operator message passes `op.name` (its text today reads `contains cannot be used with favorite`); the parser's passes `opTok.text` through the quoted variant. The registry's unknown-field error keeps its `suggestions`.

- [ ] **Step 5: The ARB keys and the localised text**

Add one key per code to `app_en.arb` after the `query_editor_*` block, named `query_error_<code>`, English value exactly the table's text with each `{arg}` a `String` placeholder declared in `argNames` order:

```json
  "query_error_noRefNamed": "no {relation} named \"{text}\"",
  "@query_error_noRefNamed": {"description": "Query error; relation and text are what the diver typed and stay verbatim", "placeholders": {"relation": {"type": "String"}, "text": {"type": "String"}}},
  "query_error_expectedAnd": "expected \"and\"",
  "@query_error_expectedAnd": {"description": "Query error: the keyword and stays in English, it is query syntax"},
```

Every key's description names the quoted words that are syntax and must stay untranslated (`and`, `in`, `none`, `any`, `NOT`, `true`, `false`, `[...]`, the operators). Then `flutter gen-l10n`.

`lib/features/query/presentation/query_error_text.dart`:

```dart
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [error] in the diver's language. Exhaustive over [QueryErrorCode], so a
/// new code cannot ship without its string.
String describeQueryError(AppLocalizations l10n, QueryError error) {
  String a(String name) => error.args[name] ?? '';
  switch (error.code) {
    case QueryErrorCode.unterminatedQuote:
      return l10n.query_error_unterminatedQuote;
    case QueryErrorCode.unexpectedCharacter:
      return l10n.query_error_unexpectedCharacter(a('text'));
    case QueryErrorCode.noRefNamed:
      return l10n.query_error_noRefNamed(a('relation'), a('text'));
    // One case per remaining code, positional args in argNames order.
  }
}
```

- [ ] **Step 6: Wire it into the surfaces**

- `QueryEditor` gains `this.describeError` (a `String Function(QueryError error)?`) and passes it to `QueryTextField`.
- `DiveQueryEditor` passes `describeError: (e) => describeQueryError(context.l10n, e)`.
- `SavedQueryLoad` gains `final QueryError? error;`; `loadSavedQuery` sets `error: errors.first` (keeping `detail: errors.first.message`) for `SavedQueryProblem.invalid`.
- `SavedQueriesPage`: the invalid subtitle becomes `l10n.savedQueries_problem_invalid(load.error == null ? load.detail ?? '' : describeQueryError(l10n, load.error!))`.

Add to `test/features/query/presentation/dive_query_editor_test.dart`:

```dart
  testWidgets('a parse error shows in the diver language', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('de'),
        overrides: [
          queryNameIndexProvider.overrideWith(
            (ref) async => QueryNameIndex.empty,
          ),
        ],
        child: SingleChildScrollView(
          child: DiveQueryEditor(value: null, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'rating > 3m');
    await tester.pump();
    final l10n = l10nForLocaleTag('de');
    expect(
      find.text(l10n.query_error_noUnitAllowed('rating')),
      findsOneWidget,
    );
  });
```

It passes in this task against the English text the German file falls back to, and proves the German string once Task 18 lands. Import `package:submersion/l10n/l10n_extension.dart` for `l10nForLocaleTag`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter gen-l10n && python3 scripts/gen_query_label_lookup.py && TMPDIR=/tmp flutter test test/core/query/ test/features/query/ test/features/dive_log/query/`
Expected: PASS, including every PR 1 parser, validator and registry test unchanged (they assert on `.message`, whose text did not move), except the "every locale" case of `query_error_text_test.dart`, which Task 18 turns green.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/query/ lib/features/query/ lib/l10n/arb/ test/core/query/domain/query_error_code_test.dart test/features/query/presentation/query_error_text_test.dart test/features/query/presentation/dive_query_editor_test.dart
git commit -m "feat(query): error codes with args, and every parser, validator and path error in the diver's language"
```

---

### Task 18: Every locale, the spec's deviations, the guards, the screenshots and the PR

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` and the generated `lib/l10n/arb/app_localizations*.dart`; `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`
- Test: the existing `test/l10n/` suite, `test/architecture/`, then the full suite

- [ ] **Step 1: Run the l10n guards to list what is missing**

Run: `TMPDIR=/tmp flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL, naming every key present in `app_en.arb` and absent from each other locale: the `query_error_*` (one per `QueryErrorCode`, Task 17), the `query_editor_*` (23), `query_saveDialog_*` and `query_saved*` (7), `savedQueries_*` (12), `settings_manage_savedQueries*` (2), `diveLog_filter_queryRow` and `diveLog_search_section_query` (2) keys. The `query_op_*` keys were done in Task 2.

- [ ] **Step 2: Translate into the ten locales**

Add each missing key, with its translated value and no `@` block, next to the locale's existing `query_*`, `savedQueries_*` (new group, place after the `query_*` block), `settings_manage_tags*` and `diveLog_filter_*` neighbours. Rules:
- `query_editor_hint` keeps its example in query syntax (`e.g. weights:none AND depth > 30` becomes, in French, `p. ex. weights:none AND depth > 30`): the field names and keywords are the language, not prose.
- Placeholders keep their `{name}` and `{detail}` argument names.
- The `query_error_*` values keep every quoted syntax word untranslated (`and`, `in`, `none`, `any`, `NOT`, `true`, `false`, `[...]`, `=`, `!=`, `.`, `,`) and every `{arg}`; `query_error_text_test.dart`'s every-locale case checks the args.
- German: "Gespeicherte Abfragen" for saved queries; never "SAC".
- French and Portuguese have no new plurals here, so the `=1{...}` rule is not exercised; if you add one, interpolate `{count}`.
- Arabic and Hebrew: keep the placeholder inside the sentence where the language puts it; the app already lays these files out RTL.

Then:

```bash
flutter gen-l10n
python3 scripts/gen_query_label_lookup.py
TMPDIR=/tmp flutter test test/l10n/ test/features/query/presentation/query_labels_test.dart test/features/query/presentation/query_error_text_test.dart test/features/query/presentation/dive_query_editor_test.dart
```

Expected: PASS (parity, no duplicate keys, diacritics, German terminology, and the label lookup guard).

- [ ] **Step 3: Record the deviations in the spec**

Append to `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`, after the PR 1 deviations section and before "Open items for the implementation plans", a section `## Deviations recorded during implementation (PR 2)` with these entries (reword any that turned out differently while implementing):

```markdown
## Deviations recorded during implementation (PR 2)

- **Both dive surfaces apply through `copyWith`.** The quick sheet and the
  search page used to build a fresh `DiveFilterState` on Apply, which
  discarded the advanced query and every axis the surface did not edit
  (trip, centre, gear ids, buddy id, the Insights dive-id seam, custom
  fields, deco on the sheet; excluded-from-stats, buddy id, dive ids,
  computer and attribute conditions on the page). Each now sets the axes it
  edits, clears them with their flags when empty, and leaves the rest.
- **The core widgets read no `AppLocalizations`.** `lib/core/query/
  presentation/` takes a `QueryLabels` implementation and string holders
  (`QueryBuilderStrings`, `QueryEditorStrings`) from the caller; the
  feature layer fills them from the ARB. Placeholder strings pass `{name}`
  through and the widgets substitute the label.
- **Errors carry a code and args.** `QueryError` holds a `QueryErrorCode`
  and the words it quotes; `message` is the English text (unchanged, so the
  engine's tests and logs read as before) and the UI shows
  `describeQueryError`, one ARB key per code in every locale. The quoted
  words are query syntax and stay verbatim, as does the `dimension` arg
  (`depth`, `temperature`) of the two wrong-unit messages.
- **Ref labels in the name index are the stored names.** Built-in dive
  types therefore show their stored name, not the localized one, in the ref
  picker and in a printed query; the printer emits the label the tree
  holds. A localized name index is a follow-up.
- **The builder does not edit scoped groups.** A `ScopedNode` renders
  read-only with its printed text; the text tab edits it. The builder also
  offers no in-list on numbers or text (between and contains cover them) and
  no `!=` on booleans.
- **Saved queries have no add button on the Manage page.** A query is saved
  from the editor; the page renames, reorders and deletes. Rows this build
  cannot read (a newer JSON version, a corrupt payload, a field or subject
  this build lacks) are listed flagged and deletable; a row whose ref was
  deleted applies with the row flagged.
- **`saved_queries.diver_id` is nullable and references `divers`** like
  `cylinder_fills`, so the diver-delete rules and the dangling-key repair
  apply unchanged; reads return the diver's rows plus unowned rows.
- **Insights shows no query chips.** Its bar is a count plus Clear; the
  quick sheet it shares with the dive list carries the Saved row.
- **The `QueryNameIndex` is a snapshot** reloaded on any ref-table tick, so
  parsing stays synchronous; until the first load the editor parses against
  an empty index.
- **Schema rung 232**, chosen with 231 held by four open PRs on 2026-09-26.
```

Also update the "Program shape" table's PR 2 row if the scope wording no longer matches, and tick nothing else in the body.

- [ ] **Step 4: The guards and the whole suite**

```bash
dart format .
flutter analyze --fatal-infos
TMPDIR=/tmp flutter test test/architecture/ test/l10n/
```

Expected: PASS. Then one full run (do not overlap it with anything else; it takes a while and is IO-bound; check `df -h /Volumes/fltmp` first if that RAM disk is the TMPDIR):

```bash
TMPDIR=/tmp flutter test --exclude-tags performance
```

Expected: PASS, with a count above the 32,176 PR 1 ended on. Read the summary line from the command's own output, never through a pipe.

- [ ] **Step 5: Screenshots**

The PR touches `presentation/`, so its description needs images. Capture them with the throwaway-golden technique (a test using `matchesGoldenFile` run with `--update-goldens`, then delete the test; load a font in `setUpAll` so text renders), at phone width (390 x 844) and desktop width (1200 x 800), light and dark:

1. The search page's Query section, text tab, with `weights:none AND depth > 30` typed and one completion chip showing.
2. The same query in the Builder tab (two rows in an "All of" card).
3. The dive list with the two query chips in the active-filter bar.
4. The quick sheet's top: the Saved row with two chips (one flagged) and the Query row.
5. Settings > Manage > Saved queries with a readable, a flagged and an unreadable row.

Save them under the scratchpad directory (not the repository), and hand the files to the maintainer with `SendUserFile`. Leave the PR's Screenshots section listing what each image shows; the maintainer drags them in on github.com. Do not tick "No visible UI change".

- [ ] **Step 6: Commit, push, open the PR**

```bash
git add lib/l10n/arb/ lib/features/query/presentation/query_label_lookup.dart docs/superpowers/specs/2026-09-25-entity-query-language-design.md
git commit -m "feat(query): editor and saved-query strings in every locale; record the PR 2 deviations"
```

Re-run the rung scan from Task 12 Step 1. If 232 is now taken, renumber (database.dart, the migration test, the spec note) in one more commit. Then:

```bash
git push -u origin ericgriffin/query-editor-saved-queries
```

If the pre-push hook's affected-test run is silent for more than 15 minutes it has hung on the ARB fan-out: kill that `flutter test` process tree only, run the flagged files by hand, then `SKIP_TESTS=1 git push -u origin ericgriffin/query-editor-saved-queries`.

Open the PR against `main` with the repository template (`.github/PULL_REQUEST_TEMPLATE.md`: Related Issue, Summary, Changes, Test Plan, Screenshots). Body outline:

```markdown
## Related Issue

Refs #2365 (PR 2 of 5: the editor surfaces, chips and saved queries; the issue stays open for PRs 3 to 5).

## Summary

Adds the two editors of the query tree (a typed field with live errors, suggestions and completions, and a rule builder with nested groups), chips for the advanced part of the dive filter, and synced per-diver saved queries with a Settings > Manage page. The engine PR 1 shipped is unchanged; `DiveFilterState.query` is the slot both editors write.

## Changes

- `lib/core/query/presentation/`: pure tree edits, completions, the text field with a positioned error underline, the field and ref pickers, the value editor, condition rows, group cards, `QueryEditor`.
- `lib/features/query/`: unit prefs from settings, the ARB label lookup (generated), the database-backed name index, `DiveQueryEditor`, the `saved_queries` table (v232), entity, repository, sync arms, providers, the Saved chip row, the save dialog, the Manage page.
- Dive search page: a Query section; quick sheet: a Query row and the Saved row; both apply through `copyWith` (they used to rebuild the state and drop the axes they did not edit).
- Dive list: one chip per top-level condition of the advanced query.
- Parser, validator and path errors carry a code and args; every error message is an ARB key in all 11 locales.
- Strings in all 11 locales; spec deviations recorded.

## Test Plan

- [x] `flutter test` passes (N tests)
- [x] `flutter analyze --fatal-infos` passes
- [ ] Manual testing on: macOS

## Screenshots

(list the five images and what each shows)
```

Use the real test count. Then `gh pr edit <n> --add-reviewer "@copilot"`, bind the PR with the app's PR tools, and hand back for review. Copilot's review rounds arrive through the app; reply without attribution lines.

---

## Self-review notes

- Spec coverage: Unit 6 Text tab (Task 6), autocomplete (Task 5, 6), Builder with field tree, negation, nesting, typed value editors (Tasks 7, 8, 9), placement on the search page and the quick sheet (Task 10, 15), chips (Task 11), Unit 7 table and sync (Tasks 12, 13), flagged loads for unresolved refs and unreadable rows (Task 14, 15, 16), Save and the Saved row (Task 15), Settings > Manage (Task 16), Localisation (Tasks 2, 9, 15, 16, 17; parser messages recorded as a deviation), Error handling for saved queries (Task 14), Testing item 8 (Tasks 6, 8, 9, 10, 11, 15, 16), item 9 (Task 13), item 10 (every task's gate).
- Review Focus 1 to 5 are pinned in Tasks 6, 14, 11, 14 plus 15, and 10 respectively.
- Names used across tasks: `QueryEditorContext` (5) consumed by 6, 7, 8, 9; `NameEntries` (5) implemented by `QueryNameIndex` (3) and `MapNameResolver` (5), read by 7 and 8; `QueryLabels.field/relation/entity/op/enumValue` (2) used by 7, 8; `QueryBuilderStrings` (8) used by 9; `opsFor`, `defaultValueFor`, `pickCondition` (8); `topLevelConjuncts`, `removeTopLevelConjunct`, `normalizeQuery` (4) used by 6, 8, 11; `SavedQueryLoad`, `loadSavedQuery` (14) used by 15, 16; `savedQueryLoadsProvider(String?)` (14) used by 15, 16; `SavedQueryRepository.create/rename/updateQuery/reorder/delete` (13) used by 15, 16; `QueryErrorCode`, `describeQueryError` (17) used by 9's editor via `describeError` and by 16's page.
