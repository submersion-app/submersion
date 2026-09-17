# Equipment Identity Labels Implementation Plan (PR 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every gear list row shows enough (brand, model, an identifier, and a differing field when rows would still collide) to tell identical equipment items apart.

**Architecture:** The cylinder-only `tank_identifier` attribute becomes a universal attribute, so any item can carry an identifier with no schema change. One pure function builds the title and subtitle for a whole list of rows at once, which is what lets it see collisions; a thin widget-side helper feeds it the localized strings and the diver's date format. Six existing row renderers drop their own `fullName != name` logic and call the helper.

**Tech Stack:** Flutter, Riverpod, Drift (untouched here), `flutter gen-l10n` ARB localization, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-17-equipment-sharing-transfer-identity-design.md`, sections "Identity in lists (#1549)" and "Delivery" item 1. This plan covers PR 1 only. PRs 2 to 4 (sharing, transfer, overlap) each get their own plan once the PR before it has merged, because they build on code this PR introduces. The owner chip and the "Shared with me" picker section belong to PR 2, not here.

## Global Constraints

- No schema change, no migration rung, no sync change in this PR.
- The stored attribute key stays `tank_identifier`. Never rename it: renaming rewrites attribute rows on every sync peer.
- Never use em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens as punctuation, in code, comments, tests, ARB strings, commit messages or the PR body.
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file. No `Co-Authored-By` trailer.
- No emojis in code, comments or docs.
- Dates shown to the diver go through `UnitFormatter.formatDate` (the diver's date format setting), never a hard-coded `DateFormat`.
- New user-visible strings are translated in all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh.
- Immutability: never mutate a list or map that was passed in.
- TDD: write the failing test first, watch it fail, then implement.
- Run `dart format .` on the whole project before each commit.
- Run `flutter analyze` on its own, never piped through `grep` or `tail` (a pipe hides the exit status). Infos are fatal in CI.
- Run specific test files, never the full suite per task; the full suite runs once, in Task 7.
- The Bash tool's working directory can reset; run every command from the worktree root and stage explicit paths (`git add <path>`), never `git add -A` or `git add -u`.
- The PR body must contain `Refs #1549` (this PR does not close the issue).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (modify) | `tank_identifier` moves to `universal`; new `EquipmentAttrKeys.identifier` |
| `lib/features/equipment/domain/entities/equipment_item.dart` (modify) | `identifier` getter |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (modify, ~line 650) | a replacement part does not inherit the old part's identifier |
| `lib/features/equipment/presentation/utils/equipment_row_label.dart` (create) | pure label builder: `EquipmentRowLabel`, `EquipmentRowLabelStrings`, `buildEquipmentRowLabels` |
| `lib/features/equipment/presentation/utils/equipment_row_labels_of.dart` (create) | widget-side helper `equipmentRowLabelsOf(context, ref, items)` |
| `lib/l10n/arb/app_*.arb` (modify, 11 files) | three new strings |
| Six row renderers (modify) | call the helper; listed per task |

---

### Task 1: Identifier attribute on every equipment type

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (the `specKeys` set near line 650)
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart`
- Test: `test/features/equipment/domain/equipment_purchase_attributes_test.dart`
- Test: `test/features/equipment/domain/entities/equipment_item_identifier_test.dart` (create)
- Test: `test/features/equipment/data/repositories/equipment_replace_child_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `EquipmentAttrKeys.identifier` (`static const String`, value `'tank_identifier'`); `String? EquipmentItem.identifier`.

- [ ] **Step 1: Write the failing tests**

In `test/features/equipment/domain/equipment_attribute_catalog_test.dart`, in the first test (`every equipment type resolves to a definition list`), change the `containsAll` list so the universal check covers the identifier:

```dart
      expect(
        defs.map((d) => d.key),
        containsAll(['buoyancy_kg', 'dry_weight_kg', 'tank_identifier']),
        reason: '${type.name} missing universal attributes',
      );
```

Create `test/features/equipment/domain/entities/equipment_item_identifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('the identifier key keeps its stored name', () {
    // Renaming the stored key would rewrite rows on every sync peer.
    expect(EquipmentAttrKeys.identifier, 'tank_identifier');
  });

  test('identifier reads the curated attribute on any type', () {
    final pouch = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'p1',
          key: EquipmentAttrKeys.identifier,
          valueText: 'P2',
        ),
      ],
    );
    expect(pouch.identifier, 'P2');
  });

  test('identifier is null when unset, and ignores a custom field', () {
    const bare = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
    );
    expect(bare.identifier, isNull);

    const custom = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
      attributes: [
        EquipmentAttribute(
          id: 'a1',
          equipmentId: 'p1',
          key: 'tank_identifier',
          isCustom: true,
          valueText: 'mine',
        ),
      ],
    );
    expect(custom.identifier, isNull);
  });
}
```

