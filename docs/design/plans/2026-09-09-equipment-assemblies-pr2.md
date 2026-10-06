# Equipment Assemblies PR 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put assemblies on dives and plans: attaching an assembly writes one junction row per part with provenance, dives remember the set that was applied, both dive pages render set buckets, collapsed assemblies and indented parts inside the diver's gear arrangement, and buoyancy stops double-counting an assembly and its parts.

**Architecture:** `Dive.gear` becomes the one list of gear links (the item, the parent assembly id, the applied set id), mirroring the junction table row for row; `Dive.equipment` stays as a getter over it so the nineteen production readers keep their flat view. `DivePlan` carries the same provenance as an id list beside `equipmentIds`. One pure `GearExpander` turns "add these items, from this set" into provenance rows, and one pure `GearTree` turns links into set buckets and parent-child nesting; every writer (edit page, bulk operations, defaulter, planner, consolidation, merge) goes through the expander, and every renderer (dive detail, dive edit, PDF) goes through the tree, with the arrangement from #1680 applied to each bucket's top-level rows.

**Tech Stack:** Flutter, Dart 3 records and patterns, Drift (SQLite), Riverpod 3, Equatable, `flutter gen-l10n` ARB localisation, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-assemblies-design.md`, sections 3, 4 and the leaf-only half of 5, plus the "Combining with the gear arrangement" amendment (decided 2026-09-09). PR 1 (#1696, merged) delivered sections 1, 2 and the rollup; PR 3 delivers the swap-with-history dialog and interchange.

## Global Constraints

- No schema change. `dive_equipment.via_equipment_id`, `dive_equipment.via_set_id` and the same pair on `dive_plan_equipment` exist since v203 and already round-trip through sync as generated rows.
- No em-dashes anywhere. No mention of the AI tool or its vendor in any file or commit message. No emojis.
- Every new user-visible string gets a key in all **11** ARB files under `lib/l10n/arb/` (`ar`, `de`, `en`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`), inserted inside the contiguous prefix block (or before the anchor key named in the task), followed by `flutter gen-l10n`, with the regenerated `app_localizations*.dart` committed.
- `Dive` keeps its `const` constructor and its `this.<field>` parameter style: `test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart` reads `dive.dart` as text between `'  const Dive({'` and `'\n  });'`, collects every `this.<x>` as a constructor parameter, collects every `dive.<x>` that `updateDive` reads, and requires each parameter in that intersection to be a named argument of the edit page's `Dive(` literal. The scan of `updateDive` stops at its first `markRecordPending` call, which comes before the child-row blocks, so the census does not see the gear write; the gear field is still named `gear` with `equipment` as a getter, and Task 7's edit-page test is what proves the save literal passes gear through.
- `ComponentsIndex` moves to the domain layer so repositories can use it; the presentation provider file re-exports it so no existing import breaks.
- Layering rule for every renderer: bucket by set (loose gear last), arrange top-level rows with `arrangeEquipment`, assemblies opaque, parts in template order.
- Installed-in children (#1708, `equipment.parent_equipment_id`) are NOT components. The expander only follows `equipment_components`.
- No Drift codegen is needed (no table changes). Run `dart format .` before every commit; stage explicit paths; run specific test files, not whole directories, except in the final task.
- `Dive`'s required constructor parameters are `id` and `dateTime`; test fixtures use `Dive(id: 'd1', dateTime: DateTime(2026, 1, 1), ...)`.
- TDD: every task writes the failing test first and shows it fail.

## File map

| Path | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/gear_provenance.dart` | `GearProvenance` value (ids only) |
| `lib/features/equipment/domain/entities/gear_link.dart` | `GearLink` (item plus provenance), `looseGear`, `gearLinksFor` |
| `lib/features/equipment/domain/services/components_index.dart` | `ComponentsIndex` (moved from the providers file, which re-exports it) |
| `lib/features/equipment/domain/services/gear_expander.dart` | `GearExpander.expand`, `subtreeIds`, `removeSubtree`, `removeSet`, `removePart` |
| `lib/features/equipment/domain/services/gear_tree.dart` | `GearNode`, `GearBucket`, `GearTree` |
| `lib/features/dive_log/domain/entities/dive.dart` | `gear` field; `equipment` and `gearProvenance` getters |
| `lib/features/planner/domain/entities/dive_plan.dart`, `lib/features/dive_planner/domain/entities/plan_result.dart`, `lib/features/planner/domain/services/dive_plan_state_mapper.dart` | plan-side provenance |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | hydration, create, diff update, bulk ops with expansion, `replaceGearRows` |
| `lib/features/dive_log/data/services/dive_consolidation_service.dart`, `lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart`, `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` | row-copying writers and undo |
| `lib/features/equipment/data/services/dive_equipment_defaulter.dart` | passes the winning set id |
| `lib/features/planner/data/repositories/dive_plan_repository.dart`, `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart`, `lib/features/weight_planner/presentation/pages/weight_planner_page.dart` | planner provenance and expansion |
| `lib/features/equipment/presentation/helpers/gear_expansion.dart` | `expandGearOnPage`, shared by the edit page and both planners |
| `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart` | the shared renderer |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `dive_edit_page.dart` | mount the renderer; edit-page provenance state |
| `lib/core/services/pdf_templates/pdf_template_detailed.dart` | grouped PDF rows |
| `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart`, `lib/features/weight_planner/data/repositories/weight_history_repository.dart` | leaf-only rules |

---

### Task 1: Gear links on the entities

This task is a refactor with no behaviour change: after it, every gear row is still a top-level row with no provenance, and the whole suite must be green.

**Files:**
- Create: `lib/features/equipment/domain/entities/gear_provenance.dart`
- Create: `lib/features/equipment/domain/entities/gear_link.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (import block L1-L16, field L41, ctor param L207, copyWith param L593 and assignment L690, props L790)
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart` (L268-L272, L379)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (L1853)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (L412, L3386, L3612, L4019, L5144)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (L5040)
- Modify: every test file that constructs a `Dive` with `equipment:` (57 files, listed in Step 6)
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (field L98, ctor L140, copyWith L222 and L282, props L332)
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart` (the class declaring `equipmentIds` at L569; ctor default L620, copyWith L693 and L760, props L807)
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart` (L72 and L124)
- Test: `test/features/equipment/domain/entities/gear_provenance_test.dart`
- Test: `test/features/dive_log/domain/entities/dive_gear_test.dart`

**Interfaces:**
- Produces:
  - `class GearProvenance extends Equatable { final String equipmentId; final String? viaEquipmentId; final String? viaSetId; const GearProvenance({required this.equipmentId, this.viaEquipmentId, this.viaSetId}); bool get isTopLevel; GearProvenance copyWith({String? viaEquipmentId, String? viaSetId, bool clearViaEquipmentId = false, bool clearViaSetId = false}); }`
  - `class GearLink extends Equatable { final EquipmentItem item; final String? viaEquipmentId; final String? viaSetId; const GearLink({required this.item, this.viaEquipmentId, this.viaSetId}); bool get isTopLevel; GearProvenance get provenance; }`
  - `List<GearLink> looseGear(Iterable<EquipmentItem> items)` (top-level rows, no set)
  - `List<GearLink> gearLinksFor(List<EquipmentItem> items, List<GearProvenance> provenance)`
  - `Dive.gear` (`List<GearLink>`, default empty), `List<EquipmentItem> get equipment`, `List<GearProvenance> get gearProvenance`
  - `DivePlan.gearProvenance`, the planner state's `gearProvenance`, mapped both ways.

- [ ] **Step 1: Write the failing entity tests**

```dart
// test/features/equipment/domain/entities/gear_provenance_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

void main() {
  test('a row with no parent is top-level', () {
    const loose = GearProvenance(equipmentId: 'reg');
    const part = GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg');
    expect(loose.isTopLevel, isTrue);
    expect(part.isTopLevel, isFalse);
    expect(loose.viaSetId, isNull);
  });

  test('copyWith sets and clears each pointer independently', () {
    const p = GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    );
    expect(p.copyWith(clearViaEquipmentId: true).viaEquipmentId, isNull);
    expect(p.copyWith(clearViaEquipmentId: true).viaSetId, 'winter');
    expect(p.copyWith(viaSetId: 'summer').viaSetId, 'summer');
    expect(p.copyWith(clearViaSetId: true).viaSetId, isNull);
  });

  test('equality is by value', () {
    expect(
      const GearProvenance(equipmentId: 'a', viaSetId: 's'),
      const GearProvenance(equipmentId: 'a', viaSetId: 's'),
    );
  });
}
```

```dart
// test/features/dive_log/domain/entities/dive_gear_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

void main() {
  const reg = EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator);
  const hose = EquipmentItem(id: 'hose', name: 'Hose', type: EquipmentType.hose);
  const fins = EquipmentItem(id: 'fins', name: 'Fins', type: EquipmentType.fins);
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 1, 1),
    gear: const [
      GearLink(item: reg, viaSetId: 'winter'),
      GearLink(item: hose, viaEquipmentId: 'reg', viaSetId: 'winter'),
      GearLink(item: fins),
    ],
  );

  test('equipment is the flat view of gear, in gear order', () {
    expect(dive.equipment, const [reg, hose, fins]);
  });

  test('gearProvenance carries the ids only', () {
    expect(dive.gearProvenance, const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'fins'),
    ]);
  });

  test('looseGear wraps items as top-level rows with no set', () {
    final loose = looseGear(const [reg, fins]);
    expect(loose.map((g) => g.item), const [reg, fins]);
    expect(loose.every((g) => g.isTopLevel && g.viaSetId == null), isTrue);
  });

  test('gearLinksFor pairs items with provenance and tolerates gaps', () {
    final links = gearLinksFor(
      const [reg, hose, fins],
      const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
        GearProvenance(equipmentId: 'gone', viaEquipmentId: 'reg'),
      ],
    );
    expect(links.map((g) => g.item.id), ['reg', 'hose', 'fins']);
    expect(links[0].isTopLevel, isTrue);
    expect(links[1].viaEquipmentId, 'reg');
    expect(links[2].isTopLevel, isTrue);
  });

  test('copyWith(gear:) replaces the list and equality sees it', () {
    final trimmed = dive.copyWith(gear: looseGear(const [fins]));
    expect(trimmed.equipment, const [fins]);
    expect(trimmed, isNot(equals(dive)));
    expect(dive.copyWith(), equals(dive));
  });
}
```

- [ ] **Step 2: Run both to verify they fail**

Run: `flutter test test/features/equipment/domain/entities/gear_provenance_test.dart test/features/dive_log/domain/entities/dive_gear_test.dart`
Expected: compile errors, `gear_provenance.dart` and `gear_link.dart` not found, `gear` undefined on `Dive`.

- [ ] **Step 3: Write the two values**

```dart
// lib/features/equipment/domain/entities/gear_provenance.dart
import 'package:equatable/equatable.dart';

/// Where one gear row on a dive or plan came from (issue #1487): the
/// assembly it was attached through, and the equipment set that was
/// applied. Both null means the diver added the item by hand.
///
/// Mirrors the two nullable columns on the gear junctions. Ids only, so
/// the expander and the repositories can work without loading items.
class GearProvenance extends Equatable {
  final String equipmentId;

  /// The immediate parent assembly, null for a top-level row.
  final String? viaEquipmentId;

  /// The set that was applied, carried by every row of its expansion.
  final String? viaSetId;

  const GearProvenance({
    required this.equipmentId,
    this.viaEquipmentId,
    this.viaSetId,
  });

  bool get isTopLevel => viaEquipmentId == null;

  GearProvenance copyWith({
    String? viaEquipmentId,
    String? viaSetId,
    bool clearViaEquipmentId = false,
    bool clearViaSetId = false,
  }) => GearProvenance(
    equipmentId: equipmentId,
    viaEquipmentId: clearViaEquipmentId
        ? null
        : (viaEquipmentId ?? this.viaEquipmentId),
    viaSetId: clearViaSetId ? null : (viaSetId ?? this.viaSetId),
  );

  @override
  List<Object?> get props => [equipmentId, viaEquipmentId, viaSetId];
}
```

```dart
// lib/features/equipment/domain/entities/gear_link.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// One gear row on a dive: the item plus where it came from (issue #1487).
/// A dive holds one of these per junction row, so membership and
/// provenance cannot drift apart.
class GearLink extends Equatable {
  final EquipmentItem item;

  /// The immediate parent assembly, null for a top-level row.
  final String? viaEquipmentId;

  /// The set that was applied, null when the row was added by hand.
  final String? viaSetId;

  const GearLink({required this.item, this.viaEquipmentId, this.viaSetId});

  bool get isTopLevel => viaEquipmentId == null;

  GearProvenance get provenance => GearProvenance(
    equipmentId: item.id,
    viaEquipmentId: viaEquipmentId,
    viaSetId: viaSetId,
  );

