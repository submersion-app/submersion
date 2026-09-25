# Entity Query Language PR 1: Core Engine and Dives, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One registry-driven query engine (AST, typed syntax, printer, validator, SQL compiler) that every dive filter path evaluates, so "dives with no weight entry" is `weights:none` and a new filter axis is one registry line.

**Architecture:** A pure-Dart AST in `lib/core/query/` is parsed from text or built by code, resolved against a per-entity registry of fields and relations, and compiled to one parameterised SQL `WHERE` expression. `DiveFilterState` keeps its fields and gains `toQuery()`; its `apply()` is deleted; the paginated list, its count, Statistics and the entity-backed views all consume the one compiled query, which also names the tables it read so change ticks are derived, not hand-maintained.

**Tech Stack:** Dart 3 (sealed classes, records, patterns), Drift `customSelect`, Riverpod, `flutter_test` with the in-memory `setUpTestDatabase()` helper.

**Spec:** `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (read it first; the plan argues from it).

**Issue:** `Refs #2365` in the PR body (the program issue; PR 5 closes it).

## Global Constraints

- No em-dashes anywhere (code, comments, commits, ARB values). No emojis. No Claude or Anthropic mention in any commit, comment or PR text.
- Immutability: every AST and registry type is `@immutable`, value-equal, with `copyWith` where it has more than one field.
- Files stay under 800 lines; split by responsibility (parser, printer, compiler are separate files).
- Every SQL value is a bind parameter. The compiler never interpolates a value; only registry-declared SQL fragments and aliases are interpolated.
- Anything displaying a number respects the diver's unit settings: the parser grounds bare numbers in the diver's unit, the printer shows them in it.
- Paths in tests are built with `p.join`, never string concatenation.
- Path depth cap: 4 relation hops.
- `dive_date_time` is a wall clock flagged as UTC in epoch milliseconds; every date bound goes through `wallClockUtcDayStart` (`lib/core/util/wall_clock_utc.dart`).
- New ARB keys go in `app_en.arb` (alphabetical) and in all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh); non-en files are feature-grouped, so insert next to the `diveLog_filter_*` keys. No plurals are added in this PR. `app_de.arb` must not contain the string "SAC".
- Run `dart format .` before every commit. Run `flutter analyze` on the whole project before the final commit; infos are fatal in CI.
- Do not overlap local test runs; prefix `TMPDIR=/tmp` if the default TMPDIR is a mounted volume.
- Stage explicit paths (`git add <paths>`), never `git add -A`.

## Review Focus

1. A number typed with a decimal comma (`depth > 18,5`) must produce a positioned parse error naming the comma, never a silent list or a wrong bound. (Task 4)
2. An empty list (`tags in []`) must be a validation error, not a condition that silently matches nothing. (Task 4 and Task 10)
3. Free text and `contains` values holding `%` or `_` must be matched literally: `"100%"` must not match every dive. (Task 12)
4. A ref label holding a double quote or backslash must survive print and re-parse (`site = "Bob's \"Reef\""`). (Task 5)
5. `bottomTime != 10` must exclude dives whose bottom time is unrecorded, and `bottomTime:none` must select exactly those. (Task 13)

---

## File map

Created (core, pure Dart, no Flutter imports unless noted):

