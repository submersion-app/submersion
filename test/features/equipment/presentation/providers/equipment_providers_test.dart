import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
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
  DateTime? purchaseDate,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    type: type,
    diverId: diverId,
    lastServiceDate: lastServiceDate,
    serviceIntervalDays: serviceIntervalDays,
    purchaseDate: purchaseDate,
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
        final sub = container.listen(
          serviceDueEquipmentProvider(ServiceDueFilter.any),
          (_, _) {},
        );
        addTearDown(sub.close);

        expect(
          await container.read(
            serviceDueEquipmentProvider(ServiceDueFilter.any).future,
          ),
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
            serviceDueEquipmentProvider(ServiceDueFilter.any).future,
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

    test('includes gear whose service-ledger clock is overdue, with no legacy '
        'interval column set', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // A regulator bought years ago and never serviced. createEquipment
      // auto-attaches the built-in 365-day regulator-service clock, which
      // anchors on the purchase date, so the clock is long overdue. The
      // legacy serviceIntervalDays column is null -- no in-app surface has
      // written it since the service ledger landed (DB v122/v131).
      await equipmentRepo.createEquipment(
        _makeEquipment(
          name: 'Neglected Reg',
          diverId: diver.id,
          purchaseDate: DateTime(2020),
        ),
      );

      final names = (await container.read(
        serviceDueEquipmentProvider(ServiceDueFilter.any).future,
      )).map((e) => e.name).toList();

      expect(
        names,
        contains('Neglected Reg'),
        reason:
            'The Service Due filter must read the service ledger; the '
            'legacy single-clock columns are no longer written',
      );
    });

    test('a lapsed clock lands under overdue and not under due soon', () async {
      // End to end against the real ledger: the severity the list buckets on
      // has to be the one the engine actually computed, or the home chip's
      // count and the list's row count part company.
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      await equipmentRepo.createEquipment(
        _makeEquipment(
          name: 'Neglected Reg',
          diverId: diver.id,
          purchaseDate: DateTime(2020),
        ),
      );

      expect(
        (await container.read(
          serviceDueEquipmentProvider(ServiceDueFilter.overdue).future,
        )).map((e) => e.name),
        contains('Neglected Reg'),
      );
      expect(
        await container.read(
          serviceDueEquipmentProvider(ServiceDueFilter.dueSoon).future,
        ),
        isEmpty,
      );
    });

    test('drops an item once its overdue clock is serviced', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      final reg = await equipmentRepo.createEquipment(
        _makeEquipment(
          name: 'Serviced Reg',
          diverId: diver.id,
          purchaseDate: DateTime(2020),
        ),
      );

      expect(
        (await container.read(
          serviceDueEquipmentProvider(ServiceDueFilter.any).future,
        )).map((e) => e.name),
        contains('Serviced Reg'),
      );

      // Logging the service resets that clock's anchor, so the item must
      // leave the list the notifier's refresh feeds.
      final now = DateTime.now();
      await container
          .read(serviceRecordNotifierProvider(reg.id).notifier)
          .addRecord(
            ServiceRecord(
              id: '',
              equipmentId: reg.id,
              serviceCategory: ServiceCategory.annual,
              serviceKindId: 'regulator-service',
              serviceDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        await container.read(
          serviceDueEquipmentProvider(ServiceDueFilter.any).future,
        ),
        isEmpty,
      );
    });

    test('excludes gear whose ledger clocks are all still ok', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      await equipmentRepo.createEquipment(
        _makeEquipment(
          name: 'Fresh Reg',
          diverId: diver.id,
          purchaseDate: DateTime.now(),
        ),
      );

      expect(
        await container.read(
          serviceDueEquipmentProvider(ServiceDueFilter.any).future,
        ),
        isEmpty,
      );
    });
  });
}
