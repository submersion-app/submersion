import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Who sold a gear item (v397, issue #5140) in sync: the links travel with
/// the equipment row, an older peer's row leaves them alone, and a seller
/// tombstoned elsewhere clears the link without dropping the item.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  Map<String, dynamic> item({Object? buddy = 'keep', int updatedAt = 2}) => {
    'id': 'reg',
    'name': 'Reg',
    'type': 'regulator',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1,
    'updatedAt': updatedAt,
    'hlc': null,
    if (buddy != 'keep') 'sellerBuddyId': buddy,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'anna',
            name: 'Anna',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await serializer.upsertRecord('equipment', item(buddy: 'anna'));
  });
  tearDown(tearDownTestDatabase);

  Future<String?> sellerOf() async =>
      (await serializer.fetchRecord('equipment', 'reg'))?['sellerBuddyId']
          as String?;

  test('a pulled row carries the seller link', () async {
    expect(await sellerOf(), 'anna');
  });

  test('an explicit null unlinks', () async {
    await serializer.upsertRecord('equipment', item(buddy: null));
    expect(await sellerOf(), isNull);
  });

  test('a row from a peer before v397 keeps the local link', () async {
    await serializer.upsertRecords('equipment', [item(updatedAt: 3)]);
    expect(await sellerOf(), 'anna');
  });

  test('a tombstoned seller clears the link, not the item', () {
    final refs = SyncService.parentRefs['equipment'];
    expect(
      refs,
      contains((field: 'sellerBuddyId', parent: 'buddies', nullable: true)),
    );
    expect(
      refs,
      contains((
        field: 'sellerDiveCenterId',
        parent: 'diveCenters',
        nullable: true,
      )),
    );
  });
}