  @override
  List<Object?> get props => [item, viaEquipmentId, viaSetId];
}

/// Wraps items the diver attached by hand: top-level rows with no set.
List<GearLink> looseGear(Iterable<EquipmentItem> items) => [
  for (final item in items) GearLink(item: item),
];

/// Pairs every item with its provenance entry, in item order. An item with
/// no entry is a top-level row added by hand; an entry with no item is
/// ignored. Used where a page holds items and provenance separately.
List<GearLink> gearLinksFor(
  List<EquipmentItem> items,
  List<GearProvenance> provenance,
) {
  final byId = {for (final p in provenance) p.equipmentId: p};
  return [
    for (final item in items)
      GearLink(
        item: item,
        viaEquipmentId: byId[item.id]?.viaEquipmentId,
        viaSetId: byId[item.id]?.viaSetId,
      ),
  ];
}
```

- [ ] **Step 4: Replace the field on Dive**

In `dive.dart` add the imports (alphabetically among the `features/equipment` ones):

```dart
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
```

Replace L41 `final List<EquipmentItem> equipment;` with

```dart
  /// The gear on this dive, one link per junction row with the item and
  /// where it came from (issue #1487). [equipment] is the flat view.
  final List<GearLink> gear;
```

Replace the constructor parameter `this.equipment = const [],` (L207) with `this.gear = const [],`. In `copyWith` replace `List<EquipmentItem>? equipment,` (L593) with `List<GearLink>? gear,` and `equipment: equipment ?? this.equipment,` (L690) with `gear: gear ?? this.gear,`. In `props` replace `equipment,` (L790) with `gear,`. Then add, immediately after the constructor's closing `});`:

```dart
  /// The gear as a flat item list, for readers that do not care about
  /// assemblies or sets.
  List<EquipmentItem> get equipment => [for (final g in gear) g.item];

  /// Provenance only, the shape the expander and the tree helpers take.
  List<GearProvenance> get gearProvenance => [
    for (final g in gear) g.provenance,
  ];
```

Do not add an `equipment:` parameter to `copyWith`: replacing the list through the flat view would silently drop provenance.

- [ ] **Step 5: Fix the four production construction sites**

`dive_merge_builder.dart` L268-L272: replace the `mergedEquipment` comprehension with

```dart
    final mergedGear = [
      for (final d in sorted)
        for (final g in d.gear)
          if (seenEquipment.add(g.item.id)) g,
    ];
