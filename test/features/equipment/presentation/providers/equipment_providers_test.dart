import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

EquipmentItem _makeEquipment({
  String id = '',
  String name = 'Test Reg',
  EquipmentType type = EquipmentType.regulator,
  String? diverId,
  DateTime? lastServiceDate,
  int? serviceIntervalDays,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    type: type,
    diverId: diverId,
    lastServiceDate: lastServiceDate,
    serviceIntervalDays: serviceIntervalDays,
  );
}

void main() {
  late SharedPreferences prefs;
  late EquipmentRepository equipmentRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    equipmentRepo = EquipmentRepository();
    diverRepo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<Diver> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  group('allEquipmentProvider', () {
    test('auto-refreshes after equipment is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // An active listener keeps the provider (and its equipment table-change
      // subscription) alive, mirroring a widget that watches the list.
      final sub = container.listen(allEquipmentProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allEquipmentProvider.future), isEmpty);

      // A sync applies remote equipment straight to the DB (no notifier
      // mutation). The watchEquipmentChanges tick must invalidate the
      // provider so the new row surfaces.
      await equipmentRepo.createEquipment(
        _makeEquipment(name: 'Synced Reg', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allEquipmentProvider.future,
        )).map((e) => e.name).toList();
        if (names.contains('Synced Reg')) break;
      }

      expect(
        names,
        contains('Synced Reg'),
        reason:
            'allEquipmentProvider should auto-refresh after a direct table '
            'write without any manual invalidation',
      );
    });
  });

  group('equipmentByStatusProvider(null)', () {
    test('auto-refreshes after equipment is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // Keep the (null status = all equipment) family provider alive so its
      // equipment table-change subscription stays open.
      final sub = container.listen(equipmentByStatusProvider(null), (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(equipmentByStatusProvider(null).future),
        isEmpty,
      );

      await equipmentRepo.createEquipment(
        _makeEquipment(name: 'Synced Mask', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          equipmentByStatusProvider(null).future,
        )).map((e) => e.name).toList();
        if (names.contains('Synced Mask')) break;
      }

      expect(
        names,
        contains('Synced Mask'),
        reason:
            'equipmentByStatusProvider(null) should auto-refresh after a '
            'direct table write without any manual invalidation',
      );
    });
  });

  group('serviceDueEquipmentProvider', () {
    test(
      'auto-refreshes after service-due equipment is written directly to the '
      'DB (sync scenario)',
      () async {
        final diver = await seedCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);

        // Keep the provider alive so its equipment table-change subscription
        // stays open.
        final sub = container.listen(serviceDueEquipmentProvider, (_, _) {});
        addTearDown(sub.close);

        expect(
          await container.read(serviceDueEquipmentProvider.future),
          isEmpty,
        );

        // A synced item serviced long ago with a short interval is overdue, so
        // it lands in the service-due list once the tick fires.
        await equipmentRepo.createEquipment(
          _makeEquipment(
            name: 'Overdue Reg',
            diverId: diver.id,
            lastServiceDate: DateTime(2020),
            serviceIntervalDays: 30,
          ),
        );

        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            serviceDueEquipmentProvider.future,
          )).map((e) => e.name).toList();
          if (names.contains('Overdue Reg')) break;
        }

        expect(
          names,
          contains('Overdue Reg'),
          reason:
              'serviceDueEquipmentProvider should auto-refresh after a direct '
              'table write without any manual invalidation',
        );
      },
    );
  });
}
