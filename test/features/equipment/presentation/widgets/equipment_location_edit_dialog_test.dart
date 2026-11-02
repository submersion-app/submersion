import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _RecordingRepository extends Fake implements EquipmentLocationRepository {
  String? createdName;
  String? createdCenterId;
  String? createdBuddyId;
  EquipmentLocationKind? createdKind;
  EquipmentLocation? updated;

  @override
  Future<EquipmentLocation> createLocation({
    required String? diverId,
    required String name,
    required EquipmentLocationKind kind,
    String? diveCenterId,
    String? buddyId,
    String notes = '',
  }) async {
    createdName = name;
    createdKind = kind;
    createdCenterId = diveCenterId;
    createdBuddyId = buddyId;
    return EquipmentLocation(
      id: 'new',
      diverId: diverId,
      name: name,
      kind: kind,
      diveCenterId: diveCenterId,
      buddyId: buddyId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> updateLocation(EquipmentLocation location) async {
    updated = location;
  }
}

void main() {
  final reef = DiveCenter(
    id: 'reef',
    name: 'Blue Reef Divers',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final bay = DiveCenter(
    id: 'bay',
    name: 'Coral Bay',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Buddy buddy(String id, String name) => Buddy(
    id: id,
    name: name,
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final anna = buddy('anna', 'Anna Lindqvist');
  final sam = buddy('sam', 'Sam Okafor');

  EquipmentLocation linked({String? centerId = 'reef'}) => EquipmentLocation(
    id: 'p',
    name: 'Reef locker',
    kind: EquipmentLocationKind.diveCenter,
    diveCenterId: centerId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final centerField = find.byKey(const ValueKey('equipment_location_center'));
  final clearButton = find.byKey(
    const ValueKey('equipment_location_center_clear'),
  );
  final nameField = find.byKey(const ValueKey('equipment_location_name'));

  Future<_RecordingRepository> pumpDialog(
    WidgetTester tester, {
    EquipmentLocation? existing,
  }) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationRepositoryProvider.overrideWithValue(repository),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          equipmentLocationsProvider.overrideWith(
            (ref) async => const <EquipmentLocation>[],
          ),
          allDiveCentersProvider.overrideWith((ref) async => [reef, bay]),
          diveCenterByIdProvider('reef').overrideWith((ref) async => reef),
          diveCenterByIdProvider('bay').overrideWith((ref) async => bay),
          diveCenterByIdProvider('gone').overrideWith((ref) async => null),
          allBuddiesProvider.overrideWith((ref) async => [anna, sam]),
          buddyByIdProvider('anna').overrideWith((ref) async => anna),
          buddyByIdProvider('sam').overrideWith((ref) async => sam),
          buddyByIdProvider('gone').overrideWith((ref) async => null),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showEquipmentLocationEditDialog(
              context,
              ref,
              existing: existing,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> chooseKind(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('equipment_location_kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickReef(WidgetTester tester) async {
    await tester.tap(centerField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Reef Divers').last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('equipment_location_save')));
    await tester.pumpAndSettle();
  }

  testWidgets('the center field shows only for a Dive center place', (
    tester,
  ) async {
    await pumpDialog(tester);
    expect(centerField, findsNothing);

    await chooseKind(tester, 'Dive center');
    expect(centerField, findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('picking a center fills a blank name', (tester) async {
    final repository = await pumpDialog(tester);
    await chooseKind(tester, 'Dive center');
    await pickReef(tester);
    await save(tester);

    expect(repository.createdName, 'Blue Reef Divers');
    expect(repository.createdKind, EquipmentLocationKind.diveCenter);
    expect(repository.createdCenterId, 'reef');
  });

  testWidgets('picking a center leaves a typed name alone', (tester) async {
    final repository = await pumpDialog(tester);
    await tester.enterText(nameField, 'Reef locker');
    await chooseKind(tester, 'Dive center');
    await pickReef(tester);
    await save(tester);

    expect(repository.createdName, 'Reef locker');
    expect(repository.createdCenterId, 'reef');
  });

  testWidgets('re-picking replaces a name the last pick filled in', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);
    await chooseKind(tester, 'Dive center');
    await pickReef(tester);
    await tester.tap(centerField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coral Bay').last);
    await tester.pumpAndSettle();
    await save(tester);

    expect(repository.createdName, 'Coral Bay');
    expect(repository.createdCenterId, 'bay');
  });

  testWidgets('saving a place of another kind keeps a link it already had', (
    tester,
  ) async {
    final repository = await pumpDialog(
      tester,
      existing: linked().copyWith(kind: EquipmentLocationKind.other),
    );

    await save(tester);

    expect(repository.updated!.kind, EquipmentLocationKind.other);
    expect(repository.updated!.diveCenterId, 'reef');
  });

  testWidgets('a pick discarded by changing the kind back is not saved', (
    tester,
  ) async {
    final repository = await pumpDialog(
      tester,
      existing: linked(
        centerId: null,
      ).copyWith(kind: EquipmentLocationKind.storage),
    );

    await chooseKind(tester, 'Dive center');
    await pickReef(tester);
    await chooseKind(tester, 'Storage');
    await save(tester);

    expect(repository.updated!.kind, EquipmentLocationKind.storage);
    expect(repository.updated!.diveCenterId, isNull);
  });

  testWidgets('a Dive center place saves with no center', (tester) async {
    final repository = await pumpDialog(tester);
    await tester.enterText(nameField, 'Island Divers');
    await chooseKind(tester, 'Dive center');
    await save(tester);

    expect(repository.createdKind, EquipmentLocationKind.diveCenter);
    expect(repository.createdCenterId, isNull);
  });

  testWidgets('changing the kind away clears the link on save', (tester) async {
    final repository = await pumpDialog(tester, existing: linked());
    expect(find.text('Blue Reef Divers'), findsOneWidget);

    await chooseKind(tester, 'Storage');
    expect(centerField, findsNothing);
    await save(tester);

    expect(repository.updated!.kind, EquipmentLocationKind.storage);
    expect(repository.updated!.diveCenterId, isNull);
  });

  testWidgets('the clear button removes the link', (tester) async {
    final repository = await pumpDialog(tester, existing: linked());

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
    expect(clearButton, findsNothing);
    await save(tester);

    expect(repository.updated!.kind, EquipmentLocationKind.diveCenter);
    expect(repository.updated!.diveCenterId, isNull);
  });

  testWidgets('a link to a center missing here does not read None', (
    tester,
  ) async {
    await pumpDialog(tester, existing: linked(centerId: 'gone'));

    expect(find.text('None'), findsNothing);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('a link to a center missing here is kept on save', (
    tester,
  ) async {
    final repository = await pumpDialog(
      tester,
      existing: linked(centerId: 'gone'),
    );

    await save(tester);

    expect(repository.updated!.diveCenterId, 'gone');
  });

  group('buddy link (issue #3790)', () {
    final buddyField = find.byKey(const ValueKey('equipment_location_buddy'));
    final clearBuddy = find.byKey(
      const ValueKey('equipment_location_buddy_clear'),
    );

    EquipmentLocation person({String? buddyId = 'anna'}) => EquipmentLocation(
      id: 'p',
      name: 'Anna at home',
      kind: EquipmentLocationKind.person,
      buddyId: buddyId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<void> pick(WidgetTester tester, String name) async {
      await tester.tap(buddyField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the field shows only for a Person place', (tester) async {
      await pumpDialog(tester);
      expect(buddyField, findsNothing);

      await chooseKind(tester, 'Person');
      expect(buddyField, findsOneWidget);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('picking a buddy fills a blank name and saves the link', (
      tester,
    ) async {
      final repository = await pumpDialog(tester);
      await chooseKind(tester, 'Person');
      await pick(tester, 'Anna Lindqvist');
      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'Anna Lindqvist',
      );

      await save(tester);

      expect(repository.createdName, 'Anna Lindqvist');
      expect(repository.createdBuddyId, 'anna');
    });

    testWidgets('picking a buddy leaves a typed name alone', (tester) async {
      final repository = await pumpDialog(tester);
      await tester.enterText(nameField, 'Anna at home');
      await chooseKind(tester, 'Person');
      await pick(tester, 'Anna Lindqvist');
      await save(tester);

      expect(repository.createdName, 'Anna at home');
      expect(repository.createdBuddyId, 'anna');
    });

    testWidgets('re-picking replaces a name the last pick filled in', (
      tester,
    ) async {
      final repository = await pumpDialog(tester);
      await chooseKind(tester, 'Person');
      await pick(tester, 'Anna Lindqvist');
      await pick(tester, 'Sam Okafor');
      await save(tester);

      expect(repository.createdName, 'Sam Okafor');
      expect(repository.createdBuddyId, 'sam');
    });

    testWidgets('a Person place saves with no buddy', (tester) async {
      final repository = await pumpDialog(tester);
      await tester.enterText(nameField, 'A neighbour');
      await chooseKind(tester, 'Person');
      await save(tester);

      expect(repository.createdKind, EquipmentLocationKind.person);
      expect(repository.createdBuddyId, isNull);
    });

    testWidgets('changing the kind away clears the link on save', (
      tester,
    ) async {
      final repository = await pumpDialog(tester, existing: person());

      await chooseKind(tester, 'Storage');
      expect(buddyField, findsNothing);
      await save(tester);

      expect(repository.updated!.kind, EquipmentLocationKind.storage);
      expect(repository.updated!.buddyId, isNull);
    });

    testWidgets('saving a place of another kind keeps a link it already had', (
      tester,
    ) async {
      final repository = await pumpDialog(
        tester,
        existing: person().copyWith(kind: EquipmentLocationKind.other),
      );

      await save(tester);

      expect(repository.updated!.kind, EquipmentLocationKind.other);
      expect(repository.updated!.buddyId, 'anna');
    });

    testWidgets('the clear button removes the link', (tester) async {
      final repository = await pumpDialog(tester, existing: person());
      expect(find.text('Anna Lindqvist'), findsOneWidget);

      await tester.tap(clearBuddy);
      await tester.pumpAndSettle();
      expect(find.text('None'), findsOneWidget);
      await save(tester);

      expect(repository.updated!.buddyId, isNull);
    });

    testWidgets('a link to a buddy missing here does not read None', (
      tester,
    ) async {
      final repository = await pumpDialog(
        tester,
        existing: person(buddyId: 'gone'),
      );

      expect(find.text('None'), findsNothing);
      await tester.tap(clearBuddy);
      await tester.pumpAndSettle();
      expect(find.text('None'), findsOneWidget);
      await save(tester);

      expect(repository.updated!.buddyId, isNull);
    });

    testWidgets('a link to a buddy missing here is kept on save', (
      tester,
    ) async {
      final repository = await pumpDialog(
        tester,
        existing: person(buddyId: 'gone'),
      );

      await save(tester);

      expect(repository.updated!.buddyId, 'gone');
    });
  });
}
