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
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The shared gear renderer (issue #1487): set bands first, loose gear last,
/// each band's top-level rows arranged by the diver's preference, assemblies
/// collapsed with their parts underneath.
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

  Widget build({
    required EquipmentArrangement arrangement,
    void Function(String)? onRemovePart,
    void Function(String)? onRemoveSubtree,
    void Function(String)? onRemoveSet,
    Widget Function(EquipmentItem)? rowTrailing,
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
            rowTrailing: rowTrailing,
          ),
        ),
      ),
    ),
  );

  testWidgets('set band first, loose gear last, assembly collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    expect(find.text('Winter kit'), findsOneWidget);
    expect(find.text('Cold water reg'), findsOneWidget);
    expect(find.textContaining('1 component'), findsOneWidget);
    expect(find.text('Long hose'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Winter kit')).dy,
      lessThan(tester.getTopLeft(find.text('Cressi mask')).dy),
    );
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

  testWidgets('the arrangement groups each band\'s top-level rows by type', (
    tester,
  ) async {
    await tester.pumpWidget(build(arrangement: EquipmentArrangement.defaults));
    await tester.pumpAndSettle();
    // One header per type per band: Fins and Regulator in the winter band,
    // Mask in the loose band. The hose is a part and gets no header.
    final headers = tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();
    expect(headers, [
      EquipmentType.fins,
      EquipmentType.regulator,
      EquipmentType.mask,
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
    // Only the set header's own button; no per-row close icons.
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
}
