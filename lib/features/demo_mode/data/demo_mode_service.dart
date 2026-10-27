import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_database_switcher.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// The pref key the selected diver lives under (`diver_providers.dart`).
const _currentDiverIdKey = 'current_diver_id';

final _log = LoggerService.forClass(DemoModeService);

enum DemoEnterStage { downloading, preparing, opening }

class DemoEnterProgress {
  const DemoEnterProgress(this.stage, {this.received = 0, this.total = 0});

  final DemoEnterStage stage;
  final int received;
  final int total;
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
  final DateTime Function() clock;

  Future<void> enter({
    required bool fromFirstRun,
    DemoUnitSettings? units,
    void Function(DemoEnterProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final state = DemoState(
      phase: DemoPhase.entering,
      fromFirstRun: fromFirstRun,
      enteredAt: clock(),
    );
    try {
      await store.write(state);
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.downloading));
      final pkg = await manifest.fetchBest(AppDatabase.currentSchemaVersion);
      if (pkg == null) {
        throw const DemoDownloadException(
          DemoDownloadFailure.network,
          'no compatible sample logbook',
        );
      }
      final zip = await downloader.download(
        pkg,
        File(paths.packageFile),
        isCancelled: isCancelled,
        onProgress: (r, t) => onProgress?.call(
          DemoEnterProgress(DemoEnterStage.downloading, received: r, total: t),
        ),
      );
      // The downloader sees Cancel only as chunks land, so a tap that comes
      // with the last one is honoured here, and again before the switch.
      _throwIfCancelled(isCancelled);
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.preparing));
      await extractor.extract(zip, paths);
      await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
      _throwIfCancelled(isCancelled);
    } catch (_) {
      await store.deleteAll();
      rethrow;
    }

    // Every sealed feature refuses from here, while the switch is under way.
    DemoModeGate.instance.markActive(true);
    try {
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.opening));
      await cancelDeviceNotifications();
      await switcher.openAt(paths.databaseFile, keyHex: null);
      await preparer.prepare(
        switcher.current,
        now: clock(),
        photosDir: paths.photosDir,
        deviceId: deviceId(),
        units: units,
      );
      final diverId = await _defaultDiverId(switcher.current);
      if (diverId != null) await prefs.setString(_currentDiverIdKey, diverId);
      // Commit point: only a fully prepared logbook is reopened on relaunch.
      // A kill before this line relaunches as entering, which restores the
      // preferences and opens the user's logbook.
      await store.write(state.copyWith(phase: DemoPhase.active));
    } catch (_) {
      await _leaveLogged();
      // The user's logbook is a new database instance, so the scope is
      // rebuilt for every provider to see it.
      restart();
      rethrow;
    }
    restart();
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
