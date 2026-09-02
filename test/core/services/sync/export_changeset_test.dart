import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

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
    'includes only dives with hlc > watermark, plus their profile series',
    () async {
      // Created through the repo so each dive gets a stamped, increasing hlc.
      // Profile points are series-first now (plan 2c): dive_profiles is
      // inbound-only, so a dive's profile is carried as a diveProfileSeries
      // row, which stamps its own hlc after the dive's.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'old', diveNumber: 1).copyWith(
          profile: const [domain.DiveProfilePoint(timestamp: 0, depth: 1.0)],
        ),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'new', diveNumber: 2).copyWith(
          profile: const [domain.DiveProfilePoint(timestamp: 0, depth: 1.0)],
        ),
      );
      final db = DatabaseService.instance.database;

      // The watermark is 'old's series hlc (stamped after 'old's own dive
      // hlc, in the same createDive call), not the dive's own hlc: unlike
      // legacy diveProfiles (a clockless child gathered by its parent's hlc),
      // diveProfileSeries carries its own hlc and is filtered by it directly.
      final oldWatermark =
          (await db
                  .customSelect(
                    "SELECT hlc FROM dive_profile_series WHERE dive_id = 'old'",
                  )
                  .getSingle())
              .read<String>('hlc');

      final serializer = SyncDataSerializer();
      final deviceId = await SyncRepository().getDeviceId();
      final changeset = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: oldWatermark,
        deletions: const [],
      );

      final diveIds = changeset.data.dives.map((d) => d['id']).toSet();
      expect(diveIds.contains('new'), isTrue);
      expect(
        diveIds.contains('old'),
        isFalse,
        reason: 'dive at the watermark must not be re-sent',
      );

      final seriesDiveIds = changeset.data.diveProfileSeries
          .map((p) => p['diveId'])
          .toSet();
      expect(seriesDiveIds.contains('new'), isTrue);
      expect(
        seriesDiveIds.contains('old'),
        isFalse,
        reason: "unchanged dive's profile series must not be re-sent",
      );

      expect(changeset.sinceHlc, oldWatermark);
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
