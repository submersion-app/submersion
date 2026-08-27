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

void main() {
  group('EquipmentEditPage legacy service section', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
      // Tall viewport so the whole (lazy ListView) form materializes into the
      // element tree -- otherwise a mid-form section is simply off-screen and
      // find.text can neither confirm nor deny its presence.
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

    testWidgets('the legacy Service Settings section is gone', (tester) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Old Reg',
          type: EquipmentType.regulator,
          serviceIntervalDays: 180,
          lastServiceDate: DateTime(2024, 1, 1),
        ),
      );
      await pumpEditor(tester, created.id);

      expect(find.text('Service Settings'), findsNothing);
      expect(find.text('Service Interval (days)'), findsNothing);
    });

    testWidgets('saving preserves the frozen legacy interval', (tester) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Old Reg',
          type: EquipmentType.regulator,
          serviceIntervalDays: 180,
          lastServiceDate: DateTime(2024, 1, 1),
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.serviceIntervalDays, 180);
      expect(saved.lastServiceDate, DateTime(2024, 1, 1));
    });
  });
}
