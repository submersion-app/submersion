import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/presentation/providers/gallery_origin_backfill_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// The gallery origin backfill stamps rows, which bumps their clocks and
/// republishes them. A sync that overlapped it could publish or merge in the
/// middle of that, so it has to run inside the sync's single flight.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  test('a sync stays in flight until the gallery backfill finishes', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var runs = 0;
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          FakeCloudStorageProvider(),
        ),
        galleryOriginBackfillProvider.overrideWithValue(() {
          runs++;
          if (!started.isCompleted) started.complete();
          return release.future;
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(syncStateProvider.notifier);
    await notifier.refreshState();

    final sync = notifier.performSync();
    await started.future;

    // Past the success path's own settle delay (2s), so a sync that only
    // started the backfill has long since returned and released the flight.
    final finishedFirst = await Future.any([
      sync.then((_) => true),
      Future<bool>.delayed(const Duration(seconds: 3), () => false),
    ]);
    expect(finishedFirst, isFalse, reason: 'the backfill is part of the sync');

    // A second trigger while the backfill runs is turned away.
    await notifier.performSync();
    expect(runs, 1);

    release.complete();
    await sync;
    expect(container.read(syncStateProvider).lastSync, isNotNull);
  });

  // Awaiting the backfill is a new pause inside performSync, and the
  // notifier can be disposed during it (app teardown, a container rebuilt).
  // Reading state afterwards throws on a disposed notifier.
  test('a notifier disposed during the backfill finishes quietly', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          FakeCloudStorageProvider(),
        ),
        galleryOriginBackfillProvider.overrideWithValue(() {
          if (!started.isCompleted) started.complete();
          return release.future;
        }),
      ],
    );
    final notifier = container.read(syncStateProvider.notifier);
    await notifier.refreshState();

    final sync = notifier.performSync();
    await started.future;
    container.dispose();
    release.complete();

    await expectLater(sync, completes);
  });
}
