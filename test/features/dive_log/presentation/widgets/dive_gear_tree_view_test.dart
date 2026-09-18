import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The shared gear renderer (issue #1487): the dive's sets as chips above
/// one list of top-level rows arranged by the diver's preference, set gear
/// and hand-added gear together (#2031), assemblies collapsed with their
/// parts underneath.
void main() {
  EquipmentItem item(String id, String name, EquipmentType type) =>
      EquipmentItem(id: id, name: name, type: type);
  final items = [
    item('mask', 'Cressi mask', EquipmentType.mask),
    item('reg', 'Cold water reg', EquipmentType.regulator),
    item('hose', 'Long hose', EquipmentType.hose),
    item('fins', 'Jets', EquipmentType.fins),
  ];
  const provenance = [
    GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    ),
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
  final flat = EquipmentArrangement.defaults.copyWith(groupByType: false);
  // The template has grown since the dive was logged: the reg now also
  // lists a first stage, which this dive never received (issue #1988).
  EquipmentComponent edge(String parent, String child, int order) =>
      EquipmentComponent(
        id: '$parent-$child',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
  final grownTemplate = ComponentsIndex.fromRows([
    edge('reg', 'hose', 0),
    edge('reg', 'first', 1),
  ]);

  Widget build({
    required EquipmentArrangement arrangement,
    List<GearLink>? gear,
    void Function(String)? onRemovePart,
    void Function(String)? onRemoveSubtree,
    void Function(String)? onRemoveSet,
    Widget Function(EquipmentItem)? rowTrailing,
    void Function(GearLink)? onUpdateAssembly,
    ComponentsIndex template = ComponentsIndex.empty,
    Set<String> activeParts = const {},
    List<EquipmentSet>? sets,
  }) => ProviderScope(
    overrides: [
      equipmentArrangementProvider.overrideWithValue(arrangement),
      equipmentSetsProvider.overrideWith((ref) async => sets ?? [winter]),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      equipmentComponentsIndexProvider.overrideWith((ref) async => template),
      activeComponentIdsProvider.overrideWith((ref) async => activeParts),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiveGearTreeView(
            links: gear ?? links,
            onRemovePart: onRemovePart,
            onRemoveSubtree: onRemoveSubtree,
            onRemoveSet: onRemoveSet,
            rowTrailing: rowTrailing,
            onUpdateAssembly: onUpdateAssembly,
          ),
        ),
      ),
    ),
  );

  testWidgets('set chip above the list, assembly collapsed', (tester) async {
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Winter kit'), findsOneWidget);
    expect(find.text('Cold water reg'), findsOneWidget);
    expect(find.textContaining('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Winter kit')).dy,
      lessThan(tester.getTopLeft(find.text('Cold water reg')).dy),
    );
  });

  testWidgets('hand-added gear sorts among the set\'s gear, not after it', (
    tester,
  ) async {
    // Issue #2031: a diver applies a set, swaps one item for another by
    // hand, and the swapped-in item trailed the set's gear whatever the
    // sort. Alphabetical type order puts the loose mask between the set's
    // fins and reg; the old per-set runs put it after both.
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Jets'), lessThan(top('Cressi mask')));
    expect(top('Cressi mask'), lessThan(top('Cold water reg')));
  });

  testWidgets('a dive with no set shows no set chips', (tester) async {
    await tester.pumpWidget(
      build(arrangement: flat, gear: looseGear([items.first])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNothing);
    expect(find.text('Cressi mask'), findsOneWidget);
  });

  testWidgets('a set missing from the catalog still gets a chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        gear: gearLinksFor(
          [items.first],
          const [GearProvenance(equipmentId: 'mask', viaSetId: 'deleted')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Set'), findsOneWidget);
  });

  testWidgets('a set with a blank name gets the fallback label', (
    tester,
  ) async {
    // The set editor accepts a name of spaces and trims it on save, so a
    // stored name can be empty; the chip must not render with no label.
    await tester.pumpWidget(
      build(
        arrangement: flat,
        sets: [winter.copyWith(name: '')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Set'), findsOneWidget);
  });

  testWidgets('expanding shows the parts indented under the assembly', (
    tester,
  ) async {
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    expect(find.text('Long hose'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Long hose')).dx,
      greaterThan(tester.getTopLeft(find.text('Cold water reg')).dx),
    );
    expect(find.byTooltip('Hide parts'), findsOneWidget);
  });

  testWidgets('the row slot reaches every row, parts included', (tester) async {
    // The detail page puts the check-in chip here, and a part (a cell, a
    // hose) takes check-ins like any other item.
    await tester.pumpWidget(
      build(arrangement: flat, rowTrailing: (item) => Text('slot-${item.id}')),
    );
    await tester.pumpAndSettle();
    for (final id in ['mask', 'reg', 'fins']) {
      expect(find.text('slot-$id'), findsOneWidget, reason: id);
    }
    expect(find.text('slot-hose'), findsNothing);
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    expect(find.text('slot-hose'), findsOneWidget);
  });

  testWidgets('the arrangement groups every top-level row by type', (
    tester,
  ) async {
    await tester.pumpWidget(build(arrangement: EquipmentArrangement.defaults));
    await tester.pumpAndSettle();
    // One header per type across the whole dive, set and loose gear alike,
    // so the loose mask lands between the set's fins and reg (#2031). The
    // hose is a part and gets no header.
    final headers = tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();
    expect(headers, [
      EquipmentType.fins,
      EquipmentType.mask,
      EquipmentType.regulator,
    ]);
  });

  testWidgets('edit mode offers the three removals', (tester) async {
    String? part, subtree, set;
    await tester.pumpWidget(
      build(
        arrangement: flat,
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
    // A loose top-level row is a one-row subtree and keeps the edit page's
    // existing tooltip.
    expect(find.byTooltip('Remove equipment'), findsNWidgets(2));
  });

  testWidgets('read mode shows no remove affordances', (tester) async {
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('a set-only callback shows no row controls that would do '
      'nothing', (tester) async {
    await tester.pumpWidget(build(arrangement: flat, onRemoveSet: (_) {}));
    await tester.pumpAndSettle();
    // Only the set chip's own delete button; no per-row close icons.
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byTooltip('Remove set from this dive'), findsOneWidget);
    expect(find.byTooltip('Remove assembly and its parts'), findsNothing);
    expect(find.byTooltip('Remove equipment'), findsNothing);
  });

  testWidgets('each row shows a control only for the callback it would call', (
    tester,
  ) async {
    await tester.pumpWidget(build(arrangement: flat, onRemoveSubtree: (_) {}));
    await tester.pumpAndSettle();
    // Top-level rows remove through onRemoveSubtree, so they get a control.
    expect(find.byTooltip('Remove assembly and its parts'), findsOneWidget);
    expect(find.byTooltip('Remove equipment'), findsNWidgets(2));
    // A part removes through onRemovePart, which was not provided, so it
    // gets no control rather than a dead one.
    await tester.tap(find.byTooltip('Show parts'));
    await tester.pumpAndSettle();
    expect(find.text('Long hose'), findsOneWidget);
    expect(find.byTooltip('Remove part'), findsNothing);
  });

  testWidgets('an assembly behind its template says how many of its parts '
      'the dive carries', (tester) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        template: grownTemplate,
        activeParts: const {'hose', 'first'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 2 components'), findsOneWidget);
    expect(find.textContaining('1 component'), findsNothing);
  });

  testWidgets('a retired template part is not missing, so the count stays '
      'plain', (tester) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        template: grownTemplate,
        activeParts: const {'hose'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 component'), findsOneWidget);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('edit mode offers the update on a behind assembly and hands '
      'back its row', (tester) async {
    GearLink? updated;
    await tester.pumpWidget(
      build(
        arrangement: flat,
        template: grownTemplate,
        activeParts: const {'hose', 'first'},
        onUpdateAssembly: (link) => updated = link,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add missing parts'), findsOneWidget);
    await tester.tap(find.byTooltip('Add missing parts'));
    expect(updated?.item.id, 'reg');
    expect(updated?.viaSetId, 'winter');
  });

  testWidgets('read mode shows the count but no update control', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        template: grownTemplate,
        activeParts: const {'hose', 'first'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 2 components'), findsOneWidget);
    expect(find.byTooltip('Add missing parts'), findsNothing);
  });

  testWidgets('an assembly that is up to date offers no update', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        template: ComponentsIndex.fromRows([edge('reg', 'hose', 0)]),
        activeParts: const {'hose'},
        onUpdateAssembly: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add missing parts'), findsNothing);
  });

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
}
