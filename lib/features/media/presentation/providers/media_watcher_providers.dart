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
import 'package:submersion/core/utils/log_failure.dart';

final watchedFolderRepositoryProvider = Provider<WatchedFolderRepository>(
  (ref) => WatchedFolderRepository(),
);

// no-tick: watched_roots lives in the device-local cache database and has
// exactly two writers, addRoot and removeRoot, both reached from this
// section's own UI, which invalidates this provider directly. Nothing that
// the tick rule exists to catch -- a sync pull, a dive merge, a repository
// bulk delete -- can reach that table, and the local cache DB has no change
// stream to subscribe to.
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
    logFailure(_prime(), WatcherAutoApplyNotifier, 'prime');
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

/// Runs the opportunistic watcher pass, at most one at a time.
///
/// Deliberately an object with a method rather than a `Provider<void>` whose
/// constructor fires the scan. That older shape meant the only way to trigger
/// a pass was to `ref.watch` it from `MediaSectionPage.build()`, which welded
/// a recursive filesystem walk to a widget's build phase (#1182) -- a section
/// opening is a strange place to start unbounded filesystem work, and the
/// once-per-provider-construction firing was an accident of Riverpod caching
/// rather than a decision anyone made.
///
/// [kick] carries the re-entrancy guard that the old shape got for free: an
/// explicit call can arrive again on the next mount (a tab switch, a route
/// pop), and the daily cadence gate alone would not stop a long pass from
/// overlapping itself.
class WatcherAutoScan {
  WatcherAutoScan(this._ref);

  final Ref _ref;
  Future<void>? _inFlight;

  static const _log = LoggerService('WatcherAutoScan');

  /// Fire-and-forget entry point for UI callers.
  ///
  /// Failure-swallowing on purpose: a scan problem must never break the
  /// section that triggered it.
  void kick() => unawaited(run());

  /// The awaitable form, for tests and for anything that wants to know when
  /// the pass finished. Returns the running pass when one is already going.
  Future<void> run() {
    final running = _inFlight;
    if (running != null) return running;
    // `_run()` is `async`, so it suspends at its first `await` and returns
    // before the assignment below -- the field is always populated before
    // any second caller can observe it.
    final started = _run().whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  Future<void> _run() async {
    // Yield before touching a provider. Callers reach this from a widget
    // lifecycle, and an `async` body runs synchronously up to its first
    // await -- so a provider initialized here would be initialized during
    // the build phase, which Riverpod turns into "setState() or
    // markNeedsBuild() called during build". Same defense as
    // `MediaItemView._resolveInner`.
    await null;
    try {
      final watched = _ref.read(watchedFolderRepositoryProvider);
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

      final report = await _ref
          .read(watcherScannerProvider)
          .scan(now: DateTime.now());
      _log.info(
        'Watcher scan: ${report.filesIndexed} indexed, '
        '${report.rehashed} hashed, ${report.autoRepaired} auto-repaired'
        '${report.hashBudgetExhausted ? ' (hash budget spent)' : ''}',
      );
    } catch (e) {
      _log.warning('Watcher scan failed', error: e);
    }
  }
}

// no-tick: this is a side effect, not a cached query -- running it re-runs a
// filesystem scan that can rewrite media.local_path. Subscribing to a tick
// would make every media write trigger another scan, and the scan itself
// writes media, so the tick would drive it in a loop.
/// Host for the opportunistic automatic pass.
///
/// The app has no startup-maintenance host, so the Media console is the hook;
/// the daily [shouldAutoScan] gate keeps that from meaning "every time you
/// open the section". Constructing this provider does nothing -- the caller
/// has to ask, via [WatcherAutoScan.kick].
final watcherAutoScanProvider = Provider<WatcherAutoScan>(WatcherAutoScan.new);
