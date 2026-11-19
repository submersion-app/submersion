import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/editing/item_shares_sharing_adapter.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A trip's sharing held in its sitting writes through this adapter (issue
/// #4527, phase 3).
void main() {
  late AppDatabase db;
  late ItemSharesSharingAdapter adapter;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me', 'sam']);
    await seedTrip(db, 'bonaire', owner: 'me');
    adapter = ItemSharesSharingAdapter(
      ItemSharesRepository(),
      SharedItemKind.trip,
    );
  });

  tearDown(tearDownTestDatabase);

  test('the owner shares, and the sharing reads back', () async {
    const sharing = ItemSharing(profileIds: {'sam'});

    final done = await adapter.write('bonaire', sharing, actingDiverId: 'me');

    expect(done, isTrue);
    expect(await adapter.read('bonaire'), sharing);
  });

  test('another profile is refused and changes nothing', () async {
    final done = await adapter.write(
      'bonaire',
      const ItemSharing(profileIds: {'sam'}),
      actingDiverId: 'sam',
    );

    expect(done, isFalse);
    expect(await adapter.read('bonaire'), ItemSharing.none);
  });

  test('rows stored beside Everyone need a rewrite, until one', () async {
    await adapter.write(
      'bonaire',
      const ItemSharing(profileIds: {'sam'}),
      actingDiverId: 'me',
    );
    expect(await adapter.needsRewrite('bonaire'), isFalse);
    // A sync race: the flag arrives while the row for Sam stays.
    await db.customStatement(
      "UPDATE trips SET is_shared = 1 WHERE id = 'bonaire'",
    );
    expect(await adapter.needsRewrite('bonaire'), isTrue);

    await adapter.write('bonaire', ItemSharing.all, actingDiverId: 'me');

    expect(await adapter.needsRewrite('bonaire'), isFalse);
  });
}
