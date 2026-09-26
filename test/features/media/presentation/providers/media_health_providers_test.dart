import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/sync/peer_device_name_store.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';

/// The reporter names a foreign row from [PeerDeviceNameStore] directly.
/// Reading the asynchronous name stream instead would have been wrong on the
/// two entry points that build a report without ever showing a label: the
/// Media Storage page and the debug log export both start the report before
/// anything has subscribed to the stream, so its value is still loading and
/// every foreign row would come out unnamed.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late ProviderContainer container;

  const peerId = 'peer-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PeerDeviceNameStore.prefsKey: jsonEncode({peerId: "Eric's MacBook"}),
    });
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    LocalCacheDatabaseService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await cacheDb.close();
    await db.close();
  });

  MediaItem foreignRow() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: '/nowhere/reef.jpg',
    originDeviceId: peerId,
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  test(
    'a foreign row is named without the name stream being started',
    () async {
      final report = await container
          .read(mediaHealthReporterProvider)
          .forItem(foreignRow());

      expect(report.rows.single.originDeviceId, peerId);
      expect(report.rows.single.originDeviceName, "Eric's MacBook");
      expect(
        container.exists(peerDeviceNamesProvider),
        isFalse,
        reason: 'the report must not depend on the stream having been started',
      );
    },
  );

  test('a name the store does not hold stays null', () async {
    final report = await container
        .read(mediaHealthReporterProvider)
        .forItem(foreignRow().copyWith(originDeviceId: 'peer-unknown'));

    expect(report.rows.single.originDeviceName, isNull);
  });
}
