import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  group('EquipmentEditPage advanced fields', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentRepositoryProvider.overrideWithValue(repository),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('populates existing buoyancy metadata and saves changes', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: '7mm Wetsuit',
          type: EquipmentType.wetsuit,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'buoyancy_kg',
              valueNum: 5.0,
            ),
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'dry_weight_kg',
              valueNum: 2.5,
            ),
          ],
        ),
      );
      await pumpEditor(tester, created.id);

      final buoyancyField = find.byKey(
        const ValueKey('attr-field-buoyancy_kg'),
      );
      final dryWeightField = find.byKey(
        const ValueKey('attr-field-dry_weight_kg'),
      );
      await tester.ensureVisible(buoyancyField);
      await tester.pumpAndSettle();
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);

      await tester.enterText(buoyancyField, '-2.5');
      await tester.ensureVisible(dryWeightField);
      await tester.enterText(dryWeightField, '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, -2.5);
      expect(saved.weightKg, 3.0);
    });

    testWidgets('empty fields save as null', (tester) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Mask',
          type: EquipmentType.mask,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'buoyancy_kg',
              valueNum: 0.2,
            ),
          ],
        ),
      );
      await pumpEditor(tester, created.id);

      final buoyancyField = find.byKey(
        const ValueKey('attr-field-buoyancy_kg'),
      );
      await tester.ensureVisible(buoyancyField);
      await tester.pumpAndSettle();
      await tester.enterText(buoyancyField, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, isNull);
    });
  });
}