| File | Responsibility |
| --- | --- |
| `lib/core/query/domain/query_node.dart` | `QueryNode` sealed hierarchy, `FieldPath`, `QueryOp` |
| `lib/core/query/domain/query_value.dart` | `QueryValue` sealed hierarchy, `QueryUnit` |
| `lib/core/query/domain/query_json.dart` | `queryNodeToJson` / `queryNodeFromJson`, `QueryJsonException` |
| `lib/core/query/domain/query_errors.dart` | `QueryError`, `ParseFailure`, `QueryCompileError` |
| `lib/core/query/domain/query_subject.dart` | `QuerySubject` enum |
| `lib/core/query/registry/query_field.dart` | `QueryField`, `FieldType`, `FieldDimension` |
| `lib/core/query/registry/query_relation.dart` | `QueryRelation`, `RelationShape` |
| `lib/core/query/registry/query_entity.dart` | `QueryEntity`, lookup by key or alias |
| `lib/core/query/registry/query_registry.dart` | `QueryRegistry`, `resolvePath`, `PathResolution` |
| `lib/core/query/units/unit_prefs.dart` | `UnitPrefs`, `groundToStorage`, `storageToDisplay` |
| `lib/core/query/syntax/date_grammar.dart` | `parseDateText` (Explore's grammar, copied; PR 5 dedupes) |
| `lib/core/query/syntax/query_tokenizer.dart` | `Token`, `TokenKind`, `tokenize` |
| `lib/core/query/syntax/query_parser.dart` | `QueryParser`, `ParseContext`, `NameResolver` |
| `lib/core/query/syntax/query_printer.dart` | `QueryPrinter` |
| `lib/core/query/syntax/query_suggestions.dart` | Dice-ranked suggestions for unknown keys |
| `lib/core/query/compiler/query_validator.dart` | `validateQuery` |
| `lib/core/query/compiler/query_compiler.dart` | `compileQuery`, `CompiledQuery` |
| `lib/core/query/compiler/sql_templates.dart` | `{r}` / `{from}` / `{to}` substitution, `?` counting |
| `lib/features/query/app_query_registry.dart` | Assembles every feature's entity into `appQueryRegistry` |
| `lib/features/dive_log/query/dive_query_entity.dart` | The dive registry: fields and relations |
| `lib/features/dive_log/query/dive_child_query_entities.dart` | tanks, weights, custom fields, sightings, media (minimal) |
| `lib/features/dive_log/query/dive_filter_query.dart` | `DiveFilterState.toQuery()` extension and `compileDiveFilter` |
| `lib/features/dive_sites/query/site_query_entity.dart` | Minimal site entity (PR 3 completes it) |
| `lib/features/equipment/query/equipment_query_entity.dart` | Minimal equipment and equipment-attribute entities |
| `lib/features/buddies/query/buddy_query_entity.dart` | Minimal buddy entity |
| `lib/features/tags/query/tag_query_entity.dart`, `lib/features/dive_types/query/dive_type_query_entity.dart`, `lib/features/trips/query/trip_query_entity.dart`, `lib/features/dive_centers/query/dive_center_query_entity.dart`, `lib/features/dive_computer/query/dive_computer_query_entity.dart`, `lib/features/courses/query/course_query_entity.dart`, `lib/features/marine_life/query/species_query_entity.dart` | Minimal target entities (name plus a few fields) |

Modified:

| File | Change |
| --- | --- |
| `lib/features/dive_log/domain/models/dive_filter_state.dart` | add `query`, delete `apply()` and `readsBuddyLinks` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `_buildFilterWhereClauses` on the compiled query; `getDiveIdsMatching`; `watchTables`; delete deco and attribute id methods and `watchEquipmentAttrFilterChanges` |
| `lib/features/statistics/data/dive_filter_sql.dart` | `buildFilteredDiveIdSubquery` becomes a wrapper; `equipmentAttrConditionSql` deleted; `decoSignalCondition` stays |
| `lib/features/dive_log/presentation/providers/dive_providers.dart` | `queryFilteredDiveIdsProvider` replaces the deco and attribute id providers; ticks derived from `tablesTouched` |
| `lib/l10n/arb/app_*.arb` | field and relation labels |
| tests listed per task |

Deleted: `test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart` (its cases move to Task 16).

---

### Task 1: The query model

**Files:**
- Create: `lib/core/query/domain/query_subject.dart`
- Create: `lib/core/query/domain/query_value.dart`
- Create: `lib/core/query/domain/query_node.dart`
- Create: `lib/core/query/domain/query_errors.dart`
- Test: `test/core/query/domain/query_node_test.dart`

**Interfaces:**
- Produces: `QuerySubject`, `QueryUnit`, `QueryValue` (+ subclasses), `FieldPath`, `QueryOp`, `QueryNode` (+ `AndNode`, `OrNode`, `NotNode`, `ConditionNode`, `ScopedNode`, `TextNode`), `QueryError`, `ParseFailure`, `QueryCompileError`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/query/domain/query_node_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';

void main() {
  test('nodes and values are value-equal', () {
    QueryNode build() => AndNode([
      ConditionNode(
        const FieldPath(['site', 'country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
      NotNode(
        ConditionNode(
          const FieldPath(['weights']),
          QueryOp.isSet,
          null,
        ),
      ),
      ScopedNode(
        const FieldPath(['gear']),
        ConditionNode(
          const FieldPath(['type']),
          QueryOp.inList,
          const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]),
        ),
      ),
      const TextNode(['night', 'dive']),
    ]);
    expect(build(), equals(build()));
    expect(build().hashCode, equals(build().hashCode));
  });

  test('a number value keeps its storage value and the typed unit', () {
    const v = NumberValue(30.48, QueryUnit.ft);
    expect(v.value, 30.48);
    expect(v.typedUnit, QueryUnit.ft);
    expect(v, isNot(equals(const NumberValue(30.48, null))));
  });

  test('FieldPath exposes its head, tail and depth', () {
    const path = FieldPath(['buddies', 'certifications', 'level']);
    expect(path.head, 'buddies');
    expect(path.tail, const FieldPath(['certifications', 'level']));
    expect(path.length, 3);
    expect(path.toString(), 'buddies.certifications.level');
  });

  test('a condition with isEmpty or isSet carries no value', () {
    expect(
      () => ConditionNode(const FieldPath(['notes']), QueryOp.isEmpty,
          const StringValue('x')),
      throwsArgumentError,
    );
    expect(
      () => ConditionNode(const FieldPath(['notes']), QueryOp.eq, null),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/query/domain/query_node_test.dart`
Expected: FAIL, the imports do not resolve.

- [ ] **Step 3: Write the model**

```dart
// lib/core/query/domain/query_subject.dart
/// Every table a query can root at or reach through a relation.
///
/// The first nine are list subjects (they get a query entry point on their
/// list page, PRs 1 to 4). The rest are child tables reachable only through
/// a relation.
enum QuerySubject {
  dives,
  sites,
  equipment,
  trips,
  buddies,
  centers,
  certifications,
  courses,
  species,
  tags,
  diveTypes,
  computers,
  tanks,
  weights,
  customFields,
  sightings,
  media,
  equipmentAttributes,
}
```

```dart
// lib/core/query/domain/query_value.dart
import 'package:meta/meta.dart';

/// A unit the diver can type after a number. Storage is always metric
/// (metres, celsius, bar, kg, litres, minutes); these name what was typed.
enum QueryUnit {
  m('m'),
  ft('ft'),
  c('c'),
  f('f'),
  bar('bar'),
  psi('psi'),
  kg('kg'),
  lb('lb'),
  l('l'),
  cuft('cuft'),
  min('min');

  final String suffix;
  const QueryUnit(this.suffix);

  static QueryUnit? fromSuffix(String s) {
    final lower = s.toLowerCase();
    for (final u in values) {
      if (u.suffix == lower) return u;
    }
    return switch (lower) {
      'lbs' => lb,
      'liter' || 'litre' || 'liters' || 'litres' => l,
      'mins' || 'minute' || 'minutes' => min,
      _ => null,
    };
  }
}

@immutable
sealed class QueryValue {
  const QueryValue();
}

/// A number in STORAGE units (the parser grounds it). [typedUnit] is what
/// the diver wrote, kept so the printer can echo it; null means the value
/// was bare and prints in the diver's unit.
class NumberValue extends QueryValue {
  final double value;
  final QueryUnit? typedUnit;
  const NumberValue(this.value, this.typedUnit);
  @override
  bool operator ==(Object o) =>
      o is NumberValue && o.value == value && o.typedUnit == typedUnit;
  @override
  int get hashCode => Object.hash(value, typedUnit);
  @override
  String toString() => 'NumberValue($value, $typedUnit)';
}

class StringValue extends QueryValue {
  final String value;
  const StringValue(this.value);
  @override
  bool operator ==(Object o) => o is StringValue && o.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'StringValue($value)';
}

class BoolValue extends QueryValue {
  final bool value;
  const BoolValue(this.value);
  @override
  bool operator ==(Object o) => o is BoolValue && o.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'BoolValue($value)';
}

/// The STORED enum name (`wetsuit`, `oc`), never a localized label.
class EnumValue extends QueryValue {
  final String name;
  const EnumValue(this.name);
  @override
  bool operator ==(Object o) => o is EnumValue && o.name == name;
  @override
  int get hashCode => name.hashCode;
  @override
  String toString() => 'EnumValue($name)';
}

/// A calendar day. Only year, month and day are read.
class DateValue extends QueryValue {
  final DateTime day;
  DateValue(DateTime d) : day = DateTime(d.year, d.month, d.day);
  @override
  bool operator ==(Object o) => o is DateValue && o.day == day;
  @override
  int get hashCode => day.hashCode;
  @override
  String toString() => 'DateValue($day)';
}

/// An inclusive range of calendar days.
class DateRangeValue extends QueryValue {
  final DateTime start;
  final DateTime end;
  DateRangeValue(DateTime s, DateTime e)
      : start = DateTime(s.year, s.month, s.day),
        end = DateTime(e.year, e.month, e.day);
  @override
  bool operator ==(Object o) =>
      o is DateRangeValue && o.start == start && o.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'DateRangeValue($start, $end)';
}

class ListValue extends QueryValue {
  final List<QueryValue> items;
  const ListValue(this.items);
  @override
  bool operator ==(Object o) =>
      o is ListValue && _listEquals(o.items, items);
  @override
  int get hashCode => Object.hashAll(items);
  @override
  String toString() => 'ListValue($items)';
}

/// A reference to a row of another entity: the id the compiler binds and
/// the label the printer shows.
class RefValue extends QueryValue {
  final String id;
  final String label;
  const RefValue(this.id, this.label);
  @override
  bool operator ==(Object o) => o is RefValue && o.id == id && o.label == label;
  @override
  int get hashCode => Object.hash(id, label);
  @override
  String toString() => 'RefValue($id, $label)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

```dart
// lib/core/query/domain/query_node.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_value.dart';

export 'package:submersion/core/query/domain/query_value.dart';

/// A dotted path from the root entity: relations, then optionally a field.
@immutable
class FieldPath {
  final List<String> segments;
  const FieldPath(this.segments);

  String get head => segments.first;
  FieldPath get tail => FieldPath(segments.sublist(1));
  int get length => segments.length;
  bool get isSingle => segments.length == 1;

  @override
  bool operator ==(Object o) =>
      o is FieldPath && _listEquals(o.segments, segments);
  @override
  int get hashCode => Object.hashAll(segments);
  @override
  String toString() => segments.join('.');
}

enum QueryOp {
  eq,
  neq,
  lt,
  lte,
  gt,
  gte,
  contains,
  inList,
  between,
  isEmpty,
  isSet;

  bool get takesValue => this != isEmpty && this != isSet;
}

@immutable
sealed class QueryNode {
  const QueryNode();
}

class AndNode extends QueryNode {
  final List<QueryNode> children;
  const AndNode(this.children);
  @override
  bool operator ==(Object o) =>
      o is AndNode && _listEquals(o.children, children);
  @override
  int get hashCode => Object.hash('and', Object.hashAll(children));
  @override
  String toString() => 'And($children)';
}

class OrNode extends QueryNode {
  final List<QueryNode> children;
  const OrNode(this.children);
  @override
  bool operator ==(Object o) =>
      o is OrNode && _listEquals(o.children, children);
  @override
  int get hashCode => Object.hash('or', Object.hashAll(children));
  @override
  String toString() => 'Or($children)';
}

class NotNode extends QueryNode {
  final QueryNode child;
  const NotNode(this.child);
  @override
  bool operator ==(Object o) => o is NotNode && o.child == child;
  @override
  int get hashCode => Object.hash('not', child);
  @override
  String toString() => 'Not($child)';
}

/// `path op value`. [value] is null exactly when [op] takes none.
class ConditionNode extends QueryNode {
  final FieldPath path;
  final QueryOp op;
  final QueryValue? value;
  ConditionNode(this.path, this.op, this.value) {
    if (op.takesValue && value == null) {
      throw ArgumentError('$op needs a value');
    }
    if (!op.takesValue && value != null) {
      throw ArgumentError('$op takes no value');
    }
  }
  @override
  bool operator ==(Object o) =>
      o is ConditionNode && o.path == path && o.op == op && o.value == value;
  @override
  int get hashCode => Object.hash(path, op, value);
  @override
  String toString() => 'Condition($path $op $value)';
}

/// `path[inner]`: [inner] is evaluated inside ONE row of the relation
/// [path] names, so `customFields[key = k AND value ~ v]` tests the same
/// row for both. A bare multi-hop condition is the same thing with a
/// single condition inside.
class ScopedNode extends QueryNode {
  final FieldPath path;
  final QueryNode inner;
  const ScopedNode(this.path, this.inner);
  @override
  bool operator ==(Object o) =>
      o is ScopedNode && o.path == path && o.inner == inner;
  @override
  int get hashCode => Object.hash(path, inner);
  @override
  String toString() => 'Scoped($path[$inner])';
}

/// Free text over the entity's declared search columns.
class TextNode extends QueryNode {
  final List<String> words;
  const TextNode(this.words);
  @override
  bool operator ==(Object o) => o is TextNode && _listEquals(o.words, words);
  @override
  int get hashCode => Object.hash('text', Object.hashAll(words));
  @override
  String toString() => 'Text($words)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

```dart
// lib/core/query/domain/query_errors.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';

/// A positioned problem with a query. [offset] and [length] locate it in
/// typed text; they are null for a tree the builder made, where [path]
/// names the row instead.
@immutable
class QueryError {
  final String message;
  final int? offset;
  final int? length;
  final FieldPath? path;
  final List<String> suggestions;

  const QueryError(
    this.message, {
    this.offset,
    this.length,
    this.path,
    this.suggestions = const [],
  });

  @override
  bool operator ==(Object o) =>
      o is QueryError &&
      o.message == message &&
      o.offset == offset &&
      o.length == length &&
      o.path == path;
  @override
  int get hashCode => Object.hash(message, offset, length, path);
  @override
  String toString() => 'QueryError($message @$offset+$length $suggestions)';
}

/// The parser's failure result. Never thrown.
@immutable
class ParseFailure {
  final QueryError error;
  const ParseFailure(this.error);
  @override
  String toString() => 'ParseFailure($error)';
}

/// Thrown by the compiler on a tree the validator would have rejected. A
/// programming error, surfaced through AsyncValue at the provider boundary.
class QueryCompileError extends Error {
  final String message;
  QueryCompileError(this.message);
  @override
  String toString() => 'QueryCompileError: $message';
}

class QueryJsonException implements Exception {
  final String message;
  const QueryJsonException(this.message);
  @override
  String toString() => 'QueryJsonException: $message';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/query/domain/query_node_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/domain test/core/query/domain/query_node_test.dart
git commit -m "feat(query): query model (AST, values, errors)"
```

---

### Task 2: JSON round trip for the AST

**Files:**
- Create: `lib/core/query/domain/query_json.dart`
- Test: `test/core/query/domain/query_json_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces: `Map<String, Object?> queryNodeToJson(QueryNode)`, `QueryNode queryNodeFromJson(Map<String, Object?>)`, `const int kQueryJsonVersion = 1`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/query/domain/query_json_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  final tree = OrNode([
    AndNode([
      ConditionNode(const FieldPath(['depth']), QueryOp.gt,
          const NumberValue(30.48, QueryUnit.ft)),
      ConditionNode(const FieldPath(['date']), QueryOp.between,
          ListValue([DateValue(DateTime(2025, 1, 1)), DateValue(DateTime(2025, 12, 31))])),
      ConditionNode(const FieldPath(['site']), QueryOp.eq,
          const RefValue('site-1', 'Salt Pier')),
      ConditionNode(const FieldPath(['favorite']), QueryOp.eq,
          const BoolValue(true)),
      ConditionNode(const FieldPath(['date']), QueryOp.inList,
          DateRangeValue(DateTime(2024, 3, 1), DateTime(2024, 3, 31))),
    ]),
    NotNode(ConditionNode(const FieldPath(['weights']), QueryOp.isSet, null)),
    ScopedNode(const FieldPath(['gear']),
        ConditionNode(const FieldPath(['type']), QueryOp.inList,
            const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]))),
    const TextNode(['night']),
  ]);

  test('round trips through JSON text', () {
    final text = jsonEncode(queryNodeToJson(tree));
    final back = queryNodeFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(back, equals(tree));
  });

  test('carries the version', () {
    expect(queryNodeToJson(tree)['version'], kQueryJsonVersion);
  });

  test('rejects a newer version, a missing node and a bad op', () {
    expect(() => queryNodeFromJson({'version': 99, 'node': {}}),
        throwsA(isA<QueryJsonException>()));
    expect(() => queryNodeFromJson({'version': 1}),
        throwsA(isA<QueryJsonException>()));
    expect(
        () => queryNodeFromJson({
              'version': 1,
              'node': {'t': 'cond', 'path': ['depth'], 'op': 'nope', 'value': null}
            }),
        throwsA(isA<QueryJsonException>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/query/domain/query_json_test.dart`
Expected: FAIL, `query_json.dart` missing.

- [ ] **Step 3: Write the codec**

```dart
// lib/core/query/domain/query_json.dart
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';

const int kQueryJsonVersion = 1;

Map<String, Object?> queryNodeToJson(QueryNode node) => {
  'version': kQueryJsonVersion,
  'node': _node(node),
};

Map<String, Object?> _node(QueryNode n) => switch (n) {
  AndNode(:final children) => {'t': 'and', 'c': children.map(_node).toList()},
  OrNode(:final children) => {'t': 'or', 'c': children.map(_node).toList()},
  NotNode(:final child) => {'t': 'not', 'c': _node(child)},
  ConditionNode(:final path, :final op, :final value) => {
    't': 'cond',
    'path': path.segments,
    'op': op.name,
    'value': value == null ? null : _value(value),
  },
  ScopedNode(:final path, :final inner) => {
    't': 'scoped',
    'path': path.segments,
    'inner': _node(inner),
  },
  TextNode(:final words) => {'t': 'text', 'words': words},
};

Map<String, Object?> _value(QueryValue v) => switch (v) {
  NumberValue(:final value, :final typedUnit) => {
    'k': 'num',
    'v': value,
    if (typedUnit != null) 'u': typedUnit.name,
  },
  StringValue(:final value) => {'k': 'str', 'v': value},
  BoolValue(:final value) => {'k': 'bool', 'v': value},
  EnumValue(:final name) => {'k': 'enum', 'v': name},
  DateValue(:final day) => {'k': 'date', 'v': _day(day)},
  DateRangeValue(:final start, :final end) => {
    'k': 'range',
    's': _day(start),
    'e': _day(end),
  },
  ListValue(:final items) => {'k': 'list', 'v': items.map(_value).toList()},
  RefValue(:final id, :final label) => {'k': 'ref', 'id': id, 'label': label},
};

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

QueryNode queryNodeFromJson(Map<String, Object?> json) {
  final version = json['version'];
  if (version is! int || version > kQueryJsonVersion || version < 1) {
    throw QueryJsonException('unsupported query version $version');
  }
  final node = json['node'];
  if (node is! Map<String, Object?>) {
    throw const QueryJsonException('missing node');
  }
  return _readNode(node);
}

QueryNode _readNode(Map<String, Object?> m) {
  switch (m['t']) {
    case 'and':
      return AndNode(_readList(m['c']).map(_readNode).toList());
    case 'or':
      return OrNode(_readList(m['c']).map(_readNode).toList());
    case 'not':
      return NotNode(_readNode(_readMap(m['c'])));
    case 'cond':
      final op = QueryOp.values.where((o) => o.name == m['op']).firstOrNull;
      if (op == null) throw QueryJsonException('unknown op ${m['op']}');
      final raw = m['value'];
      return ConditionNode(
        FieldPath(_readStrings(m['path'])),
        op,
        raw == null ? null : _readValue(_readMap(raw)),
      );
    case 'scoped':
      return ScopedNode(
        FieldPath(_readStrings(m['path'])),
        _readNode(_readMap(m['inner'])),
      );
    case 'text':
      return TextNode(_readStrings(m['words']));
    default:
      throw QueryJsonException('unknown node type ${m['t']}');
  }
}

QueryValue _readValue(Map<String, Object?> m) {
  switch (m['k']) {
    case 'num':
      final v = m['v'];
      if (v is! num) throw const QueryJsonException('bad number');
      final u = m['u'];
      return NumberValue(
        v.toDouble(),
        u == null ? null : QueryUnit.values.firstWhere((x) => x.name == u,
            orElse: () => throw QueryJsonException('unknown unit $u')),
      );
    case 'str':
      return StringValue(_str(m['v']));
    case 'bool':
      final v = m['v'];
      if (v is! bool) throw const QueryJsonException('bad bool');
      return BoolValue(v);
    case 'enum':
      return EnumValue(_str(m['v']));
    case 'date':
      return DateValue(_readDay(m['v']));
    case 'range':
      return DateRangeValue(_readDay(m['s']), _readDay(m['e']));
    case 'list':
      return ListValue(_readList(m['v']).map(_readMap).map(_readValue).toList());
    case 'ref':
      return RefValue(_str(m['id']), _str(m['label']));
    default:
      throw QueryJsonException('unknown value kind ${m['k']}');
  }
}

DateTime _readDay(Object? v) {
  final s = _str(v);
  final parts = s.split('-');
  if (parts.length != 3) throw QueryJsonException('bad day $s');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String _str(Object? v) {
  if (v is! String) throw QueryJsonException('expected a string, got $v');
  return v;
}

List<Object?> _readList(Object? v) {
  if (v is! List) throw QueryJsonException('expected a list, got $v');
  return v.cast<Object?>();
}

Map<String, Object?> _readMap(Object? v) {
  if (v is! Map) throw QueryJsonException('expected a map, got $v');
  return v.cast<String, Object?>();
}

List<String> _readStrings(Object? v) => _readList(v).map(_str).toList();
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/query/domain/query_json_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/domain/query_json.dart test/core/query/domain/query_json_test.dart
git commit -m "feat(query): versioned JSON codec for the AST"
```

---

### Task 3: Units, the date grammar, and the registry contract

**Files:**
- Create: `lib/core/query/units/unit_prefs.dart`
- Create: `lib/core/query/syntax/date_grammar.dart`
- Create: `lib/core/query/registry/query_field.dart`
- Create: `lib/core/query/registry/query_relation.dart`
- Create: `lib/core/query/registry/query_entity.dart`
- Create: `lib/core/query/registry/query_registry.dart`
- Test: `test/core/query/units/unit_prefs_test.dart`
- Test: `test/core/query/syntax/date_grammar_test.dart`
- Test: `test/core/query/registry/query_registry_test.dart`

**Interfaces:**
- Consumes: Task 1; `DepthUnit`, `TemperatureUnit`, `PressureUnit`, `WeightUnit`, `VolumeUnit` from `lib/core/constants/units.dart`.
- Produces: `UnitPrefs`, `kMetricPrefs`, `groundToStorage`, `storageToDisplay`, `parseDateText`, `DateRange`, `FieldType`, `FieldDimension`, `QueryField`, `RelationShape`, `QueryRelation`, `QueryEntity`, `QueryRegistry`, `PathResolution`, `resolvePath`, `kMaxPathHops`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/query/units/unit_prefs_test.dart
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

  test('an explicit unit wins over the preference', () {
    expect(groundToStorage(30, QueryUnit.m, FieldDimension.depth, imperial), 30);
  });

  test('a bare number takes the preference for its dimension', () {
    expect(groundToStorage(100, null, FieldDimension.depth, imperial),
        closeTo(30.48, 0.001));
    expect(groundToStorage(50, null, FieldDimension.temperature, imperial),
        closeTo(10, 0.001));
    expect(groundToStorage(10, null, FieldDimension.weight, imperial),
        closeTo(4.5359, 0.001));
  });

  test('a unitless dimension is never converted', () {
    expect(groundToStorage(32, null, FieldDimension.percent, imperial), 32);
    expect(groundToStorage(32, QueryUnit.ft, FieldDimension.percent, imperial), 32);
  });

  test('display converts back to the typed unit or the preference', () {
    final (v1, u1) = storageToDisplay(30.48, QueryUnit.ft, FieldDimension.depth, kMetricPrefs);
    expect(v1, closeTo(100, 0.001));
    expect(u1, QueryUnit.ft);
    final (v2, u2) = storageToDisplay(30, null, FieldDimension.depth, imperial);
    expect(v2, closeTo(98.425, 0.001));
    expect(u2, isNull);
  });
}
```

```dart
// test/core/query/syntax/date_grammar_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  test('years, months, days and ranges', () {
    expect(parseDateText('2025', now: now),
        (start: DateTime(2025, 1, 1), end: DateTime(2025, 12, 31)));
    expect(parseDateText('2025-02', now: now),
        (start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 28)));
    expect(parseDateText('2025-03-14', now: now),
        (start: DateTime(2025, 3, 14), end: DateTime(2025, 3, 14)));
    expect(parseDateText('2025-03-01 to 2025-03-10', now: now),
        (start: DateTime(2025, 3, 1), end: DateTime(2025, 3, 10)));
  });

  test('relative phrases', () {
    expect(parseDateText('this year', now: now)!.start, DateTime(2026, 1, 1));
    expect(parseDateText('last 90 days', now: now),
        (start: DateTime(2026, 6, 27), end: DateTime(2026, 9, 25)));
    expect(parseDateText('since 2024', now: now),
        (start: DateTime(2024, 1, 1), end: null));
  });

  test('garbage and impossible dates are null', () {
    expect(parseDateText('sometime', now: now), isNull);
    expect(parseDateText('2025-02-30', now: now), isNull);
  });
}
```

```dart
// test/core/query/registry/query_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, {List<String> aliases = const []}) => QueryField(
  key: key,
  aliases: aliases,
  type: FieldType.text,
  sql: '{r}.$key',
  emptySql: "{r}.$key IS NULL OR TRIM({r}.$key) = ''",
  labelKey: 'x',
);

final _b = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  fields: [_text('name')],
  relations: [
    QueryRelation(
      key: 'certifications',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.buddy_id = {from}.id',
      isMany: true,
      labelKey: 'x',
    ),
  ],
);
final _c = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  fields: [_text('level')],
);
final _d = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  fields: [_text('notes', aliases: ['note'])],
  relations: [
    QueryRelation(
      key: 'buddies',
      aliases: ['buddy'],
      target: QuerySubject.buddies,
      shape: RelationShape.junction,
      joinSql:
          'EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id AND j.buddy_id = {to}.id)',
      isMany: true,
      labelKey: 'x',
    ),
  ],
);
final registry = QueryRegistry([_d, _b, _c]);

void main() {
  test('resolves a field by key or alias', () {
    final r = resolvePath(registry, _d, const FieldPath(['note']));
    expect(r.error, isNull);
    expect(r.field!.key, 'notes');
    expect(r.hops, isEmpty);
  });

  test('resolves a multi-hop path through declared relations', () {
    final r = resolvePath(
        registry, _d, const FieldPath(['buddy', 'certifications', 'level']));
    expect(r.error, isNull);
    expect(r.hops.map((h) => h.key), ['buddies', 'certifications']);
    expect(r.field!.key, 'level');
  });

  test('a path ending in a relation has no field', () {
    final r = resolvePath(registry, _d, const FieldPath(['buddies']));
    expect(r.field, isNull);
    expect(r.terminalRelation!.key, 'buddies');
  });

  test('an unknown segment reports where and offers suggestions', () {
    final r = resolvePath(registry, _d, const FieldPath(['buddies', 'nmae']));
    expect(r.error!.message, contains('nmae'));
    expect(r.error!.suggestions, contains('name'));
    expect(r.errorSegment, 1);
  });

  test('a path deeper than kMaxPathHops is rejected', () {
    final deep = QueryEntity(
      subject: QuerySubject.sites,
      table: 'sites',
      relations: [
        QueryRelation(
          key: 'self',
          target: QuerySubject.sites,
          shape: RelationShape.child,
          joinSql: '{to}.id = {from}.id',
          isMany: true,
          labelKey: 'x',
        ),
      ],
      fields: [_text('name')],
    );
    final reg = QueryRegistry([deep]);
    final r = resolvePath(reg, deep,
        const FieldPath(['self', 'self', 'self', 'self', 'self', 'name']));
    expect(r.error!.message, contains('$kMaxPathHops'));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/query/units test/core/query/syntax/date_grammar_test.dart test/core/query/registry`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the units, grammar and registry**

```dart
// lib/core/query/units/unit_prefs.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// The diver's unit choices the parser and printer need. Built from
/// AppSettings by the provider layer so this file stays free of settings.
@immutable
class UnitPrefs {
  final DepthUnit depth;
  final TemperatureUnit temperature;
  final PressureUnit pressure;
  final WeightUnit weight;
  final VolumeUnit volume;
  const UnitPrefs({
    required this.depth,
    required this.temperature,
    required this.pressure,
    required this.weight,
    required this.volume,
  });
}

const kMetricPrefs = UnitPrefs(
  depth: DepthUnit.meters,
  temperature: TemperatureUnit.celsius,
  pressure: PressureUnit.bar,
  weight: WeightUnit.kilograms,
  volume: VolumeUnit.liters,
);

/// Converts a typed number to storage units. An explicit [unit] wins; a bare
/// number takes the diver's unit for [dimension]; a unitless dimension is
/// returned unchanged whatever [unit] says.
double groundToStorage(
  num value,
  QueryUnit? unit,
  FieldDimension dimension,
  UnitPrefs prefs,
) {
  final v = value.toDouble();
  switch (dimension) {
    case FieldDimension.depth:
      final from = switch (unit) {
        QueryUnit.m => DepthUnit.meters,
        QueryUnit.ft => DepthUnit.feet,
        _ => prefs.depth,
      };
      return from.convert(v, DepthUnit.meters);
    case FieldDimension.temperature:
      final from = switch (unit) {
        QueryUnit.c => TemperatureUnit.celsius,
        QueryUnit.f => TemperatureUnit.fahrenheit,
        _ => prefs.temperature,
      };
      return from.convert(v, TemperatureUnit.celsius);
    case FieldDimension.pressure:
      final from = switch (unit) {
        QueryUnit.bar => PressureUnit.bar,
        QueryUnit.psi => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return from.convert(v, PressureUnit.bar);
    case FieldDimension.weight:
      final from = switch (unit) {
        QueryUnit.kg => WeightUnit.kilograms,
        QueryUnit.lb => WeightUnit.pounds,
        _ => prefs.weight,
      };
      return from.convert(v, WeightUnit.kilograms);
    case FieldDimension.volume:
      final from = switch (unit) {
        QueryUnit.l => VolumeUnit.liters,
        QueryUnit.cuft => VolumeUnit.cubicFeet,
        _ => prefs.volume,
      };
      return from.convert(v, VolumeUnit.liters);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return v;
  }
}

/// The inverse for display: the storage value in [typedUnit] when one was
/// typed (suffix echoed), else in the diver's unit (no suffix).
(double, QueryUnit?) storageToDisplay(
  double storage,
  QueryUnit? typedUnit,
  FieldDimension dimension,
  UnitPrefs prefs,
) {
  switch (dimension) {
    case FieldDimension.depth:
      final to = switch (typedUnit) {
        QueryUnit.m => DepthUnit.meters,
        QueryUnit.ft => DepthUnit.feet,
        _ => prefs.depth,
      };
      return (DepthUnit.meters.convert(storage, to), typedUnit);
    case FieldDimension.temperature:
      final to = switch (typedUnit) {
        QueryUnit.c => TemperatureUnit.celsius,
        QueryUnit.f => TemperatureUnit.fahrenheit,
        _ => prefs.temperature,
      };
      return (TemperatureUnit.celsius.convert(storage, to), typedUnit);
    case FieldDimension.pressure:
      final to = switch (typedUnit) {
        QueryUnit.bar => PressureUnit.bar,
        QueryUnit.psi => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return (PressureUnit.bar.convert(storage, to), typedUnit);
    case FieldDimension.weight:
      final to = switch (typedUnit) {
        QueryUnit.kg => WeightUnit.kilograms,
        QueryUnit.lb => WeightUnit.pounds,
        _ => prefs.weight,
      };
      return (WeightUnit.kilograms.convert(storage, to), typedUnit);
    case FieldDimension.volume:
      final to = switch (typedUnit) {
        QueryUnit.l => VolumeUnit.liters,
        QueryUnit.cuft => VolumeUnit.cubicFeet,
        _ => prefs.volume,
      };
      return (VolumeUnit.liters.convert(storage, to), typedUnit);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return (storage, null);
  }
}
```

For `lib/core/query/syntax/date_grammar.dart`, copy `lib/features/explore/domain/time_grammar.dart` from the branch `origin/ericgriffin/explore-phase2-derived-predicates` (`git show origin/ericgriffin/explore-phase2-derived-predicates:lib/features/explore/domain/time_grammar.dart`), rename `parseTimeText` to `parseDateText`, keep `typedef DateRange = ({DateTime? start, DateTime? end});`, and add this doc line at the top: `/// Copied from Explore's time grammar; PR 5 of #2365 deletes that copy.` Keep every rule (year, ISO month, ISO date, ISO range, month-year, since, before, this/last year/month, last N days/weeks/months/years).

```dart
// lib/core/query/registry/query_field.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';

enum FieldType { number, text, bool, enumName, date, id }

enum FieldDimension {
  depth,
  temperature,
  pressure,
  weight,
  volume,
  minutes,
  percent,
  count,
  none,
}

const Set<QueryOp> kOrderingOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.lt,
  QueryOp.lte,
  QueryOp.gt,
  QueryOp.gte,
  QueryOp.between,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kTextOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.contains,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kMembershipOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
};
const Set<QueryOp> kBoolOps = {QueryOp.eq, QueryOp.neq};

/// One queryable field of an entity.
///
/// [sql] and [emptySql] are written against the placeholder `{r}`, the alias
/// of the entity's row at whatever nesting depth the compiler reaches it.
@immutable
class QueryField {
  final String key;
  final List<String> aliases;
  final FieldType type;
  final FieldDimension dimension;
  final String sql;
  final String emptySql;
  final Set<QueryOp> ops;
  final String labelKey;

  /// Stored names, for [FieldType.enumName]. The builder localizes them.
  final List<String>? enumValues;

  /// What each enum name binds as, when the column does not store the name
  /// itself (weekday stores 0..6). Defaults to the name.
  final Map<String, Object>? enumSqlValues;

  /// For [FieldType.bool] fields that are predicates rather than columns:
  /// the SQL for `= true` and for `= false`. When set, [sql] is unused.
  final ({String whenTrue, String whenFalse})? boolSql;

  /// Validation range in storage units, inclusive.
  final ({double min, double max})? sanity;

  /// Tables this field's SQL reads besides the entity's own (dive_weights
  /// inside weight's emptySql, the profile tables inside deco), for ticks.
  final List<String> tables;

  const QueryField({
    required this.key,
    this.aliases = const [],
    required this.type,
    this.dimension = FieldDimension.none,
    required this.sql,
    required this.emptySql,
    required this.labelKey,
    Set<QueryOp>? ops,
    this.enumValues,
    this.enumSqlValues,
    this.boolSql,
    this.sanity,
    this.tables = const [],
  }) : ops = ops ?? _defaultOps(type);

  static Set<QueryOp> _defaultOps(FieldType type) => switch (type) {
    FieldType.number || FieldType.date => kOrderingOps,
    FieldType.text => kTextOps,
    FieldType.enumName || FieldType.id => kMembershipOps,
    FieldType.bool => kBoolOps,
  };

  bool matches(String keyOrAlias) =>
      key == keyOrAlias || aliases.contains(keyOrAlias);
}
```

```dart
// lib/core/query/registry/query_relation.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';

/// Metadata for the guard tests; the compiler treats every shape the same.
enum RelationShape { fk, child, junction, custom }

/// A hop from one entity's row to rows of [target].
///
/// A relation is also how a row is named: `site = "Salt Pier"` is the
/// relation `site` with `=` and a [RefValue], compiled as the hop with
/// `{to}.id = ?` inside. There is no separate ref field type.
///
/// [joinSql] is the correlation predicate between the two rows, written
/// against `{from}` (the row we are on) and `{to}` (the target row). The
/// compiler emits `EXISTS (SELECT 1 FROM <target table> {to} WHERE
/// <joinSql> AND <inner>)`, so a junction hop writes its own nested EXISTS
/// over the junction table inside [joinSql].
@immutable
class QueryRelation {
  final String key;
  final List<String> aliases;
  final QuerySubject target;
  final RelationShape shape;
  final String joinSql;
  final bool isMany;
  final String labelKey;

  /// Overrides `NOT EXISTS` for `:none` when a legacy scalar also counts as
  /// "has one" (the dive's `buddy` text beside `dive_buddies`).
  final String? emptySql;

  /// Tables [joinSql] or [emptySql] read besides the target (a junction).
  final List<String> tables;

  const QueryRelation({
    required this.key,
    this.aliases = const [],
    required this.target,
    required this.shape,
    required this.joinSql,
    required this.isMany,
    required this.labelKey,
    this.emptySql,
    this.tables = const [],
  });

  bool matches(String keyOrAlias) =>
      key == keyOrAlias || aliases.contains(keyOrAlias);
}
```

```dart
// lib/core/query/registry/query_entity.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

@immutable
class QueryEntity {
  final QuerySubject subject;
  final String table;
  final String idColumn;

  /// The per-diver column, or null for a table shared across divers. The
  /// CALLER applies the scope, never the compiler.
  final String? diverScopeColumn;
  final List<QueryField> fields;
  final List<QueryRelation> relations;

  /// What a bare [TextNode] word searches, as SQL templates over `{r}` with
  /// one or more `?` each; every `?` binds the LIKE term.
  final List<String> textSearchSql;

  /// Tables [textSearchSql] reads besides the entity's own.
  final List<String> textSearchTables;

  const QueryEntity({
    required this.subject,
    required this.table,
    this.idColumn = 'id',
    this.diverScopeColumn,
    this.fields = const [],
    this.relations = const [],
    this.textSearchSql = const [],
    this.textSearchTables = const [],
  });

  QueryField? field(String keyOrAlias) =>
      fields.where((f) => f.matches(keyOrAlias)).firstOrNull;

  QueryRelation? relation(String keyOrAlias) =>
      relations.where((r) => r.matches(keyOrAlias)).firstOrNull;

  /// Every name a path segment may use here, for suggestions.
  Iterable<String> get segmentNames => [
    for (final f in fields) ...[f.key, ...f.aliases],
    for (final r in relations) ...[r.key, ...r.aliases],
  ];
}
```

```dart
// lib/core/query/registry/query_registry.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';

/// A path may cross at most this many relations. A hard cap, so a typo like
/// `site.dives.site.dives` cannot fan out.
const int kMaxPathHops = 4;

@immutable
class QueryRegistry {
  final Map<QuerySubject, QueryEntity> _entities;

  QueryRegistry(List<QueryEntity> entities)
    : _entities = {for (final e in entities) e.subject: e};

  QueryEntity entityFor(QuerySubject subject) {
    final e = _entities[subject];
    if (e == null) throw StateError('no query entity for $subject');
    return e;
  }

  QueryEntity? maybeEntityFor(QuerySubject subject) => _entities[subject];

  Iterable<QueryEntity> get entities => _entities.values;
}

/// What a [FieldPath] names, walked from [root] through the registry.
///
/// Exactly one of [field] and [terminalRelation] is set on success; on
/// failure [error] is set and [errorSegment] indexes the bad segment.
@immutable
class PathResolution {
  final List<QueryRelation> hops;
  final List<QueryEntity> entities;
  final QueryField? field;
  final QueryRelation? terminalRelation;
  final QueryError? error;
  final int? errorSegment;

  const PathResolution({
    this.hops = const [],
    this.entities = const [],
    this.field,
    this.terminalRelation,
    this.error,
    this.errorSegment,
  });

  /// The entity the last segment belongs to.
  QueryEntity get leafEntity => entities.last;
}

PathResolution resolvePath(
  QueryRegistry registry,
  QueryEntity root,
  FieldPath path,
) {
  if (path.segments.isEmpty) {
    return const PathResolution(
      error: QueryError('empty path'),
      errorSegment: 0,
    );
  }
  final hops = <QueryRelation>[];
  final entities = <QueryEntity>[root];
  var current = root;
  for (var i = 0; i < path.segments.length; i++) {
    final seg = path.segments[i];
    final isLast = i == path.segments.length - 1;
    final field = current.field(seg);
    if (field != null) {
      if (!isLast) {
        return PathResolution(
          hops: hops,
          entities: entities,
          error: QueryError(
            '"$seg" is a field and cannot be followed by ".${path.segments[i + 1]}"',
            path: path,
          ),
          errorSegment: i + 1,
        );
      }
      return PathResolution(hops: hops, entities: entities, field: field);
    }
    final relation = current.relation(seg);
    if (relation == null) {
      return PathResolution(
        hops: hops,
        entities: entities,
        error: QueryError(
          'unknown field "$seg"',
          path: path,
          suggestions: suggestNames(seg, current.segmentNames),
        ),
        errorSegment: i,
      );
    }
    hops.add(relation);
    if (hops.length > kMaxPathHops) {
      return PathResolution(
        hops: hops,
        entities: entities,
        error: QueryError(
          'a path may cross at most $kMaxPathHops relations',
          path: path,
        ),
        errorSegment: i,
      );
    }
    final next = registry.maybeEntityFor(relation.target);
    if (next == null) {
      throw StateError(
        'relation ${relation.key} targets ${relation.target}, '
        'which has no query entity',
      );
    }
    entities.add(next);
    current = next;
    if (isLast) {
      return PathResolution(
        hops: hops,
        entities: entities,
        terminalRelation: relation,
      );
    }
  }
  throw StateError('unreachable');
}
```

```dart
// lib/core/query/syntax/query_suggestions.dart
import 'package:submersion/core/text/fuzzy_match.dart';

/// Up to five candidates for a mistyped name, best first, by Dice
/// similarity over bigrams (the site resolver's measure). A prefix match
/// always ranks, so a partial word while typing still suggests.
List<String> suggestNames(String typed, Iterable<String> candidates) {
  final t = typed.toLowerCase();
  final scored = <(String, double)>[];
  for (final c in candidates) {
    final lower = c.toLowerCase();
    final score = lower.startsWith(t) && t.isNotEmpty
        ? 1.0
        : diceCoefficient(t, lower);
    if (score >= 0.4) scored.add((c, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(5)) s.$1];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/query/units test/core/query/syntax/date_grammar_test.dart test/core/query/registry`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/units lib/core/query/syntax/date_grammar.dart lib/core/query/syntax/query_suggestions.dart lib/core/query/registry test/core/query/units test/core/query/syntax/date_grammar_test.dart test/core/query/registry
git commit -m "feat(query): unit grounding, date grammar and the registry contract"
```

---

### Task 4: Tokenizer and parser

**Files:**
- Create: `lib/core/query/syntax/query_tokenizer.dart`
- Create: `lib/core/query/syntax/query_parser.dart`
- Test: `test/core/query/syntax/query_tokenizer_test.dart`
- Test: `test/core/query/syntax/query_parser_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 3.
- Produces: `Token`, `TokenKind`, `tokenize`, `TokenizeException`; `ParseContext`, `NameResolver`, `MapNameResolver`, `ParseResult` (`ParseOk` | `ParseFailure`), `QueryParser`.

The tests use a small fixture registry shared with later syntax tests. Create it first.

- [ ] **Step 1: Write the fixture registry**

```dart
// test/core/query/fixtures/fixture_registry.dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// A small dive-shaped registry for syntax and compiler tests: enough field
/// types and relation shapes to exercise every rule without the real one.
final fixtureDives = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    '{r}.notes LIKE ? ESCAPE \'\\\'',
    'EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = {r}.site_id AND ts.name LIKE ? ESCAPE \'\\\')',
  ],
  textSearchTables: const ['dive_sites'],
  fields: [
    const QueryField(
      key: 'id',
      type: FieldType.id,
      sql: '{r}.id',
      emptySql: '{r}.id IS NULL',
      labelKey: 'x',
    ),
    const QueryField(
      key: 'depth',
      aliases: ['maxDepth'],
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'x',
      sanity: (min: 0, max: 400),
    ),
    const QueryField(
      key: 'waterTemp',
      aliases: ['temp'],
      type: FieldType.number,
      dimension: FieldDimension.temperature,
      sql: '{r}.water_temp',
      emptySql: '{r}.water_temp IS NULL',
      labelKey: 'x',
      sanity: (min: -5, max: 45),
    ),
    const QueryField(
      key: 'bottomTime',
      aliases: ['time'],
      type: FieldType.number,
      dimension: FieldDimension.minutes,
      sql: '({r}.bottom_time / 60)',
      emptySql: '{r}.bottom_time IS NULL',
      labelKey: 'x',
    ),
    const QueryField(
      key: 'rating',
      type: FieldType.number,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'x',
      sanity: (min: 0, max: 5),
    ),
    const QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'x',
    ),
    const QueryField(
      key: 'favorite',
      type: FieldType.bool,
      sql: '{r}.is_favorite',
      emptySql: '0',
      labelKey: 'x',
    ),
    const QueryField(
      key: 'deco',
      type: FieldType.bool,
      sql: '',
      emptySql: '0',
      labelKey: 'x',
      boolSql: (whenTrue: '({r}.deco_flag = 1)', whenFalse: '({r}.deco_flag = 0)'),
    ),
    const QueryField(
      key: 'waterType',
      type: FieldType.enumName,
      sql: '{r}.water_type',
      emptySql: '{r}.water_type IS NULL',
      labelKey: 'x',
      enumValues: ['salt', 'fresh', 'brackish'],
    ),
    const QueryField(
      key: 'weekday',
      type: FieldType.enumName,
      sql: "CAST(strftime('%w', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)",
      emptySql: '0',
      labelKey: 'x',
      enumValues: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      enumSqlValues: {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 0},
    ),
    const QueryField(
      key: 'date',
      type: FieldType.date,
      sql: '{r}.dive_date_time',
      emptySql: '{r}.dive_date_time IS NULL',
      labelKey: 'x',
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'site',
      target: QuerySubject.sites,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.site_id',
      isMany: false,
      labelKey: 'x',
    ),
    QueryRelation(
      key: 'weights',
      target: QuerySubject.weights,
      shape: RelationShape.child,
      joinSql: '{to}.dive_id = {from}.id',
      isMany: true,
      labelKey: 'x',
    ),
    QueryRelation(
      key: 'buddies',
      target: QuerySubject.buddies,
      shape: RelationShape.junction,
      joinSql: 'EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id AND j.buddy_id = {to}.id)',
      isMany: true,
      labelKey: 'x',
      emptySql: "(({from}.buddy IS NULL OR {from}.buddy = '') AND NOT EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id))",
      tables: ['dive_buddies'],
    ),
    QueryRelation(
      key: 'gear',
      target: QuerySubject.equipment,
      shape: RelationShape.custom,
      joinSql: '{to}.id IN (SELECT de.equipment_id FROM dive_equipment de WHERE de.dive_id = {from}.id)',
      isMany: true,
      labelKey: 'x',
      tables: ['dive_equipment'],
    ),
  ],
);

final fixtureSites = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  fields: const [
    QueryField(key: 'name', type: FieldType.text, sql: '{r}.name', emptySql: "TRIM({r}.name) = ''", labelKey: 'x'),
    QueryField(key: 'country', type: FieldType.text, sql: '{r}.country', emptySql: '{r}.country IS NULL', labelKey: 'x'),
  ],
);

final fixtureWeights = QueryEntity(
  subject: QuerySubject.weights,
  table: 'dive_weights',
  fields: const [
    QueryField(key: 'amount', type: FieldType.number, dimension: FieldDimension.weight, sql: '{r}.amount_kg', emptySql: '{r}.amount_kg IS NULL', labelKey: 'x'),
  ],
);

final fixtureBuddies = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  fields: const [
    QueryField(key: 'name', type: FieldType.text, sql: '{r}.name', emptySql: "TRIM({r}.name) = ''", labelKey: 'x'),
  ],
  relations: const [
    QueryRelation(key: 'certifications', target: QuerySubject.certifications, shape: RelationShape.child, joinSql: '{to}.buddy_id = {from}.id', isMany: true, labelKey: 'x'),
  ],
);

final fixtureCertifications = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  fields: const [
    QueryField(key: 'level', type: FieldType.text, sql: '{r}.level', emptySql: '{r}.level IS NULL', labelKey: 'x'),
  ],
);

final fixtureEquipment = QueryEntity(
  subject: QuerySubject.equipment,
  table: 'equipment',
  fields: const [
    QueryField(key: 'type', type: FieldType.enumName, sql: '{r}.type', emptySql: '{r}.type IS NULL', labelKey: 'x', enumValues: ['wetsuit', 'drysuit', 'bcd', 'regulator']),
  ],
);

final fixtureRegistry = QueryRegistry([
  fixtureDives,
  fixtureSites,
  fixtureWeights,
  fixtureBuddies,
  fixtureCertifications,
  fixtureEquipment,
]);

/// The one site the fixture resolver knows.
const kFixtureSite = RefValue('site-1', 'Salt Pier');
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/core/query/syntax/query_tokenizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';

void main() {
  test('splits words, numbers with suffixes, symbols and quotes', () {
    final t = tokenize('depth >= 100ft AND site.country = "Bob\'s \\"Reef\\"" -tag:none (x)');
    expect(t.map((x) => x.kind), [
      TokenKind.word, TokenKind.symbol, TokenKind.number, TokenKind.word,
      TokenKind.word, TokenKind.symbol, TokenKind.quoted, TokenKind.symbol,
      TokenKind.word, TokenKind.symbol, TokenKind.word, TokenKind.symbol,
      TokenKind.word, TokenKind.symbol, TokenKind.end,
    ]);
    expect(t[2].text, '100ft');
    expect(t[6].text, 'Bob\'s "Reef"');
    expect(t[6].offset, 28);
  });

  test('ISO dates are words, not numbers', () {
    expect(tokenize('2025-03-14').first.kind, TokenKind.word);
    expect(tokenize('2025-03').first.kind, TokenKind.word);
    expect(tokenize('2025').first.kind, TokenKind.number);
  });

  test('two-character operators are one symbol', () {
    final t = tokenize('a != b <= c >= d');
    expect(t.where((x) => x.kind == TokenKind.symbol).map((x) => x.text),
        ['!=', '<=', '>=']);
  });

  test('an unterminated quote reports its offset', () {
    expect(() => tokenize('site = "Salt'),
        throwsA(isA<TokenizeException>().having((e) => e.offset, 'offset', 7)));
  });
}
```

```dart
// test/core/query/syntax/query_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final now = DateTime(2026, 9, 25);
  final names = MapNameResolver({
    QuerySubject.sites: {'Salt Pier': 'site-1', 'Salt Pier Deep': 'site-2', 'Hilma Hooker': 'site-3'},
  });
  QueryParser metric() => QueryParser(fixtureRegistry, fixtureDives,
      ParseContext(prefs: kMetricPrefs, now: now, names: names));
  QueryParser imperial() => QueryParser(
      fixtureRegistry,
      fixtureDives,
      ParseContext(
          prefs: const UnitPrefs(
              depth: DepthUnit.feet,
              temperature: TemperatureUnit.fahrenheit,
              pressure: PressureUnit.psi,
              weight: WeightUnit.pounds,
              volume: VolumeUnit.cubicFeet),
          now: now,
          names: names));

  QueryNode ok(QueryParser p, String s) {
    final r = p.parse(s);
    expect(r, isA<ParseOk>(), reason: '$r');
    return (r as ParseOk).node!;
  }

  ParseFailure bad(QueryParser p, String s) {
    final r = p.parse(s);
    expect(r, isA<ParseFailure>(), reason: 'parsed $s as ${(r as ParseOk).node}');
    return r as ParseFailure;
  }

  test('empty text is an empty query', () {
    expect((metric().parse('   ') as ParseOk).node, isNull);
  });

  test('numbers ground to storage: bare in the preference, suffix explicit', () {
    expect(ok(metric(), 'depth > 30'),
        ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)));
    final imp = ok(imperial(), 'depth > 100') as ConditionNode;
    expect((imp.value as NumberValue).value, closeTo(30.48, 0.001));
    final ft = ok(metric(), 'depth > 100ft') as ConditionNode;
    expect((ft.value as NumberValue).typedUnit, QueryUnit.ft);
    expect((ft.value as NumberValue).value, closeTo(30.48, 0.001));
    expect(ok(metric(), 'temp < -2'),
        ConditionNode(const FieldPath(['waterTemp']), QueryOp.lt, const NumberValue(-2, null)));
  });

  test('precedence: NOT, then AND (juxtaposition), then OR; parens group', () {
    expect(
      ok(metric(), 'depth > 30 rating >= 4 OR NOT favorite = true'),
      OrNode([
        AndNode([
          ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
          ConditionNode(const FieldPath(['rating']), QueryOp.gte, const NumberValue(4, null)),
        ]),
        NotNode(ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true))),
      ]),
    );
    expect(
      ok(metric(), '(weights:none | temp:none) & rating:any'),
      AndNode([
        OrNode([
          ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
          ConditionNode(const FieldPath(['waterTemp']), QueryOp.isEmpty, null),
        ]),
        ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null),
      ]),
    );
  });

  test('the colon shorthand follows the field type', () {
    expect(ok(metric(), 'waterType:salt'),
        ConditionNode(const FieldPath(['waterType']), QueryOp.eq, const EnumValue('salt')));
    expect(ok(metric(), 'notes:manta'),
        ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('manta')));
    expect(ok(metric(), 'depth:30'),
        ConditionNode(const FieldPath(['depth']), QueryOp.eq, const NumberValue(30, null)));
  });

  test('lists, between, contains and negation', () {
    expect(ok(metric(), 'waterType in [salt, Fresh]'),
        ConditionNode(const FieldPath(['waterType']), QueryOp.inList,
            const ListValue([EnumValue('salt'), EnumValue('fresh')])));
    expect(ok(metric(), 'depth between 18 and 30'),
        ConditionNode(const FieldPath(['depth']), QueryOp.between,
            const ListValue([NumberValue(18, null), NumberValue(30, null)])));
    expect(ok(metric(), 'notes ~ "night dive"'),
        ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('night dive')));
    expect(ok(metric(), '-favorite = true'),
        NotNode(ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true))));
  });

  test('dates: a day, a year, a month, quoted phrases, open ranges', () {
    expect(ok(metric(), 'date >= 2025-01-15'),
        ConditionNode(const FieldPath(['date']), QueryOp.gte, DateValue(DateTime(2025, 1, 15))));
    expect(ok(metric(), 'date in 2025'),
        ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31))));
    expect(ok(metric(), 'date = 2025-03'),
        ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 31))));
    expect(ok(metric(), 'date in "last 90 days"'),
        ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2026, 6, 27), DateTime(2026, 9, 25))));
    expect(ok(metric(), 'date in "since 2024"'),
        ConditionNode(const FieldPath(['date']), QueryOp.gte, DateValue(DateTime(2024, 1, 1))));
  });

  test('refs resolve by name and report candidates when they do not', () {
    expect(ok(metric(), 'site = "Salt Pier"'),
        ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite));
    final f = bad(metric(), 'site = "Salt Peer"');
    expect(f.error.suggestions, contains('Salt Pier'));
    expect(f.error.offset, 7);
  });

  test('paths, scoped groups and bare text', () {
    expect(ok(metric(), 'site.country = Mexico'),
        ConditionNode(const FieldPath(['site', 'country']), QueryOp.eq, const StringValue('Mexico')));
    expect(ok(metric(), 'buddies.certifications.level = rescue'),
        ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.eq, const StringValue('rescue')));
    expect(ok(metric(), 'gear[type in [wetsuit, drysuit]]'),
        ScopedNode(const FieldPath(['gear']),
            ConditionNode(const FieldPath(['type']), QueryOp.inList,
                const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]))));
    expect(ok(metric(), '"night dive" manta'),
        const AndNode([TextNode(['night', 'dive']), TextNode(['manta'])]));
    expect(ok(metric(), 'depth'), const TextNode(['depth']));
  });

  test('positioned errors', () {
    expect(bad(metric(), 'depht > 30').error.suggestions, contains('depth'));
    expect(bad(metric(), 'depht > 30').error.offset, 0);
    expect(bad(metric(), 'depth > 18,5').error.message, contains(','));
    expect(bad(metric(), 'depth > 18,5').error.offset, 10);
    expect(bad(metric(), 'waterType in []').error.message, contains('empty'));
    expect(bad(metric(), 'rating > 3m').error.message, contains('unit'));
    expect(bad(metric(), 'depth > 30xx').error.message, contains('unit'));
    expect(bad(metric(), 'waterType = lake').error.suggestions, contains('salt'));
    expect(bad(metric(), 'favorite ~ x').error.message, contains('~'));
    expect(bad(metric(), '(depth > 30').error.message, contains(')'));
    expect(bad(metric(), 'depth > ').error.message, contains('value'));
    expect(bad(metric(), 'weights = 3').error.message, contains('no weights named'));
    expect(bad(metric(), 'weights > 3').error.message, contains('relation'));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core/query/syntax/query_tokenizer_test.dart test/core/query/syntax/query_parser_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 4: Write the tokenizer**

```dart
// lib/core/query/syntax/query_tokenizer.dart
import 'package:meta/meta.dart';

enum TokenKind { word, quoted, number, symbol, end }

@immutable
class Token {
  final TokenKind kind;

  /// For [TokenKind.quoted], the unescaped content; otherwise the raw text.
  final String text;
  final int offset;

  /// Source length, so a quoted token spans its quotes and escapes.
  final int length;
  const Token(this.kind, this.text, this.offset, this.length);
  @override
  String toString() => '$kind($text)@$offset';
}

class TokenizeException implements Exception {
  final String message;
  final int offset;
  const TokenizeException(this.message, this.offset);
  @override
  String toString() => 'TokenizeException($message @$offset)';
}

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}(-\d{2})?(?![\w.])');
final RegExp _number = RegExp(r'^\d+(\.\d+)?[A-Za-z]*');
const _twoCharSymbols = {'!=', '<=', '>='};
const _oneCharSymbols = {'(', ')', '[', ']', ',', ':', '~', '-', '&', '|', '=', '<', '>'};

bool _isWordChar(String c) =>
    c.trim().isNotEmpty && !_oneCharSymbols.contains(c) && c != '"' && c != '!';

List<Token> tokenize(String input) {
  final out = <Token>[];
  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '"') {
      final buf = StringBuffer();
      var j = i + 1;
      var closed = false;
      while (j < input.length) {
        final d = input[j];
        if (d == '\\' && j + 1 < input.length) {
          buf.write(input[j + 1]);
          j += 2;
          continue;
        }
        if (d == '"') {
          closed = true;
          j++;
          break;
        }
        buf.write(d);
        j++;
      }
      if (!closed) throw TokenizeException('unterminated quote', i);
      out.add(Token(TokenKind.quoted, buf.toString(), i, j - i));
      i = j;
      continue;
    }
    final rest = input.substring(i);
    if (i + 2 <= input.length && _twoCharSymbols.contains(input.substring(i, i + 2))) {
      out.add(Token(TokenKind.symbol, input.substring(i, i + 2), i, 2));
      i += 2;
      continue;
    }
    if (_oneCharSymbols.contains(c)) {
      out.add(Token(TokenKind.symbol, c, i, 1));
      i++;
      continue;
    }
    final iso = _isoDate.firstMatch(rest);
    if (iso != null) {
      out.add(Token(TokenKind.word, iso[0]!, i, iso[0]!.length));
      i += iso[0]!.length;
      continue;
    }
    final num = _number.firstMatch(rest);
    if (num != null) {
      out.add(Token(TokenKind.number, num[0]!, i, num[0]!.length));
      i += num[0]!.length;
      continue;
    }
    var j = i;
    while (j < input.length && _isWordChar(input[j])) {
      j++;
    }
    if (j == i) throw TokenizeException('unexpected character "$c"', i);
    out.add(Token(TokenKind.word, input.substring(i, j), i, j - i));
    i = j;
  }
  out.add(Token(TokenKind.end, '', input.length, 0));
  return out;
}
```

- [ ] **Step 5: Write the parser**

```dart
// lib/core/query/syntax/query_parser.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

export 'package:submersion/core/query/domain/query_errors.dart' show ParseFailure;

/// Resolves a typed name to a row of [kind]. The NameIndex from Explore
/// implements this in PR 5; PR 2's editor builds one from the repositories.
abstract class NameResolver {
  RefValue? resolve(QuerySubject kind, String text);
  List<String> candidates(QuerySubject kind, String text);
}

/// Exact, case-insensitive label lookup over an in-memory map. For tests
/// and for callers that already hold the labels.
class MapNameResolver implements NameResolver {
  final Map<QuerySubject, Map<String, String>> labelsToIds;
  const MapNameResolver(this.labelsToIds);

  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final labels = labelsToIds[kind] ?? const {};
    for (final e in labels.entries) {
      if (e.key.toLowerCase() == text.toLowerCase()) {
        return RefValue(e.value, e.key);
      }
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, (labelsToIds[kind] ?? const {}).keys);
}

@immutable
class ParseContext {
  final UnitPrefs prefs;
  final DateTime now;
  final NameResolver names;
  const ParseContext({required this.prefs, required this.now, required this.names});
}

sealed class ParseResult {
  const ParseResult();
}

class ParseOk extends ParseResult {
  /// Null for an empty query, which matches everything.
  final QueryNode? node;
  const ParseOk(this.node);
  @override
  String toString() => 'ParseOk($node)';
}

class _Abort implements Exception {
  final QueryError error;
  _Abort(this.error);
}

/// Words the parser reads as syntax; the printer quotes text equal to one.
const Set<String> kQueryKeywords = {'and', 'or', 'not', 'in', 'between', 'none', 'any', 'true', 'false'};

class QueryParser {
  final QueryRegistry registry;
  final QueryEntity root;
  final ParseContext context;

  QueryParser(this.registry, this.root, this.context);

  late List<Token> _tokens;
  int _pos = 0;

  /// The entity a path is resolved against; a scoped group pushes its
  /// relation's target while parsing the bracketed inner query.
  late List<QueryEntity> _scope;

  ParseResult parse(String text) {
    try {
      _tokens = tokenize(text);
    } on TokenizeException catch (e) {
      return ParseFailure(QueryError(e.message, offset: e.offset, length: 1));
    }
    _pos = 0;
    _scope = [root];
    try {
      if (_peek.kind == TokenKind.end) return const ParseOk(null);
      final node = _or();
      if (_peek.kind != TokenKind.end) {
        throw _Abort(_err('unexpected "${_peek.text}"', _peek));
      }
      return ParseOk(node);
    } on _Abort catch (a) {
      return ParseFailure(a.error);
    }
  }

  Token get _peek => _tokens[_pos];
  Token _next() => _tokens[_pos++];
  QueryEntity get _entity => _scope.last;

  QueryError _err(String message, Token at, {List<String> suggestions = const []}) =>
      QueryError(message, offset: at.offset, length: at.length == 0 ? 1 : at.length, suggestions: suggestions);

  bool _isKeyword(Token t, String kw) =>
      t.kind == TokenKind.word && t.text.toLowerCase() == kw;
  bool _isSymbol(Token t, String s) => t.kind == TokenKind.symbol && t.text == s;

  QueryNode _or() {
    final parts = [_and()];
    while (_isKeyword(_peek, 'or') || _isSymbol(_peek, '|')) {
      _next();
      parts.add(_and());
    }
    return parts.length == 1 ? parts.first : OrNode(parts);
  }

  bool _startsPrimary(Token t) =>
      t.kind == TokenKind.word && !_isKeyword(t, 'or') && !_isKeyword(t, 'and') ||
      t.kind == TokenKind.quoted ||
      t.kind == TokenKind.number ||
      _isSymbol(t, '(') ||
      _isSymbol(t, '-');

  QueryNode _and() {
    final parts = [_not()];
    while (true) {
      if (_isKeyword(_peek, 'and') || _isSymbol(_peek, '&')) {
        _next();
        parts.add(_not());
      } else if (_startsPrimary(_peek)) {
        parts.add(_not());
      } else {
        break;
      }
    }
    return parts.length == 1 ? parts.first : AndNode(parts);
  }

  QueryNode _not() {
    if (_isKeyword(_peek, 'not') || _isSymbol(_peek, '-')) {
      _next();
      return NotNode(_not());
    }
    return _primary();
  }

  QueryNode _primary() {
    final t = _peek;
    if (_isSymbol(t, '(')) {
      _next();
      final inner = _or();
      if (!_isSymbol(_peek, ')')) throw _Abort(_err('expected ")"', _peek));
      _next();
      return inner;
    }
    if (t.kind == TokenKind.quoted) {
      _next();
      return TextNode(t.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList());
    }
    if (t.kind == TokenKind.number) {
      _next();
      return TextNode([t.text]);
    }
    if (t.kind == TokenKind.word) {
      final after = _tokens[_pos + 1];
      if (_operatorFollows(after)) {
        return _condition();
      }
      _next();
      return TextNode([t.text]);
    }
    throw _Abort(_err('expected a condition or text', t));
  }

  bool _operatorFollows(Token t) =>
      (t.kind == TokenKind.symbol && const {'=', '!=', '<', '<=', '>', '>=', '~', ':', '['}.contains(t.text)) ||
      _isKeyword(t, 'in') ||
      _isKeyword(t, 'between');

  QueryNode _condition() {
    final pathTok = _next();
    final path = FieldPath(pathTok.text.split('.'));
    final res = resolvePath(registry, _entity, path);
    if (res.error != null) {
      final seg = res.errorSegment ?? 0;
      final segOffset = pathTok.offset + path.segments.take(seg).fold<int>(0, (n, s) => n + s.length + 1);
      throw _Abort(QueryError(res.error!.message,
          offset: segOffset, length: path.segments[seg].length, suggestions: res.error!.suggestions));
    }
    final opTok = _next();

    if (_isSymbol(opTok, '[')) {
      final rel = res.terminalRelation;
      if (rel == null) throw _Abort(_err('"[...]" needs a relation, "$path" is a field', pathTok));
      _scope.add(registry.entityFor(rel.target));
      final inner = _or();
      _scope.removeLast();
      if (!_isSymbol(_peek, ']')) throw _Abort(_err('expected "]"', _peek));
      _next();
      return ScopedNode(path, inner);
    }

    if (_isSymbol(opTok, ':')) {
      final v = _peek;
      if (_isKeyword(v, 'none')) {
        _next();
        return ConditionNode(path, QueryOp.isEmpty, null);
      }
      if (_isKeyword(v, 'any')) {
        _next();
        return ConditionNode(path, QueryOp.isSet, null);
      }
      if (res.terminalRelation != null) return _relationRef(path, res.terminalRelation!, opTok);
      final field = _fieldOrAbort(res, pathTok);
      final op = field.type == FieldType.text ? QueryOp.contains : QueryOp.eq;
      _requireOp(field, op, opTok);
      return ConditionNode(path, op, _value(field, op));
    }

    if (res.terminalRelation != null) return _relationRef(path, res.terminalRelation!, opTok);
    final field = _fieldOrAbort(res, pathTok);
    if (_isKeyword(opTok, 'in')) {
      _requireOp(field, QueryOp.inList, opTok);
      if (field.type == FieldType.date && !_isSymbol(_peek, '[')) {
        return _dateCondition(path, QueryOp.inList, field);
      }
      if (!_isSymbol(_peek, '[')) throw _Abort(_err('expected "[" after "in"', _peek));
      final open = _next();
      final items = <QueryValue>[];
      while (!_isSymbol(_peek, ']')) {
        if (_peek.kind == TokenKind.end) throw _Abort(_err('expected "]"', _peek));
        items.add(_value(field, QueryOp.inList));
        if (_isSymbol(_peek, ',')) _next();
      }
      _next();
      if (items.isEmpty) throw _Abort(_err('the list is empty', open));
      return ConditionNode(path, QueryOp.inList, ListValue(items));
    }
    if (_isKeyword(opTok, 'between')) {
      _requireOp(field, QueryOp.between, opTok);
      final a = _value(field, QueryOp.between);
      if (!_isKeyword(_peek, 'and')) throw _Abort(_err('expected "and"', _peek));
      _next();
      final b = _value(field, QueryOp.between);
      return ConditionNode(path, QueryOp.between, ListValue([a, b]));
    }
    final op = switch (opTok.text) {
      '=' => QueryOp.eq,
      '!=' => QueryOp.neq,
      '<' => QueryOp.lt,
      '<=' => QueryOp.lte,
      '>' => QueryOp.gt,
      '>=' => QueryOp.gte,
      '~' => QueryOp.contains,
      _ => null,
    };
    if (op == null) throw _Abort(_err('expected an operator', opTok));
    _requireOp(field, op, opTok);
    if (field.type == FieldType.date) return _dateCondition(path, op, field);
    return ConditionNode(path, op, _value(field, op));
  }

  QueryField _fieldOrAbort(PathResolution res, Token pathTok) {
    final f = res.field;
    if (f == null) {
      throw _Abort(_err('"${pathTok.text}" is a relation; use =, in, :none, :any or [...]', pathTok));
    }
    return f;
  }

  /// `site = "Salt Pier"`, `site != x`, `site in [a, b]`, `site:name`: a
  /// relation named by a row of its target.
  QueryNode _relationRef(FieldPath path, QueryRelation rel, Token opTok) {
    if (_isKeyword(opTok, 'in')) {
      if (!_isSymbol(_peek, '[')) throw _Abort(_err('expected "[" after "in"', _peek));
      final open = _next();
      final items = <QueryValue>[];
      while (!_isSymbol(_peek, ']')) {
        if (_peek.kind == TokenKind.end) throw _Abort(_err('expected "]"', _peek));
        items.add(_refValue(rel));
        if (_isSymbol(_peek, ',')) _next();
      }
      _next();
      if (items.isEmpty) throw _Abort(_err('the list is empty', open));
      return ConditionNode(path, QueryOp.inList, ListValue(items));
    }
    final op = switch (opTok.text) {
      '=' || ':' => QueryOp.eq,
      '!=' => QueryOp.neq,
      _ => throw _Abort(_err('"${opTok.text}" cannot be used with a relation', opTok)),
    };
    return ConditionNode(path, op, _refValue(rel));
  }

  RefValue _refValue(QueryRelation rel) {
    final tok = _next();
    if (tok.kind == TokenKind.symbol || tok.kind == TokenKind.end) {
      throw _Abort(_err('expected a name', tok));
    }
    final ref = context.names.resolve(rel.target, tok.text);
    if (ref == null) {
      throw _Abort(_err('no ${rel.key} named "${tok.text}"', tok,
          suggestions: context.names.candidates(rel.target, tok.text)));
    }
    return ref;
  }

  /// Checked BEFORE the value is read, so `favorite ~ x` reports the
  /// operator, not a missing true/false.
  void _requireOp(QueryField field, QueryOp op, Token opTok) {
    if (!field.ops.contains(op)) {
      throw _Abort(_err('"${opTok.text}" cannot be used with ${field.key}', opTok));
    }
  }

  /// A date value is one token; a range collapses to `inList` and an
  /// open-ended phrase ("since 2024") to the bound it has.
  QueryNode _dateCondition(FieldPath path, QueryOp op, QueryField field) {
    final t = _next();
    if (t.kind == TokenKind.end || t.kind == TokenKind.symbol) {
      throw _Abort(_err('expected a date value', t));
    }
    final range = parseDateText(t.text, now: context.now);
    if (range == null) throw _Abort(_err('"${t.text}" is not a date', t));
    final (:start, :end) = range;
    if (start != null && end != null) {
      if (start == end) return ConditionNode(path, op, DateValue(start));
      if (op == QueryOp.eq || op == QueryOp.inList) {
        return ConditionNode(path, QueryOp.inList, DateRangeValue(start, end));
      }
      if (op == QueryOp.neq) {
        return NotNode(ConditionNode(path, QueryOp.inList, DateRangeValue(start, end)));
      }
      // An ordering op against a range takes the edge the op faces.
      final edge = (op == QueryOp.lt || op == QueryOp.gte) ? start : end;
      return ConditionNode(path, op, DateValue(edge));
    }
    if (start != null) return ConditionNode(path, QueryOp.gte, DateValue(start));
    return ConditionNode(path, QueryOp.lte, DateValue(end!));
  }

  QueryValue _value(QueryField field, QueryOp op) {
    final t = _peek;
    if (t.kind == TokenKind.end || (t.kind == TokenKind.symbol && !_isSymbol(t, '-'))) {
      throw _Abort(_err('expected a value', t));
    }
    switch (field.type) {
      case FieldType.number:
        var negative = false;
        var tok = _next();
        if (_isSymbol(tok, '-')) {
          negative = true;
          tok = _next();
        }
        if (tok.kind != TokenKind.number) throw _Abort(_err('expected a number', tok));
        final m = RegExp(r'^(\d+(?:\.\d+)?)([A-Za-z]*)$').firstMatch(tok.text)!;
        final raw = double.parse(m[1]!) * (negative ? -1 : 1);
        final suffix = m[2]!;
        QueryUnit? unit;
        if (suffix.isNotEmpty) {
          unit = QueryUnit.fromSuffix(suffix);
          if (unit == null) throw _Abort(_err('unknown unit "$suffix"', tok));
          if (field.dimension == FieldDimension.none ||
              field.dimension == FieldDimension.percent ||
              field.dimension == FieldDimension.count ||
              (field.dimension == FieldDimension.minutes && unit != QueryUnit.min)) {
            throw _Abort(_err('${field.key} takes no unit', tok));
          }
        }
        if (_isSymbol(_peek, ',') && op != QueryOp.inList) {
          throw _Abort(_err('use "." for decimals, not ","', _peek));
        }
        return NumberValue(groundToStorage(raw, unit, field.dimension, context.prefs), unit);
      case FieldType.text:
      case FieldType.id:
        final tok = _next();
        if (tok.kind == TokenKind.symbol) throw _Abort(_err('expected text', tok));
        return StringValue(tok.text);
      case FieldType.bool:
        final tok = _next();
        if (_isKeyword(tok, 'true')) return const BoolValue(true);
        if (_isKeyword(tok, 'false')) return const BoolValue(false);
        throw _Abort(_err('expected true or false', tok));
      case FieldType.enumName:
        final tok = _next();
        final values = field.enumValues ?? const [];
        final match = values.where((v) => v.toLowerCase() == tok.text.toLowerCase()).firstOrNull;
        if (match == null) {
          throw _Abort(_err('"${tok.text}" is not a ${field.key} value', tok,
              suggestions: suggestNames(tok.text, values)));
        }
        return EnumValue(match);
      case FieldType.date:
        throw StateError('dates are parsed by _dateCondition');
    }
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/query/syntax`
Expected: PASS. If the `18,5` case fails, the comma check runs before the number is returned; it must run after the number token is consumed and before returning, as written.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/syntax test/core/query/syntax test/core/query/fixtures
git commit -m "feat(query): tokenizer and parser for the typed syntax"
```

---

### Task 5: The printer and the round-trip property

**Files:**
- Create: `lib/core/query/syntax/query_printer.dart`
- Test: `test/core/query/syntax/query_printer_test.dart`
- Test: `test/core/query/syntax/query_round_trip_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4.
- Produces: `QueryPrinter(registry, entity, prefs).print(QueryNode?) -> String`, `formatQueryNumber(double) -> String`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/query/syntax/query_printer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final metric = QueryPrinter(fixtureRegistry, fixtureDives, kMetricPrefs);
  final imperial = QueryPrinter(
      fixtureRegistry,
      fixtureDives,
      const UnitPrefs(
          depth: DepthUnit.feet,
          temperature: TemperatureUnit.fahrenheit,
          pressure: PressureUnit.psi,
          weight: WeightUnit.pounds,
          volume: VolumeUnit.cubicFeet));

  test('an empty query prints as empty text', () {
    expect(metric.print(null), '');
  });

  test('numbers print in the diver unit, or with the typed suffix', () {
    final bare = ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30.48, null));
    expect(metric.print(bare), 'depth > 30.48');
    expect(imperial.print(bare), 'depth > 100');
    final typed = ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30.48, QueryUnit.ft));
    expect(metric.print(typed), 'depth > 100ft');
  });

  test('operators, presence, lists, between, scoped, text', () {
    expect(metric.print(ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null)), 'weights:none');
    expect(metric.print(ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null)), 'rating:any');
    expect(
        metric.print(ConditionNode(const FieldPath(['waterType']), QueryOp.inList,
            const ListValue([EnumValue('salt'), EnumValue('fresh')]))),
        'waterType in [salt, fresh]');
    expect(
        metric.print(ConditionNode(const FieldPath(['depth']), QueryOp.between,
            const ListValue([NumberValue(18, null), NumberValue(30, null)]))),
        'depth between 18 and 30');
    expect(
        metric.print(ScopedNode(const FieldPath(['gear']),
            ConditionNode(const FieldPath(['type']), QueryOp.eq, const EnumValue('wetsuit')))),
        'gear[type = wetsuit]');
    expect(metric.print(const TextNode(['night', 'dive'])), '"night dive"');
    expect(metric.print(const TextNode(['manta'])), 'manta');
  });

  test('minimal parentheses and explicit AND', () {
    final tree = OrNode([
      AndNode([
        ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
        NotNode(OrNode([
          ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true)),
          ConditionNode(const FieldPath(['rating']), QueryOp.gte, const NumberValue(4, null)),
        ])),
      ]),
      ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('night dive')),
    ]);
    expect(metric.print(tree),
        'depth > 30 AND NOT (favorite = true OR rating >= 4) OR notes ~ "night dive"');
    expect(
        metric.print(AndNode([
          OrNode([
            ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
            ConditionNode(const FieldPath(['waterTemp']), QueryOp.isEmpty, null),
          ]),
          ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null),
        ])),
        '(weights:none OR waterTemp:none) AND rating:any');
  });

  test('dates and refs', () {
    expect(metric.print(ConditionNode(const FieldPath(['date']), QueryOp.gte, DateValue(DateTime(2025, 1, 15)))),
        'date >= 2025-01-15');
    expect(
        metric.print(ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)))),
        'date in 2025');
    expect(
        metric.print(ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 31)))),
        'date in 2025-03');
    expect(
        metric.print(ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 10)))),
        'date in "2025-03-01 to 2025-03-10"');
    expect(metric.print(ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite)),
        'site = "Salt Pier"');
    expect(
        metric.print(ConditionNode(const FieldPath(['site']), QueryOp.eq,
            const RefValue('x', 'Bob\'s "Reef" \\ Wall'))),
        r'site = "Bob' "'" r's \"Reef\" \\ Wall"');
  });

  test('a text value that is a keyword or has spaces is quoted', () {
    expect(metric.print(ConditionNode(const FieldPath(['notes']), QueryOp.eq, const StringValue('and'))),
        'notes = "and"');
    expect(metric.print(ConditionNode(const FieldPath(['notes']), QueryOp.eq, const StringValue('2025-03-14'))),
        'notes = "2025-03-14"');
  });
}
```

```dart
// test/core/query/syntax/query_round_trip_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

