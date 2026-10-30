import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('the Git provider type round-trips', () async {
    final repo = SyncRepository();
    await repo.getOrCreateMetadata();
    await repo.setCloudProvider(CloudProviderType.git);
    expect(await repo.getCloudProvider(), CloudProviderType.git);
  });

  test(
    'a stored provider name this build does not know reads as none',
    () async {
      // A newer build (or a corrupt row) left a name this one has no enum value
      // for. It must not silently redirect sync to another backend.
      final repo = SyncRepository();
      await repo.getOrCreateMetadata();
      final db = DatabaseService.instance.database;
      await (db.update(db.syncMetadata)..where((t) => t.id.equals('global')))
          .write(const SyncMetadataCompanion(syncProvider: Value('nonsense')));
      expect(await repo.getCloudProvider(), isNull);
    },
  );
}
