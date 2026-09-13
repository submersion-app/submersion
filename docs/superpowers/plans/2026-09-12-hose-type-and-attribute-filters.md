# Hose Type and Equipment Attribute Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give hoses a Hose type (LP / HP / LPI) and let divers filter the equipment list by any choice field of a category and the dive list by one category's choice fields, with the dive attribute filter behaving the same on every dive surface.

**Architecture:** The field is one catalog entry (curated attributes are rows in `equipment_attributes`, no schema change). A new `EquipmentAttrCondition` value type is shared by both filters: the dive filter holds a list of them and evaluates them only in SQL through one builder (`equipmentAttrConditionSql`) used by Statistics, the paginated dive list (which today ignores the axis) and a new SQL-resolved id provider for the table and map views; the equipment list evaluates them in memory with `EquipmentAttrCondition.matches`. One shared chip widget renders a category's choice fields in both filter sheets.

**Tech Stack:** Flutter, Dart, Riverpod 3 (`FutureProvider.family`, `StateProvider`), Drift (SQLite, `customSelect`), gen-l10n ARB files.

**Spec:** `docs/superpowers/specs/2026-09-12-hose-type-and-attribute-filters-design.md`

## Global Constraints

- Never write the em-dash character (U+2014), and never use an en-dash, a double hyphen or a spaced hyphen as prose punctuation, in code, comments, docs, commit messages or ARB strings.
- No commit message, PR text or file may mention Claude, Claude Code or Anthropic; no `Co-Authored-By` trailer.
- No schema change and no migration rung: curated attributes are `equipment_attributes` rows.
- Choice option keys are exactly `lp`, `hp`, `lpi`; the attribute key is `hose_type`.
- Every value in generated SQL is a bound parameter, including equipment type names.
- Every new user-facing string goes into all 11 ARB files (`ar de en es fr he hu it nl pt zh`), then `flutter gen-l10n`; the generated `lib/l10n/arb/app_localizations*.dart` files are tracked and must be committed with the ARB edits.
- Stage explicit paths only (never `git add -A` or `git add -u`).
- Run `dart format .` before each commit. Never pipe `flutter test` or `flutter analyze` output through `grep`/`tail` when you need the exit status.
- Imports grouped dart, flutter, packages, local; files stay under 800 lines (the dive filter sheet is already 1257, so new UI goes in new files).
- Commits made while executing this approved plan are pre-authorized.

## Shared tooling: ARB key insertion script

Tasks 1, 6 and 8 add ARB keys. Create this script once in your scratchpad directory (not in the repo) as `add_arb_keys.py`. It inserts one-line entries immediately after an anchor key that exists in every locale file, adds `@` metadata to the English file only (matching neighbouring placeholder keys such as `diveLog_filter_sectionDepthRangeUnit`), refuses duplicates, and re-validates each file as JSON.

```python
#!/usr/bin/env python3.14
"""Insert ARB keys after an anchor key in all 11 locale files.

Usage (from the repo root): PYTHONUTF8=1 python3.14 add_arb_keys.py spec.json

spec.json:
{
  "anchor": "existing_key_present_in_every_file",
  "entries": {"new_key": {"ar": "...", "de": "...", "en": "...", ...}},
  "en_metadata": {"new_key": {"description": "...", "placeholders": {...}}}
}
"""
import json
import pathlib
import sys

LOCALES = ["ar", "de", "en", "es", "fr", "he", "hu", "it", "nl", "pt", "zh"]

spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for loc in LOCALES:
    path = pathlib.Path(f"lib/l10n/arb/app_{loc}.arb")
    lines = path.read_text(encoding="utf-8").split("\n")
    anchor = f'  "{spec["anchor"]}":'
    idx = next(i for i, line in enumerate(lines) if line.startswith(anchor))
    # Anchors are one-line entries in the middle of the file.
    assert lines[idx].rstrip().endswith(","), (loc, lines[idx])
    new = []
    for key, values in spec["entries"].items():
        if any(line.startswith(f'  "{key}":') for line in lines):
            raise SystemExit(f"{key} already present in {path}")
        new.append(f'  "{key}": {json.dumps(values[loc], ensure_ascii=False)},')
        meta = spec.get("en_metadata", {}).get(key)
        if loc == "en" and meta is not None:
            body = json.dumps(meta, ensure_ascii=False, indent=2).replace("\n", "\n  ")
            new.append(f'  "@{key}": {body},')
    lines[idx + 1 : idx + 1] = new
    text = "\n".join(lines)
    json.loads(text)
    path.write_text(text, encoding="utf-8")
    print(f"{path}: +{len(new)} lines")
```

After running it, confirm the diff is additions only:

```bash
git diff --numstat -- lib/l10n/arb
```

Expected: each `app_*.arb` shows N added and 0 removed.

---

### Task 1: Hose type catalog field

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (EquipmentAttrKeys around line 54; hose entry around line 333)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (both switches)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, regenerated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart`
- Test: `test/features/equipment/domain/equipment_type_assembly_parts_test.dart:71-88`

**Interfaces:**
- Produces: `EquipmentAttrKeys.hoseType == 'hose_type'`; catalog def `hose_type` (choice, spec group, `choiceKeys: ['lp', 'hp', 'lpi']`) on `EquipmentType.hose`, listed before `hose_length_m`; l10n getters `attrLabel_hose_type`, `attrChoice_hose_type_lp`, `attrChoice_hose_type_hp`, `attrChoice_hose_type_lpi`.

- [ ] **Step 1: Write the failing tests**

Append this group inside `main()` of `test/features/equipment/domain/equipment_attribute_catalog_test.dart` (its imports already cover `AppLocalizations`, `attributeLabel`, `Locale`):

```dart
  group('hose attributes (#1805)', () {
    test('hose_type is a spec choice of lp, hp and lpi, before the length', () {
      final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.hoseType);
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.choice);
      expect(def.group, AttributeGroup.spec);
      // The picker renders choiceKeys in this order.
      expect(def.choiceKeys, ['lp', 'hp', 'lpi']);

      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.hose,
      ).map((d) => d.key).toList();
      expect(keys.indexOf('hose_type'), lessThan(keys.indexOf('hose_length_m')));
    });

    test('hose type label and options read in English', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(attributeLabel(l10n, 'hose_type'), 'Hose type');
      expect(attributeChoiceLabel(l10n, 'hose_type', 'lp'), 'LP (low pressure)');
      expect(attributeChoiceLabel(l10n, 'hose_type', 'hp'), 'HP (high pressure)');
      expect(attributeChoiceLabel(l10n, 'hose_type', 'lpi'), 'LPI (inflator)');
    });
  });
```

In `test/features/equipment/domain/equipment_type_assembly_parts_test.dart`, replace

```dart
    expect(keysFor(EquipmentType.hose), contains('hose_length_m'));
```

with

```dart
    expect(
      keysFor(EquipmentType.hose),
      containsAll(['hose_type', 'hose_length_m']),
    );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/domain/equipment_type_assembly_parts_test.dart`
Expected: FAIL, compile error `The getter 'hoseType' isn't defined for the type 'EquipmentAttrKeys'`.

- [ ] **Step 3: Add the key and the catalog entry**

In `EquipmentAttrKeys`, after `static const fillMaterial = 'fill_material';` add:

```dart

  // Hose kind (issue #1805): LP regulator, HP gauge/transmitter, LPI inflator.
  static const hoseType = 'hose_type';
```

Replace the hose entry of `_byType`:

```dart
    EquipmentType.hose: [
      // LP (low pressure, a regulator hose), HP (high pressure, to an SPG or
      // transmitter) or LPI (the quick-disconnect inflator hose), issue
      // #1805. A choice so the equipment and dive filters can match on it.
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.hoseType,
        kind: AttributeKind.choice,
        choiceKeys: ['lp', 'hp', 'lpi'],
      ),
      // Stored in metres and shown in the diver's length unit through the
      // existing lengthM dimension, like an SMB or a reel line.
      EquipmentAttributeDef(
        key: 'hose_length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
```

- [ ] **Step 4: Add the ARB keys**

Write `hose_type_spec_a.json` in your scratchpad:

```json
{
  "anchor": "attrLabel_hose_length_m",
  "entries": {
    "attrLabel_hose_type": {
      "ar": "نوع الخرطوم", "de": "Schlauchtyp", "en": "Hose type",
      "es": "Tipo de latiguillo", "fr": "Type de flexible", "he": "סוג צינור",
      "hu": "Tömlő típusa", "it": "Tipo di frusta", "nl": "Slangtype",
      "pt": "Tipo de mangueira", "zh": "软管类型"
    }
  }
}
```

Write `hose_type_spec_b.json`:

```json
{
  "anchor": "attrChoice_connection_yoke",
  "entries": {
    "attrChoice_hose_type_lp": {
      "ar": "LP (ضغط منخفض)", "de": "MD (Mitteldruck)", "en": "LP (low pressure)",
      "es": "LP (baja presión)", "fr": "MP (moyenne pression)", "he": "LP (לחץ נמוך)",
      "hu": "Középnyomású (LP)", "it": "MP (media pressione)", "nl": "MD (middendruk)",
      "pt": "LP (baixa pressão)", "zh": "LP（低压）"
    },
    "attrChoice_hose_type_hp": {
      "ar": "HP (ضغط عالٍ)", "de": "HD (Hochdruck)", "en": "HP (high pressure)",
      "es": "HP (alta presión)", "fr": "HP (haute pression)", "he": "HP (לחץ גבוה)",
      "hu": "Nagynyomású (HP)", "it": "HP (alta pressione)", "nl": "HD (hoge druk)",
      "pt": "HP (alta pressão)", "zh": "HP（高压）"
    },
    "attrChoice_hose_type_lpi": {
      "ar": "منفاخ (LPI)", "de": "Inflator (LPI)", "en": "LPI (inflator)",
      "es": "Inflador (LPI)", "fr": "Direct system (LPI)", "he": "מנפח (LPI)",
      "hu": "Inflátor (LPI)", "it": "Frusta inflator (LPI)", "nl": "Inflatorslang (LPI)",
      "pt": "Inflador (LPI)", "zh": "充气管（LPI）"
    }
  }
}
```

Run from the repo root:

```bash
PYTHONUTF8=1 python3.14 <scratchpad>/add_arb_keys.py <scratchpad>/hose_type_spec_a.json
```

```bash
PYTHONUTF8=1 python3.14 <scratchpad>/add_arb_keys.py <scratchpad>/hose_type_spec_b.json
```

Expected: 11 files `+1 lines`, then 11 files `+3 lines`. Then:

```bash
flutter gen-l10n
```

- [ ] **Step 5: Resolve the labels**

In `attributeLabel`, after `'hose_length_m' => l10n.attrLabel_hose_length_m,` add:

