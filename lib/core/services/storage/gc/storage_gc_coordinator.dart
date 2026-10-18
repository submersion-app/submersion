import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';

/// What started a cleanup run.
enum StorageGcTrigger {
  launch,
  resume,
  timer,

  /// A restore finished; set internally when a pending restore marker is
  /// found on an automatic trigger.
  postRestore,

  /// The diver tapped "Reclaim storage".
  manual,

  /// The diver tapped "Rescan": measure the cloud, delete nothing.
  rescan,
}

/// One device sweep. A [dryRun] counts what it would reclaim.
typedef DeviceSweep =
    Future<ScratchSweepReport> Function({
      required DateTime now,
      required bool dryRun,
    });

/// Whether something last done at [last] is due again after [period].
///
/// A stamp more than a day in the future can only come from a broken clock
/// and must not suppress the work until real time catches up: the same
/// defence as `shouldSweepLocalCache` and `shouldAutoScan`.
bool isCadenceDue(DateTime? last, DateTime now, Duration period) {
  if (last == null) return true;
  if (last.isAfter(now.add(const Duration(days: 1)))) return true;
  return now.difference(last) >= period;
}

/// Runs every storage sweep on one schedule under shared safety rules
/// (storage GC design, Coordinator).
///
/// Plain Dart with every dependency injected, so the schedule is testable
/// apart from Riverpod and the platform. The providers wire it to the live
/// services and kick it on launch, on resume, on a slow timer, and from the
/// Storage usage page.
///
/// - **Device part:** at most once a day, or at once after a restore or on
///   request. Every sweep is best-effort; one failing does not stop the rest.
/// - **Cloud part:** automatic runs need an unmetered network and happen at
///   most once a day. A cleanup (deletes) runs when the fleet cadence is due,
///   after a restore until a sweep is no longer deferred, or on request.
///   Otherwise a weekly measurement lists the store without deleting. Deletes
///   wait while a sync is merging, while an upload is transferring, and
///   whenever the delete policy would defer (no listing is spent on a sweep
///   that could delete nothing). Automatic cloud work skips a merging sync
///   altogether; Rescan and Reclaim still measure, on any network but
///   offline, since the diver asked.
class StorageGcCoordinator {
  StorageGcCoordinator({
    required List<DeviceSweep> deviceSweeps,
    required Future<void> Function(DateTime now, {required bool force})
    localCacheSweep,
    required Future<NetworkKind> Function() network,
    required bool Function() isSyncBusy,
    required Future<bool> Function() hasTransferringUploads,
    required Future<VerifyLibraryReport?> Function({required bool dryRun})
    mediaSweep,
    required Future<bool> Function() deletesAllowed,
    required Future<bool> Function() isStoreRegistered,
    required Future<String?> Function() attachedStoreId,
    required Future<bool> Function(DateTime now) fleetSweepDue,
    required Future<void> Function(DateTime now) stampFleetSweep,
    required Future<({int bytes, bool partial})?> Function() measureSync,
    required Future<({int bytes, bool partial})?> Function() measureLibraries,
    required StorageGcStore store,
    DateTime Function()? now,
  }) : _deviceSweeps = deviceSweeps,
       _localCacheSweep = localCacheSweep,
       _network = network,
       _isSyncBusy = isSyncBusy,
       _hasTransferringUploads = hasTransferringUploads,
       _mediaSweep = mediaSweep,
       _deletesAllowed = deletesAllowed,
       _isStoreRegistered = isStoreRegistered,
       _attachedStoreId = attachedStoreId,
       _fleetSweepDue = fleetSweepDue,
       _stampFleetSweep = stampFleetSweep,
       _measureSync = measureSync,
       _measureLibraries = measureLibraries,
       _store = store,
       _now = now ?? DateTime.now;

  static const devicePeriod = Duration(days: 1);

  /// How soon an automatic device pass is tried again after one that failed.
  static const deviceRetry = Duration(hours: 1);
  static const cloudAttemptPeriod = Duration(days: 1);
  static const measurePeriod = Duration(days: 7);

  /// How long a sync folder or library measurement may take before the pass
  /// moves on without it (the total is then partial). A stalled call would
  /// otherwise hold the pass, and every caller that joins it, for good.
  static const measureTimeout = Duration(minutes: 2);

  /// How often a pending post-restore cloud cleanup retries while deferred.
  static const postRestoreRetry = Duration(hours: 1);

  final List<DeviceSweep> _deviceSweeps;
  final Future<void> Function(DateTime now, {required bool force})
  _localCacheSweep;
  final Future<NetworkKind> Function() _network;
  final bool Function() _isSyncBusy;
  final Future<bool> Function() _hasTransferringUploads;
  final Future<VerifyLibraryReport?> Function({required bool dryRun})
  _mediaSweep;

