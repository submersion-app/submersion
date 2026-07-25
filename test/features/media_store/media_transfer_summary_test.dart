import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('watchSummary splits in-flight, due, and deferred work', () async {
    final now = DateTime.now();
    final inFlight = await repo.enqueueUpload(mediaId: 'in-flight');
    await repo.enqueueUpload(mediaId: 'due');
    final deferred = await repo.enqueueUpload(mediaId: 'deferred');
    await repo.markTransferring(inFlight);
    await repo.defer(deferred, now.add(const Duration(hours: 25)));

    final summary = await repo.watchSummary().first;
    expect(summary.transferring, 1);
    expect(summary.queued, 1);
    expect(summary.waiting, 1);
  });

  // The reported bug: four rows parked in the 25h source-unavailable backoff
  // read as active work, so the settings page spun an indeterminate progress
  // bar for a day with an idle worker. A backed-off row is 'pending' in the
  // table but nextPending refuses to select it, so it must never count as
  // in-flight.
  test('a row in retry backoff is waiting, never transferring', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markFailed(
      id,
      'source unavailable on this device',
      retryAfter: const Duration(hours: 25),
    );

    final summary = await repo.watchSummary().first;
    expect(summary.transferring, 0);
    expect(summary.queued, 0);
    expect(summary.waiting, 1);
    expect(summary.waitingReason, 'source unavailable on this device');
    expect(summary.isBusy, isFalse);
  });

  test(
    'waitingReason is the newest failure among several parked rows',
    () async {
      final older = await repo.enqueueUpload(mediaId: 'older');
      await repo.markFailed(
        older,
        'older failure',
        retryAfter: const Duration(hours: 25),
      );
      // markFailed stamps updatedAt from the wall clock; two calls can land in
      // the same millisecond, so force a distinct tick.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final newer = await repo.enqueueUpload(mediaId: 'newer');
      await repo.markFailed(
        newer,
        'newer failure',
        retryAfter: const Duration(hours: 25),
      );
      // Parked with no error at all: the newest row overall, and still not a
      // reason. A policy deferral consumes no attempt and records nothing.
      final quiet = await repo.enqueueUpload(mediaId: 'quiet');
      await repo.defer(quiet, DateTime.now().add(const Duration(hours: 25)));

      final summary = await repo.watchSummary().first;
      expect(summary.waiting, 3);
      expect(summary.waitingReason, 'newer failure');
    },
  );

  test('terminal and completed rows are excluded entirely', () async {
    final done = await repo.enqueueUpload(mediaId: 'done');
    await repo.markDone(done);
    final failed = await repo.enqueueUpload(mediaId: 'failed');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(failed, 'boom');
    }

    final summary = await repo.watchSummary().first;
    expect(summary.isEmpty, isTrue);
    expect(summary.total, 0);
  });

  test('summary re-emits as rows change state', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final emissions = <MediaTransferSummary>[];
    final sub = repo.watchSummary().listen(emissions.add);
    await pumpEventQueue();
    await repo.markTransferring(id);
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.first.queued, 1);
    expect(emissions.last.transferring, 1);
    expect(emissions.last.queued, 0);
  });

  test(
    'earliestPendingWakeup returns the soonest future retry, skipping due rows',
    () async {
      final now = DateTime.now();
      await repo.enqueueUpload(mediaId: 'due-now');
      final soon = await repo.enqueueUpload(mediaId: 'soon');
      final later = await repo.enqueueUpload(mediaId: 'later');
      await repo.defer(soon, now.add(const Duration(minutes: 10)));
      await repo.defer(later, now.add(const Duration(hours: 25)));

      final wakeup = await repo.earliestPendingWakeup(now);
      expect(wakeup, isNotNull);
      expect(
        wakeup!.millisecondsSinceEpoch,
        now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
    },
  );

  test('earliestPendingWakeup is null when nothing is deferred', () async {
    await repo.enqueueUpload(mediaId: 'm1');
    expect(await repo.earliestPendingWakeup(DateTime.now()), isNull);
  });

  test('earliestPendingWakeup ignores non-pending rows', () async {
    final now = DateTime.now();
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.defer(id, now.add(const Duration(hours: 1)));
    await repo.markTransferring(id);
    expect(await repo.earliestPendingWakeup(now), isNull);
  });
}