In `test/features/equipment/data/repositories/equipment_replace_child_test.dart`, in the test `a replaced battery keeps its chemistry, not its receipt`, add a fifth attribute to the `old` battery's `attributes` list:

```dart
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.identifier,
            valueText: 'B1',
          ),
```

and a final expectation after `expect(stored.installedDate, now);`:

```dart
    // The identifier names one physical cell, so the new one starts unmarked.
    expect(stored.identifier, isNull);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/entities/equipment_item_identifier_test.dart test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/data/repositories/equipment_replace_child_test.dart`
Expected: FAIL. The new file and the replace-child test do not compile (`identifier` is not defined on `EquipmentAttrKeys` or `EquipmentItem`), and the catalog test reports a type "missing universal attributes".

- [ ] **Step 3: Implement**

In `equipment_attribute_catalog.dart`, add to `EquipmentAttrKeys`, after the `tankMaterial` line:

```dart
  // The diver's own mark for telling identical items apart (issue #1549).
  // Cylinders had it first, and the stored key keeps that name: renaming it
  // would rewrite attribute rows on every sync peer.
  static const identifier = 'tank_identifier';
```

Append to the `universal` list, after the `dryWeightKg` entry:

```dart
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.identifier,
      kind: AttributeKind.text,
    ),
```

Delete this line from the `EquipmentType.tank` list (it would now be a duplicate key, which the catalog test rejects):

```dart
      EquipmentAttributeDef(key: 'tank_identifier', kind: AttributeKind.text),
```

In `equipment_item.dart`, after the `productUrl` getter:

```dart
  /// The diver's own mark for this item ("P2", "Bill's spare"), shown in
  /// gear lists to tell identical items apart (issue #1549).
  String? get identifier => attrText(EquipmentAttrKeys.identifier);
```

In `equipment_repository_impl.dart`, the `specKeys` set that a replacement part inherits (near line 650) currently excludes only the install date. The identifier names one physical object, so the successor must not inherit it:

```dart
      final specKeys = {
        for (final def in EquipmentAttributeCatalog.attributesFor(current.type))
          if (def.group == AttributeGroup.spec &&
              def.key != EquipmentAttrKeys.installedDate &&
              def.key != EquipmentAttrKeys.identifier)
            def.key,
      };
```

Update the comment above it to say "Its install date, identifier and purchase record are its own."

- [ ] **Step 4: Fix the tests that assert exact key lists**

The identifier now sits after `dry_weight_kg` for every type. Run:

`flutter test test/features/equipment/domain/`

Every failure is an exact `expect(keys, [...])` list. In each, insert `'tank_identifier'` (or `EquipmentAttrKeys.identifier` where the list uses constants) directly after the `dry_weight_kg` entry. Known sites: `equipment_attribute_catalog_test.dart` (the `EquipmentType.other` `unorderedEquals` list, the dpv list, the rebreather list) and `equipment_purchase_attributes_test.dart` (`purchase attributes come last, after the universal ones`). In the tank `containsAll` list, leave `'tank_identifier'` where it is; `containsAll` ignores order.

Add one test to `equipment_attribute_catalog_test.dart` so the successor rule is pinned where the catalog lives:

```dart
  test('the identifier is a spec-group text attribute on every type', () {
    final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.identifier);
    expect(def?.kind, AttributeKind.text);
    expect(def?.group, AttributeGroup.spec);
  });
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/ test/features/equipment/data/repositories/equipment_replace_child_test.dart test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart test/core/services/export/`
Expected: PASS.

Then prove the successor expectation is doing work: temporarily remove the `def.key != EquipmentAttrKeys.identifier` clause, run `equipment_replace_child_test.dart`, and expect `a replaced battery keeps its chemistry, not its receipt` to FAIL with `Expected: null, Actual: 'B1'`. Restore the clause and run again, expected PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/domain/entities/equipment_item.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart test/features/equipment
git commit -m "feat(equipment): identifier attribute on every equipment type"
```

---

### Task 2: The row label builder

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_row_label.dart`
- Test: `test/features/equipment/presentation/utils/equipment_row_label_test.dart`

**Interfaces:**
- Consumes: `EquipmentItem.identifier` (Task 1).
- Produces:

```dart
class EquipmentRowLabel { final String title; final List<String> subtitleParts; String? get subtitle; }
class EquipmentRowLabelStrings {
  const EquipmentRowLabelStrings({required this.identifier, required this.serial, required this.purchased, required this.formatDate});
  final String Function(String identifier) identifier;
  final String Function(String serial) serial;
  final String Function(String date) purchased;
  final String Function(DateTime date) formatDate;
}
Map<String, EquipmentRowLabel> buildEquipmentRowLabels(Iterable<EquipmentItem> rows, EquipmentRowLabelStrings strings);
```