  /// Whether the delete policy allows cloud deletes at all right now (this
  /// device caught up with sync). Checked before a deleting sweep is
  /// started, so a deferral costs no deleting listing.
  final Future<bool> Function() _deletesAllowed;

  /// Whether this database registered the attached store.
  final Future<bool> Function() _isStoreRegistered;

  /// The media store this device is attached to, or null.
  final Future<String?> Function() _attachedStoreId;
  final Future<bool> Function(DateTime now) _fleetSweepDue;
  final Future<void> Function(DateTime now) _stampFleetSweep;
  final Future<({int bytes, bool partial})?> Function() _measureSync;
  final Future<({int bytes, bool partial})?> Function() _measureLibraries;
  final StorageGcStore _store;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(StorageGcCoordinator);

  final _changes = StreamController<void>.broadcast();
  Future<int>? _current;
  bool _disposed = false;
  CloudDeleteHold? _lastPassCloudHold;

  StorageGcStore get store => _store;

  /// Whether a run is in progress.
  bool get isRunning => _current != null;

  /// Why the last pass held back the cloud deletes it wanted, or null when
  /// it held none back. Read after awaiting [run], it describes that pass.
  CloudDeleteHold? get lastPassCloudHold => _lastPassCloudHold;

  /// Records a media sweep run outside a pass (Verify Library), so the
  /// Storage usage page shows what it reclaimed and the media figures it
  /// found. The other areas keep the figures of the last scan, whose time
  /// the page shows; with no scan yet, the record is this sweep's alone and
  /// partial, since nothing else was measured. [storeId] is the store the
  /// sweep listed: the attachment may have moved on since, and the figures
  /// stay that store's (the page shows only the attached store's).
  Future<void> recordMediaSweep(
    VerifyLibraryReport report, {
    required String storeId,
  }) async {
    final now = _now();
    await _recordCloudResult(report, now);
    final usage =
        _store.cloudUsage ?? CloudUsage(scannedAt: now, partial: true);
    await _store.setCloudUsage(
      _withMedia(
        usage,
        report,
        storeId: storeId,
      ).copyWith(partial: usage.partial || report.sizesUnknown),
    );
    _notify();
  }

  /// [usage] with the media figures [report] found: what the store holds,
  /// and could still give back, after the sweep's own deletes.
  ///
  /// Held back by [hold], what the sweep's policy would allow is not
  /// reclaimable now (Reclaim would delete none of it), so it counts as
  /// waiting, on that hold.
  static CloudUsage _withMedia(
    CloudUsage usage,
    VerifyLibraryReport report, {
    required String? storeId,
    CloudDeleteHold? hold,
  }) {
    final held =
        hold ?? report.hold ?? (report.deferred ? CloudDeleteHold.sync : null);
    final reclaimable = report.reclaimableBytes - report.bytesReclaimed;
    return CloudUsage(
      scannedAt: usage.scannedAt,
      mediaBytes: report.totalBytes - report.bytesReclaimed,
      mediaReclaimableBytes: held == null ? reclaimable : 0,
      mediaWaitingBytes: report.waitingBytes + (held == null ? 0 : reclaimable),
      syncBytes: usage.syncBytes,
      librariesBytes: usage.librariesBytes,
      partial: usage.partial,
      mediaHold: held,
      mediaStoreId: storeId,
    );
  }

  /// [scan] with the last known media figures, after a failed sweep (the
  /// total is already partial). Only if they are [storeId]'s: another
  /// store's figures say nothing about this one, so they are unknown.
  static CloudUsage _withLastMedia(
    CloudUsage scan,
    CloudUsage? previous, {
    required String? storeId,
  }) {
    final last = previous?.mediaStoreId == storeId ? previous : null;
    return CloudUsage(
      scannedAt: scan.scannedAt,
      mediaBytes: last?.mediaBytes,
      mediaReclaimableBytes: last?.mediaReclaimableBytes,
      mediaWaitingBytes: last?.mediaWaitingBytes,
      syncBytes: scan.syncBytes,
      librariesBytes: scan.librariesBytes,
      partial: scan.partial,
      mediaHold: last?.mediaHold,
      mediaStoreId: storeId,
    );
  }

  /// Why cloud deletes would be held back now, first the one a sync can
  /// clear (a sync can also bring the store's row from a peer).
  Future<CloudDeleteHold?> _deleteHold({required bool syncBusy}) async {
    if (syncBusy || !await _deletesAllowed()) return CloudDeleteHold.sync;
    if (!await _isStoreRegistered()) return CloudDeleteHold.unregistered;
    if (await _hasTransferringUploads()) return CloudDeleteHold.uploads;
    return null;
  }