```

and L379 `equipment: mergedEquipment,` with `gear: mergedGear,`.

`uddf_entity_importer.dart` L1853: `equipment: linkedEquipment,` becomes `gear: looseGear(linkedEquipment),` with the `gear_link.dart` import added (UDDF provenance is PR 3).

`dive_repository_impl.dart`: import `gear_link.dart`; L3386 `required List<EquipmentItem> equipment,` becomes `required List<GearLink> gear,`; L3612 `equipment: equipment,` becomes `gear: gear,`; L412 `equipment: equipmentByDive[row.id] ?? [],` becomes `gear: looseGear(equipmentByDive[row.id] ?? const []),`; L4019 `equipment: hydratedEquipmentItems,` becomes `gear: looseGear(hydratedEquipmentItems),`; L5144 `equipment: const [],` becomes `gear: const [],`. (Task 3 replaces the two `looseGear` wrappers with real links read from the junction.)

`dive_edit_page.dart` L5040: `equipment: _selectedEquipment,` becomes `gear: looseGear(_selectedEquipment),` with the import added. (Task 7 replaces this with the provenance-aware join.)

- [ ] **Step 6: Migrate the test fixtures**

The rule: inside a `Dive(` literal or a `Dive.copyWith(` call, `equipment: X` becomes `gear: looseGear(X)` and the file gains `import 'package:submersion/features/equipment/domain/entities/gear_link.dart';`. Arguments named `equipment:` on any other class (`UddfImportResult`, `EquipmentSet`, the export services) are untouched. Assertions such as `expect(dive.equipment, ...)` keep working through the getter.

List the candidate files with:

```bash
grep -rln "equipment: " --include="*.dart" test | xargs grep -l "Dive(" | xargs grep -c "equipment: " | sort -t: -k2 -n -r
```

(57 files at the time of writing; the heaviest are `buoyancy_twin_assembler_test.dart` with 16 sites, `buoyancy_history_provider_test.dart` and `dive_filter_state_test.dart` with 12 each, `uddf_entity_importer_test.dart` with 10, `healthkit_adapter_test.dart` with 8, `universal_adapter_test.dart` with 7, plus `test/helpers/mock_providers.dart`.) The one `copyWith(equipment: [gear])` at `test/features/dive_log/data/repositories/dive_repository_test.dart:300` becomes `copyWith(gear: looseGear([gear]))`.

Then run `flutter analyze` and fix every remaining `The named parameter 'equipment' isn't defined` until it reports no issues. The compiler is the completeness check; do not stop at the grep.

- [ ] **Step 7: Add provenance to DivePlan, the planner state, and the mapper**

`dive_plan.dart`: beside `equipmentIds` add `final List<GearProvenance> gearProvenance;` (import `gear_provenance.dart`), the ctor default `this.gearProvenance = const [],`, the copyWith parameter `List<GearProvenance>? gearProvenance,` and assignment `gearProvenance: gearProvenance ?? this.gearProvenance,`, and `gearProvenance,` in `props`.

`plan_result.dart`: find the class enclosing L569 (`grep -n "^class " lib/features/dive_planner/domain/entities/plan_result.dart`) and give it the same field, ctor default, copyWith and props.

`dive_plan_state_mapper.dart`: add `gearProvenance: state.gearProvenance,` at the state-to-plan site (L72) and `gearProvenance: plan.gearProvenance,` at the plan-to-state site (L124).

- [ ] **Step 8: Run the entity tests, the census, and the heaviest migrated files**

Run: `flutter test test/features/equipment/domain/entities/gear_provenance_test.dart test/features/dive_log/domain/entities/dive_gear_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart test/features/dive_log/data/repositories/dive_repository_test.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS. Then `ls test/features/planner/domain/services/` and run whichever mapper test exists there. Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib test
git commit -m "refactor(dive-log): a dive holds gear links, not a flat item list (#1487)

Dive.gear is one link per junction row (item plus the assembly it came
through plus the set applied), mirroring dive_equipment; equipment is
now a getter over it so every existing reader keeps its flat view.
DivePlan carries the same provenance beside equipmentIds. No behaviour
change: every row is still top-level until the repository reads the
provenance columns."
```

`git add lib test` is acceptable for this commit only because the fixture migration touches 57 test files; confirm with `git status --short` that nothing outside `lib/` and `test/` is staged and that no submodule pointer moved.

---

### Task 2: The expander, the tree, and the index move

**Files:**
- Create: `lib/features/equipment/domain/services/components_index.dart` (moved class)
- Modify: `lib/features/equipment/presentation/providers/equipment_component_providers.dart` (remove the class; add the import and an `export` of the new file)
- Create: `lib/features/equipment/domain/services/gear_expander.dart`
- Create: `lib/features/equipment/domain/services/gear_tree.dart`
- Test: `test/features/equipment/domain/services/gear_expander_test.dart`
- Test: `test/features/equipment/domain/services/gear_tree_test.dart`

**Interfaces:**
- Consumes: `ComponentsIndex.byParent`, `GearProvenance`, `GearLink`.
- Produces:
  - `typedef GearAddition = ({String equipmentId, String? viaSetId});`
  - `abstract final class GearExpander { static List<GearProvenance> expand({required List<GearAddition> additions, required ComponentsIndex index, required List<GearProvenance> existing, required bool Function(String equipmentId) isActive}); static Set<String> subtreeIds(List<GearProvenance> rows, String equipmentId); static List<GearProvenance> removeSubtree(List<GearProvenance> rows, String equipmentId); static List<GearProvenance> removeSet(List<GearProvenance> rows, String setId); static List<GearProvenance> removePart(List<GearProvenance> rows, String equipmentId); }`
  - `class GearNode { final GearLink link; final List<GearNode> children; }`, `class GearBucket { final String? setId; final List<GearNode> roots; }`
  - `abstract final class GearTree { static List<GearBucket> build(List<GearLink> links); static Set<String> rolledUpIds(Iterable<GearProvenance> rows); static List<EquipmentItem> leafItems(List<GearLink> links); }`

- [ ] **Step 1: Move `ComponentsIndex` to the domain layer**

Cut the whole `class ComponentsIndex { ... }` with its doc comment out of `equipment_component_providers.dart` into `lib/features/equipment/domain/services/components_index.dart`, which imports only `package:submersion/features/equipment/domain/entities/equipment_component.dart`. In the providers file add `import 'package:submersion/features/equipment/domain/services/components_index.dart';` and, on the line after the imports, `export 'package:submersion/features/equipment/domain/services/components_index.dart';`.

Run: `flutter test test/features/equipment/presentation/providers/components_index_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart`
Expected: PASS with no import changed anywhere else.

- [ ] **Step 2: Write the failing expander test**

```dart
// test/features/equipment/domain/services/gear_expander_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child, {int order = 0}) =>
      EquipmentComponent(
        id: 'c${seq++}',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
      );
  // reg > first, second, hose (in that order); kit > reg, fins.
  final index = ComponentsIndex.fromRows([
    edge('reg', 'first', order: 0),
    edge('reg', 'second', order: 1),
    edge('reg', 'hose', order: 2),
    edge('kit', 'reg', order: 0),
    edge('kit', 'fins', order: 1),
  ]);
  bool allActive(String _) => true;
  List<String> ids(List<GearProvenance> rows) =>
      rows.map((r) => r.equipmentId).toList();

  test('adding an assembly writes it and its parts, parts tagged with it', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['reg', 'first', 'second', 'hose']);
    expect(rows[0].viaEquipmentId, isNull);
    expect(rows.skip(1).map((r) => r.viaEquipmentId), everyElement('reg'));
  });

  test('nesting expands recursively with the immediate parent on each row', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'kit', viaSetId: 'winter')],
      index: index,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['kit', 'reg', 'first', 'second', 'hose', 'fins']);
    expect(rows.firstWhere((r) => r.equipmentId == 'hose').viaEquipmentId, 'reg');
    expect(rows.firstWhere((r) => r.equipmentId == 'reg').viaEquipmentId, 'kit');
    expect(rows.map((r) => r.viaSetId), everyElement('winter'));
  });

  test('a retired part is skipped', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [],
      isActive: (id) => id != 'second',
    );
    expect(ids(rows), ['reg', 'first', 'hose']);
  });

  test('an item already on the dive as loose gear adopts the assembly', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: 'winter')],
      index: index,
      existing: const [GearProvenance(equipmentId: 'hose')],
      isActive: allActive,
    );
    final hose = rows.firstWhere((r) => r.equipmentId == 'hose');
    expect(hose.viaEquipmentId, 'reg');
    expect(hose.viaSetId, 'winter');
    expect(ids(rows).where((id) => id == 'hose').length, 1);
  });

  test('an item already under another parent is left alone', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ],
      isActive: allActive,
    );
    expect(rows.firstWhere((r) => r.equipmentId == 'hose').viaEquipmentId, 'other');
  });

  test('a top-level item already present gains the set when it had none', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'fins', viaSetId: 'winter')],
      index: index,
      existing: const [GearProvenance(equipmentId: 'fins')],
      isActive: allActive,
    );
    expect(rows.single.viaSetId, 'winter');
  });

  test('a corrupt cycle terminates', () {
    final loop = ComponentsIndex.fromRows([edge('a', 'b'), edge('b', 'a')]);
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'a', viaSetId: null)],
      index: loop,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['a', 'b']);
  });

  group('removal', () {
    const onDive = [
      GearProvenance(equipmentId: 'kit', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'reg', viaEquipmentId: 'kit', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'fins', viaEquipmentId: 'kit', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'mask'),
    ];

    test('removeSubtree drops the row and everything under it', () {
      expect(ids(GearExpander.removeSubtree(onDive, 'reg')), ['kit', 'fins', 'mask']);
      expect(ids(GearExpander.removeSubtree(onDive, 'kit')), ['mask']);
    });

    test('removeSet drops every row carrying the set', () {
      expect(ids(GearExpander.removeSet(onDive, 'winter')), ['mask']);
    });

    test('removePart drops one leaf, and a row with children as a subtree', () {
      expect(ids(GearExpander.removePart(onDive, 'hose')), ['kit', 'reg', 'fins', 'mask']);
      expect(ids(GearExpander.removePart(onDive, 'reg')), ['kit', 'fins', 'mask']);
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/services/gear_expander_test.dart`
Expected: compile error, `gear_expander.dart` not found.

- [ ] **Step 4: Write the expander**

```dart
// lib/features/equipment/domain/services/gear_expander.dart
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// One item being attached to a dive or plan, and the set it came from.
typedef GearAddition = ({String equipmentId, String? viaSetId});

/// The one place an assembly is turned into gear rows (issue #1487). Pure:
/// it takes ids and the adjacency index and returns the new provenance
/// list, so the edit page, the repository bulk operations, the defaulter
/// and the planner all expand identically and one test file proves it.
///
/// Rules:
/// - An added item is a top-level row carrying the addition's set id.
/// - Each active part of it, in template order, becomes a row whose parent
///   is the item and whose set id is the same, recursively.
/// - A retired or lost part is skipped ([isActive] decides).
/// - An item already present as a top-level row that is now being added
///   beneath an assembly adopts that parent and set. A row that already has
///   a parent is left alone. A top-level row that had no set gains the set.
/// - A visited set makes the walk terminate even on a corrupt loop.
///
/// Installed-in children (equipment.parent_equipment_id) are not parts and
/// are never followed here.
abstract final class GearExpander {
  static List<GearProvenance> expand({
    required List<GearAddition> additions,
    required ComponentsIndex index,
    required List<GearProvenance> existing,
    required bool Function(String equipmentId) isActive,
  }) {
    final rows = <String, GearProvenance>{
      for (final r in existing) r.equipmentId: r,
    };
    final order = [for (final r in existing) r.equipmentId];

    void put(GearProvenance row) {
      if (!rows.containsKey(row.equipmentId)) order.add(row.equipmentId);
      rows[row.equipmentId] = row;
    }

    void addPart(String id, String parentId, String? setId, Set<String> seen) {
      if (!seen.add(id)) return;
      final current = rows[id];
      if (current == null) {
        put(
          GearProvenance(
            equipmentId: id,
            viaEquipmentId: parentId,
            viaSetId: setId,
          ),
        );
      } else if (current.isTopLevel) {
        put(
          current.copyWith(
            viaEquipmentId: parentId,
            viaSetId: setId ?? current.viaSetId,
          ),
        );
      }
      // A row that already has a parent keeps it.
      for (final edge in index.byParent[id] ?? const []) {
        final child = edge.componentEquipmentId;
        if (isActive(child)) addPart(child, id, setId, seen);
      }
    }

    for (final addition in additions) {
      final id = addition.equipmentId;
      final current = rows[id];
      if (current == null) {
        put(GearProvenance(equipmentId: id, viaSetId: addition.viaSetId));
      } else if (current.viaSetId == null && addition.viaSetId != null) {
        put(current.copyWith(viaSetId: addition.viaSetId));
      }
      final seen = <String>{id};
      for (final edge in index.byParent[id] ?? const []) {
        final child = edge.componentEquipmentId;
        if (isActive(child)) addPart(child, id, addition.viaSetId, seen);
      }
    }
    return [for (final id in order) rows[id]!];
  }

  /// [equipmentId] and every row reachable downward from it through
  /// `viaEquipmentId`, cycle-safe.
  static Set<String> subtreeIds(List<GearProvenance> rows, String equipmentId) {
    final children = <String, List<String>>{};
    for (final r in rows) {
      final parent = r.viaEquipmentId;
      if (parent != null) children.putIfAbsent(parent, () => []).add(r.equipmentId);
    }
    final out = <String>{equipmentId};
    final queue = [equipmentId];
    while (queue.isNotEmpty) {
      for (final c in children[queue.removeLast()] ?? const <String>[]) {
        if (out.add(c)) queue.add(c);
      }
    }
    return out;
  }

  static List<GearProvenance> removeSubtree(
    List<GearProvenance> rows,
    String equipmentId,
  ) {
    final gone = subtreeIds(rows, equipmentId);
    return [for (final r in rows) if (!gone.contains(r.equipmentId)) r];
  }

  static List<GearProvenance> removeSet(List<GearProvenance> rows, String setId) =>
      [for (final r in rows) if (r.viaSetId != setId) r];

  /// Drops one leaf row (the per-dive deviation). A row that still has
  /// children on the dive is removed as a subtree instead, so no row is
  /// ever left pointing at a parent that is gone.
  static List<GearProvenance> removePart(
    List<GearProvenance> rows,
    String equipmentId,
  ) {
    final hasChildren = rows.any((r) => r.viaEquipmentId == equipmentId);
    if (hasChildren) return removeSubtree(rows, equipmentId);
    return [for (final r in rows) if (r.equipmentId != equipmentId) r];
  }
}
```

- [ ] **Step 5: Run the expander test**

Run: `flutter test test/features/equipment/domain/services/gear_expander_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 6: Write the failing tree test**

```dart
// test/features/equipment/domain/services/gear_tree_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';

void main() {
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: id, type: type);
  final items = [
    item('mask', EquipmentType.mask),
    item('kit', EquipmentType.other),
    item('reg', EquipmentType.regulator),
    item('hose', EquipmentType.hose),
    item('fins', EquipmentType.fins),
    item('cam', EquipmentType.camera),
  ];
  const provenance = [
    GearProvenance(equipmentId: 'kit', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'reg', viaEquipmentId: 'kit', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'fins', viaEquipmentId: 'kit', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'cam', viaSetId: 'photo'),
  ];
  final links = gearLinksFor(items, provenance);

  test('buckets by set in first-seen order with loose gear last', () {
    final buckets = GearTree.build(links);
    expect(buckets.map((b) => b.setId), ['winter', 'photo', null]);
    expect(buckets[0].roots.map((n) => n.link.item.id), ['kit']);
    expect(buckets[1].roots.map((n) => n.link.item.id), ['cam']);
    expect(buckets[2].roots.map((n) => n.link.item.id), ['mask']);
  });

  test('nests parts under their parent in link order', () {
    final kit = GearTree.build(links)[0].roots.single;
    expect(kit.children.map((n) => n.link.item.id), ['reg', 'fins']);
    expect(kit.children[0].children.map((n) => n.link.item.id), ['hose']);
  });

  test('a row whose parent is not on the dive is treated as top-level', () {
    final orphan = gearLinksFor(
      [item('hose', EquipmentType.hose)],
      const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'missing')],
    );
    expect(GearTree.build(orphan).single.roots.single.link.item.id, 'hose');
  });

  test('rolledUpIds and leafItems agree', () {
    expect(GearTree.rolledUpIds(provenance), {'kit', 'reg'});
    expect(
      GearTree.leafItems(links).map((i) => i.id),
      ['mask', 'hose', 'fins', 'cam'],
    );
  });

  test('a corrupt loop still builds', () {
    final loop = gearLinksFor(
      [item('a', EquipmentType.other), item('b', EquipmentType.other)],
      const [
        GearProvenance(equipmentId: 'a', viaEquipmentId: 'b'),
        GearProvenance(equipmentId: 'b', viaEquipmentId: 'a'),
      ],
    );
    expect(GearTree.build(loop).single.roots, isNotEmpty);
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/services/gear_tree_test.dart`
Expected: compile error, `gear_tree.dart` not found.

- [ ] **Step 8: Write the tree**

```dart
// lib/features/equipment/domain/services/gear_tree.dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// One rendered row and the rows nested under it.
class GearNode {
  final GearLink link;
  final List<GearNode> children;
  const GearNode({required this.link, this.children = const []});
}

/// The rows that came from one set (or none), with their top-level roots.
class GearBucket {
  final String? setId;
  final List<GearNode> roots;
  const GearBucket({required this.setId, required this.roots});
}

/// Turns a flat link list into set buckets and parent-child nesting, the
/// shape both dive pages and the PDF render (issue #1487). Pure and
/// cycle-safe: a row whose parent is absent, or part of a loop, is shown
/// as a top-level row rather than dropped.
abstract final class GearTree {
  static List<GearBucket> build(List<GearLink> links) {
    final present = {for (final l in links) l.item.id};
    final childrenOf = <String, List<GearLink>>{};
    final roots = <GearLink>[];
    for (final l in links) {
      final parent = l.viaEquipmentId;
      if (parent != null && present.contains(parent) && parent != l.item.id) {
        childrenOf.putIfAbsent(parent, () => []).add(l);
      } else {
        roots.add(l);
      }
    }
    // Every row reachable from a root is nested; anything left over sits
    // in a loop with no root and is promoted so it is never invisible.
    final placed = <String>{};
    GearNode node(GearLink l) {
      placed.add(l.item.id);
      return GearNode(
        link: l,
        children: [
          for (final c in childrenOf[l.item.id] ?? const <GearLink>[])
            if (!placed.contains(c.item.id)) node(c),
        ],
      );
    }

    final rootNodes = [for (final r in roots) node(r)];
    for (final l in links) {
      if (!placed.contains(l.item.id)) rootNodes.add(node(l));
    }

    final buckets = <String?, List<GearNode>>{};
    for (final n in rootNodes) {
      buckets.putIfAbsent(n.link.viaSetId, () => []).add(n);
    }
    final loose = buckets.remove(null);
    return [
      for (final e in buckets.entries) GearBucket(setId: e.key, roots: e.value),
      if (loose != null) GearBucket(setId: null, roots: loose),
    ];
  }

  /// Ids that have at least one child row: an assembly's own attributes
  /// must not count toward buoyancy when its parts are on the dive.
  static Set<String> rolledUpIds(Iterable<GearProvenance> rows) => {
    for (final r in rows)
      if (r.viaEquipmentId != null) r.viaEquipmentId!,
  };

  /// Items with no child row on this dive, in link order.
  static List<EquipmentItem> leafItems(List<GearLink> links) {
    final parents = {
      for (final l in links)
        if (l.viaEquipmentId != null) l.viaEquipmentId!,
    };
    return [for (final l in links) if (!parents.contains(l.item.id)) l.item];
  }
}
```

- [ ] **Step 9: Run both service tests**

Run: `flutter test test/features/equipment/domain/services/gear_tree_test.dart test/features/equipment/domain/services/gear_expander_test.dart`
Expected: PASS, 15 tests.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/domain/services/components_index.dart lib/features/equipment/presentation/providers/equipment_component_providers.dart lib/features/equipment/domain/services/gear_expander.dart lib/features/equipment/domain/services/gear_tree.dart test/features/equipment/domain/services/gear_expander_test.dart test/features/equipment/domain/services/gear_tree_test.dart
git commit -m "feat(equipment): gear expander and tree for assemblies on dives (#1487)

One pure expander turns 'add these items, from this set' into
provenance rows (recursive, retired parts skipped, loose rows adopted),
one pure tree turns links into set buckets and nesting. The adjacency
index moves to the domain layer so repositories can use it."
```

---

### Task 3: The dive repository reads and writes provenance

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (list hydration L339-L372 and L412; single hydration L3727-L3766 and L4019; `createDive` insert L1473-L1482; `updateDive` block L1773-L1800; bulk ops L5720-L5808)
- Test: `test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart`

**Interfaces:**
- Consumes: `GearLink`, `GearProvenance`, `GearExpander`, `ComponentsIndex.fromRows`, `EquipmentComponent`.
- Produces:
  - `Dive.gear` hydrated with real provenance on both read paths.
  - `createDive` and `updateDive` persist provenance; `updateDive` is a diff (update changed provenance, insert added, delete removed), each row marked pending or tombstoned.
  - `Future<void> bulkAddEquipment(List<String> diveIds, List<String> equipmentIds, {String? viaSetId})` expands assemblies per dive.
  - `Future<void> bulkRemoveEquipment(List<String> diveIds, List<String> equipmentIds)` removes subtrees.
  - `Future<void> bulkReplaceEquipment(List<String> diveIds, List<String> equipmentIds)` expands like add after clearing.
  - `Future<void> replaceGearRows(String diveId, List<GearProvenance> rows)` writes exactly these rows (undo path).
  - private `_writeGearDiff`, `_provenanceOf`, `_loadComponentsIndex`, `_activeIdsAmong`.

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';

/// Provenance on dive_equipment (issue #1487): read on both hydration paths,
/// written by create and the diff update, expanded by the bulk operations.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  late EquipmentComponentRepository components;

  Future<void> seedEquipment(String id, {bool active = true}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('d1'),
          isActive: Value(active),
          status: Value(active ? 'active' : 'retired'),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    components = EquipmentComponentRepository(equipmentRepository: EquipmentRepository());
    await db
        .into(db.divers)
        .insert(DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: 1, updatedAt: 1));
    for (final id in ['reg', 'first', 'hose', 'fins', 'mask']) {
      await seedEquipment(id);
    }
    await seedEquipment('old-hose', active: false);
    await components.addComponent(parentId: 'reg', componentId: 'first');
    await components.addComponent(parentId: 'reg', componentId: 'hose');
    await components.addComponent(parentId: 'reg', componentId: 'old-hose');
    await db
        .into(db.equipmentSets)
        .insert(EquipmentSetsCompanion.insert(id: 'winter', name: 'Winter', createdAt: 1, updatedAt: 1));
  });

  tearDown(tearDownTestDatabase);

  EquipmentItem item(String id) => EquipmentItem(id: id, name: id, type: EquipmentType.regulator);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(db.diveEquipment)..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  Future<Set<String>> pending() async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == 'diveEquipment') r.recordId,
  };

  test('createDive writes provenance and marks each link pending', () async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        gear: [
          GearLink(item: item('reg'), viaSetId: 'winter'),
          GearLink(item: item('hose'), viaEquipmentId: 'reg', viaSetId: 'winter'),
          GearLink(item: item('mask')),
        ],
      ),
    );
    final rows = await rowsOf('dv');
    expect(rows['reg']!.viaSetId, 'winter');
    expect(rows['hose']!.viaEquipmentId, 'reg');
    expect(rows['mask']!.viaEquipmentId, isNull);
    expect(await pending(), containsAll(['dv|reg', 'dv|hose', 'dv|mask']));

    final read = await repo.getDiveById('dv');
    expect(read!.gear.firstWhere((g) => g.item.id == 'hose').viaEquipmentId, 'reg');
    expect(read.gear.firstWhere((g) => g.item.id == 'reg').viaSetId, 'winter');
  });

  test('getAllDives hydrates provenance too', () async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        gear: [
          GearLink(item: item('reg')),
          GearLink(item: item('hose'), viaEquipmentId: 'reg'),
        ],
      ),
    );
    final all = await repo.getAllDives();
    expect(all.single.gear.firstWhere((g) => g.item.id == 'hose').viaEquipmentId, 'reg');
  });

  test('updateDive diffs: changed provenance updated, added inserted, removed tombstoned', () async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        gear: [
          GearLink(item: item('reg')),
          GearLink(item: item('hose'), viaEquipmentId: 'reg'),
          GearLink(item: item('mask')),
        ],
      ),
    );
    final before = await repo.getDiveById('dv');
    await repo.updateDive(
      before!.copyWith(
        gear: [
          GearLink(item: item('reg')),
          GearLink(item: item('hose'), viaEquipmentId: 'reg', viaSetId: 'winter'),
          GearLink(item: item('fins')),
        ],
      ),
    );
    final rows = await rowsOf('dv');
    expect(rows.keys, unorderedEquals(['reg', 'hose', 'fins']));
    expect(rows['hose']!.viaSetId, 'winter');
    final tombstones = [
      for (final t in await db.select(db.deletionLog).get())
        if (t.entityType == 'diveEquipment') t.recordId,
    ];
    expect(tombstones, ['dv|mask']);
  });

  test('bulkAddEquipment expands an assembly, skips a retired part, tags the set', () async {
    await repo.createDive(domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)));
    await repo.bulkAddEquipment(['dv'], ['reg'], viaSetId: 'winter');
    final rows = await rowsOf('dv');
    expect(rows.keys, unorderedEquals(['reg', 'first', 'hose']));
    expect(rows['first']!.viaEquipmentId, 'reg');
    expect(rows['first']!.viaSetId, 'winter');
    expect(rows['reg']!.viaSetId, 'winter');
  });

  test('bulkRemoveEquipment drops the whole subtree', () async {
    await repo.createDive(domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)));
    await repo.bulkAddEquipment(['dv'], ['reg', 'mask']);
    await repo.bulkRemoveEquipment(['dv'], ['reg']);
    expect((await rowsOf('dv')).keys, ['mask']);
  });

  test('replaceGearRows writes exactly the given rows with provenance', () async {
    await repo.createDive(domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)));
    await repo.bulkAddEquipment(['dv'], ['reg']);
    await repo.replaceGearRows('dv', const [
      GearProvenance(equipmentId: 'mask'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'mask', viaSetId: 'winter'),
    ]);
    final rows = await rowsOf('dv');
    expect(rows.keys, unorderedEquals(['mask', 'hose']));
    expect(rows['hose']!.viaEquipmentId, 'mask');
  });
}
```

Adjust the `EquipmentCompanion.insert` named parameters if `isActive`/`status` are not `Value`-typed on the companion (`grep -n "class EquipmentCompanion" -A40 lib/core/database/database.g.dart | grep "isActive\|status"`), and the `EquipmentSetsCompanion.insert` required parameters (`grep -n "EquipmentSetsCompanion.insert" -A12 lib/core/database/database.g.dart`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart`
Expected: compile error, `viaSetId` is not a parameter of `bulkAddEquipment` and `replaceGearRows` is undefined.

