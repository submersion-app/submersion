import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #3662: a peer still below v317 sends a tank's inspection dates
/// with VIP and hydro clocks that never took them. Every batch apply ends
/// in [SyncDataSerializer.repairDanglingForeignKeys], which runs the v317
/// backfill again so this device converges on the rows it receives.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  const hydroMs = 1780000000000;
  const savedAt = 1795000000000;

  Future<void> receiveOlderPeerTank() async {
    await serializer.upsertRecord('equipment', {
      'id': 't1',
      'name': 'AL80',
      'type': 'tank',
      'status': 'active',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 2000,
    });
    await serializer.upsertRecord('equipmentAttributes', {
      'id': 'attr_t1_last_hydro_test',
      'equipmentId': 't1',
      'attrKey': 'last_hydro_test',
      'isCustom': false,
      'valueNum': hydroMs.toDouble(),
      'sortOrder': 0,
      'createdAt': savedAt,
      'updatedAt': savedAt,
    });
    await serializer.upsertRecord('serviceSchedules', {
      'id': 'auto-hydro-t1',
      'equipmentId': 't1',
      'serviceKindId': 'hydro',
      'exposureIntervals': '{}',
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 2000,
    });
  }

  Future<int?> hydroAnchor() async =>
      (await db
              .customSelect(
                "SELECT anchor_date FROM service_schedules WHERE id = 'auto-hydro-t1'",
              )
              .getSingle())
          .read<int?>('anchor_date');

  test('anchors a received tank clock from its inspection date', () async {
    await receiveOlderPeerTank();
    expect(await hydroAnchor(), isNull);

    await serializer.repairDanglingForeignKeys();

    expect(await hydroAnchor(), hydroMs);
  });

  test('leaves a received clock whose service is logged', () async {
    await receiveOlderPeerTank();
    await serializer.upsertRecord('serviceRecords', {
      'id': 'r1',
      'equipmentId': 't1',
      'serviceCategory': 'inspection',
      'serviceKindId': 'hydro',
      'serviceDate': 1700000000000,
      'currency': 'USD',
      'notes': '',
      'createdAt': 1000,
      'updatedAt': 2000,
    });

    await serializer.repairDanglingForeignKeys();

    expect(await hydroAnchor(), isNull);
  });
}
