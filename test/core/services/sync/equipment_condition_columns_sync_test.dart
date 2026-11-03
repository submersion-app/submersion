import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> equipment(String id, {String? parent}) => {
    'id': id,
    'name': id,
    'type': 'o2Cell',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
    'parentEquipmentId': ?parent,
  };

  test(
    'equipment.parentEquipmentId round-trips and tolerates omission',
    () async {
      await serializer.upsertRecord('equipment', equipment('unit'));
      await serializer.upsertRecord(
        'equipment',
        equipment('cell', parent: 'unit'),
      );
      final row = await serializer.fetchRecord('equipment', 'cell');
      expect(row!['parentEquipmentId'], 'unit');

      // An older peer republishes a row without the key: it still applies.
      await serializer.upsertRecord('equipment', equipment('orphan'));
      expect(
        (await serializer.fetchRecord(
          'equipment',
          'orphan',
        ))!['parentEquipmentId'],
        isNull,
      );
    },
  );

  test('service ledger rows carry exposureIntervals', () async {
    final reg = await serializer.fetchRecord(
      'serviceKinds',
      'regulator-service',
    );
    expect(reg!['exposureIntervals'], '{"coldDives":50}');

    await serializer.upsertRecord('equipment', equipment('r1'));
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's1',
      'equipmentId': 'r1',
      'serviceKindId': 'regulator-service',
      'exposureIntervals': '{"coldDives":25.0}',
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    expect(
      (await serializer.fetchRecord(
        'serviceSchedules',
        's1',
      ))!['exposureIntervals'],
      '{"coldDives":25.0}',
    );
  });

  test('dive tanks carry regulatorEquipmentId', () async {
    await serializer.upsertRecord('equipment', equipment('reg'));
    await serializer.upsertRecord('dives', {
      'id': 'd1',
      'diveDateTime': 1000,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('diveTanks', {
      'id': 't1',
      'diveId': 'd1',
      'o2Percent': 32.0,
      'hePercent': 0.0,
      'tankOrder': 0,
      'tankRole': 'backGas',
      'regulatorEquipmentId': 'reg',
    });
    expect(
      (await serializer.fetchRecord(
        'diveTanks',
        't1',
      ))!['regulatorEquipmentId'],
      'reg',
    );
  });

  test('incidents carry equipmentId', () async {
    await serializer.upsertRecord('equipment', equipment('reg'));
    await serializer.upsertRecord('incidents', {
      'id': 'i1',
      'diverId': null,
      'diveId': null,
      'equipmentId': 'reg',
      'occurredAt': 1000,
      'category': 'equipment',
      'severity': 'minor',
      'narrative': 'n',
      'contributingFactors': null,
      'lessonsLearned': null,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    });
    final back = await serializer.fetchRecord('incidents', 'i1');
    expect(back!['equipmentId'], 'reg');
  });

  group('incidents.observationId (v338)', () {
    Map<String, dynamic> incident({String? observationId}) => {
      'id': 'i1',
      'diverId': null,
      'diveId': null,
      'equipmentId': 'reg',
      'observationId': ?observationId,
      'occurredAt': 1000,
      'category': 'equipment',
      'severity': 'minor',
      'narrative': 'n',
      'contributingFactors': null,
      'lessonsLearned': null,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    };

    Future<void> seedCheckIn({String status = 'issue'}) async {
      await serializer.upsertRecord('equipment', equipment('reg'));
      await serializer.upsertRecord('equipmentObservations', {
        'id': 'o1',
        'diverId': null,
        'equipmentId': 'reg',
        'diveId': null,
        'observedAt': 1000,
        'status': status,
        'issueTags': '["freeFlow"]',
        'note': '',
        'createdAt': 1000,
        'updatedAt': 1000,
        'hlc': null,
      });
    }

    test('round-trips and tolerates an older peer omitting it', () async {
      await seedCheckIn();
      await serializer.upsertRecord('incidents', incident(observationId: 'o1'));
      expect(
        (await serializer.fetchRecord('incidents', 'i1'))!['observationId'],
        'o1',
      );

      // An older peer's row without the key applies; the merge overlay is
      // what keeps the local link when that row is an edit of this one.
      await serializer.upsertRecord('incidents', incident());
      expect(await serializer.fetchRecord('incidents', 'i1'), isNotNull);
    });

    group('an apply leaves the stored link alone', () {
      // A peer below v338 never clears the link, and two devices can link and
      // resolve at once, so the rows can name a check-in that cannot stand
      // behind the report. IncidentRepository reads such a link as none. A
      // device that erased it here would keep it erased when the check-in
      // came back as an issue, and part ways with its peers for good.
      test('through a check-in that goes OK and back to an issue', () async {
        await seedCheckIn();
        await serializer.upsertRecord(
          'incidents',
          incident(observationId: 'o1'),
        );

        await seedCheckIn(status: 'ok');
        await serializer.repairDanglingForeignKeys();
        await seedCheckIn();
        await serializer.repairDanglingForeignKeys();

        final back = await serializer.fetchRecord('incidents', 'i1');
        expect(back!['observationId'], 'o1');
        expect(back['updatedAt'], 1000);
      });

      test('when the report moves to another item', () async {
        await seedCheckIn();
        await serializer.upsertRecord('equipment', equipment('bcd'));
        await serializer.upsertRecord('incidents', {
          ...incident(observationId: 'o1'),
          'equipmentId': 'bcd',
        });

        await serializer.repairDanglingForeignKeys();

        final back = await serializer.fetchRecord('incidents', 'i1');
        expect(back!['observationId'], 'o1');
        expect(back['equipmentId'], 'bcd');
      });
    });

    test('a deleted check-in still loses the link in the repair', () async {
      await seedCheckIn();
      await serializer.upsertRecord('incidents', incident(observationId: 'o1'));

      await serializer.applyInDeferredFkTransaction(() async {
        await serializer.deleteRecord('equipmentObservations', 'o1');
        await serializer.repairDanglingForeignKeys();
      });

      final back = await serializer.fetchRecord('incidents', 'i1');
      expect(back, isNotNull);
      expect(back!['observationId'], isNull);
    });

    test('the merge guards the link as a nullable parent', () {
      expect(
        SyncService.parentRefs['incidents'],
        contains((
          field: 'observationId',
          parent: 'equipmentObservations',
          nullable: true,
        )),
      );
    });
  });
}
