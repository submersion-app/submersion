import 'dart:async';

import 'package:drift/drift.dart' show Value;
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

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(
    WidgetTester tester,
    String? equipmentId, {
    String? initialParentId,
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
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(
              equipmentId: equipmentId,
              embedded: true,
              initialParentId: initialParentId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an O2 cell offers rebreathers as its parent and saves it', (
    tester,
  ) async {
    final unit = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'JJ-CCR',
        type: EquipmentType.rebreather,
      ),
    );
    await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    final cell = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Cell 1', type: EquipmentType.o2Cell),
    );
    await pumpEditor(tester, cell.id);

    expect(find.text('Installed in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('equipment-parent-picker')));
    await tester.pumpAndSettle();
    expect(find.text('JJ-CCR').hitTestable(), findsOneWidget);
    expect(find.text('Apeks').hitTestable(), findsNothing);
    await tester.tap(find.text('JJ-CCR').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getEquipmentById(cell.id))!.parentEquipmentId,
      unit.id,
    );
  });

  testWidgets('a part added from its host starts fitted to it', (tester) async {
    // The children card opens the editor with its host as the parent. The
    // form starts on a type that holds nothing, so the parent has to
    // survive the switch to the cell the diver is adding.
    final unit = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'JJ-CCR',
        type: EquipmentType.rebreather,
      ),
    );
    await pumpEditor(tester, null, initialParentId: unit.id);
    await tester.enterText(find.byType(TextFormField).first, 'Cell 3');
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O2 cell').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final cell = (await repository.getAllEquipment()).singleWhere(
      (e) => e.type == EquipmentType.o2Cell,
    );
    expect(cell.parentEquipmentId, unit.id);
  });

  testWidgets('switching child type drops a parent the new type cannot use', (
    tester,
  ) async {
    final computer = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Perdix', type: EquipmentType.computer),
    );
    final battery = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'AA cell',
        type: EquipmentType.battery,
        parentEquipmentId: computer.id,
      ),
    );
    await pumpEditor(tester, battery.id);

    // A computer cannot hold an O2 cell, so the picker reads "none" after
    // the switch; the stale id must not be written on save.
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O2 cell').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getEquipmentById(battery.id);
    expect(saved!.type, EquipmentType.o2Cell);
    expect(saved.parentEquipmentId, isNull);
  });

  testWidgets('saving while the active list is loading keeps the parent', (
    tester,
  ) async {
    final unit = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'JJ-CCR',
        type: EquipmentType.rebreather,
      ),
    );
    final cell = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell 1',
        type: EquipmentType.o2Cell,
        parentEquipmentId: unit.id,
      ),
    );
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
          // Never resolves: the page saves before the candidates are known.
          activeEquipmentProvider.overrideWith(
            (ref) => Completer<List<EquipmentItem>>().future,
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: cell.id, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getEquipmentById(cell.id))!.parentEquipmentId,
      unit.id,
    );
  });

  testWidgets('a deep-linked parent owned by another diver is not saved', (
    tester,
  ) async {
    // `/equipment/new?parent=<id>` takes any id. While the active list is
    // still loading the page cannot check it against the diver's gear, so
    // the save looks the parent up itself instead of trusting the link.
    final db = DatabaseService.instance.database;
    for (final (id, isDefault) in [('me', true), ('other', false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(isDefault: Value(isDefault)),
          );
    }
    final theirs = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'other',
        name: 'Their CCR',
        type: EquipmentType.rebreather,
      ),
    );
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
          activeEquipmentProvider.overrideWith(
            (ref) => Completer<List<EquipmentItem>>().future,
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(embedded: true, initialParentId: theirs.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cell 1');
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O2 cell').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final cell = (await repository.getAllEquipment()).singleWhere(
      (e) => e.type == EquipmentType.o2Cell,
    );
    expect(cell.diverId, 'me');
    expect(cell.parentEquipmentId, isNull);
  });

  testWidgets('a regulator shows no parent picker', (tester) async {
    final reg = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    await pumpEditor(tester, reg.id);
    expect(find.text('Installed in'), findsNothing);
  });
}
