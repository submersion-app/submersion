import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_coordinator.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';

VerifyLibraryReport _report({
  int total = 100,
  int reclaimable = 0,
  int reclaimed = 0,
  int removed = 0,
  int waiting = 0,
  bool deferred = false,
  bool sizesUnknown = false,
}) => VerifyLibraryReport(
  objectsChecked: 1,
  originalsChecked: 1,
  thumbsChecked: 0,
  renditionsChecked: 0,
  orphansRemoved: removed,
  bytesReclaimed: reclaimed,
  sessionsAborted: 0,
  repairsQueued: 0,
  totalBytes: total,
  reclaimableBytes: reclaimable,
  waitingBytes: waiting,
  deferred: deferred,
  sizesUnknown: sizesUnknown,
);

/// Records every call the coordinator makes, with scripted answers.
class _Harness {
  _Harness(this.store);

  final StorageGcStore store;
  DateTime now = DateTime(2026, 10, 17, 12);
  NetworkKind network = NetworkKind.unmetered;
  bool syncBusy = false;
  bool transferring = false;
  bool fleetDue = true;
  bool hasMediaStore = true;
  bool deletesAllowed = true;
  bool storeRegistered = true;
  String? storeId = 'store-a';
  Object? mediaError;
  VerifyLibraryReport mediaReport = _report();
  int syncBytes = 30;
  bool syncPartial = false;
  ({int bytes, bool partial})? libraries = (bytes: 4, partial: false);
  bool failFirstSweep = false;

  final deviceRuns = <bool>[]; // dryRun flag per call of the first sweep
  final secondSweepRuns = <bool>[];
  var localCacheRuns = 0;
  final localCacheForced = <bool>[];
  final mediaRuns = <bool>[]; // dryRun flag per media sweep
  var fleetStamps = 0;
  Completer<void>? holdFirstSweep;
  Completer<void>? holdSyncMeasure;
  Completer<void>? holdMediaSweep;

  StorageGcCoordinator build() => StorageGcCoordinator(
    deviceSweeps: [
      ({required now, required dryRun}) async {
        deviceRuns.add(dryRun);
        await holdFirstSweep?.future;
        if (failFirstSweep) throw StateError('boom');
        return const ScratchSweepReport(filesDeleted: 2, bytesReclaimed: 200);
      },
      ({required now, required dryRun}) async {
        secondSweepRuns.add(dryRun);
        return const ScratchSweepReport(filesDeleted: 1, bytesReclaimed: 50);
      },
    ],
    localCacheSweep: (now, {required force}) async {
      localCacheRuns++;
      localCacheForced.add(force);
    },
    network: () async => network,
    isSyncBusy: () => syncBusy,
    hasTransferringUploads: () async => transferring,
    mediaSweep: ({required dryRun}) async {
      mediaRuns.add(dryRun);
      await holdMediaSweep?.future;
      final error = mediaError;
      if (error != null) throw error;
      return hasMediaStore ? mediaReport : null;
    },
    deletesAllowed: () async => deletesAllowed,
    isStoreRegistered: () async => storeRegistered,
    attachedStoreId: () async => storeId,
    fleetSweepDue: (now) async => fleetDue,
    stampFleetSweep: (now) async => fleetStamps++,
    measureSync: () async {
      await holdSyncMeasure?.future;
      return (bytes: syncBytes, partial: syncPartial);
    },
    measureLibraries: () async => libraries,
    store: store,
    now: () => now,
  );
}