The map is keyed by `EquipmentItem.id`. `subtitle` is `subtitleParts.join(' · ')`, or null when there are no parts.

- [ ] **Step 1: Write the failing tests**

Create `test/features/equipment/presentation/utils/equipment_row_label_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';

final _strings = EquipmentRowLabelStrings(
  identifier: (v) => 'ID $v',
  serial: (v) => 'S/N $v',
  purchased: (v) => 'Bought $v',
  formatDate: (d) => '${d.year}-${d.month}-${d.day}',
);

EquipmentItem _pouch(
  String id, {
  String name = 'Pouches',
  String? identifier,
  String? serial,
  String? size,
  DateTime? purchased,
}) => EquipmentItem(
  id: id,
  name: name,
  type: EquipmentType.other,
  brand: 'Palantic',
  model: 'Drop-Bottom',
  serialNumber: serial,
  purchaseDate: purchased,
  attributes: [
    if (identifier != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.identifier,
        valueText: identifier,
      ),
    if (size != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.size,
        valueText: size,
      ),
  ],
);

void main() {
  test('subtitle is brand and model, then the identifier', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: 'P2'),
    ], _strings);
    expect(labels['a']!.title, 'Pouches');
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · ID P2');
  });

  test('no subtitle when the name is all there is', () {
    const bare = EquipmentItem(
      id: 'm',
      name: 'Mask',
      type: EquipmentType.mask,
    );
    expect(buildEquipmentRowLabels([bare], _strings)['m']!.subtitle, isNull);
  });

  test('a blank identifier is not shown', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: '  '),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('rows that do not collide get no tie-break detail', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: 'P1', serial: 'X1'),
      _pouch('b', identifier: 'P2', serial: 'X2'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · ID P1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · ID P2');
  });

  test('colliding rows append the serial number first', () {
    // Fed in descending serial order: a builder that only looked at the
    // first row, or that relied on input order, would still fail here.
    final labels = buildEquipmentRowLabels([
      _pouch('b', serial: 'X2', size: 'L'),
      _pouch('a', serial: 'X1', size: 'M'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · S/N X2');
  });

  test('size breaks the tie when the serial numbers do not differ', () {
    final labels = buildEquipmentRowLabels([
      _pouch('b', size: 'L'),
      _pouch('a', size: 'M'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · M');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · L');
  });

  test('purchase date is the last tie-break, in the given date format', () {
    final labels = buildEquipmentRowLabels([
      _pouch('b', purchased: DateTime(2025, 6, 1)),
      _pouch('a', purchased: DateTime(2024, 3, 9)),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · Bought 2024-3-9');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · Bought 2025-6-1');
  });

  test('a row with no value for the deciding field stays as it was', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', serial: 'X1'),
      _pouch('b'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('truly identical rows stay identical: no invented counter', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a'),
      _pouch('b'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('a different name is not a collision', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', name: 'Pouches Bill', serial: 'X1'),
      _pouch('b', name: 'Pouches Laurie', serial: 'X2'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('the input list is not mutated', () {
    final rows = List<EquipmentItem>.unmodifiable([
      _pouch('a', serial: 'X1'),
      _pouch('b', serial: 'X2'),
    ]);
    expect(() => buildEquipmentRowLabels(rows, _strings), returnsNormally);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/equipment_row_label_test.dart`
Expected: FAIL to compile: `equipment_row_label.dart` does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/equipment/presentation/utils/equipment_row_label.dart`. This is the code as shipped. The first draft of this plan stopped at the first tie-break that separated any row of a colliding group, which left the rest of a larger group reading the same (two of four pouches split by serial number, the other two never reaching the purchase date). A six-row screenshot caught it; the fix regroups before every tie-break, and two tests with groups of three and four rows pin it:

```dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// What one gear row shows: the item's name, and the details under it.
class EquipmentRowLabel {
  final String title;
  final List<String> subtitleParts;

  const EquipmentRowLabel({required this.title, required this.subtitleParts});

  /// Null rather than empty, because a non-null ListTile subtitle forces the
  /// two-line layout.
  String? get subtitle =>
      subtitleParts.isEmpty ? null : subtitleParts.join(' · ');
}

/// The localized pieces [buildEquipmentRowLabels] needs. Passed in so the
/// builder stays pure: no BuildContext, no provider, no settings.
class EquipmentRowLabelStrings {
  final String Function(String identifier) identifier;
  final String Function(String serial) serial;
  final String Function(String date) purchased;
  final String Function(DateTime date) formatDate;

  const EquipmentRowLabelStrings({
    required this.identifier,
    required this.serial,
    required this.purchased,
    required this.formatDate,
  });
}

