import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_database_switcher.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// The pref key the selected diver lives under (`diver_providers.dart`).
const _currentDiverIdKey = 'current_diver_id';

final _log = LoggerService.forClass(DemoModeService);

/// The steps of entering demo mode, each filling its share of one progress
/// bar, from [start] to [end]. The shares meet end to end, so the bar fills
/// once and never sweeps or moves back (#3797). The download gets most of it,
/// since on a slow connection it is nearly all of the wait.
enum DemoEnterStage {
  downloading(0, 0.6),
  preparing(0.6, 0.75),
  opening(0.75, 1);

  const DemoEnterStage(this.start, this.end);

  final double start;
  final double end;
}

class DemoEnterProgress {
  const DemoEnterProgress(this.stage, {this.done = 0, this.total = 0});

  final DemoEnterStage stage;

  /// How far through [stage]: [done] of [total] bytes or steps. A [total] of
  /// 0 means the stage has only begun.
  final int done;
  final int total;

  /// How far the whole entry has come, from 0 to 1.
  double get fraction {
    final through = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    return stage.start + (stage.end - stage.start) * through;
  }
}

/// The sample logbook on offer is no longer the size the user agreed to
/// download. Nothing was downloaded; [current] is the package now on offer.
class DemoPackageChangedException implements Exception {
  const DemoPackageChangedException(this.current);

  final DemoPackage current;
}

/// An import is still writing to the user's logbook, so demo mode was not
/// entered: its remaining dives would land in the sample logbook and be
/// discarded with it (issue #3798). Nothing was changed.
class DemoImportRunningException implements Exception {
  const DemoImportRunningException();
}

/// Takes the app into the sample logbook and back out.
///
/// The user's own database is never written: entering closes it and opens a
/// separate file in the demo directory; exiting closes that and reopens the
/// user's file exactly where it was. Each step is recorded in [DemoState] so
/// a killed app resumes or finishes cleanly (see `DemoStartup`).
class DemoModeService {
  DemoModeService({
    required this.paths,
    required this.prefs,
    required this.store,
    required this.manifest,
    required this.downloader,
    required this.extractor,
    required this.preparer,
    required this.switcher,
    required this.realDatabasePath,
    required this.realKeyHex,
    required this.deviceId,
    required this.cancelDeviceNotifications,
    required this.restart,
    this.forgetPhotos,
    this.endNearbySync,
    this.importRunning,
    this.clock = DateTime.now,
  });

  final DemoPaths paths;
  final SharedPreferences prefs;
  final DemoStateStore store;
  final DemoManifestClient manifest;
  final DemoDownloader downloader;
  final DemoPackageExtractor extractor;
  final DemoDatabasePreparer preparer;
  final DemoDatabaseSwitcher switcher;
  final Future<String> Function() realDatabasePath;
  final String? Function() realKeyHex;
  final String? Function() deviceId;
  final Future<void> Function() cancelDeviceNotifications;
  final VoidCallback restart;

  /// Drops whatever the app cached for the sample photos at these paths,
  /// such as their thumbnails, so nothing of demo mode outlives it.
  final Future<void> Function(List<String> photoPaths)? forgetPhotos;

  /// Ends any nearby Bluetooth session still running, and returns once it
  /// has, so no session reads or writes across the database switch.
  final Future<void> Function()? endNearbySync;

  /// Whether an import is writing to the user's logbook. Entering refuses
  /// while one is, before downloading and again once the gate has closed.
  final bool Function()? importRunning;
  final DateTime Function() clock;