/// parse(print(ast)) == ast over generated trees, in both unit systems.
void main() {
  final names = MapNameResolver({
    QuerySubject.sites: {'Salt Pier': 'site-1', 'Bob\'s "Reef"': 'site-2'},
  });
  const imperial = UnitPrefs(
      depth: DepthUnit.feet,
      temperature: TemperatureUnit.fahrenheit,
      pressure: PressureUnit.psi,
      weight: WeightUnit.pounds,
      volume: VolumeUnit.cubicFeet);

  QueryValue number(Random r, UnitPrefs prefs) {
    final raw = r.nextInt(400) + (r.nextBool() ? 0 : r.nextInt(100) / 100);
    final unit = r.nextInt(3) == 0 ? (r.nextBool() ? QueryUnit.m : QueryUnit.ft) : null;
    return NumberValue(groundToStorage(raw, unit, FieldDimension.depth, prefs), unit);
  }

  QueryNode leaf(Random r, UnitPrefs prefs) {
    switch (r.nextInt(12)) {
      case 0:
        return ConditionNode(const FieldPath(['depth']), QueryOp.gt, number(r, prefs));
      case 1:
        return ConditionNode(const FieldPath(['depth']), QueryOp.between,
            ListValue([number(r, prefs), number(r, prefs)]));
      case 2:
        return ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null);
      case 3:
        return ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('night dive'));
      case 4:
        return ConditionNode(const FieldPath(['waterType']), QueryOp.inList,
            const ListValue([EnumValue('salt'), EnumValue('fresh')]));
      case 5:
        return ConditionNode(const FieldPath(['site']), QueryOp.eq, const RefValue('site-2', 'Bob\'s "Reef"'));
      case 6:
        return ConditionNode(const FieldPath(['date']), QueryOp.inList,
            DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)));
      case 7:
        return ConditionNode(const FieldPath(['date']), QueryOp.lt, DateValue(DateTime(2025, 6, 3)));
      case 8:
        return ScopedNode(const FieldPath(['gear']),
            ConditionNode(const FieldPath(['type']), QueryOp.neq, const EnumValue('bcd')));
      case 9:
        return ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.eq, const StringValue('rescue'));
      case 10:
        return const TextNode(['manta']);
      default:
        return ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true));
    }
  }

  QueryNode tree(Random r, int depth, UnitPrefs prefs) {
    if (depth == 0 || r.nextInt(3) == 0) return leaf(r, prefs);
    switch (r.nextInt(3)) {
      case 0:
        return AndNode([tree(r, depth - 1, prefs), tree(r, depth - 1, prefs)]);
      case 1:
        return OrNode([tree(r, depth - 1, prefs), tree(r, depth - 1, prefs)]);
      default:
        return NotNode(tree(r, depth - 1, prefs));
    }
  }

  for (final (label, prefs) in [('metric', kMetricPrefs), ('imperial', imperial)]) {
    test('parse(print(ast)) == ast, $label, 300 trees', () {
      final r = Random(20260925);
      final printer = QueryPrinter(fixtureRegistry, fixtureDives, prefs);
      final parser = QueryParser(fixtureRegistry, fixtureDives,
          ParseContext(prefs: prefs, now: DateTime(2026, 9, 25), names: names));
      for (var i = 0; i < 300; i++) {
        final ast = tree(r, 3, prefs);
        final text = printer.print(ast);
        final back = parser.parse(text);
        expect(back, isA<ParseOk>(), reason: 'could not re-parse "$text": $back');
        expect((back as ParseOk).node, equals(ast), reason: 'from "$text"');
      }
    });
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/query/syntax/query_printer_test.dart test/core/query/syntax/query_round_trip_test.dart`
Expected: FAIL, `query_printer.dart` missing.

- [ ] **Step 3: Write the printer**

```dart
// lib/core/query/syntax/query_printer.dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart' show kQueryKeywords;
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Integers print bare; other values print with up to two decimals, trailing
/// zeros trimmed. Two decimals is what every unit field in the app shows.
String formatQueryNumber(double v) {
  final rounded = (v * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var s = rounded.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

final RegExp _plainWord = RegExp(r'^[^\s"()\[\],:~=<>!&|-]+$');
final RegExp _isoLike = RegExp(r'^\d{4}(-\d{2}){0,2}$');

/// Emits exactly one canonical text per tree, which the parser reads back
/// to an equal tree.
class QueryPrinter {
  final QueryRegistry registry;
  final QueryEntity root;
  final UnitPrefs prefs;
  QueryPrinter(this.registry, this.root, this.prefs);

  String print(QueryNode? node) => node == null ? '' : _node(node, root);

  String _node(QueryNode n, QueryEntity scope) => switch (n) {
    // A nested AND inside AND (or OR inside OR) keeps its parentheses, so
    // the parser rebuilds the same tree shape instead of flattening it.
    AndNode(:final children) => children
        .map((c) => c is OrNode || c is AndNode ? '(${_node(c, scope)})' : _node(c, scope))
        .join(' AND '),
    OrNode(:final children) => children
        .map((c) => c is OrNode ? '(${_node(c, scope)})' : _node(c, scope))
        .join(' OR '),
    NotNode(:final child) => switch (child) {
      AndNode() || OrNode() => 'NOT (${_node(child, scope)})',
      _ => 'NOT ${_node(child, scope)}',
    },
    ScopedNode(:final path, :final inner) => '$path[${_node(inner, _target(path, scope))}]',
    TextNode(:final words) => words.length == 1 && _plainWord.hasMatch(words.first) && !_looksLikeCondition(words.first, scope)
        ? words.first
        : _quote(words.join(' ')),
    ConditionNode(:final path, :final op, :final value) => _condition(path, op, value, scope),
  };

  QueryEntity _target(FieldPath path, QueryEntity scope) {
    final res = resolvePath(registry, scope, path);
    return registry.entityFor(res.terminalRelation!.target);
  }

  /// A bare word that names a field would still parse as text (no operator
  /// follows), so it is safe unquoted; keywords are not.
  bool _looksLikeCondition(String w, QueryEntity scope) =>
      kQueryKeywords.contains(w.toLowerCase()) || _isoLike.hasMatch(w) || double.tryParse(w) != null;

  String _condition(FieldPath path, QueryOp op, QueryValue? value, QueryEntity scope) {
    final res = resolvePath(registry, scope, path);
    final field = res.field;
    switch (op) {
      case QueryOp.isEmpty:
        return '$path:none';
      case QueryOp.isSet:
        return '$path:any';
      case QueryOp.inList:
        if (value is DateRangeValue) return '$path in ${_dateRange(value)}';
        if (field == null) {
          final refs = (value as ListValue).items.map((v) => _quote((v as RefValue).label)).join(', ');
          return '$path in [$refs]';
        }
        final items = (value as ListValue).items.map((v) => _value(v, field!)).join(', ');
        return '$path in [$items]';
      case QueryOp.between:
        final items = (value as ListValue).items;
        return '$path between ${_value(items[0], field!)} and ${_value(items[1], field)}';
      default:
        final sym = switch (op) {
          QueryOp.eq => '=',
          QueryOp.neq => '!=',
          QueryOp.lt => '<',
          QueryOp.lte => '<=',
          QueryOp.gt => '>',
          QueryOp.gte => '>=',
          QueryOp.contains => '~',
          _ => throw StateError('unreachable'),
        };
        if (field == null) return '$path $sym ${_quote((value as RefValue).label)}';
        return '$path $sym ${_value(value!, field)}';
    }
  }

  String _value(QueryValue v, QueryField field) => switch (v) {
    NumberValue(:final value, :final typedUnit) => () {
      final (shown, unit) = storageToDisplay(value, typedUnit, field.dimension, prefs);
      return '${formatQueryNumber(shown)}${unit?.suffix ?? ''}';
    }(),
    StringValue(:final value) => _word(value),
    BoolValue(:final value) => value ? 'true' : 'false',
    EnumValue(:final name) => name,
    DateValue(:final day) => _day(day),
    DateRangeValue() => _dateRange(v),
    ListValue(:final items) => '[${items.map((i) => _value(i, field)).join(', ')}]',
    RefValue(:final label) => _quote(label),
  };

  String _dateRange(DateRangeValue r) {
    final s = r.start;
    final e = r.end;
    if (s.month == 1 && s.day == 1 && e.month == 12 && e.day == 31 && s.year == e.year) {
      return '${s.year}';
    }
    if (s.day == 1 && s.year == e.year && s.month == e.month && DateTime(e.year, e.month + 1, 0).day == e.day) {
      return '${s.year}-${_two(s.month)}';
    }
    return _quote('${_day(s)} to ${_day(e)}');
  }

  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
  String _two(int n) => n.toString().padLeft(2, '0');

  /// A word prints bare only when the tokenizer would read it back as ONE
  /// word token that the parser would not mistake for a keyword, number or
  /// date.
  String _word(String s) =>
      _plainWord.hasMatch(s) && !kQueryKeywords.contains(s.toLowerCase()) && !_isoLike.hasMatch(s) && double.tryParse(s) == null
          ? s
          : _quote(s);

  String _quote(String s) => '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/query/syntax`
Expected: PASS. If a round-trip case fails on a number, inspect whether `formatQueryNumber` lost precision: the generator only makes values with two decimals, so a failure there is a printer bug, not a generator one.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/syntax/query_printer.dart lib/core/query/syntax/query_parser.dart test/core/query/syntax
git commit -m "feat(query): canonical printer with a parse-print round-trip property"
```

---

### Task 6: The validator

**Files:**
- Create: `lib/core/query/compiler/query_validator.dart`
- Test: `test/core/query/compiler/query_validator_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3.
- Produces: `List<QueryError> validateQuery(QueryNode? node, QueryEntity root, QueryRegistry registry)`.

The parser already rejects most of these while reading text; the validator is for trees the builder (PR 2) or a lowering makes, and it is what the compiler trusts.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/query/compiler/query_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  List<String> messages(QueryNode? n) =>
      validateQuery(n, fixtureDives, fixtureRegistry).map((e) => e.message).toList();

  test('a clean tree and an empty query have no errors', () {
    expect(messages(null), isEmpty);
    expect(
        messages(AndNode([
          ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
          ScopedNode(const FieldPath(['gear']),
              ConditionNode(const FieldPath(['type']), QueryOp.eq, const EnumValue('wetsuit'))),
          ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.eq, const StringValue('x')),
          ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
          const TextNode(['manta']),
        ])),
        isEmpty);
  });

  test('every error kind, all reported at once', () {
    final errors = validateQuery(
      AndNode([
        ConditionNode(const FieldPath(['depht']), QueryOp.gt, const NumberValue(30, null)),
        ConditionNode(const FieldPath(['favorite']), QueryOp.contains, const StringValue('x')),
        ConditionNode(const FieldPath(['rating']), QueryOp.gt, const NumberValue(3, QueryUnit.m)),
        ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(900, null)),
        ConditionNode(const FieldPath(['waterType']), QueryOp.inList, const ListValue([])),
        ConditionNode(const FieldPath(['waterType']), QueryOp.eq, const EnumValue('lake')),
        ConditionNode(const FieldPath(['depth']), QueryOp.eq, const StringValue('deep')),
        ConditionNode(const FieldPath(['weights']), QueryOp.eq, const NumberValue(1, null)),
        ScopedNode(const FieldPath(['depth']), const TextNode(['x'])),
        ConditionNode(const FieldPath(['depth']), QueryOp.between, const ListValue([NumberValue(1, null)])),
        ConditionNode(const FieldPath(['site']), QueryOp.eq, const StringValue('Salt Pier')),
      ]),
      fixtureDives,
      fixtureRegistry,
    );
    final m = errors.map((e) => e.message).join('\n');
    expect(errors.length, 11, reason: m);
    expect(m, contains('unknown field "depht"'));
    expect(m, contains('contains cannot be used with favorite'));
    expect(m, contains('rating takes no unit'));
    expect(m, contains('out of range'));
    expect(m, contains('list is empty'));
    expect(m, contains('"lake" is not a waterType value'));
    expect(m, contains('depth expects a number'));
    expect(m, contains('"weights" is a relation'));
    expect(m, contains('[...] needs a relation'));
    expect(m, contains('between needs two values'));
    expect(m, contains('site expects a reference'));
    expect(errors.first.path, const FieldPath(['depht']));
  });

  test('an unknown segment deep in a scoped group is resolved in that scope', () {
    expect(
        messages(ScopedNode(const FieldPath(['gear']),
            ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(1, null)))),
        [contains('unknown field "depth"')]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/query/compiler/query_validator_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Write the validator**

```dart
// lib/core/query/compiler/query_validator.dart
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// Every problem in [node], for the editor to show at once. The compiler is
/// only called on a tree this returns nothing for.
List<QueryError> validateQuery(
  QueryNode? node,
  QueryEntity root,
  QueryRegistry registry,
) {
  if (node == null) return const [];
  final out = <QueryError>[];
  _walk(node, root, registry, out);
  return out;
}

void _walk(QueryNode n, QueryEntity scope, QueryRegistry registry, List<QueryError> out) {
  switch (n) {
    case AndNode(:final children):
    case OrNode(:final children):
      for (final c in children) {
        _walk(c, scope, registry, out);
      }
    case NotNode(:final child):
      _walk(child, scope, registry, out);
    case TextNode():
      if (scope.textSearchSql.isEmpty) {
        out.add(QueryError('free text cannot be searched inside ${scope.table}'));
      }
    case ScopedNode(:final path, :final inner):
      final res = resolvePath(registry, scope, path);
      if (res.error != null) {
        out.add(res.error!);
        return;
      }
      if (res.terminalRelation == null) {
        out.add(QueryError('[...] needs a relation, "$path" is a field', path: path));
        return;
      }
      _walk(inner, registry.entityFor(res.terminalRelation!.target), registry, out);
    case ConditionNode(:final path, :final op, :final value):
      final res = resolvePath(registry, scope, path);
      if (res.error != null) {
        out.add(res.error!);
        return;
      }
      final field = res.field;
      if (field == null) {
        switch (op) {
          case QueryOp.isEmpty:
          case QueryOp.isSet:
            return;
          case QueryOp.eq:
          case QueryOp.neq:
            if (value is! RefValue) {
              out.add(QueryError('${path.segments.last} expects a reference', path: path));
            }
          case QueryOp.inList:
            if (value is! ListValue || value.items.isEmpty) {
              out.add(QueryError('the list is empty', path: path));
            } else if (value.items.any((v) => v is! RefValue)) {
              out.add(QueryError('${path.segments.last} expects references', path: path));
            }
          default:
            out.add(QueryError('"$path" is a relation; use =, in, :none, :any or [...]', path: path));
        }
        return;
      }
      if (!field.ops.contains(op)) {
        out.add(QueryError('${op.name} cannot be used with ${field.key}', path: path));
        return;
      }
      if (value == null) return;
      _checkValue(path, field, op, value, out);
  }
}

void _checkValue(FieldPath path, QueryField field, QueryOp op, QueryValue value, List<QueryError> out) {
  if (op == QueryOp.between) {
    if (value is! ListValue || value.items.length != 2) {
      out.add(QueryError('between needs two values', path: path));
      return;
    }
    for (final v in value.items) {
      _checkValue(path, field, QueryOp.eq, v, out);
    }
    return;
  }
  if (op == QueryOp.inList) {
    if (value is DateRangeValue && field.type == FieldType.date) return;
    if (value is! ListValue) {
      out.add(QueryError('in needs a list', path: path));
      return;
    }
    if (value.items.isEmpty) {
      out.add(QueryError('the list is empty', path: path));
      return;
    }
    for (final v in value.items) {
      _checkValue(path, field, QueryOp.eq, v, out);
    }
    return;
  }
  switch (field.type) {
    case FieldType.number:
      if (value is! NumberValue) {
        out.add(QueryError('${field.key} expects a number', path: path));
        return;
      }
      final unitless = const {FieldDimension.none, FieldDimension.percent, FieldDimension.count}
          .contains(field.dimension);
      if (value.typedUnit != null && unitless) {
        out.add(QueryError('${field.key} takes no unit', path: path));
      }
      final s = field.sanity;
      if (s != null && (value.value < s.min || value.value > s.max)) {
        out.add(QueryError('${field.key} value is out of range', path: path));
      }
    case FieldType.text:
    case FieldType.id:
      if (value is! StringValue) out.add(QueryError('${field.key} expects text', path: path));
    case FieldType.bool:
      if (value is! BoolValue) out.add(QueryError('${field.key} expects true or false', path: path));
    case FieldType.enumName:
      if (value is! EnumValue) {
        out.add(QueryError('${field.key} expects one of its values', path: path));
      } else if (!(field.enumValues ?? const []).contains(value.name)) {
        out.add(QueryError('"${value.name}" is not a ${field.key} value', path: path));
      }
    case FieldType.date:
      if (value is! DateValue && value is! DateRangeValue) {
        out.add(QueryError('${field.key} expects a date', path: path));
      }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/query/compiler/query_validator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/compiler/query_validator.dart test/core/query/compiler/query_validator_test.dart
git commit -m "feat(query): validator reporting every error at once"
```

---

### Task 7: The compiler, scalar conditions and text

**Files:**
- Create: `lib/core/query/compiler/sql_templates.dart`
- Create: `lib/core/query/compiler/query_compiler.dart`
- Test: `test/core/query/compiler/query_compiler_scalar_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 6; `wallClockUtcDayStart` from `lib/core/util/wall_clock_utc.dart`.
- Produces: `CompiledQuery { where, params, tablesTouched, isEmpty, idSubquery() }`, `compileQuery(node, root, registry, {rootAlias})`, `substituteRow`, `substituteJoin`, `countPlaceholders`, `escapeLike`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/query/compiler/query_compiler_scalar_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  CompiledQuery c(QueryNode? n) => compileQuery(n, fixtureDives, fixtureRegistry);

  test('an empty query compiles to no WHERE and the bare id subquery', () {
    final q = c(null);
    expect(q.isEmpty, isTrue);
    expect(q.where, '');
    expect(q.params, isEmpty);
    expect(q.idSubquery(), 'SELECT r0.id FROM dives r0');
    expect(q.tablesTouched, {'dives'});
  });

  test('number, ordering ops, between and in', () {
    expect(c(ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null))).where,
        '(r0.max_depth > ?)');
    final b = c(ConditionNode(const FieldPath(['depth']), QueryOp.between,
        const ListValue([NumberValue(18, null), NumberValue(30, null)])));
    expect(b.where, '(r0.max_depth >= ? AND r0.max_depth <= ?)');
    expect(b.params, [18.0, 30.0]);
    final i = c(ConditionNode(const FieldPath(['rating']), QueryOp.inList,
        const ListValue([NumberValue(4, null), NumberValue(5, null)])));
    expect(i.where, '(r0.rating IN (?, ?))');
  });

  test('neq on a nullable column excludes the unrecorded (Review Focus 5)', () {
    expect(c(ConditionNode(const FieldPath(['bottomTime']), QueryOp.neq, const NumberValue(10, null))).where,
        '(((r0.bottom_time / 60)) IS NOT NULL AND (r0.bottom_time / 60) != ?)');
  });

  test('presence uses the field emptySql', () {
    expect(c(ConditionNode(const FieldPath(['notes']), QueryOp.isEmpty, null)).where,
        "((r0.notes IS NULL OR TRIM(r0.notes) = ''))");
    expect(c(ConditionNode(const FieldPath(['notes']), QueryOp.isSet, null)).where,
        "(NOT ((r0.notes IS NULL OR TRIM(r0.notes) = '')))");
  });

  test('text eq is case-insensitive, contains escapes LIKE wildcards', () {
    final e = c(ConditionNode(const FieldPath(['notes']), QueryOp.eq, const StringValue('Manta')));
    expect(e.where, '(LOWER(r0.notes) = LOWER(?))');
    expect(e.params, ['Manta']);
    final k = c(ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('100%_x')));
    expect(k.where, "(r0.notes LIKE ? ESCAPE '\\')");
    expect(k.params, ['%100\\%\\_x%']);
  });

  test('bool columns and bool predicates', () {
    expect(c(ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true))).params, [1]);
    expect(c(ConditionNode(const FieldPath(['favorite']), QueryOp.neq, const BoolValue(true))).params, [0]);
    expect(c(ConditionNode(const FieldPath(['deco']), QueryOp.eq, const BoolValue(true))).where, '((r0.deco_flag = 1))');
    expect(c(ConditionNode(const FieldPath(['deco']), QueryOp.neq, const BoolValue(true))).where, '((r0.deco_flag = 0))');
  });

  test('enum values bind their SQL value', () {
    expect(c(ConditionNode(const FieldPath(['waterType']), QueryOp.eq, const EnumValue('salt'))).params, ['salt']);
    final w = c(ConditionNode(const FieldPath(['weekday']), QueryOp.inList,
        const ListValue([EnumValue('sunday'), EnumValue('monday')])));
    expect(w.params, [0, 1]);
  });

  test('a relation compared to a ref binds the id inside its hop', () {
    final q = c(ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite));
    expect(q.where, '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id AND r1.id = ?))');
    expect(q.params, ['site-1']);
    final n = c(ConditionNode(const FieldPath(['site']), QueryOp.neq, kFixtureSite));
    expect(n.where, '(NOT EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id AND r1.id = ?))');
    final l = c(ConditionNode(const FieldPath(['site']), QueryOp.inList, const ListValue([RefValue('a', 'A'), RefValue('b', 'B')])));
    expect(l.where, '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id AND r1.id IN (?, ?)))');
    expect(c(ConditionNode(const FieldPath(['id']), QueryOp.inList,
        const ListValue([StringValue('a'), StringValue('b')]))).where, '(r0.id IN (?, ?))');
  });

  test('dates are half-open wall-clock day bounds', () {
    int ms(DateTime d) => wallClockUtcDayStart(d).millisecondsSinceEpoch;
    final day = DateTime(2025, 3, 14);
    final next = DateTime(2025, 3, 15);
    final eq = c(ConditionNode(const FieldPath(['date']), QueryOp.eq, DateValue(day)));
    expect(eq.where, '(r0.dive_date_time >= ? AND r0.dive_date_time < ?)');
    expect(eq.params, [ms(day), ms(next)]);
    expect(c(ConditionNode(const FieldPath(['date']), QueryOp.gte, DateValue(day))).params, [ms(day)]);
    expect(c(ConditionNode(const FieldPath(['date']), QueryOp.gt, DateValue(day))).params, [ms(next)]);
    expect(c(ConditionNode(const FieldPath(['date']), QueryOp.lt, DateValue(day))).params, [ms(day)]);
    expect(c(ConditionNode(const FieldPath(['date']), QueryOp.lte, DateValue(day))).params, [ms(next)]);
    final range = c(ConditionNode(const FieldPath(['date']), QueryOp.inList,
        DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31))));
    expect(range.params, [ms(DateTime(2025, 1, 1)), ms(DateTime(2026, 1, 1))]);
  });

  test('text search ORs every template per word and ANDs words', () {
    final q = c(const TextNode(['night', 'dive']));
    expect(q.where,
        "((r0.notes LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = r0.site_id AND ts.name LIKE ? ESCAPE '\\')) "
        "AND (r0.notes LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = r0.site_id AND ts.name LIKE ? ESCAPE '\\')))");
    expect(q.params, ['%night%', '%night%', '%dive%', '%dive%']);
    expect(q.tablesTouched, {'dives', 'dive_sites'});
  });

  test('AND, OR and NOT nest with parentheses', () {
    final q = c(OrNode([
      AndNode([
        ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(30, null)),
        NotNode(ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true))),
      ]),
      ConditionNode(const FieldPath(['rating']), QueryOp.gte, const NumberValue(4, null)),
    ]));
    expect(q.where, '(((r0.max_depth > ?) AND (NOT (r0.is_favorite = ?))) OR (r0.rating >= ?))');
    expect(q.params, [30.0, 1, 4.0]);
  });

  test('the bind count always equals the placeholder count', () {
    for (final n in <QueryNode>[
      ConditionNode(const FieldPath(['depth']), QueryOp.between, const ListValue([NumberValue(1, null), NumberValue(2, null)])),
      const TextNode(['a', 'b', 'c']),
      ConditionNode(const FieldPath(['waterType']), QueryOp.inList, const ListValue([EnumValue('salt'), EnumValue('fresh'), EnumValue('brackish')])),
    ]) {
      final q = c(n);
      expect(countPlaceholders(q.where), q.params.length, reason: q.where);
    }
  });

  test('the root alias is a parameter', () {
    expect(compileQuery(ConditionNode(const FieldPath(['depth']), QueryOp.gt, const NumberValue(1, null)),
        fixtureDives, fixtureRegistry, rootAlias: 'd').where, '(d.max_depth > ?)');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/query/compiler/query_compiler_scalar_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the templates helper and the compiler**

```dart
// lib/core/query/compiler/sql_templates.dart
/// `{r}` is the alias of the row a field is read from.
String substituteRow(String template, String alias) => template.replaceAll('{r}', alias);

/// `{from}` is the row we are on, `{to}` the related row.
String substituteJoin(String template, String from, String to) =>
    template.replaceAll('{from}', from).replaceAll('{to}', to);

/// How many bind placeholders a fragment carries. Every `?` outside a quoted
/// literal counts; the registry never puts a `?` inside one.
int countPlaceholders(String sql) => '?'.allMatches(sql).length;

/// Escapes a LIKE term so `%` and `_` match literally. Pair it with
/// `ESCAPE '\'` in the template.
String escapeLike(String term) =>
    term.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
```

```dart
// lib/core/query/compiler/query_compiler.dart
import 'package:meta/meta.dart';

import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

/// One compiled query, in the two spellings its consumers need.
@immutable
class CompiledQuery {
  /// A boolean expression over [rootAlias], or empty for "match all".
  final String where;
  final List<Object?> params;

  /// Every table the expression reads (root, relation targets, junctions,
  /// tables a field or template declares), for change ticks and
  /// `readsFrom`.
  final Set<String> tablesTouched;
  final String table;
  final String idColumn;
  final String rootAlias;

  const CompiledQuery({
    required this.where,
    required this.params,
    required this.tablesTouched,
    required this.table,
    required this.idColumn,
    required this.rootAlias,
  });

  bool get isEmpty => where.isEmpty;

  /// `SELECT <alias>.<id> FROM <table> <alias> [WHERE <where>]`, for
  /// `id IN (...)` consumers. Binds the same [params].
  String idSubquery() =>
      'SELECT $rootAlias.$idColumn FROM $table $rootAlias'
      '${isEmpty ? '' : ' WHERE $where'}';
}

/// Compiles a VALIDATED tree. Anything the validator would reject throws
/// [QueryCompileError], which is a programming error, not user input.
CompiledQuery compileQuery(
  QueryNode? node,
  QueryEntity root,
  QueryRegistry registry, {
  String rootAlias = 'r0',
}) {
  final ctx = _Ctx(registry, rootAlias)..tables.add(root.table);
  final where = node == null ? '' : ctx.emit(node, root, rootAlias);
  return CompiledQuery(
    where: where,
    params: List.unmodifiable(ctx.params),
    tablesTouched: Set.unmodifiable(ctx.tables),
    table: root.table,
    idColumn: root.idColumn,
    rootAlias: rootAlias,
  );
}

class _Ctx {
  final QueryRegistry registry;
  final String rootAlias;
  final params = <Object?>[];
  final tables = <String>{};
  int _aliasCounter = 0;

  _Ctx(this.registry, this.rootAlias);

  String nextAlias() => 'r${++_aliasCounter}';

  String emit(QueryNode n, QueryEntity entity, String alias) => switch (n) {
    AndNode(:final children) => '(${children.map((c) => emit(c, entity, alias)).join(' AND ')})',
    OrNode(:final children) => '(${children.map((c) => emit(c, entity, alias)).join(' OR ')})',
    NotNode(:final child) => '(NOT ${emit(child, entity, alias)})',
    TextNode(:final words) => _text(words, entity, alias),
    ScopedNode(:final path, :final inner) => _scoped(path, inner, entity, alias),
    ConditionNode(:final path, :final op, :final value) => _condition(path, op, value, entity, alias),
  };

  String _text(List<String> words, QueryEntity entity, String alias) {
    if (entity.textSearchSql.isEmpty) {
      throw QueryCompileError('${entity.table} declares no text search columns');
    }
    tables.addAll(entity.textSearchTables);
    final perWord = <String>[];
    for (final w in words) {
      final term = '%${escapeLike(w)}%';
      final alts = <String>[];
      for (final t in entity.textSearchSql) {
        final sql = substituteRow(t, alias);
        alts.add(sql);
        for (var i = 0; i < countPlaceholders(t); i++) {
          params.add(term);
        }
      }
      perWord.add('(${alts.join(' OR ')})');
    }
    return '(${perWord.join(' AND ')})';
  }

  /// Wraps [inner] (a function of the leaf alias) in one EXISTS per hop.
  String _hops(List<QueryRelation> hops, String fromAlias, String Function(String leafAlias)? inner) {
    if (hops.isEmpty) return inner!(fromAlias);
    final rel = hops.first;
    final target = registry.entityFor(rel.target);
    tables.add(target.table);
    tables.addAll(rel.tables);
    final to = nextAlias();
    final join = substituteJoin(rel.joinSql, fromAlias, to);
    final rest = hops.length == 1 && inner == null ? '' : ' AND ${_hops(hops.sublist(1), to, inner)}';
    return 'EXISTS (SELECT 1 FROM ${target.table} $to WHERE $join$rest)';
  }

  String _scoped(FieldPath path, QueryNode inner, QueryEntity entity, String alias) {
    final res = _resolve(path, entity);
    final rel = res.terminalRelation;
    if (rel == null) throw QueryCompileError('scoped path $path must end in a relation');
    final leaf = registry.entityFor(rel.target);
    return '(${_hops(res.hops, alias, (a) => emit(inner, leaf, a))})';
  }

  String _condition(FieldPath path, QueryOp op, QueryValue? value, QueryEntity entity, String alias) {
    final res = _resolve(path, entity);
    final field = res.field;
    if (field == null) {
      final rel = res.terminalRelation!;
      switch (op) {
        case QueryOp.eq:
        case QueryOp.neq:
          final target = registry.entityFor(rel.target);
          params.add((value as RefValue).id);
          final hit = _hops(res.hops, alias, (a) => '$a.${target.idColumn} = ?');
          return op == QueryOp.eq ? '($hit)' : '(NOT $hit)';
        case QueryOp.inList:
          final target = registry.entityFor(rel.target);
          final items = (value as ListValue).items;
          for (final v in items) {
            params.add((v as RefValue).id);
          }
          final ph = List.filled(items.length, '?').join(', ');
          return '(${_hops(res.hops, alias, (a) => '$a.${target.idColumn} IN ($ph)')})';
        case QueryOp.isSet:
          return '(${_hops(res.hops, alias, null)})';
        case QueryOp.isEmpty:
          if (rel.emptySql != null && res.hops.length == 1) {
            tables.add(registry.entityFor(rel.target).table);
            tables.addAll(rel.tables);
            return '(${substituteJoin(rel.emptySql!, alias, '_unused')})';
          }
          return '(NOT ${_hops(res.hops, alias, null)})';
        default:
          throw QueryCompileError('$op on relation $path');
      }
    }
    tables.addAll(field.tables);
    return '(${_hops(res.hops, alias, (a) => _fieldPredicate(field, op, value, a))})';
  }

  PathResolution _resolve(FieldPath path, QueryEntity entity) {
    final res = resolvePath(registry, entity, path);
    if (res.error != null) throw QueryCompileError(res.error!.message);
    return res;
  }

  String _fieldPredicate(QueryField f, QueryOp op, QueryValue? value, String alias) {
    final col = substituteRow(f.sql, alias);
    switch (op) {
      case QueryOp.isEmpty:
        return '(${substituteRow(f.emptySql, alias)})';
      case QueryOp.isSet:
        return '(NOT (${substituteRow(f.emptySql, alias)}))';
      case QueryOp.between:
        final items = (value as ListValue).items;
        return '(${_cmp(f, col, '>=', items[0], alias)} AND ${_cmp(f, col, '<=', items[1], alias)})';
      case QueryOp.inList:
        if (value is DateRangeValue) return _dateRange(col, value);
        final items = (value as ListValue).items;
        if (f.type == FieldType.text) {
          for (final v in items) {
            params.add((v as StringValue).value);
          }
          return '(LOWER($col) IN (${List.filled(items.length, 'LOWER(?)').join(', ')}))';
        }
        for (final v in items) {
          params.add(_bind(f, v));
        }
        return '($col IN (${List.filled(items.length, '?').join(', ')}))';
      case QueryOp.contains:
        params.add('%${escapeLike((value as StringValue).value)}%');
        return "($col LIKE ? ESCAPE '\\')";
      case QueryOp.eq:
      case QueryOp.neq:
        if (f.type == FieldType.bool && f.boolSql != null) {
          final want = (value as BoolValue).value == (op == QueryOp.eq);
          return '(${substituteRow(want ? f.boolSql!.whenTrue : f.boolSql!.whenFalse, alias)})';
        }
        if (f.type == FieldType.bool) {
          final want = (value as BoolValue).value == (op == QueryOp.eq);
          params.add(want ? 1 : 0);
          return '($col = ?)';
        }
        if (f.type == FieldType.date) {
          final v = value as DateValue;
          final eq = '($col >= ? AND $col < ?)';
          params
            ..add(_ms(v.day))
            ..add(_ms(_plusDay(v.day)));
          return op == QueryOp.eq ? eq : '(NOT $eq)';
        }
        if (f.type == FieldType.text) {
          params.add((value as StringValue).value);
          return op == QueryOp.eq ? '(LOWER($col) = LOWER(?))' : '(LOWER($col) != LOWER(?))';
        }
        if (op == QueryOp.neq) {
          params.add(_bind(f, value!));
          return '(($col) IS NOT NULL AND $col != ?)';
        }
        params.add(_bind(f, value!));
        return '($col = ?)';
      case QueryOp.lt:
      case QueryOp.lte:
      case QueryOp.gt:
      case QueryOp.gte:
        final sym = switch (op) {
          QueryOp.lt => '<',
          QueryOp.lte => '<=',
          QueryOp.gt => '>',
          _ => '>=',
        };
        return '(${_cmp(f, col, sym, value!, alias)})';
    }
  }

  String _cmp(QueryField f, String col, String sym, QueryValue v, String alias) {
    if (f.type == FieldType.date) {
      final day = (v as DateValue).day;
      // Half-open day bounds: `<= day` keeps the whole day, `> day` starts
      // the day after, mirroring DiveFilterState's endDateBoundMs.
      return switch (sym) {
        '<' => () { params.add(_ms(day)); return '$col < ?'; }(),
        '<=' => () { params.add(_ms(_plusDay(day))); return '$col < ?'; }(),
        '>' => () { params.add(_ms(_plusDay(day))); return '$col >= ?'; }(),
        _ => () { params.add(_ms(day)); return '$col >= ?'; }(),
      };
    }
    params.add(_bind(f, v));
    return '$col $sym ?';
  }

  String _dateRange(String col, DateRangeValue r) {
    params
      ..add(_ms(r.start))
      ..add(_ms(_plusDay(r.end)));
    return '($col >= ? AND $col < ?)';
  }

  Object? _bind(QueryField f, QueryValue v) => switch (v) {
    NumberValue(:final value) => value,
    StringValue(:final value) => value,
    BoolValue(:final value) => value ? 1 : 0,
    EnumValue(:final name) => f.enumSqlValues?[name] ?? name,
    RefValue(:final id) => id,
    DateValue(:final day) => _ms(day),
    DateRangeValue() || ListValue() => throw QueryCompileError('cannot bind $v'),
  };

  int _ms(DateTime day) => wallClockUtcDayStart(day).millisecondsSinceEpoch;
  DateTime _plusDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
}
```

`tablesTouched` is fed by `QueryField.tables`, `QueryRelation.tables` and `QueryEntity.textSearchTables` (Task 3), which name the tables a fragment reads beyond the entity's own: a junction inside `joinSql`, `dive_weights` inside weight's `emptySql`, the profile tables inside deco.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/query/compiler/query_compiler_scalar_test.dart test/core/query`
Expected: PASS, including the earlier suites after the registry additions.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query test/core/query
git commit -m "feat(query): SQL compiler for scalar conditions, presence and text"
```

---

### Task 8: The compiler, relation hops and scoped groups

**Files:**
- Modify: `lib/core/query/compiler/query_compiler.dart` (only if a golden fails; the hop code is already in Task 7)
- Test: `test/core/query/compiler/query_compiler_relations_test.dart`

**Interfaces:**
- Consumes: Task 7.
- Produces: nothing new; pins the relation semantics.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/query/compiler/query_compiler_relations_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  CompiledQuery c(QueryNode n) => compileQuery(n, fixtureDives, fixtureRegistry);

  test('an fk hop', () {
    final q = c(ConditionNode(const FieldPath(['site', 'country']), QueryOp.eq, const StringValue('Mexico')));
    expect(q.where,
        '(EXISTS (SELECT 1 FROM dive_sites r1 WHERE r1.id = r0.site_id AND (LOWER(r1.country) = LOWER(?))))');
    expect(q.tablesTouched, {'dives', 'dive_sites'});
  });

  test('a child hop and a junction hop', () {
    expect(c(ConditionNode(const FieldPath(['weights', 'amount']), QueryOp.gt, const NumberValue(2, null))).where,
        '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id AND (r1.amount_kg > ?)))');
    final j = c(ConditionNode(const FieldPath(['buddies', 'name']), QueryOp.contains, const StringValue('ana')));
    expect(j.where,
        '(EXISTS (SELECT 1 FROM buddies r1 WHERE EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = r0.id AND j.buddy_id = r1.id) '
        "AND (r1.name LIKE ? ESCAPE '\\')))");
    expect(j.tablesTouched, {'dives', 'buddies', 'dive_buddies'});
  });

  test('three hops number their aliases by depth', () {
    final q = c(ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.eq, const StringValue('rescue')));
    expect(q.where, contains('FROM buddies r1'));
    expect(q.where, contains('FROM certifications r2 WHERE r2.buddy_id = r1.id'));
    expect(q.where, contains('LOWER(r2.level) = LOWER(?)'));
  });

  test('presence on relations: :any, :none, and the emptySql override', () {
    expect(c(ConditionNode(const FieldPath(['weights']), QueryOp.isSet, null)).where,
        '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id))');
    expect(c(ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null)).where,
        '(NOT EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id))');
    expect(c(ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null)).where,
        "(((r0.buddy IS NULL OR r0.buddy = '') AND NOT EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = r0.id)))");
    expect(c(ConditionNode(const FieldPath(['buddies', 'certifications']), QueryOp.isEmpty, null)).where,
        startsWith('(NOT EXISTS (SELECT 1 FROM buddies r1'));
  });

  test('NOT over a collection path means no such row', () {
    final q = c(NotNode(ScopedNode(const FieldPath(['gear']),
        ConditionNode(const FieldPath(['type']), QueryOp.inList,
            const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')])))));
    expect(q.where,
        '(NOT (EXISTS (SELECT 1 FROM equipment r1 WHERE r1.id IN (SELECT de.equipment_id FROM dive_equipment de WHERE de.dive_id = r0.id) AND (r1.type IN (?, ?)))))');
    expect(q.params, ['wetsuit', 'drysuit']);
    expect(q.tablesTouched, {'dives', 'equipment', 'dive_equipment'});
  });

  test('a scoped group evaluates its conditions on ONE row', () {
    final q = c(ScopedNode(const FieldPath(['weights']),
        AndNode([
          ConditionNode(const FieldPath(['amount']), QueryOp.gte, const NumberValue(1, null)),
          ConditionNode(const FieldPath(['amount']), QueryOp.lte, const NumberValue(3, null)),
        ])));
    expect(q.where,
        '(EXISTS (SELECT 1 FROM dive_weights r1 WHERE r1.dive_id = r0.id AND ((r1.amount_kg >= ?) AND (r1.amount_kg <= ?))))');
  });

  test('a nested scoped group re-roots inside the hop', () {
    final q = c(ScopedNode(const FieldPath(['buddies']),
        AndNode([
          ConditionNode(const FieldPath(['name']), QueryOp.contains, const StringValue('a')),
          ScopedNode(const FieldPath(['certifications']),
              ConditionNode(const FieldPath(['level']), QueryOp.eq, const StringValue('rescue'))),
        ])));
    expect(q.where, contains('FROM certifications r2 WHERE r2.buddy_id = r1.id AND (LOWER(r2.level) = LOWER(?))'));
  });

  test('bind counts hold across every relation shape', () {
    for (final n in <QueryNode>[
      ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.inList,
          const ListValue([StringValue('a'), StringValue('b')])),
      NotNode(ScopedNode(const FieldPath(['gear']),
          ConditionNode(const FieldPath(['type']), QueryOp.eq, const EnumValue('bcd')))),
      ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null),
    ]) {
      final q = c(n);
      expect(countPlaceholders(q.where), q.params.length, reason: q.where);
    }
  });

  test('a relation with a value op is a compile error', () {
    expect(() => c(ConditionNode(const FieldPath(['weights']), QueryOp.eq, const NumberValue(1, null))),
        throwsA(isA<Error>()));
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/core/query/compiler/query_compiler_relations_test.dart`
Expected: PASS if Task 7's hop code is right; fix the compiler where a golden differs, never the golden, unless the golden itself misreads the spec (the aliases must be `r1`, `r2` by depth and a junction's own alias `j` lives inside its template).

- [ ] **Step 3: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/compiler test/core/query/compiler
git commit -m "test(query): pin relation hops, presence and scoped-group semantics"
```

---

### Task 9: The dive registry and the minimal target entities

**Files:**
- Create: `lib/features/dive_log/query/dive_query_entity.dart`
- Create: `lib/features/dive_log/query/dive_child_query_entities.dart`
- Create: `lib/features/dive_sites/query/site_query_entity.dart`
- Create: `lib/features/equipment/query/equipment_query_entity.dart`
- Create: `lib/features/buddies/query/buddy_query_entity.dart`
- Create: `lib/features/tags/query/tag_query_entity.dart`
- Create: `lib/features/dive_types/query/dive_type_query_entity.dart`
- Create: `lib/features/trips/query/trip_query_entity.dart`
- Create: `lib/features/dive_centers/query/dive_center_query_entity.dart`
- Create: `lib/features/dive_computer/query/dive_computer_query_entity.dart`
- Create: `lib/features/courses/query/course_query_entity.dart`
- Create: `lib/features/marine_life/query/species_query_entity.dart`
- Create: `lib/features/certifications/query/certification_query_entity.dart`
- Create: `lib/features/query/app_query_registry.dart`
- Test: `test/features/query/app_query_registry_test.dart`

**Interfaces:**
- Consumes: Task 3 registry types; `decoSignalCondition` from `lib/features/statistics/data/dive_filter_sql.dart`; enums from `lib/core/constants/enums.dart`.
- Produces: `diveQueryEntity`, one `<x>QueryEntity` per file above, `appQueryRegistry` (a `QueryRegistry`).

Label keys follow one convention, `query_<subject>_<key>` for fields and relations and `query_entity_<subject>` for the entity, so Task 10's guard can derive the expected ARB key set from the registry alone.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/query/app_query_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/query/app_query_registry.dart';

void main() {
  test('every subject a relation targets has an entity', () {
    for (final e in appQueryRegistry.entities) {
      for (final r in e.relations) {
        expect(appQueryRegistry.maybeEntityFor(r.target), isNotNull,
            reason: '${e.subject}.${r.key} targets ${r.target}');
      }
    }
  });

  test('the request examples resolve on the dive entity', () {
    final dives = appQueryRegistry.entityFor(QuerySubject.dives);
    for (final path in const [
      ['weights'],
      ['gear', 'type'],
      ['waterTemp'],
      ['temp'],
      ['buddies', 'certifications', 'level'],
      ['site', 'country'],
      ['tanks', 'o2'],
      ['customFields', 'key'],
      ['weight'],
      ['deco'],
      ['year'],
    ]) {
      expect(resolvePath(appQueryRegistry, dives, FieldPath(path)).error, isNull, reason: path.join('.'));
    }
  });

  test('keys and aliases are unique within an entity', () {
    for (final e in appQueryRegistry.entities) {
      final names = e.segmentNames.toList();
      expect(names.toSet().length, names.length, reason: '${e.subject}: $names');
    }
  });

  test('label keys follow the convention', () {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        expect(f.labelKey, 'query_${e.subject.name}_${f.key}');
      }
      for (final r in e.relations) {
        expect(r.labelKey, 'query_${e.subject.name}_${r.key}');
      }
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/query/app_query_registry_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the dive registry**

```dart
// lib/features/dive_log/query/dive_query_entity.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

/// Every field and relation a dive query can name (#2365). This file is
/// the ONLY place a dive filter axis is defined: the paginated list, its
/// count, Statistics and the entity-backed views all compile from it.
///
/// SQL is written against `{r}`, the dive row's alias at whatever depth
/// the compiler reaches it. Every fragment is a column, an expression or a
/// correlated subquery; values are never interpolated.

String _label(String key) => 'query_dives_$key';

const _weekday = "CAST(strftime('%w', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)";
const _year = "CAST(strftime('%Y', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)";
const _weightsExist = 'EXISTS (SELECT 1 FROM dive_weights w WHERE w.dive_id = {r}.id)';

/// The gear union the equipment axes have always used: items linked
/// through `dive_equipment` plus cylinders the transmitter registry matched
/// through `dive_tanks.equipment_id`.
const kDiveGearJoinSql =
    '{to}.id IN (SELECT de.equipment_id FROM dive_equipment de WHERE de.dive_id = {from}.id '
    'UNION SELECT dt.equipment_id FROM dive_tanks dt WHERE dt.dive_id = {from}.id '
    'AND dt.equipment_id IS NOT NULL)';

List<String> _names<T extends Enum>(List<T> values) => [for (final v in values) v.name];

QueryField _num(String key, String sql, {List<String> aliases = const [], FieldDimension dimension = FieldDimension.none, ({double min, double max})? sanity, String? emptySql, List<String> tables = const []}) =>
    QueryField(key: key, aliases: aliases, type: FieldType.number, dimension: dimension, sql: sql, emptySql: emptySql ?? '$sql IS NULL', labelKey: _label(key), sanity: sanity, tables: tables);

QueryField _text(String key, String column) => QueryField(
  key: key, type: FieldType.text, sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')", labelKey: _label(key));

QueryField _enum(String key, String column, List<String> values) => QueryField(
  key: key, type: FieldType.enumName, sql: '{r}.$column', emptySql: '{r}.$column IS NULL',
  labelKey: _label(key), enumValues: values);

QueryField _bool(String key, String column) => QueryField(
  key: key, type: FieldType.bool, sql: '{r}.$column', emptySql: '0', labelKey: _label(key));

QueryRelation _fk(String key, QuerySubject target, String column, {List<String> aliases = const []}) => QueryRelation(
  key: key, aliases: aliases, target: target, shape: RelationShape.fk,
  joinSql: '{to}.id = {from}.$column', isMany: false, labelKey: _label(key));

QueryRelation _child(String key, QuerySubject target) => QueryRelation(
  key: key, target: target, shape: RelationShape.child,
  joinSql: '{to}.dive_id = {from}.id', isMany: true, labelKey: _label(key));

QueryRelation _junction(String key, QuerySubject target, String junction, String targetColumn, {List<String> aliases = const [], String? emptySql}) => QueryRelation(
  key: key, aliases: aliases, target: target, shape: RelationShape.junction,
  joinSql: 'EXISTS (SELECT 1 FROM $junction j WHERE j.dive_id = {from}.id AND j.$targetColumn = {to}.id)',
  isMany: true, labelKey: _label(key), emptySql: emptySql, tables: [junction]);

final QueryEntity diveQueryEntity = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.notes LIKE ? ESCAPE '\\'",
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.buddy LIKE ? ESCAPE '\\'",
    "{r}.dive_master LIKE ? ESCAPE '\\'",
    "EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = {r}.site_id AND (ts.name LIKE ? ESCAPE '\\' OR ts.country LIKE ? ESCAPE '\\' OR ts.region LIKE ? ESCAPE '\\'))",
    "EXISTS (SELECT 1 FROM dive_centers tc WHERE tc.id = {r}.dive_center_id AND tc.name LIKE ? ESCAPE '\\')",
    "EXISTS (SELECT 1 FROM dive_buddies tdb JOIN buddies tb ON tb.id = tdb.buddy_id WHERE tdb.dive_id = {r}.id AND tb.name LIKE ? ESCAPE '\\')",
    "EXISTS (SELECT 1 FROM dive_tags tdt JOIN tags tt ON tt.id = tdt.tag_id WHERE tdt.dive_id = {r}.id AND tt.name LIKE ? ESCAPE '\\')",
    "EXISTS (SELECT 1 FROM dive_custom_fields tcf WHERE tcf.dive_id = {r}.id AND (tcf.field_key LIKE ? ESCAPE '\\' OR tcf.field_value LIKE ? ESCAPE '\\'))",
  ],
  textSearchTables: const ['dive_sites', 'dive_centers', 'dive_buddies', 'buddies', 'dive_tags', 'tags', 'dive_custom_fields'],
  fields: [
    QueryField(key: 'id', type: FieldType.id, sql: '{r}.id', emptySql: '{r}.id IS NULL', labelKey: _label('id')),
    _num('diveNumber', '{r}.dive_number', aliases: ['number'], dimension: FieldDimension.count),
    _text('name', 'name'),
    QueryField(key: 'date', type: FieldType.date, sql: '{r}.dive_date_time', emptySql: '{r}.dive_date_time IS NULL', labelKey: _label('date')),
    _num('year', _year, dimension: FieldDimension.count, emptySql: '{r}.dive_date_time IS NULL'),
    QueryField(
      key: 'weekday', type: FieldType.enumName, sql: _weekday, emptySql: '{r}.dive_date_time IS NULL',
      labelKey: _label('weekday'),
      enumValues: const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      enumSqlValues: const {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 0},
    ),
    // Whole minutes, truncated, mirroring Duration.inMinutes in the old
    // apply(); the list path used seconds * 60 and disagreed with the
    // other two by up to 59 seconds.
    _num('bottomTime', '({r}.bottom_time / 60)', aliases: ['time', 'duration'], dimension: FieldDimension.minutes, emptySql: '{r}.bottom_time IS NULL'),
    _num('runtime', '({r}.runtime / 60)', dimension: FieldDimension.minutes, emptySql: '{r}.runtime IS NULL'),
    _num('depth', '{r}.max_depth', aliases: ['maxDepth'], dimension: FieldDimension.depth, sanity: (min: 0, max: 400)),
    _num('avgDepth', '{r}.avg_depth', dimension: FieldDimension.depth, sanity: (min: 0, max: 400)),
    // The synced water temperature. dive_sensor_summaries.min_temperature
    // is device-local and never synced, so it is not offered.
    _num('waterTemp', '{r}.water_temp', aliases: ['temp'], dimension: FieldDimension.temperature, sanity: (min: -5, max: 45)),
    _num('airTemp', '{r}.air_temp', dimension: FieldDimension.temperature, sanity: (min: -40, max: 60)),
    _num('visibility', '{r}.visibility_meters', dimension: FieldDimension.depth,
        emptySql: "({r}.visibility_meters IS NULL AND ({r}.visibility IS NULL OR TRIM({r}.visibility) = ''))"),
    _num('rating', '{r}.rating', dimension: FieldDimension.count, sanity: (min: 0, max: 5)),
    _num('surfaceInterval', '({r}.surface_interval_seconds / 60)', dimension: FieldDimension.minutes, emptySql: '{r}.surface_interval_seconds IS NULL'),
    _num('cnsEnd', '{r}.cns_end', aliases: ['cns'], dimension: FieldDimension.percent),
    _num('otu', '{r}.otu', dimension: FieldDimension.count),
    // Total lead in kg: the weights table when it has rows, else the
    // legacy scalar the edit form retired (#1392). Empty means neither.
    _num('weight', 'COALESCE((SELECT SUM(w.amount_kg) FROM dive_weights w WHERE w.dive_id = {r}.id), {r}.weight_amount)',
        aliases: ['lead'], dimension: FieldDimension.weight,
        emptySql: '({r}.weight_amount IS NULL AND NOT $_weightsExist)', tables: ['dive_weights']),
    _num('gasCount', '(SELECT COUNT(*) FROM dive_tanks t WHERE t.dive_id = {r}.id)', dimension: FieldDimension.count, emptySql: '0', tables: ['dive_tanks']),
    _text('notes', 'notes'),
    _text('diveMaster', 'dive_master'),
    _text('boatName', 'boat_name'),
    _text('diveOperator', 'dive_operator'),
    _text('surfaceConditions', 'surface_conditions'),
    _enum('currentStrength', 'current_strength', _names(CurrentStrength.values)),
    _enum('waterType', 'water_type', _names(WaterType.values)),
    _enum('entryMethod', 'entry_method', _names(EntryMethod.values)),
    _enum('exitMethod', 'exit_method', _names(EntryMethod.values)),
    _enum('diveMode', 'dive_mode', _names(DiveMode.values)),
    _bool('favorite', 'is_favorite'),
    _bool('excludedFromStats', 'excluded_from_stats'),
    _bool('planned', 'is_planned'),
    QueryField(
      key: 'deco', type: FieldType.bool, sql: '', emptySql: '0', labelKey: _label('deco'),
      boolSql: (
        whenTrue: decoSignalCondition(wantDeco: true, diveIdRef: '{r}.id'),
        whenFalse: decoSignalCondition(wantDeco: false, diveIdRef: '{r}.id'),
      ),
      tables: const ['dive_profile_series', 'dive_profile_events'],
    ),
    QueryField(
      key: 'hasProfile', type: FieldType.bool, sql: '', emptySql: '0', labelKey: _label('hasProfile'),
      boolSql: (
        whenTrue: 'EXISTS (SELECT 1 FROM dive_profile_series s WHERE s.dive_id = {r}.id)',
        whenFalse: 'NOT EXISTS (SELECT 1 FROM dive_profile_series s WHERE s.dive_id = {r}.id)',
      ),
      tables: const ['dive_profile_series'],
    ),
  ],
  relations: [
    _fk('site', QuerySubject.sites, 'site_id'),
    _fk('trip', QuerySubject.trips, 'trip_id'),
    _fk('center', QuerySubject.centers, 'dive_center_id', aliases: ['diveCenter']),
    _fk('computer', QuerySubject.computers, 'computer_id'),
    _fk('course', QuerySubject.courses, 'course_id'),
    _junction('buddies', QuerySubject.buddies, 'dive_buddies', 'buddy_id', aliases: ['buddy'],
        emptySql: "(({from}.buddy IS NULL OR {from}.buddy = '') AND NOT EXISTS (SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id))"),
    _junction('tags', QuerySubject.tags, 'dive_tags', 'tag_id', aliases: ['tag']),
    _junction('types', QuerySubject.diveTypes, 'dive_dive_types', 'dive_type_id', aliases: ['type', 'diveType']),
    QueryRelation(
      key: 'gear', aliases: const ['equipment'], target: QuerySubject.equipment, shape: RelationShape.custom,
      joinSql: kDiveGearJoinSql, isMany: true, labelKey: _label('gear'), tables: const ['dive_equipment', 'dive_tanks'],
    ),
    _child('tanks', QuerySubject.tanks),
    _child('weights', QuerySubject.weights),
    _child('customFields', QuerySubject.customFields),
    _child('sightings', QuerySubject.sightings),
    _child('media', QuerySubject.media),
  ],
);
```

`decoSignalCondition` takes `diveIdRef`; passing `'{r}.id'` leaves the placeholder for the compiler to substitute, which is why the deco `boolSql` can live at any depth.

- [ ] **Step 4: Write the child and target entities**

```dart
// lib/features/dive_log/query/dive_child_query_entities.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// The dive's child tables, reachable only through a dive relation.

QueryField _num(String subject, String key, String sql, {FieldDimension dimension = FieldDimension.none, String? emptySql}) =>
    QueryField(key: key, type: FieldType.number, dimension: dimension, sql: sql, emptySql: emptySql ?? '$sql IS NULL', labelKey: 'query_${subject}_$key');

QueryField _text(String subject, String key, String column) => QueryField(
  key: key, type: FieldType.text, sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')", labelKey: 'query_${subject}_$key');

final tankQueryEntity = QueryEntity(
  subject: QuerySubject.tanks,
  table: 'dive_tanks',
  fields: [
    _num('tanks', 'o2', '{r}.o2_percent', dimension: FieldDimension.percent),
    _num('tanks', 'he', '{r}.he_percent', dimension: FieldDimension.percent),
    _num('tanks', 'startPressure', '{r}.start_pressure', dimension: FieldDimension.pressure),
    _num('tanks', 'endPressure', '{r}.end_pressure', dimension: FieldDimension.pressure),
    _num('tanks', 'volume', '{r}.volume', dimension: FieldDimension.volume),
    _text('tanks', 'name', 'tank_name'),
  ],
  relations: const [
    QueryRelation(key: 'cylinder', target: QuerySubject.equipment, shape: RelationShape.fk,
        joinSql: '{to}.id = {from}.equipment_id', isMany: false, labelKey: 'query_tanks_cylinder'),
  ],
);

final weightQueryEntity = QueryEntity(
  subject: QuerySubject.weights,
  table: 'dive_weights',
  fields: [
    _num('weights', 'amount', '{r}.amount_kg', dimension: FieldDimension.weight),
    QueryField(key: 'type', type: FieldType.enumName, sql: '{r}.weight_type', emptySql: '{r}.weight_type IS NULL',
        labelKey: 'query_weights_type', enumValues: [for (final v in WeightType.values) v.name]),
    _text('weights', 'notes', 'notes'),
  ],
);

final customFieldQueryEntity = QueryEntity(
  subject: QuerySubject.customFields,
  table: 'dive_custom_fields',
  fields: [
    _text('customFields', 'key', 'field_key'),
    _text('customFields', 'value', 'field_value'),
  ],
);

final sightingQueryEntity = QueryEntity(
  subject: QuerySubject.sightings,
  table: 'sightings',
  fields: [
    _num('sightings', 'count', '{r}.count', dimension: FieldDimension.count),
    _text('sightings', 'notes', 'notes'),
  ],
  relations: const [
    QueryRelation(key: 'species', target: QuerySubject.species, shape: RelationShape.fk,
        joinSql: '{to}.id = {from}.species_id', isMany: false, labelKey: 'query_sightings_species'),
  ],
);

final mediaQueryEntity = QueryEntity(
  subject: QuerySubject.media,
  table: 'media',
  fields: [
    QueryField(key: 'type', type: FieldType.enumName, sql: '{r}.file_type', emptySql: '{r}.file_type IS NULL',
        labelKey: 'query_media_type', enumValues: const ['photo', 'video', 'document', 'signature', 'map']),
    _text('media', 'caption', 'caption'),
    QueryField(key: 'favorite', type: FieldType.bool, sql: '{r}.is_favorite', emptySql: '0', labelKey: 'query_media_favorite'),
  ],
);
```

Check the `media.file_type` stored values against the `Media` table's `fileType` column default and its enum in `lib/core/constants/enums.dart` before committing; use the stored names, not the list above, if they differ.

The target entities are one small file each. Every one follows this shape; only the fields differ:

```dart
// lib/features/dive_sites/query/site_query_entity.dart
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

QueryField _text(String key, String column) => QueryField(
  key: key, type: FieldType.text, sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')", labelKey: 'query_sites_$key');

/// Minimal in PR 1 (enough for dive paths like `site.country`); PR 3 adds
/// the rest and the site list's own query entry point.
final siteQueryEntity = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  diverScopeColumn: 'diver_id',
  fields: [
    _text('name', 'name'),
    _text('country', 'country'),
    _text('region', 'region'),
    _text('city', 'city'),
    _text('island', 'island'),
    QueryField(key: 'rating', type: FieldType.number, dimension: FieldDimension.count, sql: '{r}.rating',
        emptySql: '{r}.rating IS NULL', labelKey: 'query_sites_rating', sanity: (min: 0, max: 5)),
    QueryField(key: 'maxDepth', type: FieldType.number, dimension: FieldDimension.depth, sql: '{r}.max_depth',
        emptySql: '{r}.max_depth IS NULL', labelKey: 'query_sites_maxDepth'),
  ],
);
```

| File | subject, table | fields (key: column) | relations |
| --- | --- | --- | --- |
| `equipment/query/equipment_query_entity.dart` | `equipment`, `equipment` | `name`, `brand`, `model`, `serialNumber: serial_number` (text); `type` (enum, `EquipmentType.values` names); `status` (text); `active: is_active` (bool) | `attributes` child to `equipmentAttributes`, `joinSql: '{to}.equipment_id = {from}.id'` |
| same file | `equipmentAttributes`, `equipment_attributes` | `key: attr_key` (text), `custom: is_custom` (bool), `valueText: value_text` (text), `valueNum: value_num` (number, dimension none) | none |
| `buddies/query/buddy_query_entity.dart` | `buddies`, `buddies`, diver scope `diver_id` | `name`, `email`, `phone`, `notes` (text), `favorite: is_favorite` (bool) | `certifications` child to `certifications`, `joinSql: '{to}.buddy_id = {from}.id'` |
| `certifications/query/certification_query_entity.dart` | `certifications`, `certifications` | `name`, `agency`, `level`, `cardNumber: card_number`, `instructorName: instructor_name` (text); `issueDate: issue_date`, `expiryDate: expiry_date` (date) | none |
| `tags/query/tag_query_entity.dart` | `tags`, `tags`, diver scope | `name` (text) | none |
| `dive_types/query/dive_type_query_entity.dart` | `diveTypes`, `dive_types`, diver scope | `name` (text), `builtIn: is_built_in` (bool) | none |
| `trips/query/trip_query_entity.dart` | `trips`, `trips`, diver scope | `name`, `location` (text); `startDate: start_date`, `endDate: end_date` (date) | none |
| `dive_centers/query/dive_center_query_entity.dart` | `centers`, `dive_centers`, diver scope | `name`, `city`, `country` (text; confirm the country column exists in `DiveCenters`, else drop it) | none |
| `dive_computer/query/dive_computer_query_entity.dart` | `computers`, `dive_computers`, diver scope | `name`, `manufacturer`, `model`, `serialNumber: serial_number` (text) | none |
| `courses/query/course_query_entity.dart` | `courses`, `courses`, diver scope | `name`, `agency` (text); `startDate: start_date`, `completionDate: completion_date` (date) | none |
| `marine_life/query/species_query_entity.dart` | `species`, `species` | `name: common_name`, `scientificName: scientific_name`, `category` (text) | none |

A date field on these tables stores epoch milliseconds like `dive_date_time`; declare it with `FieldType.date` and `emptySql: '{r}.<col> IS NULL'`.

- [ ] **Step 5: Assemble the registry**

```dart
// lib/features/query/app_query_registry.dart
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/courses/query/course_query_entity.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_computer/query/dive_computer_query_entity.dart';
import 'package:submersion/features/dive_log/query/dive_child_query_entities.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/dive_types/query/dive_type_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/tags/query/tag_query_entity.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Every entity a query can root at or reach. Built once; the core query
/// package never imports a feature, so the assembly lives here.
final QueryRegistry appQueryRegistry = QueryRegistry([
  diveQueryEntity,
  tankQueryEntity,
  weightQueryEntity,
  customFieldQueryEntity,
  sightingQueryEntity,
  mediaQueryEntity,
  siteQueryEntity,
  equipmentQueryEntity,
  equipmentAttributeQueryEntity,
  buddyQueryEntity,
  certificationQueryEntity,
  tagQueryEntity,
  diveTypeQueryEntity,
  tripQueryEntity,
  diveCenterQueryEntity,
  diveComputerQueryEntity,
  courseQueryEntity,
  speciesQueryEntity,
]);
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/query/app_query_registry_test.dart && flutter test test/architecture/`
Expected: PASS. The architecture guards scan all of `lib/`; a new `lib/` file that trips one is fixed here, not suppressed.

- [ ] **Step 7: Commit**

```bash
dart format lib/features test/features/query
git add lib/features/query lib/features/dive_log/query lib/features/dive_sites/query lib/features/equipment/query lib/features/buddies/query lib/features/certifications/query lib/features/tags/query lib/features/dive_types/query lib/features/trips/query lib/features/dive_centers/query lib/features/dive_computer/query lib/features/courses/query lib/features/marine_life/query test/features/query
git commit -m "feat(query): dive registry and the entities its relations reach"
```

---

### Task 10: Labels in every locale and the registry guards

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `lib/l10n/arb/app_*.arb`
- Test: `test/features/query/query_registry_guards_test.dart`

**Interfaces:**
- Consumes: Task 9; `setUpTestDatabase()` from `test/helpers/test_database.dart`; Drift table metadata (`AppDatabase.allTables`, `TableInfo.$columns`, `GeneratedColumn.$customConstraints`).
- Produces: nothing new; the guards.

- [ ] **Step 1: Write the failing guard test**

```dart
// test/features/query/query_registry_guards_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../helpers/test_database.dart';

/// The registry is hand-written SQL. These guards make a renamed column, a
/// misspelled table, a missing label or a template without ESCAPE fail the
/// build instead of a query at runtime.
void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  TableInfo tableNamed(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name, orElse: () => throw StateError('no table $name'));

  test('every entity names a real table with a real id column', () {
    for (final e in appQueryRegistry.entities) {
      final t = tableNamed(e.table);
      expect(t.$columns.map((c) => c.$name), contains(e.idColumn), reason: e.table);
      if (e.diverScopeColumn != null) {
        expect(t.$columns.map((c) => c.$name), contains(e.diverScopeColumn), reason: e.table);
      }
    }
  });

  test('every field sql and emptySql compiles against its table', () async {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        for (final fragment in [if (f.boolSql == null) '${substituteRow(f.sql, 'r0')} IS NOT NULL', substituteRow(f.emptySql, 'r0'), if (f.boolSql != null) substituteRow(f.boolSql!.whenTrue, 'r0'), if (f.boolSql != null) substituteRow(f.boolSql!.whenFalse, 'r0')]) {
          final sql = 'SELECT 1 FROM ${e.table} r0 WHERE $fragment';
          await expectLater(db.customSelect(sql).get(), completes, reason: '${e.subject}.${f.key}: $sql');
        }
      }
    }
  });

  test('every relation joinSql and emptySql compiles, and fk/child columns exist', () async {
    for (final e in appQueryRegistry.entities) {
      for (final r in e.relations) {
        final target = appQueryRegistry.entityFor(r.target);
        final join = substituteJoin(r.joinSql, 'r0', 'r1');
        final sql = 'SELECT 1 FROM ${e.table} r0 WHERE EXISTS (SELECT 1 FROM ${target.table} r1 WHERE $join)';
        await expectLater(db.customSelect(sql).get(), completes, reason: '${e.subject}.${r.key}: $sql');
        if (r.emptySql != null) {
          final empty = 'SELECT 1 FROM ${e.table} r0 WHERE ${substituteJoin(r.emptySql!, 'r0', 'r1')}';
          await expectLater(db.customSelect(empty).get(), completes, reason: '${e.subject}.${r.key} emptySql');
        }
        final fk = RegExp(r'\{(to|from)\}\.(\w+)').allMatches(r.joinSql);
        for (final m in fk) {
          final table = m[1] == 'to' ? target.table : e.table;
          expect(tableNamed(table).$columns.map((c) => c.$name), contains(m[2]),
              reason: '${e.subject}.${r.key} names ${m[2]} on $table');
        }
        if (r.shape == RelationShape.fk || r.shape == RelationShape.child) {
          expect(fk.length, 2, reason: '${e.subject}.${r.key}: an fk or child hop is one equality');
        }
      }
    }
  });

  test('every declared extra table exists', () {
    for (final e in appQueryRegistry.entities) {
      for (final t in [...e.textSearchTables, for (final f in e.fields) ...f.tables, for (final r in e.relations) ...r.tables]) {
        tableNamed(t);
      }
    }
  });

  test('text search templates escape LIKE and compile', () async {
    for (final e in appQueryRegistry.entities) {
      for (final t in e.textSearchSql) {
        expect(t, contains("ESCAPE '\\'"), reason: '${e.subject}: $t');
        final n = countPlaceholders(t);
        final sql = 'SELECT 1 FROM ${e.table} r0 WHERE ${substituteRow(t, 'r0')}';
        await expectLater(
            db.customSelect(sql, variables: [for (var i = 0; i < n; i++) Variable<String>('%x%')]).get(),
            completes, reason: '${e.subject}: $sql');
      }
    }
  });

  test('every label key exists in every locale', () {
    final dir = p.join('lib', 'l10n', 'arb');
    final files = Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.arb'));
    final expected = <String>{
      for (final e in appQueryRegistry.entities) ...[
        'query_entity_${e.subject.name}',
        for (final f in e.fields) f.labelKey,
        for (final r in e.relations) r.labelKey,
      ],
    };
    for (final f in files) {
      final keys = (jsonDecode(f.readAsStringSync()) as Map<String, Object?>).keys.toSet();
      final missing = expected.difference(keys);
      expect(missing, isEmpty, reason: '${p.basename(f.path)} lacks $missing');
    }
  });

  test('enum fields list the stored names', () {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        if (f.enumValues != null) {
          expect(f.enumValues, isNotEmpty, reason: '${e.subject}.${f.key}');
          expect(f.enumValues!.toSet().length, f.enumValues!.length);
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run the guard to see what fails**

Run: `flutter test test/features/query/query_registry_guards_test.dart`
Expected: the label test FAILS (no ARB keys yet); any other failure is a registry bug from Task 9 and is fixed there before moving on.

- [ ] **Step 3: Add the labels**

Add every key the guard lists to `app_en.arb`. Values are short noun labels for the builder's field picker. Use these English values; the dive block is complete, the others follow the same pattern (key name to title case):

```
query_entity_dives: Dives            query_entity_sites: Dive sites
query_entity_equipment: Equipment    query_entity_equipmentAttributes: Equipment attributes
query_entity_buddies: Buddies        query_entity_certifications: Certifications
query_entity_tags: Tags              query_entity_diveTypes: Dive types
query_entity_trips: Trips            query_entity_centers: Dive centers
query_entity_computers: Dive computers   query_entity_courses: Courses
query_entity_species: Species        query_entity_tanks: Tanks
query_entity_weights: Weights        query_entity_customFields: Custom fields
query_entity_sightings: Sightings    query_entity_media: Media

query_dives_id: Dive ID              query_dives_diveNumber: Dive number
query_dives_name: Name               query_dives_date: Date
query_dives_year: Year               query_dives_weekday: Weekday
query_dives_bottomTime: Bottom time  query_dives_runtime: Runtime
query_dives_depth: Max depth         query_dives_avgDepth: Average depth
query_dives_waterTemp: Water temperature   query_dives_airTemp: Air temperature
query_dives_visibility: Visibility   query_dives_rating: Rating
query_dives_surfaceInterval: Surface interval   query_dives_cnsEnd: CNS at end
query_dives_otu: OTU                 query_dives_weight: Weight
query_dives_gasCount: Number of tanks   query_dives_notes: Notes
query_dives_diveMaster: Dive master  query_dives_boatName: Boat
query_dives_diveOperator: Operator   query_dives_surfaceConditions: Surface conditions
query_dives_currentStrength: Current   query_dives_waterType: Water type
query_dives_entryMethod: Entry method   query_dives_exitMethod: Exit method
query_dives_diveMode: Dive mode      query_dives_favorite: Favorite
query_dives_excludedFromStats: Excluded from statistics
query_dives_planned: Planned         query_dives_deco: Decompression dive
query_dives_hasProfile: Has profile  query_dives_site: Site
query_dives_trip: Trip               query_dives_center: Dive center
query_dives_computer: Dive computer  query_dives_course: Course
query_dives_buddies: Buddies         query_dives_tags: Tags
query_dives_types: Dive types        query_dives_gear: Gear
query_dives_tanks: Tanks             query_dives_weights: Weights
query_dives_customFields: Custom fields   query_dives_sightings: Sightings
query_dives_media: Media
```

Each key gets a `@key` metadata entry with `"description": "Field label in the query builder"`. Append the block before the closing brace of `app_en.arb`, and add translated blocks to `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh` (translations only, no `@` metadata in non-en files if the file's other keys carry none; match the file's convention). German uses "AMV" never "SAC"; there is no SAC label here. Regenerate: `flutter gen-l10n`, and confirm `git status` shows only the `.arb` files and the generated `app_localizations_*.dart` changed.

- [ ] **Step 4: Run the guards and the l10n tests**

Run: `flutter test test/features/query/query_registry_guards_test.dart test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/l10n test/features/query/query_registry_guards_test.dart
git commit -m "feat(query): registry guards and field labels in every locale"
```

---

### Task 11: Semantics against a real database

**Files:**
- Create: `test/features/dive_log/query/dive_query_fixture.dart`
- Test: `test/features/dive_log/query/dive_query_semantics_test.dart`

**Interfaces:**
- Consumes: Tasks 7 to 10; `setUpTestDatabase()`.
- Produces: `seedQueryFixture(AppDatabase) -> Future<QueryFixtureIds>`, reused by Tasks 12 and 13.

- [ ] **Step 1: Write the fixture**

```dart
// test/features/dive_log/query/dive_query_fixture.dart
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';

/// Six dives that between them answer every request in #2365:
///
/// | id | weight | gear | temp | buddy | site | notes |
/// | d1 | table row 2 kg | wetsuit | 24 | Ana (linked) | Salt Pier (Bonaire) | manta |
/// | d2 | legacy scalar 3 kg | drysuit | null | legacy text "Bob" | Salt Pier | '' |
/// | d3 | none | bcd only | 18 | none | Hilma Hooker (Bonaire) | 100% night |
/// | d4 | none | none | null | none | null | '' |
/// | d5 | table row 1 kg | wetsuit + drysuit | 30 | Ana + Cid | Cenote (Mexico) | '' |
/// | d6 | none | none | 12 | none | Cenote | '' (other diver) |
class QueryFixtureIds {
  static const dives = ['d1', 'd2', 'd3', 'd4', 'd5', 'd6'];
  static const mine = ['d1', 'd2', 'd3', 'd4', 'd5'];
}

Future<void> seedQueryFixture(AppDatabase db) async {
  final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
  int day(int y, int m, int d) => DateTime.utc(y, m, d, 10).millisecondsSinceEpoch;

  Future<void> site(String id, String name, String country) => db.into(db.diveSites).insert(DiveSitesCompanion(
      id: Value(id), name: Value(name), country: Value(country), createdAt: Value(now), updatedAt: Value(now)));
  await site('s1', 'Salt Pier', 'Bonaire');
  await site('s2', 'Hilma Hooker', 'Bonaire');
  await site('s3', 'Cenote', 'Mexico');

  Future<void> buddy(String id, String name) => db.into(db.buddies).insert(BuddiesCompanion(
      id: Value(id), name: Value(name), createdAt: Value(now), updatedAt: Value(now)));
  await buddy('b1', 'Ana');
  await buddy('b2', 'Cid');
  await db.into(db.certifications).insert(CertificationsCompanion(
      id: const Value('c1'), buddyId: const Value('b1'), name: const Value('Rescue Diver'),
      agency: const Value('PADI'), level: const Value('rescue'), createdAt: Value(now), updatedAt: Value(now)));

  Future<void> gear(String id, String type) => db.into(db.equipment).insert(EquipmentCompanion(
      id: Value(id), name: Value(id), type: Value(type), createdAt: Value(now), updatedAt: Value(now)));
  await gear('g_wet', 'wetsuit');
  await gear('g_dry', 'drysuit');
  await gear('g_bcd', 'bcd');

  Future<void> dive(String id, {String diver = 'me', double? temp, String? siteId, String notes = '', String? legacyBuddy, double? legacyWeight, int? date, double? depth, int? bottom}) =>
      db.into(db.dives).insert(DivesCompanion(
          id: Value(id), diverId: Value(diver), diveDateTime: Value(date ?? day(2025, 3, 14)),
          waterTemp: Value(temp), siteId: Value(siteId), notes: Value(notes), buddy: Value(legacyBuddy),
          weightAmount: Value(legacyWeight), maxDepth: Value(depth), bottomTime: Value(bottom),
          createdAt: Value(now), updatedAt: Value(now)));
  await dive('d1', temp: 24, siteId: 's1', notes: 'manta ray', depth: 18, bottom: 50 * 60 + 30, date: day(2025, 1, 5));
  await dive('d2', temp: null, siteId: 's1', legacyBuddy: 'Bob', legacyWeight: 3, depth: 30, bottom: 45 * 60, date: day(2025, 2, 9));
  await dive('d3', temp: 18, siteId: 's2', notes: '100% night dive', depth: 25, bottom: null, date: day(2025, 3, 14));
  await dive('d4', temp: null, siteId: null, depth: null, bottom: 10 * 60, date: day(2024, 12, 31));
  await dive('d5', temp: 30, siteId: 's3', depth: 40, bottom: 10 * 60 + 59, date: day(2025, 3, 15));
  await dive('d6', diver: 'other', temp: 12, siteId: 's3', depth: 12, bottom: 20 * 60);

  Future<void> weight(String id, String diveId, double kg) => db.into(db.diveWeights).insert(DiveWeightsCompanion(
      id: Value(id), diveId: Value(diveId), weightType: const Value('belt'), amountKg: Value(kg), createdAt: Value(now)));
  await weight('w1', 'd1', 2);
  await weight('w5', 'd5', 1);

  Future<void> link(String diveId, String equipmentId) =>
      db.into(db.diveEquipment).insert(DiveEquipmentCompanion(diveId: Value(diveId), equipmentId: Value(equipmentId)));
  await link('d1', 'g_wet');
  await link('d2', 'g_dry');
  await link('d3', 'g_bcd');
  await link('d5', 'g_wet');
  await link('d5', 'g_dry');

  Future<void> buddyLink(String id, String diveId, String buddyId) => db.into(db.diveBuddies).insert(DiveBuddiesCompanion(
      id: Value(id), diveId: Value(diveId), buddyId: Value(buddyId), createdAt: Value(now)));
  await buddyLink('db1', 'd1', 'b1');
  await buddyLink('db5a', 'd5', 'b1');
  await buddyLink('db5b', 'd5', 'b2');
}
```

If a companion above lacks a column that the schema requires (check the `Divers` foreign key on `diver_id`: insert a `me` and an `other` diver first if the test database enforces it; other repository tests insert dives without one, so match them), adjust the fixture, never the assertions.

- [ ] **Step 2: Write the failing semantics test**

```dart
// test/features/dive_log/query/dive_query_semantics_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final names = MapNameResolver({
    QuerySubject.sites: {'Salt Pier': 's1', 'Hilma Hooker': 's2', 'Cenote': 's3'},
    QuerySubject.buddies: {'Ana': 'b1', 'Cid': 'b2'},
  });
  final parser = QueryParser(appQueryRegistry, dives,
      ParseContext(prefs: kMetricPrefs, now: DateTime(2026, 9, 25), names: names));

  /// Compiles [text] and returns the matching ids for the `me` diver.
  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final where = q.isEmpty ? '' : 'AND ${q.where}';
    final rows = await db.customSelect(
      'SELECT d.id FROM dives d WHERE d.diver_id = ? $where',
      variables: [Variable<String>('me'), ...q.params.map((p) => Variable(p))],
    ).get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('the request: missing weight, exposure gear, temperature', () async {
    expect(await ids('weights:none'), {'d2', 'd3', 'd4'}, reason: 'no weight ROWS; d2 has only the legacy scalar');
    expect(await ids('weight:none'), {'d3', 'd4'}, reason: 'the weight field counts the legacy scalar as present');
    expect(await ids('NOT gear.type in [wetsuit, drysuit]'), {'d3', 'd4'});
    expect(await ids('temp:none'), {'d2', 'd4'});
    expect(await ids('buddies:none'), {'d3', 'd4'}, reason: 'legacy text buddy counts as present');
    expect(await ids('(weights:none OR temp:none) AND year = 2025'), {'d2', 'd3'});
  });

  test('paths, refs and scoped groups', () async {
    expect(await ids('site.country = Bonaire'), {'d1', 'd2', 'd3'});
    expect(await ids('site = "Salt Pier"'), {'d1', 'd2'});
    expect(await ids('site:none'), {'d4'});
    expect(await ids('buddies.certifications.level = rescue'), {'d1', 'd5'});
    expect(await ids('buddies = Ana AND buddies = Cid'), {'d5'});
    expect(await ids('gear[type = wetsuit] AND gear[type = drysuit]'), {'d5'});
    expect(await ids('weights[amount >= 2]'), {'d1'});
    expect(await ids('weight >= 2'), {'d1', 'd2'}, reason: 'sums the table, falls back to the scalar');
  });

  test('numbers, units and truncated minutes', () async {
    expect(await ids('depth > 100ft'), {'d5'});
    expect(await ids('bottomTime = 50'), {'d1'}, reason: '50:30 truncates to 50');
    expect(await ids('bottomTime = 10'), {'d4', 'd5'}, reason: '10:59 truncates to 10');
    expect(await ids('bottomTime != 10'), {'d1', 'd2'}, reason: 'unrecorded is excluded (Review Focus 5)');
    expect(await ids('bottomTime:none'), {'d3'});
  });

  test('dates are calendar days in the wall clock frame', () async {
    expect(await ids('date in 2025'), {'d1', 'd2', 'd3', 'd5'});
    expect(await ids('date = 2025-03-14'), {'d3'});
    expect(await ids('date between 2025-03-14 and 2025-03-15'), {'d3', 'd5'});
    expect(await ids('date < 2025-01-01'), {'d4'});
    expect(await ids('weekday = friday'), {'d3'});
  });

  test('text search matches literally, including % (Review Focus 3)', () async {
    expect(await ids('manta'), {'d1'});
    expect(await ids('"100%"'), {'d3'});
    expect(await ids('"salt pier"'), {'d1', 'd2'}, reason: 'site name is a search column');
    expect(await ids('notes ~ "100%"'), {'d3'});
    expect(await ids('notes:none'), {'d2', 'd4', 'd5'});
  });

  test('the empty query matches every dive of the diver', () async {
    expect(await ids(''), QueryFixtureIds.mine.toSet());
  });

  test('a three-hop query is one statement with no full scan on a hop', () async {
    final q = compileQuery(
      (parser.parse('buddies.certifications.level = rescue AND site.country = Bonaire') as ParseOk).node,
      dives, appQueryRegistry, rootAlias: 'd');
    final plan = await db.customSelect(
      'EXPLAIN QUERY PLAN SELECT d.id FROM dives d WHERE ${q.where}',
      variables: q.params.map((p) => Variable(p)).toList(),
    ).get();
    final lines = plan.map((r) => r.data['detail'].toString()).toList();
    // The root scan is expected; every correlated hop must use an index.
    final scans = lines.where((l) => l.startsWith('SCAN') && !l.contains('dives')).toList();
    expect(scans, isEmpty, reason: lines.join('\n'));
  });
}
```

- [ ] **Step 3: Run the test**

Run: `flutter test test/features/dive_log/query/dive_query_semantics_test.dart`
Expected: PASS. A failing `EXPLAIN QUERY PLAN` case names a hop whose correlation column has no index; add the index in this PR only if the table's FK column is unindexed in `database.dart` (a schema rung), otherwise fix the joinSql. A failing id-set case is a registry or compiler bug, never a fixture change.

- [ ] **Step 4: Commit**

```bash
dart format test/features/dive_log/query
git add test/features/dive_log/query
git commit -m "test(query): the request's queries against a seeded database"
```

---

### Task 12: `DiveFilterState.toQuery()`, the census and the equivalence proof

**Files:**
- Create: `lib/features/dive_log/query/dive_filter_query.dart`
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (add `query`, keep `apply()` for now)
- Test: `test/features/dive_log/query/dive_filter_query_test.dart`
- Test: `test/features/dive_log/query/dive_filter_query_census_test.dart`
- Test: `test/features/dive_log/query/dive_filter_apply_equivalence_test.dart`

**Interfaces:**
- Consumes: Tasks 7, 9, 11; `EquipmentAttrCondition` (`lib/features/equipment/domain/models/equipment_attr_condition.dart`).
- Produces: `extension DiveFilterQuery on DiveFilterState { QueryNode? toQuery(); }`, `CompiledQuery compileDiveFilter(DiveFilterState, {String rootAlias = 'r0'})`, `Set<String> diveFilterTablesTouched(DiveFilterState)`.

- [ ] **Step 1: Add the `query` field to `DiveFilterState`**

In `dive_filter_state.dart`: add `final QueryNode? query;` with the doc comment below, a constructor parameter `this.query`, `copyWith` parameters `QueryNode? query` and `bool clearQuery = false`, and `query != null` in `hasActiveFilters`. Import `package:submersion/core/query/domain/query_node.dart`.

```dart
  /// The advanced part of the filter: a query tree the typed field or the
  /// rule builder edits (#2365). ANDed with every other axis by
  /// `toQuery()`. Null means no advanced conditions.
  final QueryNode? query;
```

- [ ] **Step 2: Write the failing lowering tests**

```dart
// test/features/dive_log/query/dive_filter_query_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

void main() {
  test('an empty filter lowers to null', () {
    expect(const DiveFilterState().toQuery(), isNull);
    expect(compileDiveFilter(const DiveFilterState()).isEmpty, isTrue);
  });

  test('every axis lowers to the documented condition', () {
    final f = DiveFilterState(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      weekdays: const [1, 7],
      diveTypeId: 'dt1',
      siteId: 's1',
      tripId: 't1',
      diveCenterId: 'c1',
      computerId: 'pc1',
      minDepth: 18,
      maxDepth: 30,
      minO2Percent: 30,
      maxO2Percent: 36,
      minRating: 4,
      minBottomTimeMinutes: 20,
      maxBottomTimeMinutes: 60,
      favoritesOnly: true,
      excludedFromStatsOnly: true,
      decoOnly: false,
      noBuddyOnly: true,
      tagIds: const ['tag1', 'tag2'],
      equipmentIds: const ['g1'],
      diveIds: const ['d1', 'd2'],
      buddyNameFilter: 'ana, cid',
      buddyId: 'b1',
      customFieldKey: 'Exposure',
      customFieldValue: 'dry',
      equipmentAttrConditions: [EquipmentAttrCondition.suitThickness(min: 5, max: 7)],
      query: ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('manta')),
    );
    final q = f.toQuery() as AndNode;
    expect(q.children, containsAll(<QueryNode>[
      ConditionNode(const FieldPath(['date']), QueryOp.gte, DateValue(DateTime(2025, 1, 1))),
      ConditionNode(const FieldPath(['date']), QueryOp.lte, DateValue(DateTime(2025, 12, 31))),
      ConditionNode(const FieldPath(['weekday']), QueryOp.inList, const ListValue([EnumValue('monday'), EnumValue('sunday')])),
      ConditionNode(const FieldPath(['types']), QueryOp.eq, const RefValue('dt1', 'dt1')),
      ConditionNode(const FieldPath(['site']), QueryOp.eq, const RefValue('s1', 's1')),
      ConditionNode(const FieldPath(['trip']), QueryOp.eq, const RefValue('t1', 't1')),
      ConditionNode(const FieldPath(['center']), QueryOp.eq, const RefValue('c1', 'c1')),
      ConditionNode(const FieldPath(['computer']), QueryOp.eq, const RefValue('pc1', 'pc1')),
      ConditionNode(const FieldPath(['depth']), QueryOp.gte, const NumberValue(18, null)),
      ConditionNode(const FieldPath(['depth']), QueryOp.lte, const NumberValue(30, null)),
      ScopedNode(const FieldPath(['tanks']), AndNode([
        ConditionNode(const FieldPath(['o2']), QueryOp.gte, const NumberValue(30, null)),
        ConditionNode(const FieldPath(['o2']), QueryOp.lte, const NumberValue(36, null)),
      ])),
      ConditionNode(const FieldPath(['rating']), QueryOp.gte, const NumberValue(4, null)),
      ConditionNode(const FieldPath(['bottomTime']), QueryOp.gte, const NumberValue(20, null)),
      ConditionNode(const FieldPath(['bottomTime']), QueryOp.lte, const NumberValue(60, null)),
      ConditionNode(const FieldPath(['favorite']), QueryOp.eq, const BoolValue(true)),
      ConditionNode(const FieldPath(['excludedFromStats']), QueryOp.eq, const BoolValue(true)),
      ConditionNode(const FieldPath(['deco']), QueryOp.eq, const BoolValue(false)),
      ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null),
      ConditionNode(const FieldPath(['tags']), QueryOp.inList, const ListValue([RefValue('tag1', 'tag1'), RefValue('tag2', 'tag2')])),
      ConditionNode(const FieldPath(['gear']), QueryOp.inList, const ListValue([RefValue('g1', 'g1')])),
      ConditionNode(const FieldPath(['id']), QueryOp.inList, const ListValue([StringValue('d1'), StringValue('d2')])),
      ConditionNode(const FieldPath(['buddies']), QueryOp.eq, const RefValue('b1', 'b1')),
      ScopedNode(const FieldPath(['customFields']), AndNode([
        ConditionNode(const FieldPath(['key']), QueryOp.eq, const StringValue('Exposure')),
        ConditionNode(const FieldPath(['value']), QueryOp.contains, const StringValue('dry')),
      ])),
      ConditionNode(const FieldPath(['notes']), QueryOp.contains, const StringValue('manta')),
    ]));
    // The buddy-name filter: each comma part must match a linked buddy OR
    // the legacy text, and the parts AND.
    expect(q.children, contains(OrNode([
      ScopedNode(const FieldPath(['buddies']), ConditionNode(const FieldPath(['name']), QueryOp.contains, const StringValue('ana'))),
      ConditionNode(const FieldPath(['legacyBuddy']), QueryOp.contains, const StringValue('ana')),
    ])));
    // The suit-thickness condition: a suit whose thickness_mm row is in range.
    expect(q.children, contains(ScopedNode(const FieldPath(['gear']), AndNode([
      ConditionNode(const FieldPath(['type']), QueryOp.inList, const ListValue([EnumValue('drysuit'), EnumValue('wetsuit')])),
      ScopedNode(const FieldPath(['attributes']), AndNode([
        ConditionNode(const FieldPath(['key']), QueryOp.eq, const StringValue('thickness_mm')),
        ConditionNode(const FieldPath(['custom']), QueryOp.eq, const BoolValue(false)),
        ConditionNode(const FieldPath(['valueNum']), QueryOp.gte, const NumberValue(5, null)),
        ConditionNode(const FieldPath(['valueNum']), QueryOp.lte, const NumberValue(7, null)),
      ])),
    ]))));
  });

  test('a blank buddy-name filter lowers to nothing', () {
    expect(const DiveFilterState(buddyNameFilter: ' , ').toQuery(), isNull);
  });

  test('the compiled filter names the tables it reads', () {
    expect(diveFilterTablesTouched(const DiveFilterState(noBuddyOnly: true)), containsAll(['dives', 'buddies', 'dive_buddies']));
    expect(diveFilterTablesTouched(const DiveFilterState(decoOnly: true)), containsAll(['dive_profile_series', 'dive_profile_events']));
    expect(diveFilterTablesTouched(const DiveFilterState()), {'dives'});
  });
}
```

The buddy-name lowering needs a `legacyBuddy` text field on the dive registry (`{r}.buddy`, label `query_dives_legacyBuddy`, "Buddy (legacy text)"); add it to Task 9's file and the ARB block as part of this task.

```dart
// test/features/dive_log/query/dive_filter_query_census_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every DiveFilterState field must be lowered by toQuery(), or the axis
/// silently filters nothing. Source-level, like dive_edit_save_field_census.
void main() {
  test('toQuery() names every DiveFilterState field', () {
    final state = File(p.join('lib', 'features', 'dive_log', 'domain', 'models', 'dive_filter_state.dart')).readAsStringSync();
    final lowering = File(p.join('lib', 'features', 'dive_log', 'query', 'dive_filter_query.dart')).readAsStringSync();
    final fields = RegExp(r'^  final [\w<>?, ]+ (\w+);', multiLine: true)
        .allMatches(state)
        .map((m) => m[1]!)
        .toSet();
    expect(fields, contains('query'));
    final missing = fields.where((f) => !RegExp('\\b$f\\b').hasMatch(lowering)).toList();
    expect(missing, isEmpty, reason: 'not lowered by toQuery(): $missing');
  });
}
```

```dart
// test/features/dive_log/query/dive_filter_apply_equivalence_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// Proves the lowering before apply() is deleted (Task 15): for every axis
/// the old in-memory result equals the compiled SQL result.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> viaSql(DiveFilterState f) async {
    final q = compileDiveFilter(f, rootAlias: 'd');
    final rows = await db.customSelect(
      'SELECT d.id FROM dives d WHERE d.diver_id = ?${q.isEmpty ? '' : ' AND ${q.where}'}',
      variables: [Variable<String>('me'), ...q.params.map((p) => Variable(p))],
    ).get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> viaApply(DiveFilterState f) async {
    final all = await repo.getAllDives(diverId: 'me');
    return f.apply(all).map((d) => d.id).toSet();
  }

  final cases = <String, DiveFilterState>{
    'dates': DiveFilterState(startDate: DateTime(2025, 2, 1), endDate: DateTime(2025, 3, 14)),
    'weekdays': const DiveFilterState(weekdays: [5, 6]),
    'site': const DiveFilterState(siteId: 's1'),
    'depth': const DiveFilterState(minDepth: 20, maxDepth: 30),
    'favorites': const DiveFilterState(favoritesOnly: true),
    'no buddy': const DiveFilterState(noBuddyOnly: true),
    'buddy name': const DiveFilterState(buddyNameFilter: 'an, bo'),
    'buddy id': const DiveFilterState(buddyId: 'b1'),
    'equipment': const DiveFilterState(equipmentIds: ['g_wet']),
    'ids': const DiveFilterState(diveIds: ['d1', 'd9']),
    'rating': const DiveFilterState(minRating: 1),
    'bottom time': const DiveFilterState(minBottomTimeMinutes: 10, maxBottomTimeMinutes: 50),
    'custom field': const DiveFilterState(customFieldKey: 'x'),
    'combined': DiveFilterState(startDate: DateTime(2025, 1, 1), noBuddyOnly: true, minDepth: 10),
  };

  for (final entry in cases.entries) {
    test('apply() and SQL agree: ${entry.key}', () async {
      expect(await viaSql(entry.value), equals(await viaApply(entry.value)), reason: entry.key);
    });
  }

  test('the SQL-only axes match their old id-set methods', () async {
    expect(await viaSql(const DiveFilterState(decoOnly: true)),
        await repo.getDiveIdsWithDecoSignal(wantDeco: true, diverId: 'me'));
    final cond = [EquipmentAttrCondition.suitThickness(min: 1)];
    expect(await viaSql(DiveFilterState(equipmentAttrConditions: cond)),
        await repo.getDiveIdsMatchingEquipmentAttrs(cond, diverId: 'me'));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/query/`
Expected: the three new files FAIL (no `dive_filter_query.dart`).

- [ ] **Step 4: Write the lowering**

```dart
// lib/features/dive_log/query/dive_filter_query.dart
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Lowers the sheet's filter model to the query tree the compiler reads.
///
/// This is the ONLY evaluator of a DiveFilterState (#2365): the paginated
/// list, its count, Statistics and the entity views all compile the tree
/// this returns. A field added to DiveFilterState and not named here fails
/// `dive_filter_query_census_test`.
extension DiveFilterQuery on DiveFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) => ConditionNode(FieldPath([key]), op, v);
    RefValue ref(String id) => RefValue(id, id);
    ListValue refs(List<String> ids) => ListValue([for (final id in ids) ref(id)]);

    if (startDate != null) parts.add(c('date', QueryOp.gte, DateValue(startDate!)));
    if (endDate != null) parts.add(c('date', QueryOp.lte, DateValue(endDate!)));
    if (weekdays.isNotEmpty) {
      const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      parts.add(c('weekday', QueryOp.inList, ListValue([for (final w in weekdays) EnumValue(names[w - 1])])));
    }
    if (diveTypeId != null) parts.add(c('types', QueryOp.eq, ref(diveTypeId!)));
    if (siteId != null) parts.add(c('site', QueryOp.eq, ref(siteId!)));
    if (tripId != null) parts.add(c('trip', QueryOp.eq, ref(tripId!)));
    if (diveCenterId != null) parts.add(c('center', QueryOp.eq, ref(diveCenterId!)));
    if (computerId != null) parts.add(c('computer', QueryOp.eq, ref(computerId!)));
    if (minDepth != null) parts.add(c('depth', QueryOp.gte, NumberValue(minDepth!, null)));
    if (maxDepth != null) parts.add(c('depth', QueryOp.lte, NumberValue(maxDepth!, null)));
    if (minO2Percent != null || maxO2Percent != null) {
      parts.add(ScopedNode(const FieldPath(['tanks']), AndNode([
        if (minO2Percent != null) c('o2', QueryOp.gte, NumberValue(minO2Percent!, null)),
        if (maxO2Percent != null) c('o2', QueryOp.lte, NumberValue(maxO2Percent!, null)),
      ])));
    }
    if (minRating != null) parts.add(c('rating', QueryOp.gte, NumberValue(minRating!.toDouble(), null)));
    if (minBottomTimeMinutes != null) parts.add(c('bottomTime', QueryOp.gte, NumberValue(minBottomTimeMinutes!.toDouble(), null)));
    if (maxBottomTimeMinutes != null) parts.add(c('bottomTime', QueryOp.lte, NumberValue(maxBottomTimeMinutes!.toDouble(), null)));
    if (favoritesOnly == true) parts.add(c('favorite', QueryOp.eq, const BoolValue(true)));
    if (excludedFromStatsOnly == true) parts.add(c('excludedFromStats', QueryOp.eq, const BoolValue(true)));
    if (decoOnly != null) parts.add(c('deco', QueryOp.eq, BoolValue(decoOnly!)));
    if (noBuddyOnly == true) parts.add(c('buddies', QueryOp.isEmpty, null));
    if (tagIds.isNotEmpty) parts.add(c('tags', QueryOp.inList, refs(tagIds)));
    if (equipmentIds.isNotEmpty) parts.add(c('gear', QueryOp.inList, refs(equipmentIds)));
    if (diveIds.isNotEmpty) parts.add(c('id', QueryOp.inList, ListValue([for (final id in diveIds) StringValue(id)])));
    if (buddyId != null) parts.add(c('buddies', QueryOp.eq, ref(buddyId!)));
    final names = (buddyNameFilter ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final name in names) {
      parts.add(OrNode([
        ScopedNode(const FieldPath(['buddies']), c('name', QueryOp.contains, StringValue(name))),
        c('legacyBuddy', QueryOp.contains, StringValue(name)),
      ]));
    }
    if (customFieldKey != null && customFieldKey!.isNotEmpty) {
      parts.add(ScopedNode(const FieldPath(['customFields']), AndNode([
        c('key', QueryOp.eq, StringValue(customFieldKey!)),
        if (customFieldValue != null && customFieldValue!.isNotEmpty)
          c('value', QueryOp.contains, StringValue(customFieldValue!)),
      ])));
    }
    for (final cond in equipmentAttrConditions) {
      parts.add(_attrCondition(cond));
    }
    if (query != null) parts.add(query!);
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

/// One curated attribute condition: a linked item (or transmitter-matched
/// cylinder) of one of [EquipmentAttrCondition.types] carrying a curated
/// row for the key whose text is one of the choices and whose number is in
/// range. Same rules as the deleted `equipmentAttrConditionSql`.
QueryNode _attrCondition(EquipmentAttrCondition cond) {
  QueryNode c(String key, QueryOp op, QueryValue v) => ConditionNode(FieldPath([key]), op, v);
  final types = cond.types.map((t) => t.name).toList()..sort();
  final choices = cond.choices.toList()..sort();
  return ScopedNode(const FieldPath(['gear']), AndNode([
    if (types.isNotEmpty) c('type', QueryOp.inList, ListValue([for (final t in types) EnumValue(t)])),
    ScopedNode(const FieldPath(['attributes']), AndNode([
      c('key', QueryOp.eq, StringValue(cond.key)),
      c('custom', QueryOp.eq, const BoolValue(false)),
      if (choices.isNotEmpty) c('valueText', QueryOp.inList, ListValue([for (final ch in choices) StringValue(ch)])),
      if (cond.min != null) c('valueNum', QueryOp.gte, NumberValue(cond.min!, null)),
      if (cond.max != null) c('valueNum', QueryOp.lte, NumberValue(cond.max!, null)),
    ])),
  ]));
}

/// The one compile call every dive path shares.
CompiledQuery compileDiveFilter(DiveFilterState filter, {String rootAlias = 'r0'}) =>
    compileQuery(filter.toQuery(), diveQueryEntity, appQueryRegistry, rootAlias: rootAlias);

Set<String> diveFilterTablesTouched(DiveFilterState filter) => compileDiveFilter(filter).tablesTouched;
```

`EnumValue` for `type` uses `EquipmentType.name` strings, which is what the `equipment.type` column stores and what the equipment registry's `enumValues` lists.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/query/ test/features/query/`
Expected: PASS, including the equivalence cases. An equivalence failure means the lowering or a registry fragment disagrees with `apply()`; `apply()` is the reference for every axis except bottom time, where the truncated-minutes registry field IS `apply()`'s rule (`Duration.inMinutes`), so the two agree there too.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log/query
git add lib/features/dive_log/query lib/features/dive_log/domain/models/dive_filter_state.dart lib/l10n test/features/dive_log/query
git commit -m "feat(dive-log): lower DiveFilterState to the query tree, with census and equivalence proofs"
```

---

### Task 13: The repository compiles the filter once

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:2524-2760` (`_buildFilterWhereClauses`), `:2123-2260` (`getDiveSummaries` `readsFrom`), `:2262-2330` (`getOrderedDiveIds`), `:2333-2380` (`getDiveCount`), `:160-260` (ticks)
- Test: `test/features/dive_log/data/repositories/dive_repository_query_filter_test.dart`

**Interfaces:**
- Consumes: Task 12.
- Produces: `Future<Set<String>> getDiveIdsMatching(DiveFilterState filter, {String? diverId})`, `Stream<void> watchTables(Set<String> tableNames)`, `Set<TableInfo> tablesNamed(Set<String>)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/repositories/dive_repository_query_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/core/query/domain/query_node.dart';

import '../../../../helpers/test_database.dart';
import '../../query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  final noWeights = DiveFilterState(query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null));

  test('the list, the count, the ordered ids and the id set agree on a query axis', () async {
    final list = (await repo.getDiveSummaries(diverId: 'me', filter: noWeights)).map((s) => s.id).toSet();
    final count = await repo.getDiveCount(diverId: 'me', filter: noWeights);
    final ordered = (await repo.getOrderedDiveIds(diverId: 'me', filter: noWeights)).toSet();
    final ids = await repo.getDiveIdsMatching(noWeights, diverId: 'me');
    expect(list, {'d3', 'd4'});
    expect(count, 2);
    expect(ordered, list);
    expect(ids, list);
  });

  test('the old axes still narrow the list', () async {
    final f = const DiveFilterState(noBuddyOnly: true, minDepth: 20);
    expect((await repo.getDiveSummaries(diverId: 'me', filter: f)).map((s) => s.id).toSet(), {'d3'});
  });

  test('watchTables emits on a write to a named table only', () async {
    final events = <void>[];
    final sub = repo.watchTables({'dive_weights'}).listen(events.add);
    await db.into(db.diveWeights).insert(DiveWeightsCompanion.insert(
        id: 'w9', diveId: 'd3', weightType: 'belt', amountKg: 1, createdAt: 0));
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(events, hasLength(1));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 'tg', name: 'x', createdAt: 0, updatedAt: 0));
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(events, hasLength(1));
    await sub.cancel();
  });

  test('watchTables rejects an unknown table', () {
    expect(() => repo.watchTables({'nope'}), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_query_filter_test.dart`
Expected: FAIL, `getDiveIdsMatching` and `watchTables` undefined.

- [ ] **Step 3: Replace `_buildFilterWhereClauses` and add the two methods**

Replace the whole body of `_buildFilterWhereClauses` (keep its signature and the `// stats-scope-exempt:` line) with:

```dart
  /// Translates the filter into one parameterised SQL expression over the
  /// `d` alias, compiled from `DiveFilterState.toQuery()` (#2365). Every
  /// axis, old or typed, lives in the dive registry.
  // stats-scope-exempt: this IS the view filter; the scope is applied alongside it
  void _buildFilterWhereClauses(
    DiveFilterState filter,
    List<String> clauses,
    List<Variable<Object>> args,
  ) {
    final compiled = compileDiveFilter(filter, rootAlias: 'd');
    if (compiled.isEmpty) return;
    clauses.add(compiled.where);
    args.addAll(compiled.params.map((p) => Variable<Object>(p as Object)));
  }
```

Add, next to `getDiveIdsWithDecoSignal` (which Task 15 deletes):

```dart
  /// The ids of every dive [filter] keeps, for the entity-backed views
  /// (table, maps, export) that hold hydrated dives and narrow them by id.
  // stats-scope-exempt: backs a view-filter axis; consumers apply the scope themselves
  Future<Set<String>> getDiveIdsMatching(
    DiveFilterState filter, {
    String? diverId,
  }) async {
    try {
      return await PerfTimer.measure('getDiveIdsMatching', () async {
        final compiled = compileDiveFilter(filter, rootAlias: 'd');
        final clauses = <String>[
          if (diverId != null) 'd.diver_id = ?',
          if (!compiled.isEmpty) compiled.where,
        ];
        final args = <Variable<Object>>[
          if (diverId != null) Variable(diverId),
          ...compiled.params.map((p) => Variable<Object>(p as Object)),
        ];
        final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
        final rows = await _db
            .customSelect(
              'SELECT d.id AS id FROM dives d $where',
              variables: args,
              readsFrom: tablesNamed(compiled.tablesTouched),
            )
            .get();
        return rows.map((r) => r.read<String>('id')).toSet();
      });
    } catch (e, stackTrace) {
      _log.error('Failed to resolve query-filtered dive ids', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Drift tables by their SQL names, for `readsFrom` and [watchTables].
  Set<TableInfo> tablesNamed(Set<String> names) => {
    for (final n in names)
      _db.allTables.firstWhere(
        (t) => t.actualTableName == n,
        orElse: () => throw ArgumentError.value(n, 'names', 'unknown table'),
      ),
  };

  /// A debounced change tick over exactly [tableNames]: the tables a
  /// compiled query read (`CompiledQuery.tablesTouched`), so a list follows
  /// every table its filter joins and no other. Replaces the hand-kept
  /// per-axis ticks (#1915, #1817).
  Stream<void> watchTables(Set<String> tableNames) {
    final tables = tablesNamed(tableNames);
    return _db
        .tableUpdates(TableUpdateQuery.allOf([for (final t in tables) TableUpdateQuery.onTable(t)]))
        .debounce(changeTickDebounce);
  }
```

In `getDiveSummaries`, `getOrderedDiveIds` and `getDiveCount`, replace each hard-coded `readsFrom: { ... }` set with the tables the query renders from plus the filter's: for the summary query keep `_db.dives, _db.diveSites, _db.trips, _db.diveSafetyFindings` and add `...tablesNamed(compileDiveFilter(filter, rootAlias: 'd').tablesTouched)`; for the count and ordered ids, `{_db.dives, _db.diveSites, ...tablesNamed(...)}`. Compile once per method into a local and pass it to both `_buildFilterWhereClauses` (change its parameter from `filter` to the `CompiledQuery`) and `readsFrom`, so the filter is not compiled twice per call. Import `package:submersion/features/dive_log/query/dive_filter_query.dart`.

- [ ] **Step 4: Run the test and the existing repository suites**

Run: `flutter test test/features/dive_log/data/repositories/`
Expected: PASS. `dive_repository_equipment_attr_filter_test.dart` and `dive_repository_deco_filter_test.dart` still pass here because their methods survive until Task 15.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_query_filter_test.dart
git commit -m "feat(dive-log): the repository compiles the filter once, with derived readsFrom and watchTables"
```

---

### Task 14: Statistics on the same compiled query

**Files:**
- Modify: `lib/features/statistics/data/dive_filter_sql.dart` (replace the body of `buildFilteredDiveIdSubquery`; delete `equipmentAttrConditionSql`; keep `decoSignalCondition`)
- Modify: `test/features/statistics/data/dive_filter_sql_test.dart`
- Test: `test/features/dive_log/query/dive_filter_three_paths_test.dart`

**Interfaces:**
- Consumes: Task 12.
- Produces: unchanged `({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(DiveFilterState)`.

- [ ] **Step 1: Write the failing parity test**

```dart
// test/features/dive_log/query/dive_filter_three_paths_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// Statistics, the paginated list and the id query select the same dives
/// for every kind of axis, because all three compile the same tree.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> statistics(DiveFilterState f) async {
    final s = buildFilteredDiveIdSubquery(f);
    final sql = s.subquery.isEmpty
        ? 'SELECT id FROM dives WHERE diver_id = ?'
        : 'SELECT id FROM dives WHERE diver_id = ? AND id IN (${s.subquery})';
    final rows = await db.customSelect(sql, variables: [Variable<String>('me'), ...s.params.map((p) => Variable(p))]).get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  final cases = <String, DiveFilterState>{
    'empty': const DiveFilterState(),
    'legacy axes': DiveFilterState(startDate: DateTime(2025, 1, 1), noBuddyOnly: true, minDepth: 10),
    'deco (SQL-only before)': const DiveFilterState(decoOnly: false),
    'typed presence': DiveFilterState(query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null)),
    'typed three hops': DiveFilterState(query: ConditionNode(const FieldPath(['buddies', 'certifications', 'level']), QueryOp.eq, const StringValue('rescue'))),
    'typed text': const DiveFilterState(query: TextNode(['manta'])),
  };

  for (final e in cases.entries) {
    test('three paths agree: ${e.key}', () async {
      final list = (await repo.getDiveSummaries(diverId: 'me', filter: e.value)).map((s) => s.id).toSet();
      final count = await repo.getDiveCount(diverId: 'me', filter: e.value);
      final ids = await repo.getDiveIdsMatching(e.value, diverId: 'me');
      final stats = await statistics(e.value);
      expect(count, list.length, reason: e.key);
      expect(ids, list, reason: e.key);
      expect(stats, list, reason: e.key);
    });
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_filter_three_paths_test.dart`
Expected: the typed cases FAIL on the Statistics path, which still reads the old axes only.

- [ ] **Step 3: Rewrite `buildFilteredDiveIdSubquery`**

Replace everything in `dive_filter_sql.dart` from the top of the file down to (not including) the doc comment of `decoSignalCondition` with:

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';

/// Builds a self-contained SQL subquery `SELECT fq.id FROM dives fq WHERE
/// ...` selecting the ids of all dives matching [filter], for Statistics'
/// `id IN (...)` fragments.
///
/// A wrapper over the one compiler every dive path uses (#2365): the tree
/// `DiveFilterState.toQuery()` returns, compiled with the `fq` alias so
/// its correlated subqueries never collide with the caller's `d` or
/// `dives`. Returns an empty no-op (`subquery: ''`, `params: []`) when the
/// filter has no active axes, so callers can skip injecting anything.
({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(
  DiveFilterState filter,
) {
  final compiled = compileDiveFilter(filter, rootAlias: 'fq');
  if (compiled.isEmpty) return (subquery: '', params: const <Object?>[]);
  return (subquery: compiled.idSubquery(), params: compiled.params);
}
```

Delete `equipmentAttrConditionSql` and its doc comment. Keep `decoSignalCondition` (the dive registry's `deco` field reads it) and update its doc comment's list of callers to "the dive query registry's `deco` field, at every depth via the `{r}` placeholder". Remove the now-unused imports.

In `test/features/statistics/data/dive_filter_sql_test.dart`, delete every case that asserted a specific SQL string for an axis (they tested the deleted hand-written builder); keep or rewrite the cases that assert behaviour through a database, and add one case that `buildFilteredDiveIdSubquery(const DiveFilterState()).subquery` is empty and one that a filter with `siteId` yields a subquery starting with `SELECT fq.id FROM dives fq WHERE`.

- [ ] **Step 4: Run the Statistics and dive-log suites**

Run: `flutter test test/features/statistics test/features/dive_log/query`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/statistics test/features
git add lib/features/statistics/data/dive_filter_sql.dart test/features/statistics/data/dive_filter_sql_test.dart test/features/dive_log/query/dive_filter_three_paths_test.dart
git commit -m "feat(statistics): the filtered id subquery is the compiled query"
```

---

### Task 15: Providers and ticks on the compiled query; delete `apply()`

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart:40-142` (id providers, `filteredDivesProvider`), `:495-552` (tick helpers), `:555-600` (`DiveListNotifier` ticks), `:799-890` (`PaginatedDiveListNotifier` ticks)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:43-62` (the attribute tick)
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (delete `apply()` and `readsBuddyLinks`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (delete `getDiveIdsWithDecoSignal`, `getDiveIdsMatchingEquipmentAttrs`, `watchEquipmentAttrFilterChanges`)
- Modify: `lib/features/equipment/domain/models/equipment_attr_condition.dart` (delete `EquipmentAttrConditionsKey`)
- Delete: `test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart`
- Modify tests: `test/features/dive_log/domain/models/dive_filter_state_test.dart`, `test/features/dive_log/dive_filter_excluded_axis_test.dart`, `test/features/dive_log/dive_filter_date_boundary_test.dart`, `test/features/dive_log/data/repositories/dive_repository_deco_filter_test.dart`, `test/features/dive_log/data/repositories/dive_repository_equipment_attr_filter_test.dart`, `test/features/dive_log/presentation/providers/buddy_filter_reload_test.dart`, `test/features/dive_log/presentation/providers/paginated_dive_list_attr_filter_reload_test.dart`, `test/architecture/repository_tick_stream_test.dart`, `test/features/dive_log/query/dive_filter_apply_equivalence_test.dart`
- Test: `test/features/dive_log/presentation/providers/query_filtered_dives_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 12, 13.
- Produces: `queryFilteredDiveIdsProvider` (`FutureProvider<Set<String>?>`), `kDiveListTickTables`, `_QueryTablesTick`.

`watchDivesChangesWithBuddyLinks` and `watchDiveListChangesWithBuddyLinks` STAY: `buddy_providers.dart:39` reads the first and the architecture guard lists both. Only the dive-list notifiers stop using them.

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/dive_log/presentation/providers/query_filtered_dives_provider_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../query/dive_query_fixture.dart';

/// The entity-backed views narrow the hydrated list by the compiled query's
/// id set, and refresh when a table the query read is written.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    container = ProviderContainer(overrides: [
      currentDiverIdProvider.overrideWith((ref) => 'me'),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<Set<String>> filteredIds() async {
    // Let the list and the id set load.
    for (var i = 0; i < 20; i++) {
      final v = container.read(filteredDivesProvider);
      if (v.hasValue) return v.value!.map((d) => d.id).toSet();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('filteredDivesProvider never loaded: ${container.read(filteredDivesProvider)}');
  }

  test('no filter: every dive, no id query', () async {
    expect(await filteredIds(), QueryFixtureIds.mine.toSet());
    expect(container.read(queryFilteredDiveIdsProvider).value, isNull);
  });

  test('a typed query narrows the list', () async {
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
    );
    expect(await filteredIds(), {'d3', 'd4'});
  });

  test('a write to a touched table refreshes the id set', () async {
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
    );
    expect(await filteredIds(), {'d3', 'd4'});
    await db.into(db.diveWeights).insert(DiveWeightsCompanion.insert(
        id: 'w3', diveId: 'd3', weightType: 'belt', amountKg: 2, createdAt: 0));
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 3);
    expect(await filteredIds(), {'d4'});
  });
}
```

Check the exact provider that yields the current diver id (`currentDiverIdProvider`, imported in `dive_providers.dart`) and its override shape against `buddy_filter_reload_test.dart`, and match it.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/query_filtered_dives_provider_test.dart`
Expected: FAIL, `queryFilteredDiveIdsProvider` undefined.

- [ ] **Step 3: Rewrite the providers**

Replace `decoFilteredDiveIdsProvider`, `equipmentAttrFilteredDiveIdsProvider` and `filteredDivesProvider` (dive_providers.dart:40-142) with:

```dart
/// The ids the current filter keeps, resolved in SQL through the one
/// compiled query every dive path shares (#2365), or null when the filter
/// has no active axes so the hydrated list passes through untouched.
///
/// Follows exactly the tables the compiled query read, so a write to a
/// junction or child table the filter joins (a synced buddy link, a weight
/// row, an attribute-only save) refreshes the id set without a dives write.
final queryFilteredDiveIdsProvider = FutureProvider<Set<String>?>((ref) async {
  final filter = ref.watch(diveFilterProvider);
  if (!filter.hasActiveFilters) return null;
  final diverId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTables(diveFilterTablesTouched(filter)));
  return repository.getDiveIdsMatching(filter, diverId: diverId);
});

/// Filtered dives provider: the hydrated list narrowed to the ids the
/// compiled filter keeps. No axis is evaluated in Dart any more; the
/// repository answers every one in SQL, in step with the paginated list
/// and Statistics.
final filteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final idsAsync = ref.watch(queryFilteredDiveIdsProvider);
  // Built-in AsyncValue.value retains the previous ids across a reload, so
  // a write does not blank the list. hasValue false means first load or a
  // failure, never a stale answer.
  if (!idsAsync.hasValue) {
    if (idsAsync.hasError) {
      return AsyncValue.error(idsAsync.error!, idsAsync.stackTrace ?? StackTrace.empty);
    }
    return const AsyncValue.loading();
  }
  final ids = idsAsync.value;
  return divesAsync.whenData(
    (dives) => ids == null ? dives : dives.where((d) => ids.contains(d.id)).toList(),
  );
});
```

Import `package:submersion/features/dive_log/query/dive_filter_query.dart` and `package:flutter/foundation.dart` (for `setEquals`, if not already imported). Add the `// no-tick:` marker above `filteredDivesProvider` only if `test/architecture/provider_change_tick_test.dart` flags it (it makes no repository call itself, so it should not).

Replace `_FilterTickFollower` and `_BuddyAwareTick` (dive_providers.dart:495-552) with one helper:

```dart
/// Follows [DiveRepository.watchTables] over the tables a compiled filter
/// reads beyond the ones a notifier's own tick already watches,
/// resubscribing only when that set changes. An empty set subscribes to
/// nothing, so the many test fakes that `implements DiveRepository`
/// without `watchTables` are never called for an unfiltered list.
class _QueryTablesTick {
  _QueryTablesTick(this._watchTables, this._onTick);

  final Stream<void> Function(Set<String>) _watchTables;
  final void Function() _onTick;
  StreamSubscription<void>? _subscription;
  Set<String> _tables = const {};

  void follow(Set<String> tables) {
    if (_subscription != null && setEquals(_tables, tables)) return;
    _subscription?.cancel();
    _subscription = null;
    _tables = tables;
    if (tables.isEmpty) return;
    _subscription = _watchTables(tables).listen((_) => _onTick());
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// The tables [DiveRepository.watchDiveListChanges] already watches; a
/// filter's extra tables are what remains after removing these.
const Set<String> kDiveListTickTables = {
  'dives', 'dive_sites', 'trips', 'dive_safety_findings', 'dive_tags', 'tags', 'dive_dive_types',
};
```

In `DiveListNotifier`'s constructor (dive_providers.dart:575-598) replace the `_BuddyAwareTick` block with:

```dart
    // filteredDivesProvider narrows this list by a SQL id set that joins
    // whatever tables the filter names; a write to one of them (a synced
    // buddy link, a weight row) changes the answer without a dives write,
    // so the tick follows the filter's tables beyond `dives` (#1915).
    final divesTick = _repository.watchDivesChanges().listen((_) => _silentReload());
    final queryTick = _QueryTablesTick(_repository.watchTables, _silentReload);
    Set<String> extra(DiveFilterState f) => diveFilterTablesTouched(f).difference({'dives'});
    _ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      final before = previous == null ? const <String>{} : extra(previous);
      final after = extra(next);
      queryTick.follow(after);
      // Tables not watched until now may have changed while unwatched, so
      // the hydrated entities are re-read before the new filter sees them.
      if (after.difference(before).isNotEmpty) _silentReload();
    });
    queryTick.follow(extra(_ref.read(diveFilterProvider)));
    _ref.onDispose(() {
      divesTick.cancel();
      queryTick.cancel();
    });
```

In `PaginatedDiveListNotifier` (dive_providers.dart:799-890): make `_listTick` a plain subscription to `_repository.watchDiveListChanges()` created in the constructor, delete `_attrFilterTick`, add `late final _queryTick = _QueryTablesTick(_repository.watchTables, _silentReloadLoadedPages);`, and make `_followFilterTicks` one line: `_queryTick.follow(diveFilterTablesTouched(filter).difference(kDiveListTickTables));`. Update the disposal to cancel both.

In `statistics_providers.dart:51-53`, replace the `if (filter.equipmentAttrConditions.isNotEmpty) { ref.invalidateSelfWhen(repository.watchEquipmentAttrFilterChanges()); }` block (both occurrences) with:

```dart
  // Follow every table the filter joins beyond the statistics tick's own
  // set, so an attribute-only or junction-only write refreshes the totals.
  final extra = diveFilterTablesTouched(filter).difference({'dives'});
  if (extra.isNotEmpty) ref.invalidateSelfWhen(repository.watchTables(extra));
```

- [ ] **Step 4: Delete the superseded code**

- `dive_filter_state.dart`: delete `apply()` and `readsBuddyLinks` with their doc comments; delete the now-unused `dive.dart` and `wall_clock_utc.dart` imports if nothing else uses them; update the class doc comment to say the state is lowered by `DiveFilterQuery.toQuery()` and evaluated only in SQL.
- `dive_repository_impl.dart`: delete `getDiveIdsWithDecoSignal`, `getDiveIdsMatchingEquipmentAttrs`, `watchEquipmentAttrFilterChanges` and their doc comments; the `readsFrom` sets were already rebuilt in Task 13.
- `equipment_attr_condition.dart`: delete `EquipmentAttrConditionsKey` (no family key needs it now).
- `dive_filter_sql.dart`: nothing further (Task 14).

- [ ] **Step 5: Migrate the tests**

- `dive_filter_state_test.dart`: delete every `apply(` group and the `readsBuddyLinks (#1915)` group; keep `copyWith`, `hasActiveFilters` and the date-bound getters; add one case that `copyWith(query: ...)` sets and `clearQuery` clears the field and that `hasActiveFilters` is true with only `query` set.
- `dive_filter_excluded_axis_test.dart`, `dive_filter_date_boundary_test.dart`: replace each `filter.apply(dives)` with the compiled SQL against a database: seed the same dives through `db.into(db.dives)` and read `DiveRepository().getDiveIdsMatching(filter, diverId: ...)`. The date-boundary cases keep their exact day-boundary assertions (issue #1368); they now prove them against SQL, which is where they always mattered.
- `dive_repository_deco_filter_test.dart`, `dive_repository_equipment_attr_filter_test.dart`: remove the cases and helpers that call `getDiveIdsWithDecoSignal` / `getDiveIdsMatchingEquipmentAttrs` / `equipmentAttrConditionSql`; every remaining case reads through `getDiveSummaries`, `getDiveCount` or `getDiveIdsMatching`. Keep the "Statistics, the list and the id query select the same dives" case, routed through `buildFilteredDiveIdSubquery`, `getDiveSummaries` and `getDiveIdsMatching`.
- `buddy_filter_reload_test.dart`, `paginated_dive_list_attr_filter_reload_test.dart`: in each `_CountingRepository`, delete `watchEquipmentAttrFilterChanges` and add `Stream<void> watchTables(Set<String> t) => _inner.watchTables(t);`. The attr-reload test's assertion (an attribute-only write reloads the page and count under a suit-thickness filter) is unchanged and now passes through `watchTables`.
- `repository_tick_stream_test.dart`: remove the `DiveRepository.watchEquipmentAttrFilterChanges` entry and its case; add a case that `DiveRepository().watchTables({'equipment_attributes'})` emits on an `equipment_attributes` insert (an insert, never a delete on an empty table).
- `dive_filter_apply_equivalence_test.dart`: delete the file. Its proof ran in Task 12 against the code that existed then; the three-paths test (Task 14) and the semantics test (Task 11) are the permanent guards. Say so in the commit message.
- Delete `equipment_attr_filter_providers_test.dart`.

- [ ] **Step 6: Run the affected suites**

Run: `flutter test test/features/dive_log test/features/statistics test/features/buddies test/architecture test/features/query test/core/query`
Expected: PASS. Then `flutter analyze` on the whole project: expected no issues (infos are fatal in CI).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log lib/features/statistics/presentation/providers/statistics_providers.dart lib/features/equipment/domain/models/equipment_attr_condition.dart test/features/dive_log test/architecture/repository_tick_stream_test.dart
git rm test/features/dive_log/presentation/providers/equipment_attr_filter_providers_test.dart test/features/dive_log/query/dive_filter_apply_equivalence_test.dart
git commit -m "refactor(dive-log): every dive view narrows by the compiled query; delete apply() and the per-axis id providers"
```

---

### Task 16: Whole-suite verification, spec deviations and the PR

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (a "Deviations recorded during implementation (PR 1)" section)
- Modify: `docs/superpowers/plans/2026-09-25-query-language-pr1-core-engine-dives.md` (tick every box)

- [ ] **Step 1: Format, analyze, l10n staleness**

Run: `dart format . && flutter analyze && flutter gen-l10n && git status --short`
Expected: analyze reports no issues; `git status` shows nothing new after gen-l10n (generated l10n is not stale).

- [ ] **Step 2: Run the full suite once**

Run: `TMPDIR=/tmp flutter test`
Expected: exit code 0 and no failures printed. Do not pipe the output through `tail` or `grep` (that masks the exit code); redirect to a file in the scratchpad and read the file if it is long. Do not start a second run while one is in progress.

- [ ] **Step 3: Record the deviations in the spec**

Append to the spec:

```markdown
## Deviations recorded during implementation (PR 1)

- `ScopedNode` (`path[inner]`) was added to the AST and grammar. A
  multi-condition test on ONE child row (`customFields[key = k AND value ~
  v]`, the suit-thickness condition) cannot be expressed with independent
  existential conditions, and the spec's own lowering table needed it.
- A relation is also how a row is named: `site = "Salt Pier"` is the
  relation `site` with a `RefValue`, compiled as its hop with `{to}.id = ?`
  inside. There is no `ref` field type, so `site` is one key for both
  `site = x` and `site.country = y`.
- Every relation hop compiles to a correlated `EXISTS`; an fk hop does not
  use a `JOIN`. One shape keeps the compiler small, and SQLite plans the
  primary-key lookup the same way (the EXPLAIN QUERY PLAN test pins it).
- The entity-backed views take an id set (`getDiveIdsMatching`) and narrow
  the hydrated list, rather than a `getDivesMatching` that rehydrates; the
  list is already loaded and hydration is the expensive part.
- Change ticks: `CompiledQuery.tablesTouched` is fed by `tables` lists
  declared on fields, relations and the text search, since SQL fragments
  are opaque strings. The registry guard checks every declared table exists.
- The date grammar is a copy of Explore's `time_grammar.dart` under
  `lib/core/query/syntax/`; PR 5 deletes the Explore copy.
- `legacyBuddy` (`dives.buddy`) is a registered text field so the
  buddy-name axis can lower to "linked buddy OR legacy text".
```

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/superpowers
git commit -m "docs: PR 1 deviations and plan checkboxes"
git push -u origin ericgriffin/niche-data-filtering-b18ff1
```

Open the PR against `main` with the title `feat(query): entity query language, PR 1: core engine and dives` and this body (no attribution lines of any kind):

```markdown
Refs #2365

The first of five PRs for the entity query language. This one ships the
engine and moves every dive filter path onto it.

- `lib/core/query/`: AST, typed-syntax parser and canonical printer
  (`parse(print(ast)) == ast`), field and relation registry, validator, SQL
  compiler (nested EXISTS per relation hop, 4-hop cap, every value bound).
- The dive registry: every existing filter axis plus presence (`:none`,
  `:any`) on every field and relation, so `weights:none`,
  `NOT gear.type in [wetsuit, drysuit]` and `temp:none` work today.
- `DiveFilterState.toQuery()`; `apply()` deleted. The paginated list, its
  count, Statistics and the table/map/export views compile one query;
  change ticks are derived from the tables it read.
- No UI yet (PR 2 adds the editor and saved queries); the `query` field on
  `DiveFilterState` is the seam.

Spec: `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`.
Plan: `docs/superpowers/plans/2026-09-25-query-language-pr1-core-engine-dives.md`.
```

Then `mcp__ccd_pr__get_status`, bind the PR if it is not reported, and read its CI; request Copilot review with `gh pr edit <n> --add-reviewer "@copilot"`.

---

## Self-review notes

- Spec coverage: Unit 1 (Tasks 1, 2), Unit 2 (Tasks 4, 5), Unit 3 (Tasks 3, 9, 10), Unit 4 (Tasks 6, 7, 8, 11), Unit 5 (Tasks 12, 13, 14, 15), Testing items 1 to 7 and 10 (Tasks 5, 10, 7 and 8, 11, 14, 12, 13 and 15, 9). Units 6 and 7 and Testing items 8 and 9 are PR 2. The Explore lowering is PR 5.
- Review Focus 1 (decimal comma): Task 4 parser test. 2 (empty list): Task 4 and Task 6. 3 (LIKE wildcards): Tasks 7 and 11. 4 (quotes in labels): Task 5. 5 (`!=` on NULL): Tasks 7 and 11.
- Type consistency: `compileDiveFilter(filter, rootAlias:)` (Task 12) is what Tasks 13, 14 and 15 call; `getDiveIdsMatching(filter, diverId:)` and `watchTables(Set<String>)` (Task 13) are what Task 15 calls; `diveFilterTablesTouched` (Task 12) feeds both notifiers and Statistics.