- [ ] **Step 3: Hydrate real links on both read paths**

Add imports for `gear_provenance.dart`, `gear_expander.dart`, `components_index.dart` and `equipment_component.dart` (`gear_link.dart` arrived in Task 1). In the list hydration loop (L339-L372) rename `equipmentByDive` to `gearByDive` typed `<String, List<GearLink>>`, read the junction row once, and wrap the existing `EquipmentItem(...)` construction unchanged:

```dart
        final gearByDive = <String, List<GearLink>>{};
        for (final joinRow in allDiveEquipment) {
          final link = joinRow.readTable(_db.diveEquipment);
          final diveId = link.diveId;
          final e = joinRow.readTable(_db.equipment);
          gearByDive
              .putIfAbsent(diveId, () => [])
              .add(
                GearLink(
                  viaEquipmentId: link.viaEquipmentId,
                  viaSetId: link.viaSetId,
                  item: EquipmentItem(
                    id: e.id,
                    // ... the existing field list, unchanged ...
                  ),
                ),
              );
        }
```

At L412 pass `gear: gearByDive[row.id] ?? const [],` (dropping Task 1's `looseGear` wrapper). On the single-dive path (L3727) make the map produce links the same way, rename `equipmentItems` to `hydratedGear` where it is consumed, and at L4019 pass `gear: hydratedGear,`.

- [ ] **Step 4: Add the diff writer and its helpers, then use them from createDive and updateDive**

Add near the bulk operations:

```dart
  Future<List<GearProvenance>> _provenanceOf(String diveId) async {
    final rows = await (_db.select(
      _db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return [
      for (final r in rows)
        GearProvenance(
          equipmentId: r.equipmentId,
          viaEquipmentId: r.viaEquipmentId,
          viaSetId: r.viaSetId,
        ),
    ];
  }

  /// Makes the dive's gear rows equal to [desired]: rows whose provenance
  /// changed are updated, added rows inserted, removed rows deleted with a
  /// tombstone, and every written row marked pending. (Delete-all-then-
  /// reinsert produced a payload where one key was both live and
  /// tombstoned in the same sync round.)
  Future<void> _writeGearDiff(
    String diveId,
    List<GearProvenance> desired,
    int now,
  ) async {
    final existing = await (_db.select(
      _db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    final existingById = {for (final r in existing) r.equipmentId: r};
    final desiredIds = {for (final p in desired) p.equipmentId};
    for (final row in existing) {
      if (desiredIds.contains(row.equipmentId)) continue;
      await (_db.delete(_db.diveEquipment)..where(
            (t) => t.diveId.equals(diveId) & t.equipmentId.equals(row.equipmentId),
          ))
          .go();
      await _syncRepository.logDeletion(
        entityType: 'diveEquipment',
        recordId: '$diveId|${row.equipmentId}',
      );
    }
    for (final p in desired) {
      final current = existingById[p.equipmentId];
      if (current != null &&
          current.viaEquipmentId == p.viaEquipmentId &&
          current.viaSetId == p.viaSetId) {
        continue;
      }
      await _db
          .into(_db.diveEquipment)
          .insertOnConflictUpdate(
            DiveEquipmentCompanion(
              diveId: Value(diveId),
              equipmentId: Value(p.equipmentId),
              viaEquipmentId: Value(p.viaEquipmentId),
              viaSetId: Value(p.viaSetId),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveEquipment',
        recordId: '$diveId|${p.equipmentId}',
        localUpdatedAt: now,
      );
    }
  }

  /// Writes [rows] as the dive's exact gear list, with provenance (the
  /// bulk-edit undo path).
  Future<void> replaceGearRows(String diveId, List<GearProvenance> rows) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _writeGearDiff(diveId, rows, now);
    await _bumpDives([diveId], now);
  }

  /// The assembly template as an adjacency index, read directly rather than
  /// through EquipmentComponentRepository to keep this repository free of a
  /// sibling repository dependency.
  Future<ComponentsIndex> _loadComponentsIndex() async {
    final rows =
        await (_db.select(_db.equipmentComponents)..orderBy([
              (t) => OrderingTerm.asc(t.parentEquipmentId),
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return ComponentsIndex.fromRows([
      for (final r in rows)
        EquipmentComponent(
          id: r.id,
          parentEquipmentId: r.parentEquipmentId,
          componentEquipmentId: r.componentEquipmentId,
          role: r.role,
          sortOrder: r.sortOrder,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
        ),
    ]);
  }

  /// Which of [ids] are active gear (not retired or lost, still flagged
  /// active): the expander skips the rest.
  Future<Set<String>> _activeIdsAmong(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.equipment)..where(
              (t) =>
                  t.id.isIn(ids.toList()) &
                  t.isActive.equals(true) &
                  t.status.isNotIn([
                    EquipmentStatus.retired.name,
                    EquipmentStatus.lost.name,
                  ]),
            ))
            .get();
    return {for (final r in rows) r.id};
  }
```

`createDive` (replace L1473-L1482):

```dart
          // Insert equipment associations with their provenance.
          for (final g in dive.gear) {
            batch.insert(
              _db.diveEquipment,
              DiveEquipmentCompanion(
                diveId: Value(id),
                equipmentId: Value(g.item.id),
                viaEquipmentId: Value(g.viaEquipmentId),
                viaSetId: Value(g.viaSetId),
              ),
            );
          }
```

and after the batch commits, where the other child entities are marked pending, add for each `g` in `dive.gear`: `await _syncRepository.markRecordPending(entityType: 'diveEquipment', recordId: '$id|${g.item.id}', localUpdatedAt: now);` (this closes the gap where a new dive's links only reached peers on a full snapshot).

`updateDive` (replace L1773-L1800):

```dart
      // Equipment: a diff keyed by equipment id, shared with the bulk
      // operations, so an unchanged row is neither tombstoned nor
      // re-marked pending (issue #1487).
      final desiredGear = [for (final g in dive.gear) g.provenance];
      await _writeGearDiff(dive.id, desiredGear, now);
```

Check that `now` is in scope at that point of `updateDive` (it is the timestamp the rest of the method uses). On the read side, keep the existing item maps and attribute hydration untouched and collect a parallel provenance list per dive; join the two with `gearLinksFor` at the `Dive(` construction. That keeps the diff small and reuses the helper from Task 1.

- [ ] **Step 5: Expand in the bulk operations**

Replace the three bulk operations:

```dart
  /// Add each equipment id to each dive, expanding assemblies into their
  /// active parts and tagging every written row with [viaSetId] when the
  /// addition came from a set. No notify/txn.
  Future<void> bulkAddEquipment(
    List<String> diveIds,
    List<String> equipmentIds, {
    String? viaSetId,
  }) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final index = await _loadComponentsIndex();
    final candidates = {
      for (final id in equipmentIds) ...[id, ...index.descendantsOf(id)],
    };
    final active = await _activeIdsAmong(candidates);
    final additions = [
      for (final id in equipmentIds) (equipmentId: id, viaSetId: viaSetId),
    ];
    for (final diveId in diveIds) {
      final expanded = GearExpander.expand(
        additions: additions,
        index: index,
        existing: await _provenanceOf(diveId),
        isActive: active.contains,
      );
      await _writeGearDiff(diveId, expanded, now);
    }
    await _bumpDives(diveIds, now);
  }

  /// Remove each equipment id, and everything attached through it, from
  /// each dive. No notify/txn.
  Future<void> bulkRemoveEquipment(
    List<String> diveIds,
    List<String> equipmentIds,
  ) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      var rows = await _provenanceOf(diveId);
      for (final id in equipmentIds) {
        rows = GearExpander.removeSubtree(rows, id);
      }
      await _writeGearDiff(diveId, rows, now);
    }
    await _bumpDives(diveIds, now);
  }

  /// Replace each dive's equipment with exactly [equipmentIds], expanded
  /// the same way an add is. No notify/txn.
  Future<void> bulkReplaceEquipment(
    List<String> diveIds,
    List<String> equipmentIds,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final index = await _loadComponentsIndex();
    final candidates = {
      for (final id in equipmentIds) ...[id, ...index.descendantsOf(id)],
    };
    final active = await _activeIdsAmong(candidates);
    final expanded = GearExpander.expand(
      additions: [for (final id in equipmentIds) (equipmentId: id, viaSetId: null)],
      index: index,
      existing: const [],
      isActive: active.contains,
    );
    for (final diveId in diveIds) {
      await _writeGearDiff(diveId, expanded, now);
    }
    await _bumpDives(diveIds, now);
  }
```

`EquipmentStatus` comes from `package:submersion/core/constants/enums.dart` (already imported by this file; verify with grep).

- [ ] **Step 6: Run the new test and the neighbours**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart test/features/dive_log/data/repositories/dive_repository_bulk_test.dart test/features/dive_log/data/repositories/dive_repository_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/presentation/pages/dive_edit_equipment_default_test.dart`
Expected: PASS. Also run the defaulter's own test (`ls test/features/equipment/data/services/`).

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_gear_provenance_test.dart
git commit -m "feat(dive-log): read and write gear provenance on dives (#1487)

Both hydration paths build real links, createDive writes them and marks
the links pending, updateDive and the bulk operations share one diff
writer, and the bulk operations expand assemblies through the expander
with a set id when the addition came from a set."
```

---

### Task 4: Every other writer keeps provenance

**Files:**
- Modify: `lib/features/equipment/data/services/dive_equipment_defaulter.dart` (L56)
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart` (L481-L497)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart` (L405-L417)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (snapshot L49 and L85-L91; undo L189-L193) and the snapshot class it fills (`grep -n "priorEquipmentIds" lib/features/dive_log/data/services/*.dart lib/features/dive_log/domain/entities/*.dart`)
- Test: `test/features/equipment/data/services/dive_equipment_defaulter_set_test.dart`
- Test: `test/features/dive_log/data/services/gear_provenance_writers_test.dart`

**Interfaces:**
- Consumes: `DiveRepository.bulkAddEquipment(..., viaSetId:)`, `replaceGearRows`, `GearProvenance`.
- Produces: the defaulter tags its rows with the winning set; consolidation and merge repointing copy rows; bulk-edit undo restores provenance exactly.

- [ ] **Step 1: Write the failing defaulter test**

```dart
// test/features/equipment/data/services/dive_equipment_defaulter_set_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';

import '../../../../helpers/test_database.dart';

/// The defaulter already knows which set won; it now says so on every row.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: 1, updatedAt: 1));
    for (final id in ['reg', 'fins']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('d1'),
            ),
          );
    }
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 'default',
            name: 'Default',
            createdAt: 1,
            updatedAt: 1,
            diverId: const Value('d1'),
            isDefault: const Value(true),
          ),
        );
    for (final id in ['reg', 'fins']) {
      await db
          .into(db.equipmentSetItems)
          .insert(EquipmentSetItemsCompanion.insert(setId: 'default', equipmentId: id));
    }
    await DiveRepository().createDive(
      domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1), diverId: 'd1'),
    );
  });

  tearDown(tearDownTestDatabase);

  test('rows written by the default set carry its id', () async {
    final applied = await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
      diveId: 'dv',
      diverId: 'd1',
      divePoints: const [],
    );
    expect(applied, isTrue);
    final rows = await (db.select(db.diveEquipment)..where((t) => t.diveId.equals('dv'))).get();
    expect(rows.map((r) => r.viaSetId), everyElement('default'));
  });
}
```

Confirm `Dive` has a `diverId` parameter, the defaulter's constructor and method names (`grep -n "class DiveEquipmentDefaulter\|Future<bool>" lib/features/equipment/data/services/dive_equipment_defaulter.dart`), and that `EquipmentSetItemsCompanion.insert` takes exactly `setId` and `equipmentId` (`grep -n "EquipmentSetItemsCompanion.insert" -A6 lib/core/database/database.g.dart`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/services/dive_equipment_defaulter_set_test.dart`
Expected: FAIL, every `viaSetId` is null.

- [ ] **Step 3: Pass the set id from the defaulter**

In `dive_equipment_defaulter.dart` change `await _dives.bulkAddEquipment([diveId], best.equipmentIds);` to

```dart
      await _dives.bulkAddEquipment(
        [diveId],
        best.equipmentIds,
        viaSetId: best.id,
      );
```

Run the defaulter test. Expected: PASS.

- [ ] **Step 4: Write the failing writers test**

```dart
// test/features/dive_log/data/services/gear_provenance_writers_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';

/// Writers that rebuild junction rows must copy provenance, not drop it.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db
        .into(db.divers)
        .insert(DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: 1, updatedAt: 1));
    for (final id in ['reg', 'hose', 'mask']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('d1'),
            ),
          );
    }
    await repo.createDive(domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)));
    await repo.replaceGearRows('dv', const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
    ]);
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(db.diveEquipment)..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  test('bulk edit undo restores provenance exactly', () async {
    final service = BulkDiveEditService();
    final snapshot = await service.apply(
      BulkEditRequest(diveIds: const ['dv'], ops: const [
        EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['mask']),
      ]),
    );
    expect((await rowsOf('dv')).keys, containsAll(['reg', 'hose', 'mask']));
    await service.undo(snapshot);
    final rows = await rowsOf('dv');
    expect(rows.keys, unorderedEquals(['reg', 'hose']));
    expect(rows['hose']!.viaEquipmentId, 'reg');
    expect(rows['hose']!.viaSetId, 'winter');
  });
}
```

Match `BulkDiveEditService`'s constructor and the names of its apply and undo methods and of `BulkEditRequest`/`EquipmentOp` to the real code (`grep -n "class BulkDiveEditService\|Future<.*> apply\|Future<void> undo\|class EquipmentOp\|class BulkEditRequest" lib/features/dive_log/data/services/bulk_dive_edit_service.dart lib/features/dive_log/domain/entities/bulk_edit_request.dart`), and look at `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` for how it is constructed in tests.

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/services/gear_provenance_writers_test.dart`
Expected: FAIL, the restored hose row has null provenance.

- [ ] **Step 6: Make the writers copy rows**

`dive_consolidation_service.dart` L486-L491: replace the bare companion with a copy of the source row moved to the target:

```dart
          await _db
              .into(_db.diveEquipment)
              .insert(
                row.toCompanion(false).copyWith(diveId: Value(targetDiveId)),
              );
```

`dive_computer_merge_repository.dart` L408-L414: keep provenance while re-keying the equipment:

```dart
        await _db
            .into(_db.diveEquipment)
            .insert(
              link.toCompanion(false).copyWith(
                equipmentId: Value(survivorTwinId),
              ),
            );
```

`bulk_dive_edit_service.dart`: change the snapshot field from `Map<String, List<String>>? priorEquipmentIds` to `Map<String, List<GearProvenance>>? priorGear` (rename in the snapshot class too), capture it as

```dart
        case EquipmentOp():
          final rows = await (_db.select(
            _db.diveEquipment,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorGear = {for (final id in ids) id: <GearProvenance>[]};
          for (final r in rows) {
            priorGear[r.diveId]!.add(
              GearProvenance(
                equipmentId: r.equipmentId,
                viaEquipmentId: r.viaEquipmentId,
                viaSetId: r.viaSetId,
              ),
            );
          }
```

and restore it with `await _diveRepo.replaceGearRows(id, gear[id] ?? const []);` in the undo loop. Update the snapshot class's field, constructor and any `copyWith`/equality it has, and fix `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` where it names `priorEquipmentIds`.

- [ ] **Step 7: Run the writers test and the neighbours**

Run: `flutter test test/features/dive_log/data/services/gear_provenance_writers_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart test/features/dive_log/data/repositories/dive_consolidation_test.dart test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart`
Expected: PASS (find the consolidation and merge test files with `ls test/features/dive_log/data/repositories/ test/features/dive_log/data/services/` if these names differ).

- [ ] **Step 8: Format and commit**

```bash
dart format lib/features/equipment/data/services/dive_equipment_defaulter.dart lib/features/dive_log/data/services lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart test/features/equipment/data/services/dive_equipment_defaulter_set_test.dart test/features/dive_log/data/services
git add lib/features/equipment/data/services/dive_equipment_defaulter.dart lib/features/dive_log/data/services/dive_consolidation_service.dart lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart test/features/equipment/data/services/dive_equipment_defaulter_set_test.dart test/features/dive_log/data/services/gear_provenance_writers_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart
git commit -m "feat(dive-log): every gear writer keeps provenance (#1487)

The defaulter tags rows with the set that won; consolidation and the
computer-merge repointer copy rows instead of rebuilding bare pairs;
bulk-edit undo snapshots provenance and restores it exactly."
```

Also stage the snapshot class file if it lives outside `bulk_dive_edit_service.dart`.

---

### Task 5: Planner parity

**Files:**
- Create: `lib/features/equipment/presentation/helpers/gear_expansion.dart`
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart` (junction write L136-L161, load L236-L246)
- Modify: `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart` (add at ~L39, remove at ~L63 and ~L138)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (a `setGearProvenance` beside the `equipmentIds` setter at ~L399)
- Modify: `lib/features/weight_planner/presentation/pages/weight_planner_page.dart` (`_gear` L47, `onGearAdded`/`onGearSetAdded`/`onGearRemoved` L429-L438)
- Modify: `lib/features/weight_planner/presentation/widgets/rig_composer.dart` (set picker callback L97 passes the set; chip label shows a part count)
- Test: `test/features/planner/data/repositories/dive_plan_gear_provenance_test.dart`

**Interfaces:**
- Consumes: `DivePlan.gearProvenance`, `GearExpander`, `ComponentsIndex`, `equipmentComponentsIndexProvider`, `equipmentRepositoryProvider.getEquipmentByIds`.
- Produces: plan junction rows with provenance; `RigComposer.onGearSetAdded` becomes `void Function(EquipmentSet set, List<EquipmentItem> items)`; `RigComposer.partCounts` (`Map<String, int>`, default empty); `bool isGearActive(EquipmentItem)`; `typedef GearExpansion = ({List<GearProvenance> provenance, List<EquipmentItem> newItems})`; `Future<GearExpansion> expandGearOnPage(WidgetRef ref, {required List<GearAddition> additions, required List<GearProvenance> existing, required List<EquipmentItem> existingItems})`, used by both planner surfaces and, in Task 7, the dive edit page.

- [ ] **Step 1: Write the failing plan repository test**

```dart
// test/features/planner/data/repositories/dive_plan_gear_provenance_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DivePlanRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DivePlanRepository();
    for (final id in ['reg', 'hose']) {
      await db
          .into(db.equipment)
          .insert(EquipmentCompanion.insert(id: id, name: id, type: 'regulator', createdAt: 1, updatedAt: 1));
    }
  });

  tearDown(tearDownTestDatabase);

  test('a plan round-trips gear provenance', () async {
    final plan = DivePlan(
      id: 'p1',
      name: 'Test',
      equipmentIds: const ['reg', 'hose'],
      gearProvenance: const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg')],
    );
    await repo.createPlan(plan);
    final read = await repo.getPlanById('p1');
    expect(read!.gearProvenance.firstWhere((p) => p.equipmentId == 'hose').viaEquipmentId, 'reg');

    await repo.updatePlan(read.copyWith(gearProvenance: const []));
    final again = await repo.getPlanById('p1');
    expect(again!.gearProvenance.every((p) => p.viaEquipmentId == null), isTrue);
  });
}
```

Match `DivePlan`'s required constructor parameters and the repository's create/get/update method names to the real code (`grep -n "Future<.*> createPlan\|Future<.*> getPlanById\|Future<.*> updatePlan\|Future<.*> savePlan" lib/features/planner/data/repositories/dive_plan_repository.dart`, `grep -n "required this" lib/features/planner/domain/entities/dive_plan.dart | head`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/data/repositories/dive_plan_gear_provenance_test.dart`
Expected: FAIL, provenance reads back empty.

- [ ] **Step 3: Persist provenance on the plan junction**

In the junction write, build the desired rows with provenance and diff on provenance as well as membership:

```dart
        final provenanceById = {
          for (final p in plan.gearProvenance) p.equipmentId: p,
        };
        final existingEqRows = await (_db.select(
          _db.divePlanEquipment,
        )..where((e) => e.planId.equals(plan.id))).get();
        final existingById = {for (final r in existingEqRows) r.equipmentId: r};
        final keptEqIds = plan.equipmentIds.toSet();
        removedEquipmentIds.addAll(existingById.keys.toSet().difference(keptEqIds));
        for (final id in keptEqIds) {
          final p = provenanceById[id];
          final current = existingById[id];
          if (current == null) addedEquipmentIds.add(id);
          if (current != null &&
              current.viaEquipmentId == p?.viaEquipmentId &&
              current.viaSetId == p?.viaSetId) {
            continue;
          }
          if (current != null) changedEquipmentIds.add(id);
          await _db
              .into(_db.divePlanEquipment)
              .insertOnConflictUpdate(
                db.DivePlanEquipmentCompanion(
                  planId: Value(plan.id),
                  equipmentId: Value(id),
                  viaEquipmentId: Value(p?.viaEquipmentId),
                  viaSetId: Value(p?.viaSetId),
                ),
              );
        }
        for (final id in removedEquipmentIds) {
          await (_db.delete(_db.divePlanEquipment)..where(
                (e) => e.planId.equals(plan.id) & e.equipmentId.equals(id),
              ))
              .go();
        }
```

Declare `changedEquipmentIds` beside `addedEquipmentIds` and mark both sets pending in the post-transaction sync bookkeeping keyed `'${plan.id}|$id'`. On load, pass both `equipmentIds` and

```dart
        gearProvenance: [
          for (final r in equipmentRows)
            GearProvenance(
              equipmentId: r.equipmentId,
              viaEquipmentId: r.viaEquipmentId,
              viaSetId: r.viaSetId,
            ),
        ],
```

into `_mapPlan` (add the parameter) and on to `DivePlan(...)`. Apply the same to the create path if it writes the junction separately from update.

Run the plan repository test. Expected: PASS.

- [ ] **Step 4: Add the shared expansion helper for pages**

```dart
// lib/features/equipment/presentation/helpers/gear_expansion.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// True for gear the expander may attach as a part.
bool isGearActive(EquipmentItem item) =>
    item.isActive &&
    item.status != EquipmentStatus.retired &&
    item.status != EquipmentStatus.lost;

/// What a page gets back from [expandGearOnPage]: the new provenance list
/// and the items (parts) that were not in the page's list before, so the
/// page can append them to its flat item list.
typedef GearExpansion = ({
  List<GearProvenance> provenance,
  List<EquipmentItem> newItems,
});

/// Expands [additions] on a page's in-memory gear list, fetching the parts'
/// items so the page can show them. [existingItems] must already contain
/// the items being added. Best-effort on the template: if the index cannot
/// be read, the additions are attached flat, which is what the app did
/// before assemblies existed.
Future<GearExpansion> expandGearOnPage(
  WidgetRef ref, {
  required List<GearAddition> additions,
  required List<GearProvenance> existing,
  required List<EquipmentItem> existingItems,
}) async {
  ComponentsIndex index;
  try {
    index = await ref.read(equipmentComponentsIndexProvider.future);
  } catch (_) {
    index = ComponentsIndex.empty;
  }
  final candidateIds = {
    for (final a in additions) ...index.descendantsOf(a.equipmentId),
  }..removeAll(existingItems.map((e) => e.id));
  final fetched = candidateIds.isEmpty
      ? const <EquipmentItem>[]
      : await ref.read(equipmentRepositoryProvider).getEquipmentByIds(candidateIds.toList());
  final itemsById = {
    for (final e in existingItems) e.id: e,
    for (final e in fetched) e.id: e,
  };
  final provenance = GearExpander.expand(
    additions: additions,
    index: index,
    existing: existing,
    isActive: (id) {
      final item = itemsById[id];
      return item != null && isGearActive(item);
    },
  );
  final known = {for (final e in existingItems) e.id};
  final newItems = [
    for (final p in provenance)
      if (!known.contains(p.equipmentId) && itemsById[p.equipmentId] != null)
        itemsById[p.equipmentId]!,
  ];
  return (provenance: provenance, newItems: newItems);
}
```

Confirm the name of the repository provider (`grep -n "equipmentRepositoryProvider" lib/features/equipment/presentation/providers/equipment_providers.dart`).

- [ ] **Step 5: Expand on both planner surfaces**

`rig_composer.dart`: change `onGearSetAdded` to `final void Function(EquipmentSet set, List<EquipmentItem> items) onGearSetAdded;` and pass `(set, items) => onGearSetAdded(set, items)` at L97; add `import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';`. Add `final Map<String, int> partCounts;` (constructor default `const {}`) and render each chip's label as `partCounts[item.id] case final n? when n > 0 ? '${item.name} (+$n)' : item.name` (or an equivalent `if` when the pattern form does not read well).

`weight_planner_page.dart`: add `final List<GearProvenance> _gearProvenance = [];`; replace the three handlers:

```dart
            onGearAdded: (item) => _addGear([item]),
            onGearSetAdded: (set, items) => _addGear(items, viaSetId: set.id),
            onGearRemoved: (item) => _mutate(units, () {
              final kept = GearExpander.removeSubtree(_gearProvenance, item.id);
              _gearProvenance
                ..clear()
                ..addAll(kept);
              final keep = {for (final p in kept) p.equipmentId};
              _gear.removeWhere((g) => !keep.contains(g.id));
            }),
```

with

```dart
  Future<void> _addGear(List<EquipmentItem> items, {String? viaSetId}) async {
    for (final item in items) {
      if (!_gear.any((g) => g.id == item.id)) _gear.add(item);
    }
    final expansion = await expandGearOnPage(
      ref,
      additions: [for (final i in items) (equipmentId: i.id, viaSetId: viaSetId)],
      existing: _gearProvenance,
      existingItems: _gear,
    );
    if (!mounted) return;
    setState(() {
      _gearProvenance
        ..clear()
        ..addAll(expansion.provenance);
      _gear.addAll(expansion.newItems);
    });
  }
```

(`_mutate` recomputes the prediction after a change; call whatever it calls after `setState` so the twin refreshes. Read `_mutate` first.) Pass `partCounts` to the composer computed from `_gearProvenance` (count rows per `viaEquipmentId`).

`plan_gear_weights_section.dart`: the dive planner keeps ids in the notifier. On add (L39-L44 region), replace the direct id append with an expansion whose result is written back through the notifier's existing setter for `equipmentIds` plus a new `setGearProvenance(List<GearProvenance>)` added beside wherever `equipmentIds: ids` is set at `dive_planner_providers.dart:399`. On remove (L63 and L138), apply `GearExpander.removeSubtree` to the state's provenance and derive the kept ids from it.

- [ ] **Step 6: Run the planner tests**

Run: `flutter test test/features/planner/ test/features/weight_planner/ test/features/dive_planner/presentation/widgets/`
Expected: PASS (if these directories are too large for the timeout, run the files that name `rig_composer`, `plan_gear_weights_section`, `dive_plan_repository`, and `weight_planner_page`).

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/planner lib/features/dive_planner lib/features/weight_planner lib/features/equipment/presentation/helpers test/features/planner
git add lib/features/planner/data/repositories/dive_plan_repository.dart lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart lib/features/dive_planner/presentation/providers/dive_planner_providers.dart lib/features/weight_planner/presentation/pages/weight_planner_page.dart lib/features/weight_planner/presentation/widgets/rig_composer.dart lib/features/equipment/presentation/helpers/gear_expansion.dart test/features/planner/data/repositories/dive_plan_gear_provenance_test.dart
git commit -m "feat(planner): assemblies expand on plans the same way as on dives (#1487)

Plan junction rows carry provenance, the rig composer and the dive
planner's gear section expand an assembly into its parts through the
shared page helper, and removing an assembly removes its parts."
```

---

### Task 6: The shared tree renderer and the dive detail section

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildEquipmentSection` L4622-L4717)
- Modify: all 11 ARB files; regenerate
- Test: `test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart`

**Interfaces:**
- Consumes: `GearTree`, `GearLink`, `arrangeEquipment`, `EquipmentGroupHeader`, `equipmentArrangementProvider`, `equipmentSetsProvider` (set names), `equipmentTypeIcon`, `localizedName`.
- Produces:
  - `class DiveGearTreeView extends ConsumerStatefulWidget { const DiveGearTreeView({super.key, required List<GearLink> links, void Function(EquipmentItem item)? onTap, void Function(String setId)? onRemoveSet, void Function(String equipmentId)? onRemoveSubtree, void Function(String equipmentId)? onRemovePart}); }` (any non-null remove callback puts the view in edit mode)
  - ARB keys `diveLog_gear_unknownSet` ("Set"), `diveLog_gear_removeSet` ("Remove set from this dive"), `diveLog_gear_removeAssembly` ("Remove assembly and its parts"), `diveLog_gear_removePart` ("Remove part"), `diveLog_gear_expand` ("Show parts"), `diveLog_gear_collapse` ("Hide parts"). The count subtitle reuses `equipment_components_count`.

- [ ] **Step 1: Add the ARB keys to all 11 locales and regenerate**

Anchor for the new prefix: the key `diveLog_detail_section_equipment` (place the block immediately before it in each file).

`en`: `"diveLog_gear_collapse": "Hide parts"`, `"diveLog_gear_expand": "Show parts"`, `"diveLog_gear_removeAssembly": "Remove assembly and its parts"`, `"diveLog_gear_removePart": "Remove part"`, `"diveLog_gear_removeSet": "Remove set from this dive"`, `"diveLog_gear_unknownSet": "Set"`.
`de`: "Teile ausblenden", "Teile anzeigen", "Baugruppe und ihre Teile entfernen", "Teil entfernen", "Set von diesem Tauchgang entfernen", "Set".
`fr`: "Masquer les pièces", "Afficher les pièces", "Retirer l'ensemble et ses pièces", "Retirer la pièce", "Retirer le kit de cette plongée", "Kit".
`es`: "Ocultar piezas", "Mostrar piezas", "Quitar el conjunto y sus piezas", "Quitar pieza", "Quitar el equipo de esta inmersión", "Equipo".
`it`: "Nascondi parti", "Mostra parti", "Rimuovi l'assieme e le sue parti", "Rimuovi parte", "Rimuovi il set da questa immersione", "Set".
`nl`: "Onderdelen verbergen", "Onderdelen tonen", "Samenstel en onderdelen verwijderen", "Onderdeel verwijderen", "Set van deze duik verwijderen", "Set".
`pt`: "Ocultar peças", "Mostrar peças", "Remover o conjunto e as suas peças", "Remover peça", "Remover o conjunto deste mergulho", "Conjunto".
`hu`: "Részek elrejtése", "Részek megjelenítése", "Összeállítás és részei eltávolítása", "Rész eltávolítása", "Készlet eltávolítása erről a merülésről", "Készlet".
`ar`: "إخفاء الأجزاء", "إظهار الأجزاء", "إزالة التجميعة وأجزائها", "إزالة الجزء", "إزالة الطقم من هذه الغطسة", "طقم".
`he`: "הסתרת חלקים", "הצגת חלקים", "הסרת המכלול וחלקיו", "הסרת חלק", "הסרת הסט מהצלילה הזו", "סט".
`zh`: "隐藏部件", "显示部件", "移除组合及其部件", "移除部件", "从本次潜水移除套装", "套装".

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing renderer test**

```dart
// test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  EquipmentItem item(String id, String name, EquipmentType type) =>
      EquipmentItem(id: id, name: name, type: type);
  final items = [
    item('mask', 'Mask', EquipmentType.mask),
    item('reg', 'Cold water reg', EquipmentType.regulator),
    item('hose', 'Long hose', EquipmentType.hose),
    item('fins', 'Jets', EquipmentType.fins),
  ];
  const provenance = [
    GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'fins', viaSetId: 'winter'),
  ];
  final links = gearLinksFor(items, provenance);
  final winter = EquipmentSet(
    id: 'winter',
    name: 'Winter kit',
    equipmentIds: const ['reg', 'fins'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Widget build({
    EquipmentArrangement arrangement = EquipmentArrangement.defaults,
    void Function(String)? onRemovePart,
    void Function(String)? onRemoveSubtree,
    void Function(String)? onRemoveSet,
  }) => ProviderScope(
    overrides: [
      equipmentArrangementProvider.overrideWithValue(arrangement),
      equipmentSetsProvider.overrideWith((ref) async => [winter]),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiveGearTreeView(
            links: links,
            onRemovePart: onRemovePart,
            onRemoveSubtree: onRemoveSubtree,
            onRemoveSet: onRemoveSet,
          ),
        ),
      ),
    ),
  );

  testWidgets('set band first, loose gear last, assembly collapsed', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Winter kit'), findsOneWidget);
    expect(find.text('Cold water reg'), findsOneWidget);
    expect(find.text('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Winter kit')).dy,
      lessThan(tester.getTopLeft(find.text('Mask')).dy),
    );
  });

  testWidgets('expanding shows the parts indented under the assembly', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    expect(find.text('Long hose'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Long hose')).dx,
      greaterThan(tester.getTopLeft(find.text('Cold water reg')).dx),
    );
  });

  testWidgets('the arrangement groups top-level rows by type inside the band', (tester) async {
    await tester.pumpWidget(
      build(arrangement: const EquipmentArrangement(groupByType: true)),
    );
    await tester.pumpAndSettle();
    // Type headers appear for the winter band (Regulator, Fins) and the
    // loose band (Mask), the assembly row placed by its own type.
    expect(find.text('Regulator'), findsOneWidget);
    expect(find.text('Fins'), findsOneWidget);
  });

  testWidgets('edit mode offers the three removals', (tester) async {
    String? part, subtree, set;
    await tester.pumpWidget(
      build(
        onRemovePart: (id) => part = id,
        onRemoveSubtree: (id) => subtree = id,
        onRemoveSet: (id) => set = id,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove set from this dive'));
    expect(set, 'winter');
    await tester.tap(find.byTooltip('Remove assembly and its parts'));
    expect(subtree, 'reg');
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove part'));
    expect(part, 'hose');
  });
}
```

Check `EquipmentArrangement`'s constructor parameters (`grep -n "const EquipmentArrangement({" -A8 lib/features/equipment/domain/models/equipment_arrangement.dart`) and use the real names for "group by type on, types alphabetical".

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
Expected: compile error, `dive_gear_tree_view.dart` not found.

- [ ] **Step 4: Write the renderer**

```dart
// lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear on a dive, rendered the same way on the detail and edit pages
/// (issue #1487): rows bucketed by the set they came from (loose gear
/// last), each bucket's top-level rows ordered and optionally type-grouped
/// by the diver's arrangement, an assembly as one collapsed row that
/// expands in place to its parts in template order.
///
/// Passing any remove callback puts the view in edit mode.
class DiveGearTreeView extends ConsumerStatefulWidget {
  final List<GearLink> links;
  final void Function(EquipmentItem item)? onTap;
  final void Function(String setId)? onRemoveSet;
  final void Function(String equipmentId)? onRemoveSubtree;
  final void Function(String equipmentId)? onRemovePart;

  const DiveGearTreeView({
    super.key,
    required this.links,
    this.onTap,
    this.onRemoveSet,
    this.onRemoveSubtree,
    this.onRemovePart,
  });

  @override
  ConsumerState<DiveGearTreeView> createState() => _DiveGearTreeViewState();
}

class _DiveGearTreeViewState extends ConsumerState<DiveGearTreeView> {
  final _expanded = <String>{};

  bool get _editable =>
      widget.onRemoveSet != null ||
      widget.onRemoveSubtree != null ||
      widget.onRemovePart != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arrangement = ref.watch(equipmentArrangementProvider);
    final setsById = {
      for (final s in ref.watch(equipmentSetsProvider).value ?? const []) s.id: s,
    };
    final buckets = GearTree.build(widget.links);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bucket in buckets) ...[
          if (bucket.setId != null)
            _SetHeader(
              name: setsById[bucket.setId]?.name ?? l10n.diveLog_gear_unknownSet,
              onRemove: widget.onRemoveSet == null
                  ? null
                  : () => widget.onRemoveSet!(bucket.setId!),
            ),
          // The arrangement sees only the top-level items of this bucket;
          // parts keep template order underneath their assembly.
          for (final group in arrangeEquipment(
            [for (final n in bucket.roots) n.link.item],
            arrangement,
            typeLabel: (type) => type.localizedName(l10n),
          )) ...[
            if (group.type != null) EquipmentGroupHeader(type: group.type!),
            for (final item in group.items)
              ..._rows(
                context,
                bucket.roots.firstWhere((n) => n.link.item.id == item.id),
                depth: 0,
                showType: group.type == null,
              ),
          ],
        ],
      ],
    );
  }

  List<Widget> _rows(
    BuildContext context,
    GearNode node, {
    required int depth,
    required bool showType,
  }) {
    final l10n = context.l10n;
    final item = node.link.item;
    final hasParts = node.children.isNotEmpty;
    final open = _expanded.contains(item.id);
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (depth == 0 && item.fullName != item.name) item.fullName,
      if (depth == 0 && showType) item.type.localizedName(l10n),
      if (hasParts) l10n.equipment_components_count(node.children.length),
    ];
    return [
      Padding(
        padding: EdgeInsets.only(left: 24.0 * depth),
        child: ListTile(
          key: ValueKey('gear-row-${item.id}'),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Icon(
              equipmentTypeIcon(item.type),
              color: theme.colorScheme.onTertiaryContainer,
              size: 20,
            ),
          ),
          title: Text(item.name),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          onTap: widget.onTap == null ? null : () => widget.onTap!(item),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasParts)
                IconButton(
                  icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                  tooltip: open ? l10n.diveLog_gear_collapse : l10n.diveLog_gear_expand,
                  onPressed: () => setState(() {
                    if (!_expanded.remove(item.id)) _expanded.add(item.id);
                  }),
                ),
              if (_editable)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: hasParts
                      ? l10n.diveLog_gear_removeAssembly
                      : l10n.diveLog_gear_removePart,
                  onPressed: () => hasParts || depth == 0
                      ? widget.onRemoveSubtree?.call(item.id)
                      : widget.onRemovePart?.call(item.id),
                )
              else if (widget.onTap != null)
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
      if (hasParts && open)
        for (final child in node.children)
          ..._rows(context, child, depth: depth + 1, showType: false),
    ];
  }
}

class _SetHeader extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;

  const _SetHeader({required this.name, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: context.l10n.diveLog_gear_removeSet,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
```

A top-level row with no parts on the edit page is a loose item; removing it goes through `onRemoveSubtree`, which the expander treats as a one-row subtree, so the edit page needs no third code path for loose rows. A leaf part (depth above zero) goes through `onRemovePart`.

- [ ] **Step 5: Run the renderer test**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Write the failing detail-page test**

Copy `test/features/dive_log/presentation/pages/dive_detail_equipment_arrangement_test.dart` to `dive_detail_gear_tree_test.dart`, keep its pump helper, give the fixture dive `gear: gearLinksFor(items, provenance)` with the `items`/`provenance` from the renderer test above, add `equipmentSetsProvider.overrideWith((ref) async => [winter])` to its overrides, and replace its tests with:

```dart
  testWidgets('the section shows the set band and a collapsed assembly', (tester) async {
    await pumpDetail(tester);
    expect(find.text('Winter kit'), findsOneWidget);
    expect(find.text('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
  });

  testWidgets('the collapsed summary counts top-level rows, not parts', (tester) async {
    await pumpDetail(tester);
    // 4 items on the dive, 3 of them top-level.
    expect(find.text('3 items'), findsOneWidget);
  });
```

(`pumpDetail` is whatever the copied helper is called; the summary text comes from `diveLog_detail_equipmentCount`, whose en value is `{count} {count, plural, =1{item} other{items}}`.)

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart`
Expected: FAIL, no set band and the summary says 4.

- [ ] **Step 8: Mount the renderer on the detail page**

In `_buildEquipmentSection`, replace the `arrangeEquipment(...)` local and the whole `Column` inside `contentBuilder` with:

```dart
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DiveGearTreeView(
          links: dive.gear,
          onTap: (item) => context.push('/equipment/${item.id}'),
        ),
      ),
```

and change the collapsed subtitle to count top-level rows:

```dart
    final collapsedSubtitle = context.l10n.diveLog_detail_equipmentCount(
      dive.gear.where((g) => g.isTopLevel).length,
    );
```

Remove imports that become unused (`equipment_arranger`, `equipment_group_header`) and add the tree view import. Run the new test and the existing arrangement test: `flutter test test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart test/features/dive_log/presentation/pages/dive_detail_equipment_arrangement_test.dart`. Expected: PASS (the arrangement test's expectations about type headers still hold because the view arranges each bucket).

- [ ] **Step 9: Format and commit**

```bash
dart format lib/features/dive_log/presentation test/features/dive_log/presentation
git add lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart lib/l10n/arb
git commit -m "feat(dive-log): render gear as set bands and collapsible assemblies (#1487)

One tree view for both dive pages: rows bucketed by the set they came
from, each bucket's top-level rows arranged by the diver's preference,
assemblies collapsed with their parts in template order underneath."
```

---

### Task 7: The dive edit page writes provenance

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state L240-L246, load L715, `_equipmentChild` L3274-L3411, pickers L3413-L3468, defaults L3209-L3272, `_saveEquipmentAsSet` ~L3860, `Dive(` at L5040, bulk `trailingBuilder` ~L1399-L1411)
- Test: `test/features/dive_log/presentation/pages/dive_edit_gear_tree_test.dart`

**Interfaces:**
- Consumes: `expandGearOnPage`, `GearExpander.removeSubtree/removeSet/removePart`, `DiveGearTreeView`, `gearLinksFor`, `AssemblyChips`.
- Produces: `_gearProvenance` state; `_addGear(List<EquipmentItem>, {String? viaSetId, bool markDirty = true})`; `_setGear(List<GearProvenance>)`; the save passes `gear: gearLinksFor(_selectedEquipment, _gearProvenance)`; "Save as set" stores top-level ids only; both pickers mark the form dirty.

- [ ] **Step 1: Write the failing edit-page test**

Copy `test/features/dive_log/presentation/pages/dive_edit_equipment_arrangement_test.dart` to `dive_edit_gear_tree_test.dart`, keep its pump helper and `expandGasGear()`, seed the dive with `gear: gearLinksFor(items, provenance)` using the renderer fixture, add overrides for `equipmentSetsProvider` (the winter set), `equipmentComponentsIndexProvider` (`ComponentsIndex.empty`) and `activeEquipmentProvider` (the four items), and write:

```dart
  testWidgets('removing an assembly removes its parts from the saved dive', (tester) async {
    await pumpEdit(tester);
    await expandGasGear(tester);
    await tester.tap(find.byTooltip('Remove assembly and its parts'));
    await tester.pumpAndSettle();
    expect(find.text('Cold water reg'), findsNothing);
    expect(find.byTooltip('Show parts'), findsNothing);
  });

  testWidgets('removing a set band removes every row that came from it', (tester) async {
    await pumpEdit(tester);
    await expandGasGear(tester);
    await tester.tap(find.byTooltip('Remove set from this dive'));
    await tester.pumpAndSettle();
    expect(find.text('Winter kit'), findsNothing);
    expect(find.text('Jets'), findsNothing);
    expect(find.text('Mask'), findsOneWidget);
  });

  testWidgets('the saved dive carries the provenance', (tester) async {
    await pumpEdit(tester);
    await expandGasGear(tester);
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove part'));
    await tester.pumpAndSettle();
    await saveDive(tester);
    final saved = repository.lastUpdated!;
    expect(saved.equipment.map((e) => e.id), unorderedEquals(['mask', 'reg', 'fins']));
    expect(saved.gear.firstWhere((g) => g.item.id == 'reg').viaSetId, 'winter');
  });
```

Match `pumpEdit`, `saveDive` and the fake repository's captured-dive field to what the copied test provides (it stubs `diveRepositoryProvider`; if it captures `updateDive` calls under another name, use that).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_gear_tree_test.dart`
Expected: FAIL, no assembly tooltip exists on the page.

- [ ] **Step 3: Add provenance state and the add/remove helpers**

Beside `_selectedEquipment` add `List<GearProvenance> _gearProvenance = [];`; at load (L715) add `_gearProvenance = dive.gearProvenance;`. Add:

```dart
  /// Every way gear reaches this page funnels here so an assembly expands
  /// identically whether it came from the picker, a set, a geofence
  /// suggestion or the on-empty default (issue #1487).
  Future<void> _addGear(
    List<EquipmentItem> items, {
    String? viaSetId,
    bool markDirty = true,
  }) async {
    if (items.isEmpty) return;
    final merged = [
      ..._selectedEquipment,
      for (final item in items)
        if (!_selectedEquipment.any((e) => e.id == item.id)) item,
    ];
    final expansion = await expandGearOnPage(
      ref,
      additions: [for (final i in items) (equipmentId: i.id, viaSetId: viaSetId)],
      existing: _gearProvenance,
      existingItems: merged,
    );
    if (!mounted) return;
    if (markDirty) _markDirty();
    setState(() {
      _selectedEquipment = [...merged, ...expansion.newItems];
      _gearProvenance = expansion.provenance;
    });
  }

  void _setGear(List<GearProvenance> rows) {
    final keep = {for (final p in rows) p.equipmentId};
    _markDirty();
    setState(() {
      _gearProvenance = rows;
      _selectedEquipment = [
        for (final e in _selectedEquipment) if (keep.contains(e.id)) e,
      ];
    });
  }
```

Rewire the call sites:
- `_showEquipmentPicker`: `onEquipmentSelected: (equipment) { Navigator.of(context).pop(); _addGear([equipment]); }`
- `_showEquipmentSetPicker`: `onSetSelected: (set, items) { Navigator.of(context).pop(); _addGear(items, viaSetId: set.id); }`
- Geofence banner apply (L3304-L3312): `_addGear(_geofenceSuggestion!.items ?? const [], viaSetId: _geofenceSuggestion!.id);` then clear the suggestion.
- `_applyEquipmentDefaultsOnEmpty` and the on-empty branch of `_reevaluateGeofenceForSite`: replace `setState(() => _selectedEquipment = [...items]);` with `await _addGear(items, viaSetId: best!.id, markDirty: false);` (these were silent before; keep them silent).
- `_equipmentChild`: replace the arranged `ListTile` loop with

```dart
              DiveGearTreeView(
                links: gearLinksFor(_selectedEquipment, _gearProvenance),
                onRemoveSet: (setId) => _setGear(GearExpander.removeSet(_gearProvenance, setId)),
                onRemoveSubtree: (id) => _setGear(GearExpander.removeSubtree(_gearProvenance, id)),
                onRemovePart: (id) => _setGear(GearExpander.removePart(_gearProvenance, id)),
              ),
```

  keeping the overline actions, the banner, the empty state and the footer. "Clear all" also clears `_gearProvenance`.
- `_saveEquipmentAsSet`: build `equipmentIds` from top-level rows only: `[for (final g in gearLinksFor(_selectedEquipment, _gearProvenance)) if (g.isTopLevel) g.item.id]`.
- The `Dive(` literal at L5040: replace Task 1's `gear: looseGear(_selectedEquipment),` with `gear: gearLinksFor(_selectedEquipment, _gearProvenance),`.
- Bulk mode: pass `trailingBuilder: (item) => AssemblyChips(itemId: item.id)` to the equipment `BulkMembershipEditor`.

Since a loose row's remove now arrives through `onRemoveSubtree`, the existing id-keyed removal test keeps its meaning.

- [ ] **Step 4: Run the new test and the existing edit-page equipment tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_gear_tree_test.dart test/features/dive_log/presentation/pages/dive_edit_equipment_arrangement_test.dart test/features/dive_log/presentation/pages/dive_edit_equipment_default_test.dart test/features/dive_log/presentation/pages/dive_edit_geofence_suggestion_test.dart test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`
Expected: PASS. The default and geofence tests may need `equipmentComponentsIndexProvider.overrideWith((ref) async => ComponentsIndex.empty)` and an `equipmentRepositoryProvider` stub for `getEquipmentByIds` if they did not already stub it; add those, not product changes.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages
git commit -m "feat(dive-log): the edit page expands assemblies and keeps provenance (#1487)

Every way gear reaches the page funnels through one add helper that
expands assemblies and tags rows with the set they came from; removals
drop a set band, an assembly with its parts, or one part; the pickers
now mark the form dirty; save-as-set stores top-level rows only."
```

---

### Task 8: PDF grouping

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart` (`_equipmentFields` L434-L466)
- Test: `test/core/services/pdf_templates/pdf_detailed_gear_fields_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/pdf_templates/pdf_detailed_gear_fields_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('parts print indented under their assembly, with their type', () {
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026, 1, 1),
      gear: gearLinksFor(
        const [
          EquipmentItem(id: 'reg', name: 'Cold water reg', type: EquipmentType.regulator),
          EquipmentItem(id: 'hose', name: 'Long hose', type: EquipmentType.hose),
          EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
        ],
        const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg')],
      ),
    );
    final fields = equipmentFieldsForTest(
      dive,
      units: const UnitFormatter(AppSettings()),
      arrangement: EquipmentArrangement.defaults,
    );
    final labels = fields.map((f) => f.label).toList();
    final regAt = labels.indexOf('Regulator');
    expect(regAt, greaterThanOrEqualTo(0));
    expect(labels[regAt + 1], '  Hose');
    expect(fields[regAt + 1].value, 'Long hose');
  });
}
```

Match `equipmentFieldsForTest`'s signature and `_Field`'s public accessor names to the file (L424-L432).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_detailed_gear_fields_test.dart`
Expected: FAIL, the hose prints as a top-level "Hose" row.

- [ ] **Step 3: Print the tree**

Replace the `for (final group in groups) for (final item in group.items) _Field(...)` with a walk over `GearTree.build(dive.gear)`: for each bucket, arrange `[for (final n in bucket.roots) n.link.item]`, and for each top-level item emit `_Field(item.type.displayName, item.name)` followed, for each child node recursively, by `_Field('${'  ' * depth}${child.link.item.type.displayName}', child.link.item.name)`. Set names are not available to the template, so buckets print without a header. Import `gear_tree.dart`.

- [ ] **Step 4: Run the PDF tests**

Run: `flutter test test/core/services/pdf_templates/ test/core/services/pdf_equipment_arrangement_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/pdf_templates/pdf_template_detailed.dart test/core/services/pdf_templates/pdf_detailed_gear_fields_test.dart
git add lib/core/services/pdf_templates/pdf_template_detailed.dart test/core/services/pdf_templates/pdf_detailed_gear_fields_test.dart
git commit -m "feat(pdf): print assembly parts indented under their assembly (#1487)"
```

---

### Task 9: Leaf-only buoyancy and weight-model observations

**Files:**
- Modify: `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart` (`composeRigTerms` L122-L131 and loop L167-L189; `assemble` L103-L104; `droppableLeadKg` L231; `_carriedLead` L310)
- Modify: `lib/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart` (L103 call) and `lib/features/weight_planner/presentation/pages/weight_planner_page.dart` (L151 call)
- Modify: `lib/features/weight_planner/data/repositories/weight_history_repository.dart` (L47-L59)
- Test: `test/features/dive_log/data/services/buoyancy_twin_assembler_leaf_test.dart`
- Test: `test/features/weight_planner/data/repositories/weight_history_leaf_test.dart`

**Interfaces:**
- Produces: `composeRigTerms({..., Set<String> rolledUpIds = const {}})` skips items in the set; `assemble` passes `GearTree.rolledUpIds(dive.gearProvenance)`; lead helpers use `GearTree.leafItems(dive.gear)`; `WeightObservation.equipmentIds` excludes rolled-up ids.

- [ ] **Step 1: Write the failing assembler test**

```dart
// test/features/dive_log/data/services/buoyancy_twin_assembler_leaf_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import 'buoyancy_twin_assembler_test.dart' show fittedModelForTest;

void main() {
  EquipmentItem withMass(String id, EquipmentType type, double kg) => EquipmentItem(
    id: id,
    name: id,
    type: type,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.dryWeightKg,
        valueNum: kg,
      ),
    ],
  );

  test('an assembly with parts on the dive contributes no mass of its own', () {
    final bcd = withMass('bcd', EquipmentType.bcd, 3.0);
    final wing = withMass('wing', EquipmentType.wing, 2.0);
    final both = BuoyancyTwinAssembler.composeRigTerms(
      items: [bcd, wing],
      tanks: const [],
      model: fittedModelForTest(),
      waterType: WaterType.salt,
      bodyWeightKg: 80,
      rolledUpIds: const {'bcd'},
    );
    final flat = BuoyancyTwinAssembler.composeRigTerms(
      items: [bcd, wing],
      tanks: const [],
      model: fittedModelForTest(),
      waterType: WaterType.salt,
      bodyWeightKg: 80,
    );
    expect(both.gearDryMassKg, 2.0);
    expect(flat.gearDryMassKg, 5.0);
  });
}
```

If `buoyancy_twin_assembler_test.dart` does not export a model helper, build the `FittedWeightModel` the way that file does inline (read its first 60 lines) and assert on whichever `RigTerms` field holds the summed dry mass (`grep -n "class RigTerms" -A12 lib/features/dive_log/data/services/buoyancy_twin_assembler.dart`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/services/buoyancy_twin_assembler_leaf_test.dart`
Expected: compile error, `rolledUpIds` is not a parameter.

- [ ] **Step 3: Add the parameter and the three call sites**

In `composeRigTerms` add `Set<String> rolledUpIds = const {},` after `salinityPpt` and, at the top of the item loop, `if (rolledUpIds.contains(item.id)) continue;` with the comment `// An assembly whose parts are on this dive declares nothing itself: the parts carry the mass and lift (issue #1487).` In `assemble` pass `rolledUpIds: GearTree.rolledUpIds(dive.gearProvenance)`. Change `_carriedLead` to `EquipmentLead.totalKg(GearTree.leafItems(dive.gear))` and `droppableLeadKg` to `EquipmentLead.droppableKg(GearTree.leafItems(dive.gear))`. In `plan_buoyancy_twin_provider.dart` pass `rolledUpIds: GearTree.rolledUpIds(state.gearProvenance)`; in `weight_planner_page.dart` pass `rolledUpIds: GearTree.rolledUpIds(_gearProvenance)`.

- [ ] **Step 4: Write the failing weight-history test and fix the observation build**

```dart
// test/features/weight_planner/data/repositories/weight_history_leaf_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/weight_planner/data/repositories/weight_history_repository.dart';

import '../../../../helpers/test_database.dart';

/// Training observations list leaf gear only: an assembly and its parts
/// would otherwise be two features for one object (issue #1487).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.into(db.divers).insert(DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: 1, updatedAt: 1));
    for (final id in ['bcd', 'wing']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(id: id, name: id, type: 'bcd', createdAt: 1, updatedAt: 1, diverId: const Value('d1')),
      );
    }
    await db.into(db.dives).insert(
      DivesCompanion.insert(id: 'dv', diveDateTime: 1, createdAt: 1, updatedAt: 1, diverId: const Value('d1'), weightAmount: const Value(6.0)),
    );
    await db.into(db.diveEquipment).insert(
      const DiveEquipmentCompanion(diveId: Value('dv'), equipmentId: Value('bcd')),
    );
    await db.into(db.diveEquipment).insert(
      const DiveEquipmentCompanion(diveId: Value('dv'), equipmentId: Value('wing'), viaEquipmentId: Value('bcd')),
    );
  });

  tearDown(tearDownTestDatabase);

  test('the observation lists the wing but not the assembly', () async {
    final observations = await WeightHistoryRepository().observationsForDiver('d1');
    expect(observations.single.equipmentIds, ['wing']);
  });
}
```

Match the repository's constructor and method name (`grep -n "Future<List<WeightObservation>>" lib/features/weight_planner/data/repositories/weight_history_repository.dart`) and `DivesCompanion.insert`'s required parameters (`grep -n "DivesCompanion.insert" -A20 lib/core/database/database.g.dart | grep required`). The existing `test/features/weight_planner/data/weight_history_repository_test.dart` shows how that repository is exercised.

Run it: expected FAIL (both ids listed). Then in `weight_history_repository.dart` L57-L59, after collecting rows per dive, drop ids that are a `viaEquipmentId` of another row on the same dive:

```dart
    final rolledUpByDive = <String, Set<String>>{};
    for (final row in rows) {
      if (row.viaEquipmentId != null) {
        rolledUpByDive.putIfAbsent(row.diveId, () => {}).add(row.viaEquipmentId!);
      }
    }
    final equipmentByDive = <String, List<String>>{};
    for (final row in rows) {
      if (rolledUpByDive[row.diveId]?.contains(row.equipmentId) ?? false) continue;
      equipmentByDive.putIfAbsent(row.diveId, () => []).add(row.equipmentId);
    }
```

(`rows` is whatever the existing select at L47 is assigned to.) Run the test again: expected PASS.

- [ ] **Step 5: Run the buoyancy suites**

Run: `flutter test test/features/dive_log/data/services/buoyancy_twin_assembler_leaf_test.dart test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart test/features/dive_log/data/services/buoyancy_twin_gear_lead_scenario_test.dart test/features/weight_planner/data/repositories/weight_history_leaf_test.dart test/features/weight_planner/data/weight_history_repository_test.dart test/features/dive_log/presentation/providers/buoyancy_history_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/dive_log/data/services/buoyancy_twin_assembler.dart lib/features/weight_planner test/features/dive_log/data/services test/features/weight_planner
git add lib/features/dive_log/data/services/buoyancy_twin_assembler.dart lib/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart lib/features/weight_planner/presentation/pages/weight_planner_page.dart lib/features/weight_planner/data/repositories/weight_history_repository.dart test/features/dive_log/data/services/buoyancy_twin_assembler_leaf_test.dart test/features/weight_planner/data/repositories/weight_history_leaf_test.dart
git commit -m "fix(buoyancy): count an assembly's parts, not the assembly too (#1487)

The rig composer skips items whose parts are on the dive, the lead
helpers read leaf gear, and weight-model observations list leaf ids,
so a BCD assembly with a wing declares lift and mass once."
```

---

### Task 10: Whole-project verification

- [ ] **Step 1: Format, analyze, generated l10n**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter gen-l10n && git status --short lib/l10n/arb
```

Expected: no changes, `No issues found!`, empty status.

- [ ] **Step 2: Full suite, in the background**

Run `flutter test` with output redirected to a file (never piped through `grep`), in the background with a long timeout. Expected: 0 failures. Rerun any single flaky file alone before calling it a regression.

- [ ] **Step 3: Commit anything the checks touched and report**

Stage by path and commit as `style(dive-log): format and analyzer fixes for assemblies PR 2` if needed. Report the commits, the test counts, and for the PR body: that `Dive.gear` is now the single gear list per the spec with `equipment` as a getter, the arrangement layering decision, that installed-in children are untouched, and that PR 3 (swap-with-history, UDDF, CSV, Excel) is next.