/// Labels for every row of one list, keyed by item id (issue #1549).
///
/// Built for the whole list at once because telling identical items apart
/// is a property of the list, not of a row: when two rows would read the
/// same, each gains the first detail that differs between them (serial
/// number, then size, then purchase date), and rows that still read the
/// same after one detail go on to the next. Rows that are identical in all
/// three stay identical; a counter would not be stable from one list to
/// the next.
Map<String, EquipmentRowLabel> buildEquipmentRowLabels(
  Iterable<EquipmentItem> rows,
  EquipmentRowLabelStrings strings,
) {
  final items = rows.toList(growable: false);
  final parts = {for (final item in items) item.id: _baseParts(item, strings)};

  final tieBreaks = <String? Function(EquipmentItem)>[
    (e) => _text(e.serialNumber, strings.serial),
    (e) => _text(e.size, (v) => v),
    (e) => e.purchaseDate == null
        ? null
        : strings.purchased(strings.formatDate(e.purchaseDate!)),
  ];

  // Regrouped before every tie-break, not once: a detail that separates
  // some rows of a group can leave others still reading the same (two of
  // four pouches have a serial number, the other two only a purchase date),
  // and those move on to the next detail.
  for (final detailOf in tieBreaks) {
    for (final group in _collidingGroups(items, parts)) {
      final details = {for (final e in group) e.id: detailOf(e)};
      if (details.values.toSet().length < 2) continue;
      for (final e in group) {
        final detail = details[e.id];
        if (detail != null) parts[e.id] = [...parts[e.id]!, detail];
      }
    }
  }

  return {
    for (final item in items)
      item.id: EquipmentRowLabel(
        title: item.name,
        subtitleParts: parts[item.id]!,
      ),
  };
}

/// The rows that currently read the same as at least one other row.
List<List<EquipmentItem>> _collidingGroups(
  List<EquipmentItem> items,
  Map<String, List<String>> parts,
) {
  final groups = <String, List<EquipmentItem>>{};
  for (final item in items) {
    final key = '${item.name}\u0000${parts[item.id]!.join('\u0000')}';
    (groups[key] ??= []).add(item);
  }
  return [
    for (final group in groups.values)
      if (group.length > 1) group,
  ];
}

List<String> _baseParts(EquipmentItem item, EquipmentRowLabelStrings strings) {
  final identifier = _text(item.identifier, strings.identifier);
  return [if (item.fullName != item.name) item.fullName, ?identifier];
}

String? _text(String? value, String Function(String) wrap) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : wrap(trimmed);
}
```

The `?identifier` null-aware list element is valid Dart in this project (see `?myUnitsKeyFor(def.key): def` in `csv_attribute_codec.dart`); do not rewrite it as an `if`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/utils/equipment_row_label_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Mutation check the tie-break order**

In `equipment_row_label.dart`, temporarily swap the first two entries of `tieBreaks` (size before serial). Run the test file again.
Expected: `colliding rows append the serial number first` FAILS. Restore the order, run again, expected PASS. This proves the order test is doing work.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/presentation/utils/equipment_row_label.dart test/features/equipment/presentation/utils/equipment_row_label_test.dart
git commit -m "feat(equipment): row label builder that tells identical items apart"
```

---

### Task 3: Localized strings and the widget-side helper

**Files:**
- Modify: all 11 of `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_en.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (generated by `flutter gen-l10n`, committed)
- Create: `lib/features/equipment/presentation/utils/equipment_row_labels_of.dart`
- Test: `test/features/equipment/presentation/utils/equipment_row_labels_of_test.dart`

**Interfaces:**
- Consumes: `buildEquipmentRowLabels`, `EquipmentRowLabelStrings` (Task 2).
- Produces: `Map<String, EquipmentRowLabel> equipmentRowLabelsOf(BuildContext context, WidgetRef ref, Iterable<EquipmentItem> items)` and three l10n getters: `equipment_rowLabel_identifier(String identifier)`, `equipment_rowLabel_serial(String serial)`, `equipment_rowLabel_purchased(String date)`.

- [ ] **Step 1: Add the strings to all 11 ARB files**

Only `app_en.arb` is alphabetical; the others are grouped by feature. In every file, insert the three lines directly after the line that starts with `"equipment_components_count":` (it exists exactly once in each file). Values per locale:

| Locale | `equipment_rowLabel_identifier` | `equipment_rowLabel_serial` | `equipment_rowLabel_purchased` |
| --- | --- | --- | --- |
| en | `ID {identifier}` | `S/N {serial}` | `Bought {date}` |
| ar | `المعرّف {identifier}` | `الرقم التسلسلي {serial}` | `تاريخ الشراء {date}` |
| de | `ID {identifier}` | `S/N {serial}` | `Gekauft {date}` |
| es | `ID {identifier}` | `N.º de serie {serial}` | `Comprado {date}` |
| fr | `ID {identifier}` | `N° de série {serial}` | `Acheté le {date}` |
| he | `מזהה {identifier}` | `מס׳ סידורי {serial}` | `נרכש {date}` |
| hu | `Azonosító: {identifier}` | `Sorozatszám: {serial}` | `Vásárolva: {date}` |
| it | `ID {identifier}` | `N. di serie {serial}` | `Acquistato {date}` |
| nl | `ID {identifier}` | `S/N {serial}` | `Gekocht {date}` |
| pt | `ID {identifier}` | `N.º de série {serial}` | `Comprado {date}` |
| zh | `编号 {identifier}` | `序列号 {serial}` | `购买于 {date}` |

The English block, as it should read in `app_en.arb`:

```json
  "equipment_rowLabel_identifier": "ID {identifier}",
  "equipment_rowLabel_serial": "S/N {serial}",
  "equipment_rowLabel_purchased": "Bought {date}",