```dart
  'hose_type' => l10n.attrLabel_hose_type,
```

In `attributeChoiceLabel`, before the final `_ => option,` add:

```dart
  'hose_type_lp' => l10n.attrChoice_hose_type_lp,
  'hose_type_hp' => l10n.attrChoice_hose_type_hp,
  'hose_type_lpi' => l10n.attrChoice_hose_type_lpi,
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/domain/equipment_type_assembly_parts_test.dart test/features/equipment/presentation/equipment_attribute_l10n_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS (the l10n completeness and parity tests cover the new keys in every locale).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart lib/l10n/arb/ test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/domain/equipment_type_assembly_parts_test.dart
git commit -m "feat(equipment): hose type field, LP / HP / LPI (#1805)"
```

---

### Task 2: EquipmentAttrCondition value types

**Files:**
- Create: `lib/features/equipment/domain/models/equipment_attr_condition.dart`
- Test: `test/features/equipment/domain/models/equipment_attr_condition_test.dart`

**Interfaces:**
- Produces:
  - `class EquipmentAttrCondition { const EquipmentAttrCondition({required String key, Set<String> choices = const {}, double? min, double? max, Set<EquipmentType> types = const {}}); factory EquipmentAttrCondition.suitThickness({double? min, double? max}); static const Set<EquipmentType> suitTypes; bool get isSuitThickness; bool matches(EquipmentItem item); }` with value equality (sets compared as sets).
  - `class EquipmentAttrConditionsKey { const EquipmentAttrConditionsKey(List<EquipmentAttrCondition> conditions); final List<EquipmentAttrCondition> conditions; }` with element-wise `==` / `hashCode`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/models/equipment_attr_condition_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

EquipmentItem _item(
  String id,
  EquipmentType type, {
  String? key,
  String? text,
  double? num,
  bool custom = false,
}) => EquipmentItem(
  id: id,
  name: id,
  type: type,
  attributes: [
    if (key != null)
      custom
          ? EquipmentAttribute(
              id: 'c-$id',
              equipmentId: id,
              key: key,
              isCustom: true,
              valueText: text,
              valueNum: num,
            )
          : EquipmentAttribute.curated(
              equipmentId: id,
              key: key,
              valueText: text,
              valueNum: num,
            ),
  ],
);

