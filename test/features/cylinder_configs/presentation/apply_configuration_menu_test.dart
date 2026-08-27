import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_menu.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);

  CylinderConfig config({
    required String id,
    required String name,
    String? equipmentId,
  }) => CylinderConfig(
    id: id,
    name: name,
    equipmentId: equipmentId,
    createdAt: now,
    updatedAt: now,
  );

  const unit = EquipmentItem(
    id: 'rb-1',
    name: 'JJ-CCR',
    type: EquipmentType.rebreather,
  );

  Widget host({
    required List<CylinderConfig> configs,
    ValueChanged<CylinderConfig>? onSelected,
  }) => ProviderScope(
    overrides: [
      cylinderConfigsProvider.overrideWith((ref) async => configs),
      allEquipmentProvider.overrideWith((ref) async => [unit]),
    ],
    child: MaterialApp(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ApplyConfigurationMenu(onSelected: onSelected ?? (_) {}),
      ),
    ),
  );

  testWidgets('the menu is hidden when the diver has no configurations', (
    tester,
  ) async {
    await tester.pumpWidget(host(configs: const []));
    await tester.pumpAndSettle();

    expect(find.text('Apply configuration'), findsNothing);
  });

  testWidgets('configs are grouped by owning unit with a Gas plans section', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        configs: [
          config(id: 'c1', name: 'JJ trimix', equipmentId: 'rb-1'),
          config(id: 'c2', name: 'Doubles + 50'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply configuration'));
    await tester.pumpAndSettle();

    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.text('JJ trimix'), findsOneWidget);
    expect(find.text('Gas plans'), findsOneWidget);
    expect(find.text('Doubles + 50'), findsOneWidget);
  });

  testWidgets('choosing a configuration reports it to the caller', (
    tester,
  ) async {
    CylinderConfig? chosen;
    await tester.pumpWidget(
      host(
        configs: [config(id: 'c1', name: 'JJ trimix', equipmentId: 'rb-1')],
        onSelected: (c) => chosen = c,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JJ trimix'));
    await tester.pumpAndSettle();

    expect(chosen?.id, 'c1');
  });

  testWidgets('a generic-only list shows no unit header', (tester) async {
    await tester.pumpWidget(
      host(
        configs: [config(id: 'c1', name: 'Doubles + 50')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply configuration'));
    await tester.pumpAndSettle();

    expect(find.text('Gas plans'), findsOneWidget);
    expect(find.text('JJ-CCR'), findsNothing);
  });
}