  Future<void> _recordCloudResult(VerifyLibraryReport report, DateTime at) {
    if (report.orphansRemoved == 0) return Future.value();
    return _store.setLastCloudResult(
      AreaResult(
        bytes: report.bytesReclaimed,
        items: report.orphansRemoved,
        at: at,
      ),
    );
  }

  /// Fires when a run starts and when it ends.
  Stream<void> get changes => _changes.stream;

  /// Runs one pass and returns the bytes it reclaimed, on the device and in
  /// the cloud. A call while a pass is running joins that pass and gets its
  /// result.
  Future<int> run(StorageGcTrigger trigger) {
    final running = _current;
    if (running != null) return running;
    final pass = _serial(() => _run(trigger)).whenComplete(() {
      _current = null;
      _notify();
    });
    _current = pass;
    _notify();
    return pass;
  }

  /// Runs [sweep] (a Verify Library run) once no pass is in flight, and
  /// holds any pass that starts meanwhile until it ends: two sweeps of one
  /// store at once would each judge the listing the other is deleting from.
  Future<T> exclusive<T>(Future<T> Function() sweep) => _serial(sweep);

  /// The end of the last queued pass or Verify run, null when none is
  /// queued; failures are absorbed so one never blocks the next.
  Future<void>? _tail;

  Future<T> _serial<T>(Future<T> Function() work) {
    final previous = _tail;
    // Idle: start now, as a pass always did, rather than a microtask later.
    final result = previous == null
        ? Future.sync(work)
        : previous.then((_) => work());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    tail.whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    return result;
  }

  /// Bytes the device sweeps would reclaim now (a dry run of each).
  Future<int> deviceReclaimableBytes() async {
    final now = _now();
    var bytes = 0;
    for (final sweep in _deviceSweeps) {
      try {
        bytes += (await sweep(now: now, dryRun: true)).bytesReclaimed;
      } catch (e) {
        _log.warning('Device sweep measurement failed', error: e);
      }
    }
    return bytes;
  }

