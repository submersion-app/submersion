import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';

/// exportChangeset is the HLC-watermark delta: mutable entities by their own
/// hlc, write-once children gathered by their HLC parent.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'includes only dives with hlc > watermark, plus their profiles',
    () async {
      // Created through the repo so each dive gets a stamped, increasing hlc.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'old', diveNumber: 1),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'new', diveNumber: 2),
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) "
        "VALUES ('p_old', 'old', 0, 1.0)",
      );
      await db.customStatement(
        "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) "
        "VALUES ('p_new', 'new', 0, 1.0)",
      );

      final oldHlc =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'old'")
                  .getSingle())
              .read<String>('hlc');

      final serializer = SyncDataSerializer();
      final deviceId = await SyncRepository().getDeviceId();
      final changeset = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: oldHlc,
        deletions: const [],
      );

      final diveIds = changeset.data.dives.map((d) => d['id']).toSet();
      expect(diveIds.contains('new'), isTrue);
      expect(
        diveIds.contains('old'),
        isFalse,
        reason: 'dive at the watermark must not be re-sent',
      );

      final profileDiveIds = changeset.data.diveProfiles
          .map((p) => p['diveId'])
          .toSet();
      expect(profileDiveIds.contains('new'), isTrue);
      expect(
        profileDiveIds.contains('old'),
        isFalse,
        reason: "unchanged dive's profile must not be re-sent",
      );

      expect(changeset.sinceHlc, oldHlc);
      expect(changeset.toHlc, isNotNull);
    },
  );

  test('null watermark exports everything (degenerate full delta)', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final serializer = SyncDataSerializer();
    final deviceId = await SyncRepository().getDeviceId();
    final changeset = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null,
      deletions: const [],
    );
    expect(
      changeset.data.dives.map((d) => d['id']).toSet().contains('d1'),
      isTrue,
    );
  });
}
