# Hose type and equipment attribute filters

Date: 2026-09-12
Issue: #1805

## Problem

A diver owns three kinds of hose: low pressure (LP) regulator hoses, high
pressure (HP) hoses to an SPG or transmitter, and low pressure inflator (LPI)
hoses with a quick-disconnect for a BCD or drysuit. The Hose equipment type
has only a length field, so the kind can live only in the name, where nothing
can filter on it.

Investigating the filter side turned up two more problems that the feature
depends on:

1. The dive filter's equipment-attribute axis is a single slot (one key, one
   choice, one min/max), and Suit thickness already occupies it. A second
   attribute condition has nowhere to go.
2. The paginated dive list ignores that axis entirely.
   `DiveRepository._buildFilterWhereClauses` has no attribute branch, so the
   existing Suit thickness filter narrows the table view and Statistics but
   not the main dive list or its count. A hose filter would inherit the bug.

## Goals

- Hose items carry a Hose type of LP, HP or LPI, edited and shown like every
  other catalog field.
- The equipment list can be filtered by every choice field of the selected
  category, hose type included.
- The dive list can be filtered by the choice fields of one gear category
  (for example "dives with an HP hose"), combined with Suit thickness.
- The attribute filter behaves the same on every dive surface: the paginated
  list, its count, the table and map views, and Statistics.

## Non-goals

- UDDF and Excel round trips of the new field. Neither carries any curated
  attribute except `size` today; hose length has the same gap.
- A Hose type column in the equipment table view.
- The Add Equipment picker's own filter (`equipment_picker_filter.dart`).
- Conditions spanning several categories at once in the dive sheet (for
  example "HP hose AND dry gloves"). The model supports it; the sheet offers
  one category at a time plus Suit thickness.
- Filtering on flag, number or purchase fields through the new chip UI.

## Design

### 1. The field

`EquipmentAttributeCatalog._byType[EquipmentType.hose]` gains, ahead of
`hose_length_m`:

```dart
EquipmentAttributeDef(
  key: EquipmentAttrKeys.hoseType, // 'hose_type'
  kind: AttributeKind.choice,
  choiceKeys: ['lp', 'hp', 'lpi'],
),
```

Curated attributes are rows in `equipment_attributes` (value in
`value_text` for a choice), so there is no schema change and no migration.
The edit form (`EquipmentAttributeFormSection`), the detail page, sync,
backup and the CSV "Attributes" column already handle any catalog key.

Localization, all 11 ARB files, resolved by `attributeLabel` and
`attributeChoiceLabel` in `equipment_attribute_l10n.dart`:

| Key | English |
| --- | --- |
| `attrLabel_hose_type` | Hose type |
| `attrChoice_hose_type_lp` | LP (low pressure) |
| `attrChoice_hose_type_hp` | HP (high pressure) |
| `attrChoice_hose_type_lpi` | LPI (inflator) |

### 2. One condition model

New immutable value type in the equipment domain
(`lib/features/equipment/domain/models/equipment_attr_condition.dart`):

```dart
@immutable
class EquipmentAttrCondition {
  final String key;                 // curated catalog key
  final Set<String> choices;        // value_text in choices; empty = any
  final double? min;                // value_num >= min (canonical metric)
  final double? max;                // value_num <= max
  final Set<EquipmentType> types;   // item type in types; empty = any

  bool matches(EquipmentItem item);
}
```

Semantics, identical in SQL and in `matches`:

- Only curated rows (`is_custom = 0`) with `attr_key = key` count.
- When `types` is not empty, the item's type must be in it.
- When `choices` is not empty, `value_text` must be one of them (OR).
- `min` and `max` bound `value_num`; a null `value_num` fails a set bound.
- Value equality and `hashCode` over all fields (sets compared as sets), so
  a filter state holding conditions compares by value and a provider family
  keyed on them caches correctly.

`DiveFilterState` replaces `equipmentAttrKey`, `equipmentAttrChoice`,
`equipmentAttrMin` and `equipmentAttrMax` with
`List<EquipmentAttrCondition> equipmentAttrConditions` (default empty), and
`clearEquipmentAttr` with `clearEquipmentAttrConditions`. Conditions combine
with AND; a dive satisfies a condition when any item linked to it matches.
`hasActiveFilters` is true when the list is not empty.

Suit thickness becomes an ordinary condition:
`EquipmentAttrCondition(key: 'thickness_mm', min: .., max: .., types:
{wetsuit, drysuit})`. The two hardcoded `suitOnly` branches (SQL and Dart)
are deleted; the restriction now lives in the data.

The filter state is in-memory only (nothing serializes it), so the field
change needs no persisted-state migration.

### 3. SQL is the only implementation of the dive axis

A shared builder in `lib/features/statistics/data/dive_filter_sql.dart`,
beside `decoSignalCondition`:

```dart
({String sql, List<Object> params}) equipmentAttrConditionSql(
  EquipmentAttrCondition condition, {
  required String diveIdRef,
});
```

It returns one correlated `EXISTS` over the dive's gear, where the gear is
`dive_equipment.equipment_id` UNION `dive_tanks.equipment_id` (not null), the
same union the equipment-id axis already uses:

```sql
EXISTS (
  SELECT 1 FROM (
    SELECT de.equipment_id AS eid FROM dive_equipment de
      WHERE de.dive_id = <diveIdRef>
    UNION
    SELECT dt.equipment_id FROM dive_tanks dt
      WHERE dt.dive_id = <diveIdRef> AND dt.equipment_id IS NOT NULL
  ) g
  JOIN equipment_attributes ea ON ea.equipment_id = g.eid
  [JOIN equipment eqf ON eqf.id = g.eid AND eqf.type IN (?, ...)]
  WHERE ea.attr_key = ? AND ea.is_custom = 0
  [AND ea.value_text IN (?, ...)]
  [AND ea.value_num >= ?] [AND ea.value_num <= ?]
)
```

