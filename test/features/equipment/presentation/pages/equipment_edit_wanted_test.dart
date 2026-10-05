import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The edit form for wishlist gear (#2025): fields that only make sense for
/// gear in hand are hidden, never cleared.
void main() {
  group('EquipmentEditPage for Wanted gear', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
      // Tall viewport so the whole (lazy ListView) form materializes.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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

    Future<void> pickStatus(WidgetTester tester, String from, String to) async {
      await tester.tap(find.text(from));
      await tester.pumpAndSettle();
      await tester.tap(find.text(to).last);
      await tester.pumpAndSettle();
    }

    testWidgets('a wanted item loads as Wanted, relabelled and trimmed', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Dream Reg',
          type: EquipmentType.regulator,
          status: EquipmentStatus.wanted,
          isActive: false,
          purchasePrice: 899,
        ),
      );
      await pumpEditor(tester, created.id);

      expect(find.text('Wanted'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
      expect(find.text('Expected Price'), findsOneWidget);
      expect(find.text('Purchase Price'), findsNothing);
      expect(find.text('Purchase Date'), findsNothing);
      expect(find.text('Serial Number'), findsNothing);
      expect(find.text('Notifications (Optional)'), findsNothing);
    });

    testWidgets('switching an owned item to Wanted and back keeps its fields', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'My Reg',
          type: EquipmentType.regulator,
          serialNumber: 'SN-42',
          purchaseDate: DateTime(2024, 3, 1),
        ),
      );
      await pumpEditor(tester, created.id);

      await pickStatus(tester, 'Active', 'Wanted');
      expect(find.text('SN-42'), findsNothing);
      await pickStatus(tester, 'Wanted', 'Active');
      expect(find.text('SN-42'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.serialNumber, 'SN-42');
      expect(saved.purchaseDate, DateTime(2024, 3, 1));
      expect(saved.isActive, isTrue);
    });

    testWidgets('saving as Wanted stores isActive=false and keeps hidden '
        'values', (tester) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'My Reg',
          type: EquipmentType.regulator,
          serialNumber: 'SN-42',
          purchaseDate: DateTime(2024, 3, 1),
        ),
      );
      await pumpEditor(tester, created.id);

      await pickStatus(tester, 'Active', 'Wanted');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.status, EquipmentStatus.wanted);
      expect(saved.isActive, isFalse);
      expect(saved.serialNumber, 'SN-42');
      expect(saved.purchaseDate, DateTime(2024, 3, 1));
    });
  });
}
