import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
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
            locale: const Locale('en'),
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
        const EquipmentItem(
          id: '',
          name: '7mm Wetsuit',
          type: EquipmentType.wetsuit,
          buoyancyKg: 5.0,
          weightKg: 2.5,
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.scrollUntilVisible(
        find.text('Advanced'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);

      await tester.enterText(find.text('5.0'), '-2.5');
      await tester.enterText(find.text('2.5'), '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, -2.5);
      expect(saved.weightKg, 3.0);
    });

    testWidgets('lift capacity field shows for a BCD and saves', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Wing 18',
          type: EquipmentType.bcd,
          liftCapacityKg: 15.0,
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.scrollUntilVisible(
        find.text('Advanced'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Lift capacity (kg)'), findsOneWidget);
      expect(find.text('15.0'), findsOneWidget);

      await tester.enterText(find.text('15.0'), '18');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.liftCapacityKg, 18.0);
    });

    testWidgets('lift capacity field is hidden for a wetsuit', (tester) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: '5mm Wetsuit',
          type: EquipmentType.wetsuit,
          buoyancyKg: 3.0,
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.scrollUntilVisible(
        find.text('Advanced'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Lift capacity (kg)'), findsNothing);
    });

    testWidgets('empty fields save as null', (tester) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Mask',
          type: EquipmentType.mask,
          buoyancyKg: 0.2,
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.scrollUntilVisible(
        find.text('Advanced'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.text('0.2'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, isNull);
    });
  });
}
