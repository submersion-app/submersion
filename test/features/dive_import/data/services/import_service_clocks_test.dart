import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/import_service_clocks.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../../helpers/test_database.dart';

/// Kinds map by id, then name, then are created; clocks merge by kind with
/// the clocks createEquipment seeds (issue #2651).
void main() {
  late AppDatabase db;
  final kinds = ServiceKindRepository();
  final schedules = ServiceScheduleRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  ServiceKind custom(String id, String name) => ServiceKind(
    id: id,
    diverId: 'd1',
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('only an import naming a kind reads the kind list', () {
    expect(carriesServiceKinds(const [], const [], const []), isFalse);
    expect(
      carriesServiceKinds(
        const [],
        const [
          {'uddfId': 'equip_a', 'serviceSchedules': []},
        ],
        const [
          {'equipmentRef': 'equip_a'},
        ],
      ),
      isFalse,
    );
    expect(
      carriesServiceKinds(
        const [
          {'id': 'k'},
        ],
        const [],
        const [],
      ),
      isTrue,
    );
    expect(
      carriesServiceKinds(const [], const [
        {
          'serviceSchedules': [
            {'kindRef': 'hydro'},
          ],
        },
      ], const []),
      isTrue,
    );
    expect(
      carriesServiceKinds(const [], const [], const [
        {'serviceKindRef': 'hydro'},
      ]),
      isTrue,
    );
  });

  test('a kind maps by id, then by name, else is created for the '
      'diver', () async {
    await kinds.createKind(custom('k-same-id', 'Valve rebuild'));
    await kinds.createKind(custom('k-local', 'Burst Disc'));
    final resolver = await importServiceKinds(
      [
        {'id': 'k-same-id', 'name': 'Renamed elsewhere'},
        {'id': 'k-file', 'name': 'burst disc'},
        {
          'id': 'k-new',
          'name': 'Scooter seals',
          'applicableTypes': ['other'],
          'defaultIntervalDays': 180,
          'exposureIntervals': {'cycles': 40.0},
          'defaultCategory': 'replacement',
          'autoAttach': false,
        },
      ],
      kinds,
      diverId: 'd1',
    );
    expect(resolver.resolve('k-same-id'), 'k-same-id');
    expect(resolver.resolve('k-file'), 'k-local');
    final created = resolver.resolve('k-new')!;
    expect(created, isNot('k-new'));
    final stored = (await kinds.getKindById(created))!;
    expect(stored.diverId, 'd1');
    expect(stored.name, 'Scooter seals');
    expect(stored.applicableTypes, [EquipmentType.other]);
    expect(stored.defaultIntervalDays, 180);
    expect(stored.exposureIntervals, {ExposureUnit.cycles: 40.0});
    expect(stored.defaultCategory, ServiceCategory.replacement);
    // A built-in resolves to itself; an unknown ref to nothing.
    expect(resolver.resolve('hydro'), 'hydro');
    expect(resolver.resolve('nowhere'), isNull);
    expect(resolver.resolve(null), isNull);

    // The same file again creates nothing more.
    final before = (await kinds.getAllKinds(diverId: 'd1')).length;
    await importServiceKinds(
      [
        {'id': 'k-new', 'name': 'Scooter seals'},
      ],
      kinds,
      diverId: 'd1',
    );
    expect((await kinds.getAllKinds(diverId: 'd1')).length, before);
  });

  test('a restored clock replaces the seeded clock of its kind and keeps '
      'its id; a matched duplicate is left alone', () async {
    final repo = EquipmentRepository();
    final created = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'AL80',
        type: EquipmentType.tank,
        diverId: 'd1',
      ),
    );
    final matched = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Old',
        type: EquipmentType.tank,
        diverId: 'd1',
      ),
    );
    final seeded = (await schedules.getSchedulesForEquipment(
      created.id,
    )).singleWhere((s) => s.serviceKindId == 'hydro');
    final matchedBefore = await schedules.getSchedulesForEquipment(matched.id);

    final resolver = await importServiceKinds(const [], kinds, diverId: 'd1');
    final count = await restoreServiceClocks(
      [
        {
          'uddfId': 'equip_a',
          'serviceSchedules': [
            {
              'kindRef': 'hydro',
              'intervalDays': 1095,
              'anchorDate': DateTime(2026, 1, 10),
              'enabled': false,
            },
            {'kindRef': 'o2-clean', 'intervalDays': 365},
            {'kindRef': 'nowhere', 'intervalDays': 1},
          ],
        },
        {
          'uddfId': 'equip_b',
          'serviceSchedules': [
            {'kindRef': 'hydro', 'intervalDays': 1},
          ],
        },
      ],
      {0, 1},
      {'equip_a': created.id, 'equip_b': matched.id},
      {'equip_b': matched.id},
      schedules,
      resolver,
    );
    expect(count, 2);
    final after = await schedules.getSchedulesForEquipment(created.id);
    final hydro = after.where((s) => s.serviceKindId == 'hydro').toList();
    expect(hydro, hasLength(1));
    expect(hydro.single.id, seeded.id);
    expect(hydro.single.intervalDays, 1095);
    expect(hydro.single.anchorDate, DateTime(2026, 1, 10));
    expect(hydro.single.enabled, isFalse);
    expect(
      after.where((s) => s.serviceKindId == 'o2-clean').single.intervalDays,
      365,
    );
    expect(await schedules.getSchedulesForEquipment(matched.id), matchedBefore);
  });
}
