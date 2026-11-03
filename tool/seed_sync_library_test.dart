// A flutter test run as a tool, outside test/: seeds a sync library in an
// S3-compatible store for the browser round trip in
// test/web/sync/s3_round_trip_test.dart (issue #4121).
//
//   flutter test tool/seed_sync_library_test.dart \
//     --dart-define=MINIO_ENDPOINT=http://localhost:9000 \
//     --dart-define=MINIO_BUCKET=submersion-test \
//     --dart-define=MINIO_ACCESS_KEY=minioadmin \
//     --dart-define=MINIO_SECRET_KEY=minioadmin
//
// Skipped, saying so, when MINIO_ENDPOINT is not set. The sync stack needs
// the Flutter binding and the repositories' service locator, which is why
// this is a test rather than a `dart run` script (tool/demo_data does the
// same).
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../test/web/sync/minio_round_trip_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = minioConfigFromEnvironment();

  test(
    'seed two divers, a site, a buddy and five dives, then publish',
    () async {
      // The test binding answers every HTTP request with 400; this tool
      // talks to a real store.
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      DatabaseService.instance.setTestDatabase(db);
      addTearDown(() async {
        DatabaseService.instance.resetForTesting();
        await db.close();
      });

      final now = DateTime.now().toUtc();
      final divers = [
        for (final (index, name) in [
          'Seed Diver One',
          'Seed Diver Two',
        ].indexed)
          await DiverRepository().createDiver(
            Diver(
              id: 'seed-diver-${index + 1}',
              name: name,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      ];
      final site = await SiteRepository().createSite(
        const DiveSite(id: 'seed-site', name: 'Seed Reef'),
      );
      await BuddyRepository().createBuddy(
        Buddy(
          id: 'seed-buddy',
          name: 'Seed Buddy',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final dives = DiveRepository();
      for (final (index, id) in kSeededDiveIds.indexed) {
        final number = index + 1;
        await dives.createDive(
          Dive(
            id: id,
            diverId: divers[number <= 3 ? 0 : 1].id,
            diveNumber: number,
            dateTime: DateTime.utc(2026, 1, number, 9),
            entryTime: DateTime.utc(2026, 1, number, 9),
            exitTime: DateTime.utc(2026, 1, number, 9, 40),
            runtime: const Duration(minutes: 40),
            maxDepth: 18 + number.toDouble(),
            site: site,
            notes: 'Seeded dive $number',
            profile: [
              for (var second = 0; second <= 2400; second += 60)
                DiveProfilePoint(
                  timestamp: second,
                  depth: second < 300
                      ? second / 300 * (18 + number)
                      : second > 2100
                      ? (2400 - second) / 300 * (18 + number)
                      : 18 + number.toDouble(),
                  temperature: 24,
                ),
            ],
          ),
        );
      }

      await SyncRepository().getDeviceId();
      await db.customStatement(
        "UPDATE sync_metadata SET device_id = ? WHERE id = 'global'",
        [kSeedDeviceId],
      );
      final s3 = S3StorageProvider(store: FixedS3CredentialsStore(config!));
      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: s3,
      ).performSync();
      expect(
        result.isSuccess,
        isTrue,
        reason: 'publish failed: ${result.status} (${result.message})',
      );

      final names = [
        for (final file in await s3.listFiles(
          folderId: await s3.getOrCreateSyncFolder(),
          namePattern: ChangesetLogLayout.listPattern,
        ))
          file.name,
      ];
      expect(names, contains(ChangesetLogLayout.manifestName(kSeedDeviceId)));
    },
    skip: config == null ? minioSkipReason : null,
  );
}
