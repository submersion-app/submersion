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
}