void main() {
  group('EquipmentAttrCondition.matches', () {
    const hp = EquipmentAttrCondition(
      key: 'hose_type',
      choices: {'hp'},
      types: {EquipmentType.hose},
    );

    test('matches the chosen value on the right type', () {
      expect(hp.matches(_item('h', EquipmentType.hose, key: 'hose_type', text: 'hp')), isTrue);
      expect(hp.matches(_item('h', EquipmentType.hose, key: 'hose_type', text: 'lp')), isFalse);
    });

    test('a non-empty types set rejects other types', () {
      expect(hp.matches(_item('r', EquipmentType.regulator, key: 'hose_type', text: 'hp')), isFalse);
    });

    test('choices are ORed', () {
      const either = EquipmentAttrCondition(key: 'hose_type', choices: {'hp', 'lpi'});
      expect(either.matches(_item('a', EquipmentType.hose, key: 'hose_type', text: 'lpi')), isTrue);
      expect(either.matches(_item('b', EquipmentType.hose, key: 'hose_type', text: 'lp')), isFalse);
    });

    test('min and max bound the number; a missing number fails a bound', () {
      final c = EquipmentAttrCondition.suitThickness(min: 4, max: 6);
      expect(c.matches(_item('s', EquipmentType.wetsuit, key: 'thickness_mm', num: 5)), isTrue);
      expect(c.matches(_item('s', EquipmentType.wetsuit, key: 'thickness_mm', num: 7)), isFalse);
      expect(c.matches(_item('s', EquipmentType.wetsuit, key: 'thickness_mm', text: 'thin')), isFalse);
    });

    test('suit thickness never matches a hood', () {
      final c = EquipmentAttrCondition.suitThickness(min: 1);
      expect(c.matches(_item('h', EquipmentType.hood, key: 'thickness_mm', num: 5)), isFalse);
      expect(c.matches(_item('d', EquipmentType.drysuit, key: 'thickness_mm', num: 5)), isTrue);
    });

    test('a key-only condition means "has this attribute"', () {
      const c = EquipmentAttrCondition(key: 'hose_type');
      expect(c.matches(_item('h', EquipmentType.hose, key: 'hose_type', text: 'lp')), isTrue);
      expect(c.matches(_item('h', EquipmentType.hose)), isFalse);
    });

    test('custom fields never match, even with the same key', () {
      const c = EquipmentAttrCondition(key: 'hose_type', choices: {'hp'});
      expect(
        c.matches(_item('h', EquipmentType.hose, key: 'hose_type', text: 'hp', custom: true)),
        isFalse,
      );
    });
  });

  group('equality', () {
    test('conditions compare by value, sets as sets', () {
      const a = EquipmentAttrCondition(key: 'k', choices: {'x', 'y'}, types: {EquipmentType.hose});
      final b = EquipmentAttrCondition(key: 'k', choices: {'y', 'x'}, types: {EquipmentType.hose});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const EquipmentAttrCondition(key: 'k', choices: {'x'})));
    });

    test('isSuitThickness recognises only the suit condition', () {
      expect(EquipmentAttrCondition.suitThickness(min: 3).isSuitThickness, isTrue);
      expect(const EquipmentAttrCondition(key: 'thickness_mm').isSuitThickness, isFalse);
    });

    test('the list key compares element by element', () {
      final one = EquipmentAttrConditionsKey([EquipmentAttrCondition.suitThickness(min: 3)]);
      final two = EquipmentAttrConditionsKey([EquipmentAttrCondition.suitThickness(min: 3)]);
      expect(one, two);
      expect(one.hashCode, two.hashCode);
      expect(one, isNot(EquipmentAttrConditionsKey([EquipmentAttrCondition.suitThickness(min: 4)])));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/models/equipment_attr_condition_test.dart`
Expected: FAIL, `Error when reading 'lib/features/equipment/domain/models/equipment_attr_condition.dart': No such file`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/equipment/domain/models/equipment_attr_condition.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One condition on a curated equipment attribute (issue #1805).
///
/// Shared by the dive list filter, which evaluates it in SQL through
/// `equipmentAttrConditionSql`, and the equipment list filter, which
/// evaluates it in memory through [matches]. Both follow the same rules:
///
/// - Only curated rows with [key] count; custom fields never match.
/// - A non-empty [types] requires the item's type to be one of them.
/// - A non-empty [choices] requires `value_text` to be one of them (OR).
/// - [min] and [max] bound `value_num` in canonical metric; a row with no
///   number fails a set bound.
/// - A condition with only a key means "has this attribute".
@immutable
class EquipmentAttrCondition {
  final String key;
  final Set<String> choices;
  final double? min;
  final double? max;
  final Set<EquipmentType> types;

  const EquipmentAttrCondition({
    required this.key,
    this.choices = const {},
    this.min,
    this.max,
    this.types = const {},
  });

  /// The exposure suits the Suit thickness filter covers. Hoods, gloves and
  /// boots carry `thickness_mm` too, but are not suits.
  static const Set<EquipmentType> suitTypes = {
    EquipmentType.wetsuit,
    EquipmentType.drysuit,
  };

  /// The dive filter's Suit thickness condition.
  factory EquipmentAttrCondition.suitThickness({double? min, double? max}) =>
      EquipmentAttrCondition(
        key: EquipmentAttrKeys.thicknessMm,
        min: min,
        max: max,
        types: suitTypes,
      );

  /// Whether this is the condition [EquipmentAttrCondition.suitThickness]
  /// builds, so the dive filter sheet can show it in its own section.
  bool get isSuitThickness =>
      key == EquipmentAttrKeys.thicknessMm &&
      choices.isEmpty &&
      setEquals(types, suitTypes);

  bool matches(EquipmentItem item) {
    if (types.isNotEmpty && !types.contains(item.type)) return false;
    final lo = min;
    final hi = max;
    return item.attributes.any((attr) {
      if (attr.isCustom || attr.key != key) return false;
      if (choices.isNotEmpty && !choices.contains(attr.valueText)) {
        return false;
      }
      final value = attr.valueNum;
      if (lo != null && (value == null || value < lo)) return false;
      if (hi != null && (value == null || value > hi)) return false;
      return true;
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentAttrCondition &&
          other.key == key &&
          setEquals(other.choices, choices) &&
          other.min == min &&
          other.max == max &&
          setEquals(other.types, types);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAllUnordered(choices),
    min,
    max,
    Object.hashAllUnordered(types),
  );

  @override
  String toString() =>
      'EquipmentAttrCondition(key: $key, choices: $choices, min: $min, '
      'max: $max, types: $types)';
}

/// A value-equal wrapper around a condition list, for use as a provider
/// family key.
///
/// A Dart `List`, and a record holding one, compares by identity, so a
/// family keyed on the list itself would treat an equal condition set as a
/// new key and never reuse its cached result.
@immutable
class EquipmentAttrConditionsKey {
  final List<EquipmentAttrCondition> conditions;

  const EquipmentAttrConditionsKey(this.conditions);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentAttrConditionsKey &&
          listEquals(other.conditions, conditions);

  @override
  int get hashCode => Object.hashAll(conditions);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/models/equipment_attr_condition_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/equipment/domain/models/equipment_attr_condition.dart test/features/equipment/domain/models/equipment_attr_condition_test.dart
git commit -m "feat(equipment): shared equipment attribute condition model (#1805)"
```

---

### Task 3: The shared SQL builder

**Files:**
- Modify: `lib/features/statistics/data/dive_filter_sql.dart` (add a top-level function after `buildFilteredDiveIdSubquery`, before `decoSignalCondition`'s doc comment)
- Test: `test/features/statistics/data/equipment_attr_condition_sql_test.dart` (create)

**Interfaces:**
- Consumes: `EquipmentAttrCondition` (Task 2).
- Produces: `({String sql, List<Object> params}) equipmentAttrConditionSql(EquipmentAttrCondition condition, {required String diveIdRef})`. Params order: sorted type names, then the key, then sorted choices, then min, then max.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/data/equipment_attr_condition_sql_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertItem(
    String id,
    EquipmentType type, {
    String? key,
    String? text,
    double? num,
    bool custom = false,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value(id),
            type: Value(type.name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (key == null) return;
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_$key'),
            equipmentId: Value(id),
            attrKey: Value(key),
            isCustom: Value(custom),
            valueText: Value(text),
            valueNum: Value(num),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkGear(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion(
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  // A cylinder matched by the transmitter registry: linked through
  // dive_tanks.equipment_id only, never through dive_equipment.
  Future<void> linkTank(String diveId, String equipmentId) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('tank-$diveId'),
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  Future<Set<String>> idsMatching(List<EquipmentAttrCondition> conditions) async {
    final parts = [
      for (final c in conditions) equipmentAttrConditionSql(c, diveIdRef: 'dives.id'),
    ];
    final rows = await db
        .customSelect(
          'SELECT id FROM dives WHERE ${parts.map((p) => p.sql).join(' AND ')}',
          variables: [
            for (final p in parts) ...p.params.map((v) => Variable<Object>(v)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  const hp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('binds every value in placeholder order', () {
    final result = equipmentAttrConditionSql(
      const EquipmentAttrCondition(
        key: 'k',
        choices: {'b', 'a'},
        min: 1,
        max: 2,
        types: {EquipmentType.hose, EquipmentType.bcd},
      ),
      diveIdRef: 'd.id',
    );
    expect(result.params, ['bcd', 'hose', 'k', 'a', 'b', 1.0, 2.0]);
    expect(result.sql, contains('de.dive_id = d.id'));
    expect(result.sql, contains('dt.dive_id = d.id'));
    expect(result.sql, isNot(contains("'hose'")));
  });

  test('a choice matches gear linked through dive_equipment', () async {
    for (final d in ['d1', 'd2', 'd3']) {
      await insertDive(d);
    }
    await insertItem('hpHose', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('lpHose', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await linkGear('d1', 'hpHose');
    await linkGear('d2', 'lpHose');
    expect(await idsMatching([hp]), {'d1'});
  });

  test('choices are ORed', () async {
    for (final d in ['d1', 'd2', 'd3']) {
      await insertDive(d);
    }
    await insertItem('a', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('b', EquipmentType.hose, key: 'hose_type', text: 'lpi');
    await insertItem('c', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await linkGear('d1', 'a');
    await linkGear('d2', 'b');
    await linkGear('d3', 'c');
    expect(
      await idsMatching([
        const EquipmentAttrCondition(key: 'hose_type', choices: {'hp', 'lpi'}),
      ]),
      {'d1', 'd2'},
    );
  });

  test('a registry-linked cylinder matches through dive_tanks', () async {
    await insertDive('steel');
    await insertDive('alu');
    await insertItem('t1', EquipmentType.tank, key: 'tank_material', text: 'steel');
    await insertItem('t2', EquipmentType.tank, key: 'tank_material', text: 'aluminum');
    await linkTank('steel', 't1');
    await linkTank('alu', 't2');
    expect(
      await idsMatching([
        const EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ]),
      {'steel'},
    );
  });

  test('suit thickness skips hoods and rows with no number', () async {
    for (final d in ['suit', 'hood', 'legacy']) {
      await insertDive(d);
    }
    await insertItem('w', EquipmentType.wetsuit, key: 'thickness_mm', num: 5);
    await insertItem('h', EquipmentType.hood, key: 'thickness_mm', num: 5);
    await insertItem('l', EquipmentType.wetsuit, key: 'thickness_mm', text: 'thin');
    await linkGear('suit', 'w');
    await linkGear('hood', 'h');
    await linkGear('legacy', 'l');
    expect(
      await idsMatching([EquipmentAttrCondition.suitThickness(min: 4, max: 6)]),
      {'suit'},
    );
  });

  test('custom rows never match', () async {
    await insertDive('d1');
    await insertItem('h', EquipmentType.hose, key: 'hose_type', text: 'hp', custom: true);
    await linkGear('d1', 'h');
    expect(await idsMatching([hp]), isEmpty);
  });

  test('a key-only condition means "has this attribute"', () async {
    await insertDive('d1');
    await insertDive('d2');
    await insertItem('h', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await insertItem('g', EquipmentType.hose);
    await linkGear('d1', 'h');
    await linkGear('d2', 'g');
    expect(await idsMatching([const EquipmentAttrCondition(key: 'hose_type')]), {'d1'});
  });

  test('two conditions AND together', () async {
    await insertDive('both');
    await insertDive('hoseOnly');
    await insertItem('h1', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('h2', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('w', EquipmentType.wetsuit, key: 'thickness_mm', num: 7);
    await linkGear('both', 'h1');
    await linkGear('both', 'w');
    await linkGear('hoseOnly', 'h2');
    expect(
      await idsMatching([hp, EquipmentAttrCondition.suitThickness(min: 5)]),
      {'both'},
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/equipment_attr_condition_sql_test.dart`
Expected: FAIL, compile error `Method not found: 'equipmentAttrConditionSql'`.

- [ ] **Step 3: Write the builder**

In `lib/features/statistics/data/dive_filter_sql.dart` add the import:

```dart
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
```

and, directly above the doc comment that starts `/// Recorded deco-signal SQL condition`, add:

```dart
/// SQL for one [EquipmentAttrCondition] (issue #1805): a correlated EXISTS
/// over the dive's gear. The gear is every item linked through
/// `dive_equipment` plus every cylinder the transmitter registry matched
/// through `dive_tanks.equipment_id`, the same union the equipment-id axis
/// uses. [diveIdRef] names the outer dive id column (`dives.id` in
/// [buildFilteredDiveIdSubquery], `d.id` in DiveRepository).
///
/// Every value is bound; [params] follow the placeholders in order: the
/// sorted type names, the key, the sorted choices, then min and max.
///
/// This is the only implementation of the dive filter's attribute axis. It
/// is shared by [buildFilteredDiveIdSubquery],
/// `DiveRepository._buildFilterWhereClauses` and
/// `DiveRepository.getDiveIdsMatchingEquipmentAttrs`, so Statistics, the
/// paginated list and the entity-backed views cannot disagree.
({String sql, List<Object> params}) equipmentAttrConditionSql(
  EquipmentAttrCondition condition, {
  required String diveIdRef,
}) {
  final params = <Object>[];
  final sql = StringBuffer('EXISTS (SELECT 1 FROM equipment_attributes ea ');
  if (condition.types.isNotEmpty) {
    final types = condition.types.map((t) => t.name).toList()..sort();
    sql.write(
      'JOIN equipment eqf ON eqf.id = ea.equipment_id '
      'AND eqf.type IN (${List.filled(types.length, '?').join(', ')}) ',
    );
    params.addAll(types);
  }
  sql.write('WHERE ea.attr_key = ? AND ea.is_custom = 0');
  params.add(condition.key);
  if (condition.choices.isNotEmpty) {
    final choices = condition.choices.toList()..sort();
    sql.write(
      ' AND ea.value_text IN (${List.filled(choices.length, '?').join(', ')})',
    );
    params.addAll(choices);
  }
  final min = condition.min;
  if (min != null) {
    sql.write(' AND ea.value_num >= ?');
    params.add(min);
  }
  final max = condition.max;
  if (max != null) {
    sql.write(' AND ea.value_num <= ?');
    params.add(max);
  }
  sql.write(
    ' AND ea.equipment_id IN ('
    'SELECT de.equipment_id FROM dive_equipment de '
    'WHERE de.dive_id = $diveIdRef '
    'UNION SELECT dt.equipment_id FROM dive_tanks dt '
    'WHERE dt.dive_id = $diveIdRef AND dt.equipment_id IS NOT NULL))',
  );
  return (sql: sql.toString(), params: params);
}
```

The gear union is a correlated `IN` subquery in the WHERE clause, not a derived table in FROM, because SQLite resolves outer references reliably there.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/equipment_attr_condition_sql_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/statistics/data/dive_filter_sql.dart test/features/statistics/data/equipment_attr_condition_sql_test.dart
git commit -m "feat(stats): one SQL builder for equipment attribute conditions (#1805)"
```

---

### Task 4: The dive filter holds a condition list; Statistics and the paginated list use the builder

This task fixes the existing bug where the paginated dive list and its count ignore the attribute filter. Step 1 proves the bug with the current API before anything changes.

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (fields 85-90, constructor 119-122, `hasActiveFilters` 174, `copyWith` 203-206 / 233 / 284-295, `apply` 449-480)
- Modify: `lib/features/statistics/data/dive_filter_sql.dart:91-124`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_buildFilterWhereClauses`, after the `filter.equipmentIds` block)
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart:123-126` and `:1249-1253`
- Test: `test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart` (create)
- Test: `test/features/statistics/data/dive_filter_sql_attribute_test.dart` (rewrite)
- Test: `test/features/dive_log/domain/models/dive_filter_state_test.dart:856-1027` (replace group)
- Test: `test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart:368-487` (migrate)

**Interfaces:**
- Consumes: `EquipmentAttrCondition`, `EquipmentAttrCondition.suitThickness`, `isSuitThickness` (Task 2); `equipmentAttrConditionSql` (Task 3).
- Produces: `DiveFilterState.equipmentAttrConditions` (`List<EquipmentAttrCondition>`, default `const []`); `copyWith({List<EquipmentAttrCondition>? equipmentAttrConditions, bool clearEquipmentAttrConditions = false})`. The fields `equipmentAttrKey`, `equipmentAttrChoice`, `equipmentAttrMin`, `equipmentAttrMax` and the flag `clearEquipmentAttr` are removed.

- [ ] **Step 1: Write the failing list test against the CURRENT API**

Create `test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertItem(
    String id,
    EquipmentType type, {
    required String key,
    String? text,
    double? num,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value(id),
            type: Value(type.name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_$key'),
            equipmentId: Value(id),
            attrKey: Value(key),
            valueText: Value(text),
            valueNum: Value(num),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkGear(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion(
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  Future<void> linkTank(String diveId, String equipmentId) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('tank-$diveId'),
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  Future<Set<String>> listIds(DiveFilterState filter) async =>
      (await repo.getDiveSummaries(filter: filter)).map((s) => s.id).toSet();

  /// Three dives: a 7 mm suit, a 3 mm suit, and bare.
  Future<void> seedSuits() async {
    for (final d in ['suit7', 'suit3', 'bare']) {
      await insertDive(d);
    }
    await insertItem('w7', EquipmentType.wetsuit, key: 'thickness_mm', num: 7);
    await insertItem('w3', EquipmentType.wetsuit, key: 'thickness_mm', num: 3);
    await linkGear('suit7', 'w7');
    await linkGear('suit3', 'w3');
  }

  test('the paginated list and its count apply the suit thickness filter', () async {
    await seedSuits();
    const filter = DiveFilterState(
      equipmentAttrKey: 'thickness_mm',
      equipmentAttrMin: 5.0,
    );
    expect(await listIds(filter), {'suit7'});
    expect(await repo.getDiveCount(filter: filter), 1);
  });
}
```

- [ ] **Step 2: Run it to see the bug**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart`
Expected: FAIL with `Expected: Set:['suit7'] Actual: Set:['suit7', 'suit3', 'bare']` (the list ignores the axis). Keep a note of this output for the PR description.

- [ ] **Step 3: Replace the single slot with a condition list in `DiveFilterState`**

In `lib/features/dive_log/domain/models/dive_filter_state.dart`:

Add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';` and remove the imports of `enums.dart` and `equipment_attribute_catalog.dart` only if `flutter analyze` later reports them unused.

Replace the field block:

```dart
  // Equipment-attribute axis (curated keys only). key selects the attribute;
  // choice matches value_text; min/max bound value_num (canonical metric).
  final String? equipmentAttrKey;
  final String? equipmentAttrChoice;
  final double? equipmentAttrMin;
  final double? equipmentAttrMax;
```

with:

```dart
  /// Equipment-attribute conditions (curated keys only, issue #1805),
  /// combined with AND. A dive satisfies one when any item linked to it
  /// matches, directly or through a cylinder the transmitter registry
  /// matched. Suit thickness is one of them
  /// ([EquipmentAttrCondition.suitThickness]).
  final List<EquipmentAttrCondition> equipmentAttrConditions;
```

In the constructor replace the four `this.equipmentAttr...` lines with `this.equipmentAttrConditions = const [],`.

In `hasActiveFilters` replace `equipmentAttrKey != null;` with `equipmentAttrConditions.isNotEmpty;`.

In `copyWith`, replace the four `equipmentAttr...` parameters with `List<EquipmentAttrCondition>? equipmentAttrConditions,`, replace `bool clearEquipmentAttr = false,` with `bool clearEquipmentAttrConditions = false,`, and replace the four `equipmentAttr...:` assignments in the returned state with:

```dart
      equipmentAttrConditions: clearEquipmentAttrConditions
          ? const []
          : (equipmentAttrConditions ?? this.equipmentAttrConditions),
```

In `apply`, replace the whole block from `// Equipment-attribute axis: mirror the SQL subquery` through its closing `if (!matches) return false;\n      }` with:

```dart
      // Equipment-attribute conditions over the dive's hydrated gear.
      if (equipmentAttrConditions.isNotEmpty &&
          !equipmentAttrConditions.every(
            (condition) => dive.equipment.any(condition.matches),
          )) {
        return false;
      }
```

(Task 5 moves this axis to SQL for the entity views; this keeps them working until then.)

- [ ] **Step 4: Statistics uses the builder**

In `lib/features/statistics/data/dive_filter_sql.dart`, replace the block from `// Equipment attribute: dives linked to an equipment item whose curated` through `conditions.add(sub.toString());\n  }` with:

```dart
  // Equipment attributes: one EXISTS per condition, so they AND.
  for (final condition in filter.equipmentAttrConditions) {
    final c = equipmentAttrConditionSql(condition, diveIdRef: 'dives.id');
    conditions.add(c.sql);
    params.addAll(c.params);
  }
```

Remove the `equipment_attribute_catalog.dart` import if it is now unused.

- [ ] **Step 5: The paginated list uses the builder (the bug fix)**

In `DiveRepository._buildFilterWhereClauses`, directly after the closing brace of the `if (filter.equipmentIds.isNotEmpty) { ... }` block, add:

```dart
    // Equipment attributes: the same EXISTS Statistics uses, one per
    // condition. Missing until #1805, so the list and its count ignored the
    // Suit thickness filter that the table view and Statistics applied.
    for (final condition in filter.equipmentAttrConditions) {
      final c = equipmentAttrConditionSql(condition, diveIdRef: 'd.id');
      clauses.add(c.sql);
      args.addAll(c.params.map((p) => Variable<Object>(p)));
    }
```

`dive_filter_sql.dart` is already imported by this file.

- [ ] **Step 6: The sheet reads and writes the suit condition**

In `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';`. Replace:

```dart
    if (filter.equipmentAttrKey == 'thickness_mm') {
      _suitThicknessMin = filter.equipmentAttrMin;
      _suitThicknessMax = filter.equipmentAttrMax;
    }
```

with:

```dart
    for (final condition in filter.equipmentAttrConditions) {
      if (condition.isSuitThickness) {
        _suitThicknessMin = condition.min;
        _suitThicknessMax = condition.max;
      }
    }
```

and in `_applyFilters` replace the three `equipmentAttrKey` / `equipmentAttrMin` / `equipmentAttrMax` arguments with:

```dart
      equipmentAttrConditions: [
        if (_suitThicknessMin != null || _suitThicknessMax != null)
          EquipmentAttrCondition.suitThickness(
            min: _suitThicknessMin,
            max: _suitThicknessMax,
          ),
      ],
```

- [ ] **Step 7: Move the tests to the new API**

In the new repository test, change the filter to the new API and add the hose and tank cases:

```dart
  test('the paginated list and its count apply the suit thickness filter', () async {
    await seedSuits();
    final filter = DiveFilterState(
      equipmentAttrConditions: [EquipmentAttrCondition.suitThickness(min: 5.0)],
    );
    expect(await listIds(filter), {'suit7'});
    expect(await repo.getDiveCount(filter: filter), 1);
  });

  test('the paginated list filters by hose type', () async {
    await insertDive('hp');
    await insertDive('lp');
    await insertItem('h1', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('h2', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await linkGear('hp', 'h1');
    await linkGear('lp', 'h2');
    const filter = DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
    );
    expect(await listIds(filter), {'hp'});
    expect(await repo.getDiveCount(filter: filter), 1);
  });

  test('the paginated list matches a registry-linked cylinder', () async {
    await insertDive('steel');
    await insertDive('alu');
    await insertItem('t1', EquipmentType.tank, key: 'tank_material', text: 'steel');
    await insertItem('t2', EquipmentType.tank, key: 'tank_material', text: 'aluminum');
    await linkTank('steel', 't1');
    await linkTank('alu', 't2');
    const filter = DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    );
    expect(await listIds(filter), {'steel'});
  });
```

and add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';`.

Rewrite `test/features/statistics/data/dive_filter_sql_attribute_test.dart` as:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  const hose = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('each condition becomes the shared EXISTS clause, in order', () {
    final suit = EquipmentAttrCondition.suitThickness(min: 5.0, max: 7.0);
    final result = buildFilteredDiveIdSubquery(
      DiveFilterState(equipmentAttrConditions: [hose, suit]),
    );
    final hoseSql = equipmentAttrConditionSql(hose, diveIdRef: 'dives.id');
    final suitSql = equipmentAttrConditionSql(suit, diveIdRef: 'dives.id');
    expect(result.subquery, contains(hoseSql.sql));
    expect(result.subquery, contains(suitSql.sql));
    expect(result.params, [...hoseSql.params, ...suitSql.params]);
  });

  test('no conditions, no attribute SQL', () {
    final result = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(result.subquery, isNot(contains('equipment_attributes')));
  });

  test('hasActiveFilters reflects the conditions', () {
    expect(
      const DiveFilterState(equipmentAttrConditions: [hose]).hasActiveFilters,
      isTrue,
    );
    expect(const DiveFilterState().hasActiveFilters, isFalse);
  });

  test('copyWith sets and clears the conditions', () {
    final set = const DiveFilterState().copyWith(equipmentAttrConditions: [hose]);
    expect(set.equipmentAttrConditions, [hose]);
    expect(
      set.copyWith(clearEquipmentAttrConditions: true).equipmentAttrConditions,
      isEmpty,
    );
  });
}
```

In `test/features/dive_log/domain/models/dive_filter_state_test.dart`, replace the whole `group('equipmentAttr axis', () { ... });` (lines 856-1027) with:

```dart
      group('equipment attribute conditions', () {
        EquipmentAttribute curated(String id, String key, {String? text, double? num}) =>
            EquipmentAttribute.curated(
              equipmentId: id,
              key: key,
              valueText: text,
              valueNum: num,
            );

        test('conditions AND together over the dive gear', () {
          final filter = DiveFilterState(
            equipmentAttrConditions: [
              const EquipmentAttrCondition(
                key: 'hose_type',
                choices: {'hp'},
                types: {EquipmentType.hose},
              ),
              EquipmentAttrCondition.suitThickness(min: 5),
            ],
          );
          final dives = [
            _makeDive(
              id: 'both',
              equipment: [
                _makeEquipment('h', type: EquipmentType.hose, attributes: [curated('h', 'hose_type', text: 'hp')]),
                _makeEquipment('w', attributes: [curated('w', 'thickness_mm', num: 7)]),
              ],
            ),
            _makeDive(
              id: 'hoseOnly',
              equipment: [
                _makeEquipment('h2', type: EquipmentType.hose, attributes: [curated('h2', 'hose_type', text: 'hp')]),
              ],
            ),
          ];
          expect(filter.apply(dives).map((d) => d.id), ['both']);
        });
      });
```

and add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';`. The matching rules themselves are covered by Task 2 and Task 3.

In `test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart` add the same import and migrate the four thickness tests:

- `'suit-thickness min/max write the equipment-attribute axis'`: replace the three `expect(applied.equipmentAttr...)` lines with
  ```dart
    expect(applied.equipmentAttrConditions, [
      EquipmentAttrCondition.suitThickness(min: 3, max: 7),
    ]);
  ```
- `'suit-thickness bounds hydrate from an existing filter'`: use `initial: DiveFilterState(equipmentAttrConditions: [EquipmentAttrCondition.suitThickness(min: 5, max: 5)])` (drop `const`), and replace the two final expects with `expect(applied.equipmentAttrConditions, [EquipmentAttrCondition.suitThickness(min: 5, max: 5)]);`
- `'suit-thickness bounds keep decimals and accept comma input'`: `initial: DiveFilterState(equipmentAttrConditions: [EquipmentAttrCondition.suitThickness(min: 2.5)])`; final expect `expect(applied.equipmentAttrConditions, [EquipmentAttrCondition.suitThickness(min: 2.5, max: 7.5)]);`
- `'a comma is read as thousands under a dot-decimal locale'`: `initial: const DiveFilterState()` (the old key-only initial state hydrated nothing); final expect `expect(ref.read(filterProvider).equipmentAttrConditions.single.max, 1250);`

- [ ] **Step 8: Run the affected tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart test/features/statistics/data/ test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS. Then `flutter analyze` must report no issues (fix any unused import it names).

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/models/dive_filter_state.dart lib/features/statistics/data/dive_filter_sql.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart test/features/statistics/data/dive_filter_sql_attribute_test.dart test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart
git commit -m "fix(dive-log): the dive list applies equipment attribute filters (#1805)"
```

---

### Task 5: SQL-resolved ids for the table and map views

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (new tick before the `/// Aggregate change-tick for the dive DETAIL page` doc comment; new method before the `/// Build SQL WHERE clauses from a [DiveFilterState].` doc comment)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (new provider after `decoFilteredDiveIdsProvider`; rewrite `filteredDivesProvider`)
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (`apply` doc and body)
- Test: `test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart` (create)
- Test: `test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart` (extend)
- Test: `test/features/dive_log/domain/models/dive_filter_state_test.dart` (replace Task 4's group)

**Interfaces:**
- Consumes: `equipmentAttrConditionSql` (Task 3), `EquipmentAttrConditionsKey` (Task 2), `DiveFilterState.equipmentAttrConditions` (Task 4).
- Produces: `Stream<void> DiveRepository.watchEquipmentAttrFilterChanges()`; `Future<Set<String>> DiveRepository.getDiveIdsMatchingEquipmentAttrs(List<EquipmentAttrCondition> conditions, {String? diverId})`; `equipmentAttrFilteredDiveIdsProvider` (`FutureProvider.family<Set<String>, EquipmentAttrConditionsKey>`).

- [ ] **Step 1: Write the failing provider test**

Create `test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveEquipmentCompanion,
        DiveTanksCompanion,
        EquipmentAttributesCompanion,
        EquipmentCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The table view and the maps read [filteredDivesProvider], whose dives come
/// from getAllDives. A cylinder matched through the transmitter registry
/// reaches those entities as a bare DiveTank.equipmentId, so the attribute
/// axis must be resolved in SQL to select the same dives as the paginated
/// list (#1805).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertItem(String id, EquipmentType type, String key, String text) async {
    await db.into(db.equipment).insert(
      EquipmentCompanion(
        id: Value(id),
        name: Value(id),
        type: Value(type.name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.into(db.equipmentAttributes).insert(
      EquipmentAttributesCompanion(
        id: Value('attr_${id}_$key'),
        equipmentId: Value(id),
        attrKey: Value(key),
        valueText: Value(text),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final diveRepo = DiveRepository();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);

    for (final (id, day) in [('hpDive', 1), ('lpDive', 2), ('steelDive', 3), ('bare', 4)]) {
      await diveRepo.createDive(
        Dive(id: id, diverId: diver.id, dateTime: DateTime(2026, 1, day)),
      );
    }
    await insertItem('hpHose', EquipmentType.hose, 'hose_type', 'hp');
    await insertItem('lpHose', EquipmentType.hose, 'hose_type', 'lp');
    await insertItem('steelTank', EquipmentType.tank, 'tank_material', 'steel');
    await db.into(db.diveEquipment).insert(
      const DiveEquipmentCompanion(diveId: Value('hpDive'), equipmentId: Value('hpHose')),
    );
    await db.into(db.diveEquipment).insert(
      const DiveEquipmentCompanion(diveId: Value('lpDive'), equipmentId: Value('lpHose')),
    );
    // Linked only through the registry, never through dive_equipment.
    await db.into(db.diveTanks).insert(
      const DiveTanksCompanion(
        id: Value('tank-steel'),
        diveId: Value('steelDive'),
        equipmentId: Value('steelTank'),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  Future<Set<String>> filteredIds(ProviderContainer container) async {
    for (var i = 0; i < 100; i++) {
      final value = container.read(filteredDivesProvider);
      if (value.hasValue) return value.value!.map((d) => d.id).toSet();
      if (value.hasError) fail('filteredDivesProvider failed: ${value.error}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('filteredDivesProvider never produced a value');
  }

  Future<ProviderContainer> settled() async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    await filteredIds(container);
    return container;
  }

  const hp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('a registry-linked cylinder matches in the entity views', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    );
    expect(await filteredIds(container), {'steelDive'});
  });

  test('hose type narrows the entity views', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [hp],
    );
    expect(await filteredIds(container), {'hpDive'});
  });

  test('a changed condition set does not reuse the previous ids', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [hp],
    );
    expect(await filteredIds(container), {'hpDive'});
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(key: 'hose_type', choices: {'lp'}),
      ],
    );
    expect(await filteredIds(container), {'lpDive'});
  });

  test('the conditions combine with the in-memory axes', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      equipmentAttrConditions: const [
        EquipmentAttrCondition(key: 'hose_type'),
      ],
      startDate: DateTime(2026, 1, 2),
    );
    expect(await filteredIds(container), {'lpDive'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart`
Expected: the registry-linked cylinder test FAILS (`Expected: Set:['steelDive'] Actual: Set:[]`), because `apply` only looks at `dive.equipment`. The other three pass.

- [ ] **Step 3: Add the tick and the id query to `DiveRepository`**

Add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';`.

Directly above the doc comment `/// Aggregate change-tick for the dive DETAIL page`, add:

```dart
  /// Change tick for [getDiveIdsMatchingEquipmentAttrs]: the dives, both
  /// gear links, the items (their type) and their attribute rows.
  /// `saveAttributes` and a sync pull write only `equipment_attributes`,
  /// which no other dive tick watches.
  Stream<void> watchEquipmentAttrFilterChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.equipmentAttributes),
        ]),
      )
      .debounce(changeTickDebounce);

```

Directly above the doc comment `/// Build SQL WHERE clauses from a [DiveFilterState].`, add:

```dart
  /// The ids of every dive satisfying all of [conditions], through the same
  /// [equipmentAttrConditionSql] the paginated list uses.
  ///
  /// The in-memory filter path ([DiveFilterState.apply]) cannot answer this:
  /// a cylinder matched only through the transmitter registry reaches the
  /// entity as a bare `DiveTank.equipmentId`, without its item or its
  /// attributes. So the entity-backed surfaces (the table view, the activity
  /// and heat maps) resolve the axis here. Only called while a condition is
  /// set.
  // stats-scope-exempt: backs a view-filter axis; consumers apply the scope themselves
  Future<Set<String>> getDiveIdsMatchingEquipmentAttrs(
    List<EquipmentAttrCondition> conditions, {
    String? diverId,
  }) async {
    try {
      return await PerfTimer.measure(
        'getDiveIdsMatchingEquipmentAttrs',
        () async {
          final whereClauses = <String>[];
          final args = <Variable<Object>>[];
          for (final condition in conditions) {
            final c = equipmentAttrConditionSql(condition, diveIdRef: 'd.id');
            whereClauses.add(c.sql);
            args.addAll(c.params.map((p) => Variable<Object>(p)));
          }
          if (diverId != null) {
            whereClauses.add('d.diver_id = ?');
            args.add(Variable(diverId));
          }
          final where = whereClauses.isEmpty
              ? ''
              : 'WHERE ${whereClauses.join(' AND ')}';
          final rows = await _db
              .customSelect(
                'SELECT d.id AS id FROM dives d $where',
                variables: args,
                readsFrom: {
                  _db.dives,
                  _db.diveEquipment,
                  _db.diveTanks,
                  _db.equipment,
                  _db.equipmentAttributes,
                },
              )
              .get();
          return rows.map((r) => r.read<String>('id')).toSet();
        },
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to resolve equipment-attribute dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

```

- [ ] **Step 4: Add the provider and intersect in `filteredDivesProvider`**

In `lib/features/dive_log/presentation/providers/dive_providers.dart` add the import `import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';`. After `decoFilteredDiveIdsProvider`, add:

```dart
/// The ids of every dive matching the equipment-attribute conditions.
///
/// Like [decoFilteredDiveIdsProvider], this exists because the in-memory
/// path cannot evaluate the axis: a cylinder matched through the transmitter
/// registry reaches the entity without its item or attributes. Keyed on
/// [EquipmentAttrConditionsKey], which compares the list element by element,
/// so a changed condition set lands on a fresh instance rather than briefly
/// reusing the previous set's ids.
final equipmentAttrFilteredDiveIdsProvider =
    FutureProvider.family<Set<String>, EquipmentAttrConditionsKey>((
      ref,
      key,
    ) async {
      final diverId = ref.watch(currentDiverIdProvider);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentAttrFilterChanges());
      return repository.getDiveIdsMatchingEquipmentAttrs(
        key.conditions,
        diverId: diverId,
      );
    });
```

Replace the body of `filteredDivesProvider` with:

```dart
final filteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);

  // Axes the entity cannot answer resolve to SQL id sets; each one present
  // narrows the in-memory result.
  final idSets = <AsyncValue<Set<String>>>[
    if (filter.decoOnly case final decoOnly?)
      ref.watch(decoFilteredDiveIdsProvider(decoOnly)),
    if (filter.equipmentAttrConditions.isNotEmpty)
      ref.watch(
        equipmentAttrFilteredDiveIdsProvider(
          EquipmentAttrConditionsKey(filter.equipmentAttrConditions),
        ),
      ),
  ];

  final resolved = <Set<String>>[];
  for (final idsAsync in idSets) {
    // Built-in AsyncValue.value, not the repo's valueOrNull polyfill: it
    // retains the previous ids across a reload, so a write does not blank the
    // list. Null means first load (or a failure), never a stale answer.
    final ids = idsAsync.value;
    if (ids == null) {
      if (idsAsync.hasError) {
        return AsyncValue.error(
          idsAsync.error!,
          idsAsync.stackTrace ?? StackTrace.empty,
        );
      }
      return const AsyncValue.loading();
    }
    resolved.add(ids);
  }

  return divesAsync.whenData(
    (dives) => filter
        .apply(dives)
        .where((d) => resolved.every((ids) => ids.contains(d.id)))
        .toList(),
  );
});
```

- [ ] **Step 5: `apply` leaves the axis to SQL**

In `DiveFilterState.apply`, delete the block added in Task 4 (`// Equipment-attribute conditions over the dive's hydrated gear.` and its `if`). Replace the doc paragraph that begins `/// equipmentAttr* is applied in-memory here to mirror the SQL axis` (through `/// curated attributes (getAllDives does this).`) with:

```dart
  /// [equipmentAttrConditions] is NOT applied here: a cylinder matched through
  /// the transmitter registry reaches the entity without its item or
  /// attributes, so only SQL can see it. Callers that honour the axis
  /// intersect this result with `equipmentAttrFilteredDiveIdsProvider`, which
  /// uses the same `equipmentAttrConditionSql` as the paginated list.
```

In `test/features/dive_log/domain/models/dive_filter_state_test.dart`, replace the Task 4 test `'conditions AND together over the dive gear'` with:

```dart
        test('apply leaves the conditions to SQL', () {
          const filter = DiveFilterState(
            equipmentAttrConditions: [
              EquipmentAttrCondition(key: 'hose_type', choices: {'hp'}),
            ],
          );
          final dives = [_makeDive(id: 'a'), _makeDive(id: 'b')];
          expect(filter.apply(dives).map((d) => d.id), ['a', 'b']);
        });
```

and delete the now-unused local `curated` helper in that group.

- [ ] **Step 6: Pin the tick and the three-path parity**

Append to `test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart` (add `import 'package:submersion/features/statistics/data/dive_filter_sql.dart';`):

```dart
  test('Statistics, the list and the id query select the same dives', () async {
    await seedSuits();
    await insertDive('steel');
    await insertItem('t1', EquipmentType.tank, key: 'tank_material', text: 'steel');
    await linkTank('steel', 't1');
    for (final conditions in [
      [EquipmentAttrCondition.suitThickness(min: 5.0)],
      [
        const EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    ]) {
      final filter = DiveFilterState(equipmentAttrConditions: conditions);
      final stats = buildFilteredDiveIdSubquery(filter);
      final statsIds = (await db
              .customSelect(
                stats.subquery,
                variables: stats.params.map((p) => Variable<Object>(p!)).toList(),
              )
              .get())
          .map((r) => r.read<String>('id'))
          .toSet();
      final listed = await listIds(filter);
      final resolved = await repo.getDiveIdsMatchingEquipmentAttrs(conditions);
      expect(listed, statsIds, reason: '$conditions');
      expect(resolved, statsIds, reason: '$conditions');
    }
  });

  test('the filter tick fires on an attribute-only write', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: const Value('h'),
            name: const Value('h'),
            type: const Value('hose'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final events = <void>[];
    final sub = repo.watchEquipmentAttrFilterChanges().listen(events.add);
    addTearDown(sub.cancel);
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: const Value('attr_h_hose_type'),
            equipmentId: const Value('h'),
            attrKey: const Value('hose_type'),
            valueText: const Value('hp'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    expect(events, isNotEmpty);
  });
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/dive_log/presentation/providers/ test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart test/features/dive_log/domain/models/dive_filter_state_test.dart test/architecture/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS, including the existing `deco_filter_providers_test.dart` (the intersection loop must keep the deco behaviour identical) and `provider_change_tick_test.dart`.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart lib/features/dive_log/domain/models/dive_filter_state.dart test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart test/features/dive_log/domain/models/dive_filter_state_test.dart
git commit -m "feat(dive-log): resolve equipment attribute filters in SQL for every view (#1805)"
```

---

### Task 6: Equipment list filter by choice conditions

**Files:**
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart`
- Create: `lib/features/equipment/presentation/utils/equipment_attr_condition_text.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:248`, `:284`, and `_buildActiveFiltersBar` (after the `if (filter.type != null)` chip)
- Modify: all 11 ARB files and the regenerated `app_localizations*.dart`
- Test: `test/features/equipment/domain/models/equipment_filter_state_test.dart`
- Test: `test/features/equipment/presentation/utils/equipment_attr_condition_text_test.dart` (create)

**Interfaces:**
- Consumes: `EquipmentAttrCondition` (Task 2); `attributeLabel`, `attributeChoiceLabel` (Task 1).
- Produces: `EquipmentFilterState.attrConditions` (`List<EquipmentAttrCondition>`, default `const []`); `EquipmentFilterState.apply(List<EquipmentItem>)` (replaces `applyType`); `copyWith({List<EquipmentAttrCondition>? attrConditions, bool clearAttrConditions = false, ...})` which drops the conditions when the category changes or is cleared; `String attrConditionLabel(AppLocalizations l10n, EquipmentAttrCondition condition)`; l10n `equipment_list_activeFilter_attribute(String field, String values)`.

- [ ] **Step 1: Write the failing tests**

In `test/features/equipment/domain/models/equipment_filter_state_test.dart`, rename both `applyType` tests to use `apply` (replace `applyType(` with `apply(` and `'applyType ` with `'apply ` in their names), add the imports for `EquipmentAttribute` and `EquipmentAttrCondition`, and append inside the group:

```dart
    const hp = EquipmentAttrCondition(
      key: 'hose_type',
      choices: {'hp'},
      types: {EquipmentType.hose},
    );

    EquipmentItem hose(String id, String kind) => EquipmentItem(
      id: id,
      name: id,
      type: EquipmentType.hose,
      attributes: [
        EquipmentAttribute.curated(equipmentId: id, key: 'hose_type', valueText: kind),
      ],
    );

    test('apply narrows by the category and then each condition', () {
      final equipment = [hose('hp1', 'hp'), hose('lp1', 'lp'), _item('bcd', EquipmentType.bcd)];
      const filter = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [hp],
      );
      expect(filter.apply(equipment).map((e) => e.id), ['hp1']);
      expect(filter.hasActiveFilters, isTrue);
    });

    test('changing or clearing the category drops the conditions', () {
      const filter = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [hp],
      );
      expect(filter.copyWith(type: EquipmentType.bcd).attrConditions, isEmpty);
      expect(filter.copyWith(clearType: true).attrConditions, isEmpty);
      expect(filter.copyWith(type: EquipmentType.hose).attrConditions, [hp]);
      expect(
        filter.copyWith(status: EquipmentStatus.retired).attrConditions,
        [hp],
      );
      expect(filter.copyWith(clearAttrConditions: true).attrConditions, isEmpty);
    });

    test('equality includes the conditions', () {
      const a = EquipmentFilterState(type: EquipmentType.hose, attrConditions: [hp]);
      final b = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [
          EquipmentAttrCondition(key: 'hose_type', choices: {'hp'}, types: {EquipmentType.hose}),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const EquipmentFilterState(type: EquipmentType.hose)));
    });
```

Create `test/features/equipment/presentation/utils/equipment_attr_condition_text_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attr_condition_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('names the field and lists the options in catalog order', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      attrConditionLabel(
        l10n,
        const EquipmentAttrCondition(key: 'hose_type', choices: {'lpi', 'hp'}),
      ),
      'Hose type: HP (high pressure), LPI (inflator)',
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/models/equipment_filter_state_test.dart test/features/equipment/presentation/utils/equipment_attr_condition_text_test.dart`
Expected: FAIL, compile errors (`attrConditions` is not a parameter; the util file does not exist).

- [ ] **Step 3: Extend `EquipmentFilterState`**

Rewrite `lib/features/equipment/domain/models/equipment_filter_state.dart` as follows (keeping the existing class doc, with the axis list extended):

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

/// Filter state for the equipment list, shared by the phone, master-detail and
/// table layouts and edited through the filter panel.
///
/// Three axes:
///
/// - Status decides which provider the list reads: the default active-gear
///   view, the computed service-due list, or one [EquipmentStatus]. Those are
///   mutually exclusive because the list can only read one source.
/// - Type narrows the result client-side, so status and category compose with
///   AND semantics.
/// - Attribute conditions (#1805) narrow the selected category by its choice
///   fields, client-side, ANDed. They belong to the category.
@immutable
class EquipmentFilterState {
  /// The status to show, or null for the default view. The default hides
  /// retired gear; the Retired status is the way to see it (#636).
  final EquipmentStatus? status;

  /// Show only gear with a service clock due. Mutually exclusive with
  /// [status].
  final bool serviceDueOnly;

  /// Narrow to a single gear category, or null for every category.
  final EquipmentType? type;

  /// Choice conditions on [type]'s curated fields, ANDed. Changing or
  /// clearing the category through [copyWith] drops them.
  final List<EquipmentAttrCondition> attrConditions;

  const EquipmentFilterState({
    this.status,
    this.serviceDueOnly = false,
    this.type,
    this.attrConditions = const [],
  }) : assert(
         !(serviceDueOnly && status != null),
         'The status axis is a single choice: service due or a status, never '
         'both -- the list reads one provider.',
       );

  /// Whether the panel is narrowing anything, i.e. whether the top-bar icon
  /// should carry its badge.
  bool get hasActiveFilters =>
      hasStatusFilter || type != null || attrConditions.isNotEmpty;

  /// Whether the status axis is anything other than the default view.
  bool get hasStatusFilter => status != null || serviceDueOnly;

  /// Narrow [equipment] to the selected category and its conditions.
  ///
  /// The status axis is applied upstream by provider selection, so this is the
  /// only filtering the list itself has to do.
  List<EquipmentItem> apply(List<EquipmentItem> equipment) {
    final selected = type;
    if (selected == null && attrConditions.isEmpty) return equipment;
    return equipment
        .where(
          (e) =>
              (selected == null || e.type == selected) &&
              attrConditions.every((c) => c.matches(e)),
        )
        .toList();
  }

  /// Copy with per-axis clearing. Clearing the status axis resets both of its
  /// values, since they are one choice to the diver. A new or cleared
  /// category drops the attribute conditions unless new ones are given,
  /// because they belong to the category.
  EquipmentFilterState copyWith({
    EquipmentStatus? status,
    bool? serviceDueOnly,
    EquipmentType? type,
    List<EquipmentAttrCondition>? attrConditions,
    bool clearStatus = false,
    bool clearType = false,
    bool clearAttrConditions = false,
  }) {
    final nextType = clearType ? null : (type ?? this.type);
    final categoryChanged = nextType != this.type;
    return EquipmentFilterState(
      status: clearStatus ? null : (status ?? this.status),
      serviceDueOnly: clearStatus
          ? false
          : (serviceDueOnly ?? this.serviceDueOnly),
      type: nextType,
      attrConditions: clearAttrConditions
          ? const []
          : (attrConditions ??
                (categoryChanged ? const [] : this.attrConditions)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentFilterState &&
          other.status == status &&
          other.serviceDueOnly == serviceDueOnly &&
          other.type == type &&
          listEquals(other.attrConditions, attrConditions);

  @override
  int get hashCode => Object.hash(
    status,
    serviceDueOnly,
    type,
    Object.hashAll(attrConditions),
  );

  @override
  String toString() =>
      'EquipmentFilterState(status: $status, serviceDueOnly: $serviceDueOnly, '
      'type: $type, attrConditions: $attrConditions)';
}
```

(The existing `--` inside the assert message is pre-existing text; leave it as is.)

In `equipment_list_content.dart` replace both `filter.applyType(` calls with `filter.apply(`.

- [ ] **Step 4: Add the chip label string and helper**

Write `activefilter_attr_spec.json` in your scratchpad:

```json
{
  "anchor": "equipment_list_activeFilter_clear",
  "entries": {
    "equipment_list_activeFilter_attribute": {
      "ar": "{field}: {values}", "de": "{field}: {values}", "en": "{field}: {values}",
      "es": "{field}: {values}", "fr": "{field} : {values}", "he": "{field}: {values}",
      "hu": "{field}: {values}", "it": "{field}: {values}", "nl": "{field}: {values}",
      "pt": "{field}: {values}", "zh": "{field}：{values}"
    }
  },
  "en_metadata": {
    "equipment_list_activeFilter_attribute": {
      "description": "Active-filter chip for an equipment attribute filter. {field} is the field name (e.g. Hose type), {values} the selected options joined with commas.",
      "placeholders": {"field": {"type": "String"}, "values": {"type": "String"}}
    }
  }
}
```

Run:

```bash
PYTHONUTF8=1 python3.14 <scratchpad>/add_arb_keys.py <scratchpad>/activefilter_attr_spec.json
```

```bash
flutter gen-l10n
```

Create `lib/features/equipment/presentation/utils/equipment_attr_condition_text.dart`:

```dart
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Short label for an active choice condition, e.g. "Hose type: HP (high
/// pressure), LPI (inflator)". Options follow the catalog's order rather than
/// the order they were tapped, so one filter always reads the same way.
String attrConditionLabel(
  AppLocalizations l10n,
  EquipmentAttrCondition condition,
) {
  final order =
      EquipmentAttributeCatalog.defFor(condition.key)?.choiceKeys ??
      const <String>[];
  int rank(String option) {
    final index = order.indexOf(option);
    return index < 0 ? order.length : index;
  }

  final options = condition.choices.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  return l10n.equipment_list_activeFilter_attribute(
    attributeLabel(l10n, condition.key),
    options
        .map((option) => attributeChoiceLabel(l10n, condition.key, option))
        .join(', '),
  );
}
```

- [ ] **Step 5: Show each condition in the active-filter bar**

In `_buildActiveFiltersBar`, after the `if (filter.type != null) _buildActiveFilterChip(...)` entry, add:

```dart
            for (final condition in filter.attrConditions)
              _buildActiveFilterChip(
                attrConditionLabel(context.l10n, condition),
                () => ref.read(equipmentFilterProvider.notifier).state = filter
                    .copyWith(
                      attrConditions: [
                        for (final c in filter.attrConditions)
                          if (c != condition) c,
                      ],
                    ),
              ),
```

and add `import 'package:submersion/features/equipment/presentation/utils/equipment_attr_condition_text.dart';`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/domain/models/equipment_filter_state_test.dart test/features/equipment/presentation/utils/equipment_attr_condition_text_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/equipment/domain/models/equipment_filter_state.dart lib/features/equipment/presentation/utils/equipment_attr_condition_text.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/l10n/arb/ test/features/equipment/domain/models/equipment_filter_state_test.dart test/features/equipment/presentation/utils/equipment_attr_condition_text_test.dart
git commit -m "feat(equipment): filter the equipment list by attribute conditions (#1805)"
```

---

### Task 7: Shared choice-field chips and the equipment filter panel

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_choice_attribute_filter_test.dart` (create)
- Test: `test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (group `'filter panel (#1274, PR #1435 review)'`)

**Interfaces:**
- Consumes: `EquipmentAttrCondition` (Task 2); `EquipmentFilterState.attrConditions` (Task 6); `attributeLabel`, `attributeChoiceLabel`.
- Produces: `class EquipmentChoiceAttributeFilter extends StatelessWidget { const EquipmentChoiceAttributeFilter({Key? key, required EquipmentType type, required List<EquipmentAttrCondition> conditions, required ValueChanged<List<EquipmentAttrCondition>> onChanged}); static List<EquipmentAttributeDef> choiceDefsFor(EquipmentType type); }`. Chip keys: `ValueKey('equipment_filter_attr_<key>_<option>')`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/equipment/presentation/widgets/equipment_choice_attribute_filter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Finder chip(String key, String option) =>
      find.byKey(ValueKey('equipment_filter_attr_${key}_$option'));

  testWidgets('hose offers its type options and builds one condition', (
    tester,
  ) async {
    var conditions = <EquipmentAttrCondition>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => EquipmentChoiceAttributeFilter(
              type: EquipmentType.hose,
              conditions: conditions,
              onChanged: (next) => setState(() => conditions = next),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hose type'), findsOneWidget);
    expect(find.text('LP (low pressure)'), findsOneWidget);

    await tester.tap(chip('hose_type', 'hp'));
    await tester.pumpAndSettle();
    await tester.tap(chip('hose_type', 'lpi'));
    await tester.pumpAndSettle();
    expect(conditions, [
      const EquipmentAttrCondition(
        key: 'hose_type',
        choices: {'hp', 'lpi'},
        types: {EquipmentType.hose},
      ),
    ]);
    expect(tester.widget<FilterChip>(chip('hose_type', 'hp')).selected, isTrue);

    await tester.tap(chip('hose_type', 'hp'));
    await tester.pumpAndSettle();
    await tester.tap(chip('hose_type', 'lpi'));
    await tester.pumpAndSettle();
    expect(conditions, isEmpty);
  });

  testWidgets('a type with no choice fields renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EquipmentChoiceAttributeFilter(
            type: EquipmentType.other,
            conditions: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  test('choiceDefsFor lists spec choice fields only', () {
    final keys = EquipmentChoiceAttributeFilter.choiceDefsFor(
      EquipmentType.hose,
    ).map((d) => d.key);
    expect(keys, ['hose_type']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_choice_attribute_filter_test.dart`
Expected: FAIL, missing file `equipment_choice_attribute_filter.dart`.

- [ ] **Step 3: Write the widget**

Create `lib/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-select chips for every choice field of [type] (issue #1805), shared
/// by the equipment filter panel and the dive filter sheet.
///
/// Each field with at least one chip selected is one condition in
/// [conditions] (its key, the selected options, `types: {type}`), in catalog
/// order; deselecting a field's last chip removes its condition. Fields come
/// from the catalog, so a new choice field appears here with no change to
/// this widget. A type with no choice fields renders nothing.
class EquipmentChoiceAttributeFilter extends StatelessWidget {
  final EquipmentType type;
  final List<EquipmentAttrCondition> conditions;
  final ValueChanged<List<EquipmentAttrCondition>> onChanged;

  const EquipmentChoiceAttributeFilter({
    super.key,
    required this.type,
    required this.conditions,
    required this.onChanged,
  });

  /// The fields offered for [type]: its choice attributes in the spec group.
  static List<EquipmentAttributeDef> choiceDefsFor(EquipmentType type) => [
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      if (def.kind == AttributeKind.choice && def.group == AttributeGroup.spec)
        def,
  ];

  @override
  Widget build(BuildContext context) {
    final defs = choiceDefsFor(type);
    if (defs.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final def in defs) ...[
          const SizedBox(height: 12),
          Text(
            attributeLabel(l10n, def.key),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in def.choiceKeys)
                FilterChip(
                  key: ValueKey('equipment_filter_attr_${def.key}_$option'),
                  label: Text(attributeChoiceLabel(l10n, def.key, option)),
                  selected: _selectedFor(def.key).contains(option),
                  onSelected: (selected) => _toggle(def.key, option, selected),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Set<String> _selectedFor(String key) {
    for (final condition in conditions) {
      if (condition.key == key) return condition.choices;
    }
    return const {};
  }

  void _toggle(String key, String option, bool selected) {
    final choices = {..._selectedFor(key)};
    if (selected) {
      choices.add(option);
    } else {
      choices.remove(option);
    }
    onChanged([
      for (final def in choiceDefsFor(type))
        if (def.key == key)
          ...[
            if (choices.isNotEmpty)
              EquipmentAttrCondition(
                key: key,
                choices: Set.unmodifiable(choices),
                types: {type},
              ),
          ]
        else
          ...conditions.where((c) => c.key == def.key),
    ]);
  }
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_choice_attribute_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing panel and list tests**

In `test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart`, add the imports for `EquipmentAttribute` and `EquipmentAttrCondition`, and append inside the group:

```dart
    testWidgets('a picked category offers its choice fields, applied on Apply', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(
        owned: [..._gear, _item('hose', EquipmentType.hose)],
      );
      await _openSheet(tester, container);

      expect(find.text('Hose type'), findsNothing);
      await tester.tap(_typeChip(EquipmentType.hose));
      await tester.pumpAndSettle();
      expect(find.text('Hose type'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('equipment_filter_attr_hose_type_hp')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
      await tester.pumpAndSettle();

      expect(container.read(equipmentFilterProvider).attrConditions, [
        const EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ]);
    });

    testWidgets('switching category drops the chips of the old one', (tester) async {
      _useTallSurface(tester);
      final container = await _container(
        owned: [..._gear, _item('hose', EquipmentType.hose)],
        filter: const EquipmentFilterState(
          type: EquipmentType.hose,
          attrConditions: [
            EquipmentAttrCondition(key: 'hose_type', choices: {'hp'}, types: {EquipmentType.hose}),
          ],
        ),
      );
      await _openSheet(tester, container);

      await tester.tap(_typeChip(EquipmentType.bcd));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
      await tester.pumpAndSettle();

      final applied = container.read(equipmentFilterProvider);
      expect(applied.type, EquipmentType.bcd);
      expect(applied.attrConditions, isEmpty);
    });
```

In `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`, inside the group `'filter panel (#1274, PR #1435 review)'`, append:

```dart
    testWidgets('a hose type chip narrows the list and shows in the bar', (
      tester,
    ) async {
      EquipmentItem hose(String id, String name, String kind) => EquipmentItem(
        id: id,
        name: name,
        type: EquipmentType.hose,
        attributes: [
          EquipmentAttribute.curated(equipmentId: id, key: 'hose_type', valueText: kind),
        ],
      );
      await pumpPhoneList(
        tester,
        equipment: [...items, hose('h1', 'Gauge Hose', 'hp'), hose('h2', 'Reg Hose', 'lp')],
      );

      await _filterVia(tester, [
        _typeChipKey(EquipmentType.hose),
        'equipment_filter_attr_hose_type_hp',
      ]);

      expect(find.text('Gauge Hose'), findsOneWidget);
      expect(find.text('Reg Hose'), findsNothing);
      final chip = find.widgetWithText(InputChip, 'Hose type: HP (high pressure)');
      expect(chip, findsOneWidget);

      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pumpAndSettle();
      expect(find.text('Reg Hose'), findsOneWidget);
    });
```

Add `import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';` to that file.

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
Expected: the three new tests FAIL (`Hose type` not found / chip key not found).

- [ ] **Step 7: Wire the widget into the panel**

In `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`:

Add imports:

```dart
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
```

Add the draft field after `EquipmentType? _type;`:

```dart
  List<EquipmentAttrCondition> _attrConditions = const [];
```

and in `initState` after `_type = filter.type;`:

```dart
    _attrConditions = filter.attrConditions;
```

Add a helper to the state class:

```dart
  /// Conditions belong to a category, so picking another one drops them.
  void _selectType(EquipmentType? type) {
    setState(() {
      if (type != _type) _attrConditions = const [];
      _type = type;
    });
  }
```

In `_buildCategorySection`, change the All chip's `onSelected: (_) => setState(() => _type = null),` to `onSelected: (_) => _selectType(null),` and each type chip's `onSelected: (selected) => setState(() => _type = selected ? type : null),` to `onSelected: (selected) => _selectType(selected ? type : null),`. After the closing `),` of the `Wrap`, still inside the Column's `children`, add:

```dart
        if (_type case final selected?)
          EquipmentChoiceAttributeFilter(
            type: selected,
            conditions: _attrConditions,
            onChanged: (next) => setState(() => _attrConditions = next),
          ),
```

In `_clearAll` add `_attrConditions = const [];`. In `_applyFilters` add `attrConditions: _attrConditions,` to the constructed `EquipmentFilterState`.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart test/features/equipment/presentation/widgets/equipment_choice_attribute_filter_test.dart test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git commit -m "feat(equipment): choice-field chips in the equipment filter panel (#1805)"
```

---

### Task 8: Gear attributes in the dive filter sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (state fields, `initState` loop from Task 4, section after Suit thickness, `_applyFilters`)
- Modify: all 11 ARB files and the regenerated `app_localizations*.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart`

**Interfaces:**
- Consumes: `EquipmentChoiceAttributeFilter` and `choiceDefsFor` (Task 7); `ownedEquipmentTypesProvider` (existing, `lib/features/equipment/presentation/providers/equipment_providers.dart:114`); `EquipmentTypeDisplay.localizedName` (existing, `equipment_enum_display.dart`); `isSuitThickness` (Task 2).
- Produces: `class DiveFilterGearAttributesSection extends ConsumerWidget { const DiveFilterGearAttributesSection({Key? key, required EquipmentType? category, required List<EquipmentAttrCondition> conditions, required void Function(EquipmentType? category, List<EquipmentAttrCondition> conditions) onChanged}); }`; dropdown key `ValueKey('diveFilter_gearCategory')`; l10n `diveLog_filter_sectionGearAttributes`, `diveLog_filter_gearCategory`, `diveLog_filter_gearCategoryAny`.

- [ ] **Step 1: Add the strings**

Write `dive_gear_spec.json` in your scratchpad:

```json
{
  "anchor": "diveLog_filter_sectionSuitThickness",
  "entries": {
    "diveLog_filter_sectionGearAttributes": {
      "ar": "خصائص المعدات", "de": "Ausrüstungsmerkmale", "en": "Gear attributes",
      "es": "Atributos del equipo", "fr": "Caractéristiques de l'équipement", "he": "מאפייני ציוד",
      "hu": "Felszerelés jellemzői", "it": "Caratteristiche dell'attrezzatura", "nl": "Uitrustingskenmerken",
      "pt": "Atributos do equipamento", "zh": "装备属性"
    },
    "diveLog_filter_gearCategory": {
      "ar": "فئة المعدات", "de": "Ausrüstungskategorie", "en": "Gear category",
      "es": "Categoría de equipo", "fr": "Catégorie d'équipement", "he": "קטגוריית ציוד",
      "hu": "Felszerelés kategóriája", "it": "Categoria di attrezzatura", "nl": "Uitrustingscategorie",
      "pt": "Categoria de equipamento", "zh": "装备类别"
    },
    "diveLog_filter_gearCategoryAny": {
      "ar": "أي فئة", "de": "Beliebige Kategorie", "en": "Any category",
      "es": "Cualquier categoría", "fr": "Toutes catégories", "he": "כל קטגוריה",
      "hu": "Bármely kategória", "it": "Qualsiasi categoria", "nl": "Elke categorie",
      "pt": "Qualquer categoria", "zh": "任意类别"
    }
  }
}
```

Run:

```bash
PYTHONUTF8=1 python3.14 <scratchpad>/add_arb_keys.py <scratchpad>/dive_gear_spec.json
```

```bash
flutter gen-l10n
```

- [ ] **Step 2: Write the failing sheet tests**

In `test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart`:

Add imports:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
```

Give `openSheet` a new parameter `List<EquipmentItem> ownedGear = const [],` and add to its overrides list:

```dart
          allEquipmentProvider.overrideWith((ref) async => ownedGear),
```

Append these tests inside `main()`:

```dart
  const hoseHp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );
  const hoseItem = EquipmentItem(id: 'h', name: 'Gauge hose', type: EquipmentType.hose);

  testWidgets('no owned gear with choice fields hides the section', (tester) async {
    await openSheet(tester);
    await scrollTo(tester, find.text('Tags'));
    expect(find.text('Gear attributes'), findsNothing);
  });

  testWidgets('hose type chips write a condition beside suit thickness', (
    tester,
  ) async {
    final ref = await openSheet(tester, ownedGear: [hoseItem]);

    await scrollTo(tester, find.text('Suit thickness (mm)'));
    final minField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Min' &&
          w.decoration?.suffixText == null,
    );
    await tester.enterText(minField, '5');
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('diveFilter_gearCategory')));
    await tester.tap(find.byKey(const ValueKey('diveFilter_gearCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hose').last);
    await tester.pumpAndSettle();

    final hp = find.byKey(const ValueKey('equipment_filter_attr_hose_type_hp'));
    await scrollTo(tester, hp);
    await tester.tap(hp);
    await tester.pumpAndSettle();

    await tapText(tester, 'Apply Filters');
    expect(ref.read(filterProvider).equipmentAttrConditions, [
      EquipmentAttrCondition.suitThickness(min: 5),
      hoseHp,
    ]);
  });

  testWidgets('the gear section hydrates from an existing filter', (tester) async {
    final initial = DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition.suitThickness(min: 3),
        hoseHp,
      ],
    );
    final ref = await openSheet(tester, initial: initial, ownedGear: [hoseItem]);

    final hp = find.byKey(const ValueKey('equipment_filter_attr_hose_type_hp'));
    await scrollTo(tester, hp);
    expect(tester.widget<FilterChip>(hp).selected, isTrue);

    await tapText(tester, 'Apply Filters');
    expect(
      ref.read(filterProvider).equipmentAttrConditions,
      initial.equipmentAttrConditions,
    );
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart`
Expected: the two gear tests FAIL (`diveFilter_gearCategory` key not found; the hydrate test fails on the chip finder). The hidden-section test passes.

- [ ] **Step 4: Write the section**

Create `lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive filter's gear-attribute section (issue #1805): pick one gear
/// category the diver owns, then narrow by its choice fields with the same
/// chips the equipment filter panel uses. Suit thickness keeps its own
/// section; its condition and these combine with AND.
///
/// Renders nothing when the diver owns no category with a choice field.
class DiveFilterGearAttributesSection extends ConsumerWidget {
  final EquipmentType? category;
  final List<EquipmentAttrCondition> conditions;
  final void Function(
    EquipmentType? category,
    List<EquipmentAttrCondition> conditions,
  )
  onChanged;

  const DiveFilterGearAttributesSection({
    super.key,
    required this.category,
    required this.conditions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedEquipmentTypesProvider);
    final categories = [
      for (final type in EquipmentType.values)
        if ((owned.contains(type) || type == category) &&
            EquipmentChoiceAttributeFilter.choiceDefsFor(type).isNotEmpty)
          type,
    ];
    if (categories.isEmpty) return const SizedBox.shrink();

    final selected = category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_filter_sectionGearAttributes,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EquipmentType?>(
          key: const ValueKey('diveFilter_gearCategory'),
          initialValue: selected,
          decoration: InputDecoration(
            labelText: context.l10n.diveLog_filter_gearCategory,
          ),
          items: [
            DropdownMenuItem<EquipmentType?>(
              value: null,
              child: Text(context.l10n.diveLog_filter_gearCategoryAny),
            ),
            for (final type in categories)
              DropdownMenuItem<EquipmentType?>(
                value: type,
                child: Text(type.localizedName(context.l10n)),
              ),
          ],
          // A new category starts with no chips: conditions belong to one.
          onChanged: (type) => onChanged(type, const []),
        ),
        if (selected != null)
          EquipmentChoiceAttributeFilter(
            type: selected,
            conditions: conditions,
            onChanged: (next) => onChanged(selected, next),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
```

- [ ] **Step 5: Wire it into the sheet**

In `dive_filter_sheet.dart`:

Add imports:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart';
```

(skip `enums.dart` if the file already imports it).

Add state fields next to `_suitThicknessMin` / `_suitThicknessMax`:

```dart
  // Gear-attribute section (#1805): one category and its choice conditions.
  EquipmentType? _gearCategory;
  List<EquipmentAttrCondition> _gearConditions = const [];
```

Replace the Task 4 `initState` loop with:

```dart
    for (final condition in filter.equipmentAttrConditions) {
      if (condition.isSuitThickness) {
        _suitThicknessMin = condition.min;
        _suitThicknessMax = condition.max;
      } else {
        _gearConditions = [..._gearConditions, condition];
        if (condition.types.length == 1) {
          _gearCategory ??= condition.types.first;
        }
      }
    }
```

Directly before the `// Tags Section` comment (after the Suit thickness block's `const SizedBox(height: 24),`), add:

```dart
                      DiveFilterGearAttributesSection(
                        category: _gearCategory,
                        conditions: _gearConditions,
                        onChanged: (category, conditions) => setState(() {
                          _gearCategory = category;
                          _gearConditions = conditions;
                        }),
                      ),
```

In `_applyFilters`, change the `equipmentAttrConditions:` list to:

```dart
      equipmentAttrConditions: [
        if (_suitThicknessMin != null || _suitThicknessMax != null)
          EquipmentAttrCondition.suitThickness(
            min: _suitThicknessMin,
            max: _suitThicknessMax,
          ),
        ..._gearConditions,
      ],
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/presentation/widgets/ test/l10n/arb_parity_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/l10n/arb/ test/features/dive_log/presentation/widgets/dive_filter_sheet_interactions_test.dart
git commit -m "feat(dive-log): filter dives by a gear category's choice fields (#1805)"
```

---

### Task 9: Whole-project verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `git status --porcelain` (expected: nothing new to format), then `flutter analyze`.
Expected: `No issues found!` (infos are fatal in CI; fix any).

- [ ] **Step 2: Generated l10n is current**

Run: `flutter gen-l10n` then `git status --porcelain lib/l10n`
Expected: empty output.

- [ ] **Step 3: No forbidden punctuation or attribution in the diff**

Run: `git diff origin/main --stat` and `git log origin/main..HEAD --format=%B`, and search the diff for U+2014:

```bash
git diff origin/main -- . ':!lib/l10n' | grep -nP '^\+.*\x{2014}'
```

Expected: no output, and no commit body mentions Claude or carries a co-author trailer.

- [ ] **Step 4: One full test run**

Run: `flutter test`
Expected: all tests pass. Do not overlap this with any other local test run.

- [ ] **Step 5: Report**

Summarise for the maintainer: the commits, the Task 4 Step 2 failure output (the list bug, before the fix), and the full-suite result. Opening a PR is a separate decision for the maintainer.