Every value is bound, including the type names (a literal today).

Callers, one per condition:

- `buildFilteredDiveIdSubquery` (Statistics), with `diveIdRef: 'id'`.
- `DiveRepository._buildFilterWhereClauses` (paginated list and count), with
  `diveIdRef: 'd.id'`. This is the list bug fix.
- New `equipmentAttrFilteredDiveIdsProvider`, a diver-scoped
  `FutureProvider.family` like `decoFilteredDiveIdsProvider`, backed by a new
  `DiveRepository.getDiveIdsMatchingEquipmentAttrs(conditions, diverId:)`.
  A Dart `List` (and a record holding one) compares by identity, so the
  family key is `EquipmentAttrConditionsKey`, a small value class beside
  `EquipmentAttrCondition` whose `==` and `hashCode` compare the list
  element by element. A changed condition set therefore lands on a fresh
  instance instead of briefly reusing the previous set's cached ids (the
  reason the deco provider is a family). It ticks on dive, equipment and
  equipment-attribute changes so
  `test/architecture/provider_change_tick_test.dart` passes.

`DiveFilterState.apply` stops evaluating the attribute axis and documents
why, as it does for the deco axis: tank-linked items are not hydrated on the
entity, so only SQL can see them. `filteredDivesProvider` (the one caller of
`apply`) intersects with the provider's ids when conditions are set, next to
the existing deco intersection, and surfaces loading and error the same way.

### 4. Equipment list filter

`EquipmentFilterState` gains `List<EquipmentAttrCondition> attrConditions`
(choice conditions only) and `clearAttrConditions`. Changing or clearing the
category clears the conditions, since they belong to it. `applyType` becomes
`apply`: the type narrowing, then `every(condition.matches)`. The two call
sites in `equipment_list_content.dart` move over, `hasActiveFilters`
counts the conditions, and `==` / `hashCode` include them element by element
(the class already has value equality over its other fields). List providers already hydrate attributes through
`_mapRowsWithAttributes`, so `matches` has what it needs.

Shared widget
`lib/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart`:

```dart
EquipmentChoiceAttributeFilter({
  required EquipmentType type,
  required List<EquipmentAttrCondition> conditions,
  required ValueChanged<List<EquipmentAttrCondition>> onChanged,
});
```

For each `AttributeKind.choice` def in
`EquipmentAttributeCatalog.attributesFor(type)` in `AttributeGroup.spec`, it
renders the localized field label and a `Wrap` of multi-select `FilterChip`s,
one per option. A field with at least one chip selected becomes one condition
(`key`, `choices`, `types: {type}`); deselecting the last chip removes it.
A type with no choice fields renders nothing.

`EquipmentFilterSheet` shows the widget under the Category chips once a
category is selected.

### 5. Dive filter sheet

New section widget
`lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart`
(the sheet is already 1257 lines), placed after Suit thickness:

- A "Gear category" dropdown listing owned categories
  (`ownedEquipmentTypesProvider`) that have at least one choice field, plus
  an "Any" entry to clear.
- Once a category is picked, the shared `EquipmentChoiceAttributeFilter`.
  Switching category clears its chips.

Sheet draft state: the existing thickness min/max, plus the picked category
and its choice conditions. Apply writes `equipmentAttrConditions` = the
thickness condition (when a bound is set) followed by the choice conditions.
Loading splits an existing list back: the `thickness_mm` condition fills the
thickness fields; the others fill the picker, with the category read from
their `types`. Clear all resets both.

## Error handling

- `equipmentAttrFilteredDiveIdsProvider` failures surface through
  `filteredDivesProvider` as an `AsyncValue.error`, the deco pattern, never as
  an empty list that reads as "no matches".
- A stored choice value the catalog no longer lists still matches by exact
  string in SQL; the chip UI simply cannot select it. A condition key the
  catalog does not know is harmless (it matches nothing).
- A condition with a key and nothing else (no choices, no bounds) is legal
  and means "has this attribute"; the builder emits no value clause for it.

## Testing

Test first for every behaviour change.

- Catalog: `hose_type` is a choice on Hose with exactly `lp`, `hp`, `lpi`;
  extend `equipment_type_assembly_parts_test.dart`'s hose keys. The existing
  l10n completeness and ARB parity tests cover the new keys.
- `EquipmentAttrCondition.matches`: type filter, choices OR, min/max bounds
  with null `value_num`, custom rows ignored, value equality.
- `equipmentAttrConditionSql` and `buildFilteredDiveIdSubquery`: migrate
  `dive_filter_sql_attribute_test.dart`; add tank-link matching through
  `dive_tanks.equipment_id`, type restriction, choices IN, and two conditions
  AND.
- Paginated list: `getDiveSummaries` and `getDiveCount` with a condition,
  written to fail on current code (proves the list bug), for Suit thickness
  and for hose type.
- Parity: one filter through `buildFilteredDiveIdSubquery`, the paginated
  query and `filteredDivesProvider` yields the same dive ids.
- `DiveFilterState`: migrate the attribute cases in
  `dive_filter_state_test.dart` (copyWith, clear, `hasActiveFilters`);
  `apply` no longer filters on conditions.
- `EquipmentFilterState`: `apply` with conditions, conditions cleared on a
  category change, `hasActiveFilters`.
- Widgets: `EquipmentChoiceAttributeFilter` chip toggling; equipment filter
  sheet hose chips narrow the list; dive filter sheet round trip (apply,
  reopen, fields restored) including thickness plus hose type together;
  migrate `dive_filter_sheet_interactions_test.dart`.
- Finish: `dart format .`, `flutter analyze`, one full suite run.
