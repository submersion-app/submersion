import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late MediaStoresRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaStoresRepository();
  });
  tearDown(tearDownTestDatabase);

  test('stampLastSweep round-trips through the active descriptor', () async {
    await repo.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'dive-media @ minio',
    );
    expect((await repo.getActive())!.lastSweepAt, isNull);

    final sweptAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.utc(2026, 7, 23).millisecondsSinceEpoch,
    );
    await repo.stampLastSweep('store-1', sweptAt);
    final active = await repo.getActive();
    expect(active!.id, 'store-1');
    expect(active.lastSweepAt, sweptAt);
  });

  test('stamping an older store does not make it the active one', () async {
    // The active store is the most recently announced one. A sweep stamp on
    // a store the library moved away from must not bring it back, or every
    // delete gate would read the wrong descriptor.
    await repo.upsertActive(
      storeId: 'old-store',
      providerType: 's3',
      displayHint: 'old',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.upsertActive(
      storeId: 'new-store',
      providerType: 's3',
      displayHint: 'new',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await repo.stampLastSweep('old-store', DateTime.utc(2026, 7, 23));

    expect((await repo.getActive())!.id, 'new-store');
    expect((await repo.getById('old-store'))!.lastSweepAt, isNotNull);
  });
}
