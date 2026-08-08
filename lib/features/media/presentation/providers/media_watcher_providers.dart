import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final watchedFolderRepositoryProvider = Provider<WatchedFolderRepository>(
  (ref) => WatchedFolderRepository(),
);

/// The registered watched roots, re-read after every mutation.
final watchedRootsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(watchedFolderRepositoryProvider).getRoots(),
);

/// Whether exact-hash matches are applied automatically. Off demotes the
/// watcher to index-only (the spec's suggest-only mode).
final watcherAutoApplyProvider =
    StateNotifierProvider<WatcherAutoApplyNotifier, bool>(
      (ref) =>
          WatcherAutoApplyNotifier(ref.watch(appSettingsRepositoryProvider)),
    );

/// Reads the persisted auto-apply setting.
///
/// On when nothing has been stored, and otherwise only when the stored
/// value is exactly "true". [WatcherAutoApplyNotifier.setEnabled] is the
/// only writer and only ever writes "true" or "false", so anything else is
/// corruption -- and this gate decides whether the watcher may rewrite
/// `media.local_path` without asking. An unrecognised value therefore
/// resolves to off: the direction that can only cost a repair the user can
/// still run by hand, rather than one they opted out of.
Future<bool> readWatcherAutoApply(AppSettingsRepository settings) async {
  final raw = await settings.getRawSetting(kWatcherAutoApplySettingKey);
  return raw == null || raw == 'true';
}

const String kWatcherAutoApplySettingKey = 'media_watcher_auto_apply';

class WatcherAutoApplyNotifier extends StateNotifier<bool> {
  WatcherAutoApplyNotifier(this._settings) : super(true) {
    _prime();
  }

  final AppSettingsRepository _settings;

  Future<void> _prime() async {
    final value = await readWatcherAutoApply(_settings);
    if (!mounted) return;
    state = value;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await _settings.setRawSetting(
      kWatcherAutoApplySettingKey,
      value ? 'true' : 'false',
    );
  }
}

/// Every missing row, paged out in full: the watcher repairs the whole
/// backlog, not the first screenful.
Future<List<MediaItem>> loadAllMissingRows(Ref ref) async {
  final repo = ref.read(mediaLibraryRepositoryProvider);
  final diverId = ref.read(currentDiverIdProvider);
  final rows = <MediaItem>[];
  MediaLibraryCursor? cursor;
  do {
    final page = await repo.getPage(
      diverId: diverId,
      filter: const MediaLibraryFilter(health: MediaHealthFilter.missing),
      after: cursor,
      limit: 200,
    );
    rows.addAll(page.entries.map((e) => e.item));
    cursor = page.nextCursor;
  } while (cursor != null);
  return rows;
}

final watcherScannerProvider = Provider<WatchedFolderScanner>((ref) {
  return WatchedFolderScanner(
    watched: ref.watch(watchedFolderRepositoryProvider),
    repair: ref.watch(mediaRepairServiceProvider),
    loadMissingRows: () => loadAllMissingRows(ref),
    // Read from the database at scan time, NOT from watcherAutoApplyProvider:
    // that notifier starts at its `true` default and loads the stored value
    // asynchronously, so a scanner built from it would auto-repair for
    // someone who had turned auto-apply off.
    isAutoApplyEnabled: () =>
        readWatcherAutoApply(ref.read(appSettingsRepositoryProvider)),
  );
});

/// Opportunistic automatic pass, read once when the Media console builds.
///
/// The app has no startup-maintenance host, so the console is the hook;
/// the daily [shouldAutoScan] gate keeps that from meaning "every time you
/// open the section". Fire-and-forget and failure-swallowing on purpose: a
/// scan problem must never break the section that triggered it.
final watcherAutoScanProvider = Provider<void>((ref) {
  unawaited(() async {
    try {
      final watched = ref.read(watchedFolderRepositoryProvider);
      final roots = await watched.getRoots();
      if (roots.isEmpty) return;
      // The oldest root's stamp drives the cadence: if any root is due, the
      // pass runs (it re-stamps them all).
      DateTime? oldest;
      for (final root in roots) {
        final stamp = await watched.lastScanAt(root);
        if (stamp == null) {
          oldest = null;
          break;
        }
        if (oldest == null || stamp.isBefore(oldest)) oldest = stamp;
      }
      if (!shouldAutoScan(lastScanAt: oldest, now: DateTime.now())) return;

      final report = await ref
          .read(watcherScannerProvider)
          .scan(now: DateTime.now());
      LoggerService.forClass(WatchedFolderScanner).info(
        'Watcher scan: ${report.filesIndexed} indexed, '
        '${report.rehashed} hashed, ${report.autoRepaired} auto-repaired',
      );
    } catch (e) {
      LoggerService.forClass(
        WatchedFolderScanner,
      ).warning('Watcher scan failed', error: e);
    }
  }());
});
