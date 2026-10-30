import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A dive computer's or transmitter's item keeps its type (issue #3676), and
/// "add by hand" from either list starts the form on that type.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? equipmentId,
    EquipmentType? initialType,
    String? initialSerial,
    List<dynamic> extra = const [],
  }) async {
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
          equipmentRepositoryProvider.overrideWithValue(EquipmentRepository()),
          ...extra,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(
              equipmentId: equipmentId,
              initialType: initialType,
              initialSerial: initialSerial,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DropdownButton<EquipmentType> dropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<EquipmentType>>(
        find.byType(DropdownButton<EquipmentType>),
      );

  testWidgets('the type field is locked for an item with a computer', (
    tester,
  ) async {
    late String gearId;
    await tester.runAsync(() async {
      final gear = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Teric',
          type: EquipmentType.computer,
        ),
      );
      gearId = gear.id;
      final db = DatabaseService.instance.database;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'c1',
              name: 'Teric',
              equipmentId: Value(gear.id),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    });

    await pumpEditor(tester, equipmentId: gearId);

    expect(dropdown(tester).onChanged, isNull);
  });

  testWidgets('an item with no device keeps its type editable', (tester) async {
    late String gearId;
    await tester.runAsync(() async {
      final gear = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Teric',
          type: EquipmentType.computer,
        ),
      );
      gearId = gear.id;
    });

    await pumpEditor(tester, equipmentId: gearId);

    expect(dropdown(tester).onChanged, isNotNull);
  });

  testWidgets('?type=transmitter starts the form on Transmitter', (
    tester,
  ) async {
    await pumpEditor(tester, initialType: EquipmentType.transmitter);

    expect(dropdown(tester).value, EquipmentType.transmitter);
  });

  testWidgets('the type field stays locked while the device lookup loads '
      '(review)', (tester) async {
    late String gearId;
    await tester.runAsync(() async {
      final gear = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Teric',
          type: EquipmentType.computer,
        ),
      );
      gearId = gear.id;
    });
    final never = Completer<bool>();

    await pumpEditor(
      tester,
      equipmentId: gearId,
      extra: [
        equipmentHasDeviceProvider(gearId).overrideWith((ref) => never.future),
      ],
    );

    expect(dropdown(tester).onChanged, isNull);
  });

  testWidgets('a serial handed over starts in the serial field (review)', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialType: EquipmentType.transmitter,
      initialSerial: '4A21F',
    );

    expect(find.widgetWithText(TextFormField, '4A21F'), findsOneWidget);
  });
}
