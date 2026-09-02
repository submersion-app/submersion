import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository queue;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  /// Counts runtime builds without constructing a real store. Building the
  /// real runtime is what kicks the drain, attaches the connectivity
  /// subscription, and arms the retry wakeup, so "was it built?" is the whole
  /// question this provider answers.
  ({ProviderContainer container, List<int> builds}) buildContainer({
    required bool attached,
  }) {
    final builds = <int>[];
    final container = ProviderContainer(
      overrides: [
        mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
        mediaStoreAttachedProvider.overrideWith((ref) async => attached),
        mediaStoreRuntimeProvider.overrideWith((ref) async {
          builds.add(builds.length);
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, builds: builds);
  }

  // Issue #1270: nothing in main.dart, app.dart, or startup_page.dart ever
  // reads mediaStoreRuntimeProvider, so a queue left over from a previous
  // session had no trigger at all - the reporter's 196 rows survived every
  // restart untouched.
  test('a device with due work builds the runtime, which drains it', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, hasLength(1));
  });

  // Building the runtime opens the keychain and reads the store marker out of
  // the bucket. That is far too expensive to pay on every launch and resume of
  // a device that has nothing to transfer.
  test('an empty queue does not build the runtime', () async {
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, isEmpty);
  });

  // The attach check is one SharedPreferences read and short-circuits before
  // the queue is even opened, which is why mediaStoreAttachedProvider exists.
  test('a device with no store attached does not build the runtime', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final harness = buildContainer(attached: false);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, isEmpty);
  });

  // A row parked behind markFailed's backoff (up to 25 hours) is not due, so
  // there is nothing for a drain to take. The worker's own wakeup timer owns
  // that case once the runtime exists.
  test('a queue holding only deferred rows does not build the '
      'runtime', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final entry = (await queue.nextPending(DateTime.now()))!;
    await queue.defer(entry.id, DateTime.now().add(const Duration(hours: 25)));
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, isEmpty);
  });

  // Both call sites are fire-and-forget, so an unusable local cache database
  // (StateError, an Error rather than an Exception) must not escape into the
  // zone handler the way the preflight throw did in #942.
  test('a failure resuming transfers is contained, not thrown', () async {
    final container = ProviderContainer(
      overrides: [
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaTransferQueueRepositoryProvider.overrideWith(
          (ref) => MediaTransferQueueRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(mediaTransferResumeProvider)(), completes);
  });
}