void main() {
  late _Harness h;
  late StorageGcCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = _Harness(StorageGcStore(await SharedPreferences.getInstance()));
    coordinator = h.build();
  });

  test('launch runs device sweeps once a day', () async {
    await coordinator.run(StorageGcTrigger.launch);
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.deviceRuns, [false], reason: 'second launch the same day skips');
    expect(h.localCacheRuns, 1);

    h.now = h.now.add(const Duration(days: 1));
    await coordinator.run(StorageGcTrigger.resume);
    expect(h.deviceRuns, [false, false]);
  });

  test(
    'manual runs device and cloud regardless of cadence and network',
    () async {
      await coordinator.run(StorageGcTrigger.launch);
      h.network = NetworkKind.cellular;
      h.fleetDue = false;

      await coordinator.run(StorageGcTrigger.manual);

      expect(h.deviceRuns, [false, false]);
      expect(h.mediaRuns.last, isFalse, reason: 'manual deletes');
    },
  );

  test('automatic cloud waits for an unmetered network', () async {
    h.network = NetworkKind.cellular;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, isEmpty);
    expect(h.deviceRuns, [false], reason: 'the device part still runs');
  });

  test('nothing in the cloud runs offline, even on request', () async {
    h.network = NetworkKind.offline;
    await coordinator.run(StorageGcTrigger.manual);
    expect(h.mediaRuns, isEmpty);
  });

  test(
    'cloud deletes wait while a sync is running; Reclaim still measures',
    () async {
      h.syncBusy = true;
      await coordinator.run(StorageGcTrigger.manual);
      expect(h.mediaRuns, [true], reason: 'a dry run writes nothing');
      expect(h.fleetStamps, 0);
      expect(h.deviceRuns, [false]);
    },
  );

  test('automatic cloud work skips while a sync is running', () async {
    h.syncBusy = true;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, isEmpty);
  });

  test('rescan measures while a sync is running', () async {
    h.syncBusy = true;
    await coordinator.run(StorageGcTrigger.rescan);
    expect(h.mediaRuns, [true]);
    expect(h.store.cloudUsage, isNotNull);
  });

  test('no deleting sweep while the policy would defer', () async {
    // Listing the whole store to delete nothing, hourly after a restore,
    // costs time and data for no result.
    h.deletesAllowed = false;
    h.fleetDue = true;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, [true], reason: 'measurement only, as it was due');
    expect(h.fleetStamps, 0);
  });

  test('cloud deletes wait while an upload is transferring', () async {
    h.transferring = true;
    await coordinator.run(StorageGcTrigger.manual);
    expect(h.mediaRuns, [true], reason: 'measures instead of deleting');
  });

  test('rescan measures without deleting', () async {
    h.network = NetworkKind.cellular;
    await coordinator.run(StorageGcTrigger.rescan);

    expect(h.mediaRuns, [true]);
    expect(h.deviceRuns, isEmpty, reason: 'rescan is cloud only');
    final usage = h.store.cloudUsage!;
    expect(usage.mediaBytes, 100);
    expect(usage.syncBytes, 30);
    expect(usage.librariesBytes, 4);
    expect(usage.scannedAt, h.now);
  });

  test('an automatic delete run stamps the fleet and records usage', () async {
    h.mediaReport = _report(
      total: 100,
      reclaimable: 40,
      reclaimed: 40,
      removed: 4,
      waiting: 7,
    );
    await coordinator.run(StorageGcTrigger.launch);

    expect(h.mediaRuns, [false]);
    expect(h.fleetStamps, 1);
    final usage = h.store.cloudUsage!;
    expect(usage.mediaBytes, 60, reason: 'what is left after the deletes');
    expect(usage.mediaReclaimableBytes, 0);
    expect(usage.mediaWaitingBytes, 7);
    expect(h.store.lastCloudResult!.bytes, 40);
    expect(h.store.lastCloudResult!.items, 4);
  });

  test('a deferred media sweep does not stamp the fleet', () async {
    h.mediaReport = _report(deferred: true, waiting: 9);
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.fleetStamps, 0);
    expect(h.store.lastCloudResult, isNull);
  });

  test('automatic cloud attempts are at most daily', () async {
    h.fleetDue = true;
    h.mediaReport = _report(deferred: true);
    await coordinator.run(StorageGcTrigger.launch);
    await coordinator.run(StorageGcTrigger.resume);
    expect(h.mediaRuns, hasLength(1));

    h.now = h.now.add(const Duration(days: 1));
    await coordinator.run(StorageGcTrigger.resume);
    expect(h.mediaRuns, hasLength(2));
  });

  test('a weekly measurement runs when no cleanup is due', () async {
    h.fleetDue = false;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, [true]);

    h.now = h.now.add(const Duration(days: 2));
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, [true], reason: 'measured two days ago');

    h.now = h.now.add(const Duration(days: 6));
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.mediaRuns, [true, true]);
  });

  test(
    'a restore marker forces a post-restore run and clears after it',
    () async {
      await coordinator.run(StorageGcTrigger.launch);
      expect(h.deviceRuns, [false]);

      await StorageGcStore.markRestored(
        await SharedPreferences.getInstance(),
        h.now,
      );
      await coordinator.run(StorageGcTrigger.launch);

      expect(h.deviceRuns, [false, false], reason: 'cadence ignored');
      expect(h.store.postRestorePendingSince, isNull);
    },
  );

  test(
    'post-restore keeps the cloud delete pending while the media sweep is deferred',
    () async {
      h.fleetDue = false;
      await StorageGcStore.markRestored(
        await SharedPreferences.getInstance(),
        h.now,
      );
      h.mediaReport = _report(deferred: true);

      await coordinator.run(StorageGcTrigger.launch);
      expect(h.mediaRuns, [false]);
      expect(h.store.postRestoreCloudPending, isTrue);

      // An hour later the pull after the restore has happened.
      h.now = h.now.add(const Duration(hours: 1));
      h.mediaReport = _report(reclaimed: 5, removed: 1, reclaimable: 5);
      await coordinator.run(StorageGcTrigger.resume);

      expect(h.mediaRuns, [false, false]);
      expect(h.store.postRestoreCloudPending, isFalse);
    },
  );

  test('a failed post-restore device pass stays pending', () async {
    // The forced retry is what clears a restore's leftovers; losing it to
    // one transient failure leaves them until the daily cadence.
    await StorageGcStore.markRestored(
      await SharedPreferences.getInstance(),
      h.now,
    );
    h.failFirstSweep = true;

    await coordinator.run(StorageGcTrigger.launch);

    expect(h.store.postRestorePendingSince, isNotNull);
  });

  test('a stalled measurement does not hold the pass forever', () {
    // A half-open connection with no request timeout would otherwise keep
    // the pass running, and every later trigger and tap would join it.
    fakeAsync((async) {
      h.holdSyncMeasure = Completer<void>();
      var finished = false;
      coordinator.run(StorageGcTrigger.rescan).then((_) => finished = true);

      async.elapse(StorageGcCoordinator.measureTimeout);
      async.flushMicrotasks();

      expect(finished, isTrue);
      expect(h.store.cloudUsage!.partial, isTrue);
      expect(h.store.cloudUsage!.librariesBytes, 4);
    });
  });

  test('records last reclaimed per area', () async {
    await coordinator.run(StorageGcTrigger.launch);
    final device = h.store.lastDeviceResult!;
    expect(device.bytes, 250);
    expect(device.items, 3);
    expect(device.at, h.now);
  });

  test('a failing sweep does not stop the others', () async {
    h.failFirstSweep = true;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.secondSweepRuns, [false]);
    expect(h.localCacheRuns, 1);
    expect(h.mediaRuns, isNotEmpty);
  });

  test('a failed device pass retries within the hour, not a day', () async {
    h.failFirstSweep = true;
    await coordinator.run(StorageGcTrigger.launch);
    expect(h.store.lastDeviceRun, isNull);

    h.failFirstSweep = false;
    h.now = h.now.add(StorageGcCoordinator.deviceRetry);
    await coordinator.run(StorageGcTrigger.resume);
    expect(h.deviceRuns, [false, false]);
    expect(h.store.lastDeviceRun, h.now);
  });

  test('a failing device pass is not retried on every trigger', () async {
    // A persistent failure (a full disk, a folder it may not read) would
    // otherwise walk every folder again on each resume and timer tick.
    h.failFirstSweep = true;
    await coordinator.run(StorageGcTrigger.launch);
    h.now = h.now.add(const Duration(minutes: 10));
    await coordinator.run(StorageGcTrigger.resume);
    await coordinator.run(StorageGcTrigger.timer);

    expect(h.deviceRuns, [false]);

    await coordinator.run(StorageGcTrigger.manual);
    expect(h.deviceRuns, [false, false], reason: 'the diver asked');
  });

  test('a restore after a failed pass is not held by the retry wait', () async {
    h.failFirstSweep = true;
    await coordinator.run(StorageGcTrigger.launch);
    h.now = h.now.add(const Duration(minutes: 10));
    await StorageGcStore.markRestored(
      await SharedPreferences.getInstance(),
      h.now,
    );

    await coordinator.run(StorageGcTrigger.resume);

    expect(h.deviceRuns, [false, false]);
  });

  test('Reclaim forces the weekly local cache sweep', () async {
    await coordinator.run(StorageGcTrigger.launch);
    h.now = h.now.add(const Duration(days: 2));
    await coordinator.run(StorageGcTrigger.manual);

    expect(h.localCacheForced, [false, true]);
  });

  test('a pass whose cloud deletes were held back says so', () async {
    h.mediaReport = _report(deferred: true, waiting: 40);

    await coordinator.run(StorageGcTrigger.manual);

    expect(coordinator.lastPassCloudHold, CloudDeleteHold.sync);
    expect(h.store.cloudUsage!.mediaHold, CloudDeleteHold.sync);

    h.mediaReport = _report();
    await coordinator.run(StorageGcTrigger.manual);
    expect(coordinator.lastPassCloudHold, isNull);
    expect(h.store.cloudUsage!.mediaHold, isNull);
  });

  group('deletes held back by this device', () {
    // The sweep's own policy cannot see these holds, so its dry run counts
    // the objects as reclaimable; Reclaim would then delete none of them.
    test('an unregistered store counts nothing as reclaimable', () async {
      h.storeRegistered = false;
      h.mediaReport = _report(reclaimable: 40, waiting: 10);

      await coordinator.run(StorageGcTrigger.manual);

      expect(h.mediaRuns, [true]);
      expect(coordinator.lastPassCloudHold, CloudDeleteHold.unregistered);
      final usage = h.store.cloudUsage!;
      expect(usage.mediaHold, CloudDeleteHold.unregistered);
      expect(usage.mediaReclaimableBytes, 0);
      expect(usage.mediaWaitingBytes, 50);
    });

    test('an upload in flight is named as the reason', () async {
      h.transferring = true;
      h.mediaReport = _report(reclaimable: 40);

      await coordinator.run(StorageGcTrigger.manual);

      expect(coordinator.lastPassCloudHold, CloudDeleteHold.uploads);
      expect(h.store.cloudUsage!.mediaHold, CloudDeleteHold.uploads);
    });

    test('a scan names the hold too', () async {
      h.storeRegistered = false;
      h.mediaReport = _report(reclaimable: 40);

      await coordinator.run(StorageGcTrigger.rescan);

      expect(h.store.cloudUsage!.mediaReclaimableBytes, 0);
      expect(h.store.cloudUsage!.mediaHold, CloudDeleteHold.unregistered);
    });

    test('not caught up with sync comes before the others', () async {
      // A sync can bring the store's row from a peer; reconnecting is the
      // remedy only once this device is caught up.
      h.deletesAllowed = false;
      h.storeRegistered = false;

      await coordinator.run(StorageGcTrigger.manual);

      expect(coordinator.lastPassCloudHold, CloudDeleteHold.sync);
    });
  });

  test(
    'a Verify Library run before any scan still shows its figures',
    () async {
      await coordinator.recordMediaSweep(
        _report(total: 90, reclaimable: 30, reclaimed: 30, removed: 3),
        storeId: 'store-a',
      );

      final usage = h.store.cloudUsage!;
      expect(usage.mediaBytes, 60);
      expect(usage.scannedAt, h.now);
      expect(usage.partial, isTrue, reason: 'the other areas are not measured');
    },
  );

  test(
    'a Verify Library run with unknown sizes marks the total partial',
    () async {
      await coordinator.run(StorageGcTrigger.rescan);
      expect(h.store.cloudUsage!.partial, isFalse);

      await coordinator.recordMediaSweep(
        _report(sizesUnknown: true),
        storeId: 'store-a',
      );

      expect(h.store.cloudUsage!.partial, isTrue);
    },
  );

  test('a Verify Library result names the store it swept', () async {
    // The attachment moved on while the old store was listed: its figures
    // are that store's, not the newly attached one's.
    await coordinator.run(StorageGcTrigger.rescan);
    h.storeId = 'store-b';

    await coordinator.recordMediaSweep(
      _report(total: 90, reclaimable: 30),
      storeId: 'store-a',
    );

    expect(h.store.cloudUsage!.mediaStoreId, 'store-a');
  });

  test('a Verify Library result updates the page figures', () async {
    await coordinator.run(StorageGcTrigger.rescan);
    final notified = <void>[];
    final sub = coordinator.changes.listen(notified.add);
    addTearDown(sub.cancel);

    await coordinator.recordMediaSweep(
      _report(total: 90, reclaimable: 30, reclaimed: 30, removed: 3),
      storeId: 'store-a',
    );
    await Future<void>.delayed(Duration.zero);

    final usage = h.store.cloudUsage!;
    expect(usage.mediaBytes, 60);
    expect(usage.mediaReclaimableBytes, 0);
    expect(usage.syncBytes, 30, reason: 'other areas keep their figures');
    expect(h.store.lastCloudResult!.bytes, 30);
    expect(notified, isNotEmpty);
  });

  test(
    'an incomplete sync or media size marks the cloud usage partial',
    () async {
      h.syncPartial = true;
      await coordinator.run(StorageGcTrigger.rescan);
      expect(h.store.cloudUsage!.partial, isTrue);

      h.syncPartial = false;
      h.mediaReport = _report(sizesUnknown: true);
      await coordinator.run(StorageGcTrigger.rescan);
      expect(h.store.cloudUsage!.partial, isTrue);

      h.mediaReport = _report();
      await coordinator.run(StorageGcTrigger.rescan);
      expect(h.store.cloudUsage!.partial, isFalse);
    },
  );

  test('no media store leaves the media figures out', () async {
    h.hasMediaStore = false;
    await coordinator.run(StorageGcTrigger.rescan);
    final usage = h.store.cloudUsage!;
    expect(usage.mediaBytes, isNull);
    expect(usage.syncBytes, 30);
  });

  test('concurrent runs share one execution', () async {
    h.holdFirstSweep = Completer<void>();
    final first = coordinator.run(StorageGcTrigger.manual);
    final second = coordinator.run(StorageGcTrigger.manual);
    expect(coordinator.isRunning, isTrue);
    h.holdFirstSweep!.complete();
    await Future.wait([first, second]);
    expect(h.deviceRuns, [false]);
    expect(coordinator.isRunning, isFalse);
  });

  test(
    'a run in flight when the coordinator is disposed ends quietly',
    () async {
      // A soft restart after a restore disposes the provider mid-run.
      h.holdFirstSweep = Completer<void>();
      final pass = coordinator.run(StorageGcTrigger.launch);
      coordinator.dispose();
      h.holdFirstSweep!.complete();

      await expectLater(pass, completes);
      expect(h.mediaRuns, isEmpty, reason: 'a disposed run skips the cloud');
    },
  );

  test('a pass disposed during its media sweep writes nothing after', () async {
    // A soft restart while the store is listed: the new scope runs its own
    // pass, and the old one must not stamp the fleet or overwrite figures
    // with a scan it could not finish.
    h.holdMediaSweep = Completer<void>();
    h.mediaReport = _report(reclaimable: 40, reclaimed: 40, removed: 4);
    final pass = coordinator.run(StorageGcTrigger.manual);
    await Future<void>.delayed(Duration.zero);
    while (h.mediaRuns.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    coordinator.dispose();
    h.holdMediaSweep!.complete();

    await expectLater(pass, completes);
    expect(h.fleetStamps, 0);
    expect(h.store.cloudUsage, isNull);
    expect(h.store.lastCloudResult, isNull);
  });

  group('Verify Library and a pass', () {
    // Two sweeps of one store at once judge the same listing twice: each
    // counts what the other removes, and their delete guards miss each
    // other's work.
    test('a Verify run waits for the pass in flight', () async {
      h.holdMediaSweep = Completer<void>();
      final pass = coordinator.run(StorageGcTrigger.manual);
      while (h.mediaRuns.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      var verified = false;
      final verify = coordinator.exclusive(() async => verified = true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(verified, isFalse);

      h.holdMediaSweep!.complete();
      await pass;
      await verify;

      expect(verified, isTrue);
    });

    test('a pass waits for the Verify run in flight', () async {
      final release = Completer<void>();
      final verify = coordinator.exclusive(() => release.future);
      final pass = coordinator.run(StorageGcTrigger.manual);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.mediaRuns, isEmpty);
      expect(coordinator.isRunning, isTrue);

      release.complete();
      await verify;
      await pass;

      expect(h.mediaRuns, isNotEmpty);
    });

    test('a failed Verify run does not block the next pass', () async {
      await expectLater(
        coordinator.exclusive<void>(() async => throw StateError('offline')),
        throwsStateError,
      );

      await coordinator.run(StorageGcTrigger.manual);

      expect(h.mediaRuns, isNotEmpty);
    });
  });

  test(
    'a run returns what the pass reclaimed on the device and in the cloud',
    () async {
      h.mediaReport = _report(reclaimable: 40, reclaimed: 40, removed: 4);
      expect(await coordinator.run(StorageGcTrigger.manual), 250 + 40);
    },
  );

  test('a joining caller gets the shared pass\'s result', () async {
    h.holdFirstSweep = Completer<void>();
    final first = coordinator.run(StorageGcTrigger.launch);
    final joined = coordinator.run(StorageGcTrigger.manual);
    h.holdFirstSweep!.complete();
    expect(await joined, await first);
    expect(await joined, greaterThan(0));
  });

  test(
    'a failing media sweep still records the other areas, marked partial',
    () async {
      await coordinator.run(StorageGcTrigger.rescan);
      final before = h.store.cloudUsage!;
      h.mediaError = Exception('list failed');
      h.syncBytes = 77;

      await coordinator.run(StorageGcTrigger.rescan);

      final usage = h.store.cloudUsage!;
      expect(usage.syncBytes, 77);
      expect(usage.partial, isTrue);
      expect(
        usage.mediaBytes,
        before.mediaBytes,
        reason: 'the last known media figure stays, flagged partial',
      );
    },
  );

  test('a scan records which media store it measured', () async {
    await coordinator.run(StorageGcTrigger.rescan);

    expect(h.store.cloudUsage!.mediaStoreId, 'store-a');
  });

  test(
    'a failing sweep of a newly attached store keeps no old figures',
    () async {
      // Store A's 40 GB are not the figure of store B, which could not be
      // listed: the media figures are unknown, not A's.
      await coordinator.run(StorageGcTrigger.rescan);
      h.storeId = 'store-b';
      h.mediaError = Exception('list failed');

      await coordinator.run(StorageGcTrigger.rescan);

      final usage = h.store.cloudUsage!;
      expect(usage.mediaBytes, isNull);
      expect(usage.mediaReclaimableBytes, isNull);
      expect(usage.mediaStoreId, 'store-b');
      expect(usage.partial, isTrue);
    },
  );

  test(
    'a failing media sweep keeps the post-restore cleanup pending',
    () async {
      await StorageGcStore.markRestored(
        await SharedPreferences.getInstance(),
        h.now,
      );
      h.mediaError = StateError('attached store unavailable');

      await coordinator.run(StorageGcTrigger.launch);

      expect(h.store.postRestoreCloudPending, isTrue);
      expect(h.fleetStamps, 0);
    },
  );

  test('device reclaimable bytes come from a dry run', () async {
    expect(await coordinator.deviceReclaimableBytes(), 250);
    expect(h.deviceRuns, [true]);
    expect(h.secondSweepRuns, [true]);
  });

  group('isCadenceDue', () {
    final now = DateTime(2026, 10, 17);
    test('never run is due', () {
      expect(isCadenceDue(null, now, const Duration(days: 7)), isTrue);
    });
    test('inside the period is not due', () {
      expect(
        isCadenceDue(
          now.subtract(const Duration(days: 6)),
          now,
          const Duration(days: 7),
        ),
        isFalse,
      );
    });
    test('a far-future stamp is due', () {
      expect(
        isCadenceDue(
          now.add(const Duration(days: 30)),
          now,
          const Duration(days: 7),
        ),
        isTrue,
      );
    });
  });
}