  /// Stops notifying and makes a run in flight skip whatever it has not
  /// started yet, and write nothing once its media sweep returns. A soft
  /// restart after a restore disposes the provider while a run may still be
  /// listing the store; that run must not go on against services that were
  /// torn down, nor overwrite what the new scope's pass records.
  void dispose() {
    _disposed = true;
    _changes.close();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<int> _run(StorageGcTrigger trigger) async {
    final now = _now();
    _lastPassCloudHold = null;
    var effective = trigger;
    final automatic =
        trigger == StorageGcTrigger.launch ||
        trigger == StorageGcTrigger.resume ||
        trigger == StorageGcTrigger.timer;
    if (automatic && _store.postRestorePendingSince != null) {
      effective = StorageGcTrigger.postRestore;
    }
    var reclaimed = 0;
    try {
      reclaimed += await _devicePart(effective, now);
    } catch (e) {
      _log.warning('Device cleanup failed', error: e);
    }
    if (_disposed) return reclaimed;
    try {
      reclaimed += await _cloudPart(effective, now, automatic: automatic);
    } catch (e) {
      _log.warning('Cloud cleanup failed', error: e);
    }
    return reclaimed;
  }

  /// Returns the bytes the device sweeps reclaimed.
  Future<int> _devicePart(StorageGcTrigger trigger, DateTime now) async {
    if (trigger == StorageGcTrigger.rescan) return 0;
    final manual = trigger == StorageGcTrigger.manual;
    final forced = manual || trigger == StorageGcTrigger.postRestore;
    if (!manual && _retryWaiting(now)) return 0;
    if (!forced && !isCadenceDue(_store.lastDeviceRun, now, devicePeriod)) {
      return 0;
    }
    if (!manual) await _store.setLastDeviceAttempt(now);
    var total = ScratchSweepReport.empty;
    var failed = false;
    for (final sweep in _deviceSweeps) {
      try {
        total += await sweep(now: now, dryRun: false);
      } catch (e) {
        failed = true;
        _log.warning('Device sweep failed (will retry)', error: e);
      }
    }
    try {
      await _localCacheSweep(now, force: forced);
    } catch (e) {
      failed = true;
      _log.warning('Local cache sweep failed (will retry)', error: e);
    }
    // Stamped only after a clean pass, so a failure retries on the next
    // trigger rather than a day later.
    if (!failed) await _store.setLastDeviceRun(now);
    if (!total.isEmpty) {
      await _store.setLastDeviceResult(
        AreaResult(
          bytes: total.bytesReclaimed,
          items: total.filesDeleted,
          at: now,
        ),
      );
    }
    // Likewise the forced post-restore pass: a failure keeps it pending.
    if (trigger == StorageGcTrigger.postRestore && !failed) {
      await _store.clearPostRestorePending();
    }
    return total.bytesReclaimed;
  }

  /// Whether an automatic device pass tried less than [deviceRetry] ago. A
  /// restore since that attempt is new work, so it never waits.
  bool _retryWaiting(DateTime now) {
    final attempt = _store.lastDeviceAttempt;
    if (attempt == null) return false;
    final restored = _store.postRestorePendingSince;
    if (restored != null && !attempt.isAfter(restored)) return false;
    return !isCadenceDue(attempt, now, deviceRetry);
  }

  /// Returns the bytes the cloud cleanup reclaimed.
  Future<int> _cloudPart(
    StorageGcTrigger trigger,
    DateTime now, {
    required bool automatic,
  }) async {
    final requested =
        trigger == StorageGcTrigger.manual ||
        trigger == StorageGcTrigger.rescan;
    // A merge in progress rules out deletes, not measuring: a dry run writes
    // nothing, so a requested scan goes ahead.
    final syncBusy = _isSyncBusy();
    if (syncBusy && !requested) return 0;
    final network = await _network();
    if (network == NetworkKind.offline) return 0;
    if (!requested && network != NetworkKind.unmetered) return 0;

    final cloudPending = _store.postRestoreCloudPending;
    if (automatic || trigger == StorageGcTrigger.postRestore) {
      final period = cloudPending ? postRestoreRetry : cloudAttemptPeriod;
      if (!isCadenceDue(_store.lastCloudAttempt, now, period)) return 0;
    }

    final wantDelete =
        trigger == StorageGcTrigger.manual ||
        (trigger != StorageGcTrigger.rescan &&
            (cloudPending || await _fleetSweepDue(now)));
    final measureDue =
        requested ||
        trigger == StorageGcTrigger.postRestore ||
        isCadenceDue(_store.lastCloudMeasure, now, measurePeriod);

    if (!wantDelete && !measureDue) return 0;
    // Asked even for a scan: one that counted held objects as reclaimable
    // would promise what Reclaim cannot give.
    final hold = await _deleteHold(syncBusy: syncBusy);
    final deleting = wantDelete && hold == null;
    if (!deleting && !measureDue) return 0;
    if (!requested) await _store.setLastCloudAttempt(now);

    // A media failure must not cost the other areas their figures; the last
    // known media figures stay, and the total is marked partial.
    // Read before the sweep: the figures describe the store it swept.
    final storeId = await _attachedStoreId();
    VerifyLibraryReport? report;
    var mediaFailed = false;
    try {
      report = await _mediaSweep(dryRun: !deleting);
    } catch (e) {
      mediaFailed = true;
      _log.warning('Media store sweep failed', error: e);
    }
    // Disposed meanwhile (a soft restart): the new scope runs its own pass,
    // and this one must not stamp or overwrite what that pass records.
    if (_disposed) return report?.bytesReclaimed ?? 0;

    var reclaimed = 0;
    if (report != null) {
      reclaimed = report.bytesReclaimed;
      await _recordCloudResult(report, now);
      if (wantDelete && (hold != null || report.deferred)) {
        _lastPassCloudHold = hold ?? CloudDeleteHold.sync;
      }
    }
    // Only a completed sweep counts: a deferred or failed one is retried.
    if (deleting && !mediaFailed && (report == null || !report.deferred)) {
      if (report != null) await _stampFleetSweep(now);
      if (cloudPending) await _store.setPostRestoreCloudPending(false);
    }

    var partial = mediaFailed || (report?.sizesUnknown ?? false);
    int? syncBytes;
    try {
      final sync = await _measureSync().timeout(measureTimeout);
      syncBytes = sync?.bytes;
      partial = partial || (sync?.partial ?? false);
    } catch (e) {
      partial = true;
      _log.warning('Sync folder measurement failed', error: e);
    }
    ({int bytes, bool partial})? libraries;
    try {
      libraries = await _measureLibraries().timeout(measureTimeout);
    } catch (e) {
      partial = true;
      _log.warning('Shared library measurement failed', error: e);
    }

    if (_disposed) return reclaimed;
    final previous = _store.cloudUsage;
    final scan = CloudUsage(
      scannedAt: now,
      syncBytes: syncBytes,
      librariesBytes: libraries?.bytes,
      partial: partial || (libraries?.partial ?? false),
    );
    final r = report;
    await _store.setCloudUsage(
      mediaFailed
          ? _withLastMedia(scan, previous, storeId: storeId)
          : r == null
          ? scan
          : _withMedia(scan, r, storeId: storeId, hold: hold),
    );
    await _store.setLastCloudMeasure(now);
    return reclaimed;
  }
}
