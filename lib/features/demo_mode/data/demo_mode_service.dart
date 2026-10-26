import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
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
      onProgress?.call(const DemoEnterProgress(DemoEnterStage.preparing));
      await extractor.extract(zip, paths);
      await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    } catch (_) {
      await store.deleteAll();
      rethrow;
    }

    // Commit point: from here a relaunch opens the sample logbook, and every
    // sealed feature refuses to run.
    await store.write(state.copyWith(phase: DemoPhase.active));
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
    } catch (_) {
      await _leave();
      rethrow;
    }
    restart();
  }

  Future<void> exit() async {
    await _leave();
    restart();
  }

  Future<void> _leave() async {
    final current = await store.read();
    if (current != null) {
      await store.write(current.copyWith(phase: DemoPhase.exiting));
    }
    await cancelDeviceNotifications();
    await switcher.openAt(await realDatabasePath(), keyHex: realKeyHex());
    final snapshot = File(paths.prefsSnapshotFile);
    if (await snapshot.exists()) await PrefsSnapshot.restore(prefs, snapshot);
    await store.deleteAll();
    DemoModeGate.instance.markActive(false);
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