  /// Downloads and opens [package], the one whose size the user agreed to.
  ///
  /// That package may have been read from the manifest hours ago, and a
  /// republish replaces the zip in place (`tool/demo_data/README.md`), so the
  /// manifest is read again on every attempt, Retry included. A package of
  /// the same size is downloaded from its current entry; one whose size
  /// changed throws [DemoPackageChangedException] so the user is asked again.
  /// When the manifest cannot be reached, [package] itself is tried.
  ///
  /// Throws [DemoImportRunningException] while [importRunning] says an
  /// import is writing, leaving everything as it was.
  Future<void> enter({
    required bool fromFirstRun,
    required DemoPackage package,
    DemoUnitSettings? units,
    void Function(DemoEnterProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    _throwIfImporting();
    final state = DemoState(
      phase: DemoPhase.entering,
      fromFirstRun: fromFirstRun,
      enteredAt: clock(),
    );
    // Byte or step counts from each stage, placed in that stage's share.
    void Function(int, int) reportIn(DemoEnterStage stage) =>
        (done, total) => onProgress?.call(
          DemoEnterProgress(stage, done: done, total: total),
        );
    try {
      await store.write(state);
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.downloading));
      final pkg =
          await manifest.fetchBest(AppDatabase.currentSchemaVersion) ?? package;
      if (pkg.size != package.size) throw DemoPackageChangedException(pkg);
      final zip = await downloader.download(
        pkg,
        File(paths.packageFile),
        isCancelled: isCancelled,
        onProgress: reportIn(DemoEnterStage.downloading),
      );
      // The downloader sees Cancel only as chunks land, so a tap that comes
      // with the last one is honoured here, and again before the switch.
      _throwIfCancelled(isCancelled);
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.preparing));
      await extractor.extract(
        zip,
        paths,
        onProgress: reportIn(DemoEnterStage.preparing),
      );
      await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
      _throwIfCancelled(isCancelled);
    } catch (_) {
      await store.deleteAll();
      rethrow;
    }

    // Every sealed feature refuses from here, while the switch is under way.
    DemoModeGate.instance.markActive(true);
    // An import (a file dropped on the window, say) may have started during
    // the download, before the gate could refuse it. The user's logbook is
    // still the open one, so stepping back only reopens the gate.
    if (_importing) {
      DemoModeGate.instance.markActive(false);
      await store.deleteAll();
      throw const DemoImportRunningException();
    }
    try {
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.opening));
      await cancelDeviceNotifications();
      await endNearbySync?.call();
      // A sync that started before the gate closed may still be merging, and
      // its later steps reach whichever database is open: in the sample
      // logbook, whose cursors are empty, a pull brings in every record from
      // the user's other devices (issue #3798). Switching as a coordinator
      // turn waits for that merge and lets no other merge in until the
      // sample logbook is ready.
      await SyncCoordinator.run(
        () => _openSampleLogbook(
          state,
          units: units,
          onProgress: reportIn(DemoEnterStage.opening),
        ),
      );
      onProgress?.call(
        const DemoEnterProgress(DemoEnterStage.opening, done: 1, total: 1),
      );
    } catch (_) {
      await _leaveLogged();
      // The user's logbook is a new database instance, so the scope is
      // rebuilt for every provider to see it.
      restart();
      rethrow;
    }
    restart();
  }

  Future<void> _openSampleLogbook(
    DemoState state, {
    DemoUnitSettings? units,
    void Function(int done, int total)? onProgress,
  }) async {
    await switcher.openAt(paths.databaseFile, keyHex: null);
    await preparer.prepare(
      switcher.current,
      now: clock(),
      photosDir: paths.photosDir,
      deviceId: deviceId(),
      units: units,
      onProgress: onProgress,
    );
    final diverId = await _defaultDiverId(switcher.current);
    if (diverId != null) await prefs.setString(_currentDiverIdKey, diverId);
    // Commit point: only a fully prepared logbook is reopened on relaunch.
    // A kill before this line relaunches as entering, which restores the
    // preferences and opens the user's logbook.
    await store.write(state.copyWith(phase: DemoPhase.active));
  }

  bool get _importing => importRunning?.call() ?? false;

  void _throwIfImporting() {
    if (_importing) throw const DemoImportRunningException();
  }

  static void _throwIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const DemoDownloadException(DemoDownloadFailure.cancelled);
    }
  }

  /// Leaves demo mode and restarts. Never throws: whatever is left half done
  /// is finished by `DemoStartup` on the restart.
  Future<void> exit() async {
    await _leaveLogged();
    restart();
  }

  Future<void> _leaveLogged() async {
    try {
      await _leave();
    } catch (e, st) {
      _log.error('Leaving demo mode failed', error: e, stackTrace: st);
    }
  }

  Future<void> _leave() async {
    final current = await store.read();
    if (current != null) {
      await store.write(current.copyWith(phase: DemoPhase.exiting));
    }
    await cancelDeviceNotifications();
    // Preferences first: the user's logbook is found through them, so
    // nothing a demo session wrote can point the reopen elsewhere.
    final snapshot = File(paths.prefsSnapshotFile);
    if (await snapshot.exists()) {
      try {
        await PrefsSnapshot.restore(prefs, snapshot);
      } on StateError catch (e) {
        _log.warning('Demo mode preferences could not be restored: $e');
      }
    }
    await _forgetPhotos();
    // On failure the state stays exiting: startup finishes the exit on the
    // restart, and shows its own screens if the logbook still cannot open.
    await switcher.openAt(await realDatabasePath(), keyHex: realKeyHex());
    await store.deleteAll();
    DemoModeGate.instance.markActive(false);
  }

  /// Best effort: a cache that cannot be cleared never stops an exit.
  Future<void> _forgetPhotos() async {
    final forget = forgetPhotos;
    final dir = Directory(paths.photosDir);
    if (forget == null || !await dir.exists()) return;
    try {
      final photos = [
        await for (final entry in dir.list())
          if (entry is File) entry.path,
      ]..sort();
      await forget(photos);
    } catch (e, st) {
      _log.warning(
        'Sample photo caches could not be cleared',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<String?> _defaultDiverId(AppDatabase db) async {
    final row = await db
        .customSelect(
          'SELECT id FROM divers ORDER BY is_default DESC, created_at LIMIT 1',
        )
        .getSingleOrNull();
    return row?.read<String>('id');
  }
}
