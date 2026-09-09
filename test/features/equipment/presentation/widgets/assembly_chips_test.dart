import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const yoke = EquipmentItem(
    id: 'yoke',
    name: 'Travel reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
  );

  Widget build(String itemId, List<EquipmentComponent> edges) => ProviderScope(
    overrides: [
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.fromRows(edges),
      ),
      activeEquipmentProvider.overrideWith((ref) async => [reg, yoke, hose]),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AssemblyChips(itemId: itemId)),
    ),
  );

  testWidgets('an assembly shows its component count', (tester) async {
    await tester.pumpWidget(
      build('reg', [edge('reg', 'hose'), edge('reg', 'yoke')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 components'), findsOneWidget);
  });

  testWidgets('a part of one assembly names it', (tester) async {
    await tester.pumpWidget(build('hose', [edge('reg', 'hose')]));
    await tester.pumpAndSettle();
    expect(find.text('Part of Cold water reg'), findsOneWidget);
  });

  testWidgets('a part of two assemblies shows the count', (tester) async {
    await tester.pumpWidget(
      build('hose', [edge('reg', 'hose'), edge('yoke', 'hose')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Part of 2 assemblies'), findsOneWidget);
  });

  testWidgets('an unrelated item renders nothing', (tester) async {
    await tester.pumpWidget(build('yoke', [edge('reg', 'hose')]));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