```

Edit the ARB files with the Edit tool, not a Python rewrite: some project files are CRLF and a text-mode rewrite normalizes line endings. After editing, `git diff --numstat lib/l10n/arb/*.arb` must show exactly 3 added lines and 0 removed per file.

- [ ] **Step 2: Regenerate the localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `git status --short lib/l10n` lists the 11 ARB files plus the regenerated `app_localizations*.dart` files.

- [ ] **Step 3: Write the failing test**

Create `test/features/equipment/presentation/utils/equipment_row_labels_of_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('feeds the builder the localized strings and the date format', (
    tester,
  ) async {
    final items = [
      EquipmentItem(
        id: 'b',
        name: 'Pouches',
        type: EquipmentType.other,
        purchaseDate: DateTime(2025, 6, 1),
      ),
      EquipmentItem(
        id: 'a',
        name: 'Pouches',
        type: EquipmentType.other,
        purchaseDate: DateTime(2024, 3, 9),
      ),
    ];
    late Map<String, EquipmentRowLabel> labels;
    late String expectedDate;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              labels = equipmentRowLabelsOf(context, ref, items);
              expectedDate = UnitFormatter(
                ref.watch(settingsProvider),
              ).formatDate(DateTime(2024, 3, 9));
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(labels['a']!.subtitle, 'Bought $expectedDate');
  });
}
```

Add `import 'package:submersion/core/utils/unit_formatter.dart';` to the imports. If `test/helpers/mock_providers.dart` resolves differently from this directory, fix the relative path (the helper lives at `test/helpers/mock_providers.dart`).

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/equipment_row_labels_of_test.dart`
Expected: FAIL to compile: `equipment_row_labels_of.dart` does not exist.

- [ ] **Step 5: Implement**

Create `lib/features/equipment/presentation/utils/equipment_row_labels_of.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Row labels for [items] as one list shows them, in the app's language and
/// the active diver's date format. Pass every row the list shows, not one
/// row at a time: collisions are detected across the list.
Map<String, EquipmentRowLabel> equipmentRowLabelsOf(
  BuildContext context,
  WidgetRef ref,
  Iterable<EquipmentItem> items,
) {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.watch(settingsProvider));
  return buildEquipmentRowLabels(
    items,
    EquipmentRowLabelStrings(
      identifier: l10n.equipment_rowLabel_identifier,
      serial: l10n.equipment_rowLabel_serial,
      purchased: l10n.equipment_rowLabel_purchased,
      formatDate: units.formatDate,
    ),
  );
}
```

Confirm the import path of `UnitFormatter` with `grep -rn "^class UnitFormatter" lib`; use the path it reports.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/utils/equipment_row_labels_of_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/l10n/arb lib/features/equipment/presentation/utils/equipment_row_labels_of.dart test/features/equipment/presentation/utils/equipment_row_labels_of_test.dart
git commit -m "feat(equipment): localized row label strings and widget helper"
```

---

### Task 4: The dive equipment picker shows brand, model and identifier

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart`
- Test: `test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `equipmentRowLabelsOf` (Task 3), `EquipmentRowLabel.subtitle`.
- Produces: nothing new for later tasks.

The picker is the list the issue is about: today a row is `Text(item.name)` with the type name underneath only when type grouping is off. Brand, model, serial and identifier never appear.

- [ ] **Step 1: Make the existing tests survive the new settings dependency**

The picker will now read `settingsProvider`, which without an override reaches for the database. In `equipment_picker_sheet_test.dart`, add to the `overrides:` list inside `_pump`:

```dart
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
```

and the imports:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/mock_providers.dart';
```

- [ ] **Step 2: Write the failing tests**

Append to `main()` in the same file:

```dart
  testWidgets('rows show brand, model and identifier under the name', (
    tester,
  ) async {
    final pouch = EquipmentItem(
      id: 'p',
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'p',
          key: EquipmentAttrKeys.identifier,
          valueText: 'P2',
        ),
      ],
    );
    await _pump(tester, equipment: [pouch]);
    expect(find.text('Pouches'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · ID P2'), findsOneWidget);
  });

  testWidgets('two identical items are told apart by serial number', (
    tester,
  ) async {
    EquipmentItem pouch(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      serialNumber: serial,
    );
    await _pump(tester, equipment: [pouch('b', 'X2'), pouch('a', 'X1')]);
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });
```

with the imports:

```dart
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart`
Expected: the two new tests FAIL (`Found 0 widgets with text "Palantic Drop-Bottom · ID P2"`); every older test PASSES.

- [ ] **Step 4: Implement**

In `equipment_picker_sheet.dart`, import the helper:

```dart
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
```

Directly before `final rows = <_PickerRow>[`, build the labels for the rows the diver will actually see:

```dart
              final labels = equipmentRowLabelsOf(context, ref, available);
```

Replace the `_ItemRow` arm of the `itemBuilder` switch. The type name joins the subtitle when type grouping is off, as before:

```dart
                  _ItemRow(:final item, :final showTypeLabel) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        equipmentTypeIcon(item.type),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: _subtitle(
                      context,
                      labels[item.id]?.subtitleParts ?? const [],
                      item,
                      showTypeLabel: showTypeLabel,
                    ),
                    onTap: () => onEquipmentSelected(item),
                  ),
```

and add to the `EquipmentPickerSheet` class:

```dart
  /// The type name leads when there is no type heading to say it, then the
  /// details that tell this item from its neighbours.
  Widget? _subtitle(
    BuildContext context,
    List<String> parts,
    EquipmentItem item, {
    required bool showTypeLabel,
  }) {
    final all = [
      if (showTypeLabel) item.type.localizedName(context.l10n),
      ...parts,
    ];
    return all.isEmpty ? null : Text(all.join(' · '));
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart`
Expected: PASS, all tests.

- [ ] **Step 6: Run the other hosts of the picker**

The picker is also opened from the dive edit page, bulk edit, the transmitter editor, the weight rig composer and the planner. Run:

`flutter test test/features/transmitters test/features/weight_planner test/features/dive_planner`

and `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart` if that file exists (`ls test/features/dive_log/presentation/pages/ | grep dive_edit`). Any failure that mentions the database service or `diverSettingsRepositoryProvider` is a test that opens the picker without a settings override; add this line to that test's `overrides:` and import `test/helpers/mock_providers.dart`:

```dart
settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
```

Expected after fixes: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart test/features
git commit -m "feat(dive-log): equipment picker rows show brand, model and identifier"
```

---

### Task 5: The gear list on a dive (detail and edit pages)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`

**Interfaces:**
- Consumes: `equipmentRowLabelsOf` (Task 3).
- Produces: nothing new.

`DiveGearTreeView` renders both the read-only list on the dive detail page and the editable list on the dive edit page, so this one change covers two of the three lists in the issue. Gear on a dive is attribute-hydrated (`dive_repository_impl.dart`, `_equipmentAttributesFor`), so the identifier is available.

- [ ] **Step 1: Make the existing tests survive the settings dependency**

In `dive_gear_tree_view_test.dart`, add to the `overrides:` list in `build(...)`:

```dart
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
```

with imports:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
```

- [ ] **Step 2: Write the failing test**

The file's `build` helper renders a fixed `links`. Give it an optional parameter so a test can supply its own, by changing its signature and body:

```dart
  Widget build({
    required EquipmentArrangement arrangement,
    List<GearLink>? gear,
    void Function(String)? onRemovePart,
```

and `links: gear ?? links,` in the `DiveGearTreeView(...)` call. Then append:

```dart
  testWidgets('identical items on a dive are told apart', (tester) async {
    EquipmentItem pouch(String id, String mark) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.identifier,
          valueText: mark,
        ),
      ],
    );
    await tester.pumpWidget(
      build(
        arrangement: flat,
        gear: gearLinksFor([pouch('b', 'P2'), pouch('a', 'P1')], const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Palantic Drop-Bottom · ID P1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · ID P2'), findsOneWidget);
  });
```

with imports for `EquipmentAttribute` and `EquipmentAttrKeys` (same two lines as Task 4 Step 2).

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
Expected: the new test FAILS (`Found 0 widgets with text "Palantic Drop-Bottom · ID P1"`); older tests PASS.

- [ ] **Step 4: Implement**

In `dive_gear_tree_view.dart`, import the helper and the label type:

```dart
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
```

Add a field to `_DiveGearTreeViewState`:

```dart
  var _labels = const <String, EquipmentRowLabel>{};
```

At the top of `build`, after `final l10n = context.l10n;`, label every item on the dive, parts included, so an expanded part is compared with its neighbours too:

```dart
    _labels = equipmentRowLabelsOf(context, ref, [
      for (final link in widget.links) link.item,
    ]);
```

In `_rows`, replace the first element of `subtitleParts`:

```dart
    final subtitleParts = <String>[
      ...?_labels[item.id]?.subtitleParts,
      if (hasParts) l10n.equipment_components_count(node.children.length),
    ];
```

Assigning `_labels` in `build` is deliberate: it is derived state recomputed on every build, not state that outlives one, so it needs no `setState`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
Expected: PASS, all tests (the `1 component` expectation still holds, since the parts count is still appended).

- [ ] **Step 6: Run the two host pages**

Run: `flutter test test/features/dive_log/presentation/pages/` restricted to the files whose names contain `dive_detail` or `dive_edit` (`ls test/features/dive_log/presentation/pages/ | grep -E "dive_(detail|edit)"`, then pass those paths). Add the `settingsProvider` override from Step 1 to any test that fails on the database service.
Expected after fixes: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart test/features/dive_log
git commit -m "feat(dive-log): gear rows on a dive tell identical items apart"
```

---

### Task 6: Equipment list, set pages and the component picker

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile`, `_buildEquipmentList`, `EquipmentSearchDelegate._buildSearchResults`)
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` (`_buildEquipmentTile` and its caller)
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` (`_buildEquipmentCheckbox` and its caller)
- Modify: `lib/features/equipment/presentation/widgets/component_picker_sheet.dart` (the `CheckboxListTile` loop)
- Test: `test/features/equipment/presentation/pages/equipment_list_page_test.dart`, `test/features/equipment/presentation/pages/equipment_set_edit_page_test.dart`, `test/features/equipment/presentation/widgets/component_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `equipmentRowLabelsOf`, `EquipmentRowLabel` (Task 3).
- Produces: `EquipmentListTile` gains an optional `final EquipmentRowLabel? label;` constructor parameter.

The dense list tile (`dense_equipment_list_tile.dart`) is a single-line row with no subtitle and is out of scope, as is table mode, where brand, model and serial are already columns.

- [ ] **Step 1: Write the failing test for the equipment list**

`equipment_list_page_test.dart` pumps the page through `_buildTestWidget({required Widget child, required List<Override> overrides, ...})` and each test passes its own `overrides`, including `activeEquipmentProvider.overrideWith((ref) async => <items>)`. Copy the override list and the pump sequence of the nearest existing test that renders list rows (search the file for `activeEquipmentProvider.overrideWith`), wrap them in a local `Future<void> pumpList(WidgetTester tester, List<EquipmentItem> items)` inside the new test's group, and append:

```dart
  testWidgets('identical items are told apart in the equipment list', (
    tester,
  ) async {
    EquipmentItem pouch(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      serialNumber: serial,
    );
    // Descending serial order, so input order cannot produce the result.
    await pumpList(tester, [pouch('b', 'X2'), pouch('a', 'X1')]);
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });
```

The list page already reads `settingsProvider`, so its tests already override it.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_list_page_test.dart`
Expected: the new test FAILS (both rows read `Palantic Drop-Bottom`, so `findsOneWidget` finds two); older tests PASS.

- [ ] **Step 3: Implement the equipment list**

In `equipment_list_content.dart`, import:

```dart
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
```

Add the field and constructor parameter to `EquipmentListTile`:

```dart
  /// The row's label as its list computed it. Null falls back to the item's
  /// own brand and model, for a tile shown outside a list.
  final EquipmentRowLabel? label;
```

```dart
    this.onCheckChanged,
    this.label,
  });
```

In `EquipmentListTile.build`, replace `final hasFullName = item.fullName != item.name;` and the subtitle:

```dart
    final detail =
        label?.subtitle ?? (item.fullName != item.name ? item.fullName : null);
```

```dart
        subtitle: detail != null || hasChips
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (detail != null) Text(detail),
                  if (hasChips) AssemblyChips(itemId: item.id),
                ],
              )
            : null,
```

In `_buildEquipmentList`, after the `rows` list is built:

```dart
    final labels = equipmentRowLabelsOf(context, ref, [
      for (final group in groups) ...group.items,
    ]);
```

and pass `label: labels[item.id],` to the `EquipmentListTile(...)` in the `itemBuilder`.

In `EquipmentSearchDelegate._buildSearchResults`, `dataBuilder` has no `WidgetRef`. Wrap the `ListView.builder` in a `Consumer` so the labels can be computed for the result list:

```dart
      dataBuilder: (context, equipment) {
        return Consumer(
          builder: (context, ref, _) {
            final labels = equipmentRowLabelsOf(context, ref, equipment);
            return ListView.builder(
              itemCount: equipment.length,
              itemBuilder: (context, index) {
                final item = equipment[index];
                return EquipmentListTile(
                  item: item,
                  label: labels[item.id],
                  onTap: () {
                    close(context, item);
                    context.push('/equipment/${item.id}');
                  },
                );
              },
            );
          },
        );
      },
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/equipment/presentation/pages/equipment_list_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing tests for the set edit page and the component picker**

In `equipment_set_edit_page_test.dart` and `component_picker_sheet_test.dart`, find each file's pump helper (search for `activeEquipmentProvider.overrideWith`), add the `settingsProvider` override from Task 4 Step 1 if the helper lacks one, and append to each file a test of this shape, using that file's helper:

```dart
  testWidgets('identical items are told apart', (tester) async {
    EquipmentItem pouch(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      serialNumber: serial,
    );
    await pumpWith(tester, [pouch('b', 'X2'), pouch('a', 'X1')]);
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });
```

For the component picker, the two pouches must be valid candidates for the parent under test: `component_picker_sheet.dart` filters candidates through `_candidates` (a cycle guard) and may restrict types, so use the item type the file's existing tests use for candidates instead of `EquipmentType.other` if needed.

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_edit_page_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart`
Expected: the two new tests FAIL.

- [ ] **Step 6: Implement the set pages and the component picker**

Import `equipment_row_label.dart` and `equipment_row_labels_of.dart` in all three files.

`equipment_set_edit_page.dart`: `_buildEquipmentCheckbox` gains a `Map<String, EquipmentRowLabel> labels` parameter. At the call site (the place that maps the equipment list to checkboxes; search for `_buildEquipmentCheckbox(`), compute `final labels = equipmentRowLabelsOf(context, ref, <the same list being mapped>);` once, outside the loop, and pass it. The subtitle becomes:

```dart
      subtitle: switch (labels[item.id]?.subtitle) {
        final detail? => Text(detail),
        null => null,
      },
```

`equipment_set_detail_page.dart`: `_buildEquipmentTile` gains the same `labels` parameter, computed once at its call site from the set's item list (search for `_buildEquipmentTile(`). If the enclosing method has no `WidgetRef`, the page is a `ConsumerWidget` or `ConsumerStatefulWidget`; pass `ref` down from `build`. The first subtitle line keeps its fallback to the type name:

```dart
            Text(
              labels[item.id]?.subtitle ??
                  item.type.localizedName(context.l10n),
            ),
```

`component_picker_sheet.dart`: compute `final labels = equipmentRowLabelsOf(context, ref, <all candidate items across the groups>);` once before the grouped `for` loops that build the `CheckboxListTile`s, and replace the subtitle:

```dart
                              subtitle: switch (labels[item.id]?.subtitle) {
                                final detail? => Text(detail),
                                null => null,
                              },
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/`
Expected: PASS. Add the `settingsProvider` override to any test that now fails on the database service.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment/presentation test/features/equipment/presentation
git commit -m "feat(equipment): list, set and component rows tell identical items apart"
```

---

### Task 7: Whole-project verification and the PR

**Files:** none new.

- [ ] **Step 1: No renderer still builds its own brand and model subtitle**

Run: `grep -rn "fullName != item.name\|fullName != name" lib/features/equipment lib/features/dive_log`
Expected: exactly one hit, the fallback inside `EquipmentListTile.build` from Task 6. Any other hit is a renderer this plan missed: route it through `equipmentRowLabelsOf` the same way.

- [ ] **Step 2: Architecture guards**

`test/architecture/` scans all of `lib/` and is not part of any per-directory run. Two new `lib/` files were added.

Run: `flutter test test/architecture/`
Expected: PASS.

- [ ] **Step 3: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `dart format` reports 0 changed files; `flutter analyze` prints `No issues found!`. Infos are fatal in CI, so fix them too.

- [ ] **Step 4: One full test run**

Do not start it while another `flutter test` is running on this machine.

Run: `flutter test`
Expected: PASS. Read the exit status directly; do not pipe the command.

- [ ] **Step 5: The generated localizations are current**

Run: `flutter gen-l10n && git status --short lib/l10n`
Expected: no output from `git status` (nothing left to regenerate).

- [ ] **Step 6: Open the PR**

Push the branch and open a PR against `main` titled `feat(equipment): tell identical gear apart in every list`. The body must include the line `Refs #1549` on its own (not inside a code span or an HTML comment), a summary of the three visible changes (an Identifier field on every equipment type; brand, model and identifier in the Add Equipment picker and every gear list; automatic serial, size or purchase date when rows would still read the same), and a note that sharing and transfer follow in later PRs. No attribution lines, no tool or model names.
