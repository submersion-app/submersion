import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

/// What the library sync is doing and how each library's last run ended.
class SharedLibrarySyncState {
  const SharedLibrarySyncState({
    this.syncing = false,
    this.syncingLibraryId,
    this.lastResults = const {},
  });

  final bool syncing;
  final String? syncingLibraryId;
  final Map<String, SharedLibrarySyncResult> lastResults;

  SharedLibrarySyncState copyWith({
    bool? syncing,
    String? syncingLibraryId,
    bool clearSyncingLibraryId = false,
    Map<String, SharedLibrarySyncResult>? lastResults,
  }) => SharedLibrarySyncState(
    syncing: syncing ?? this.syncing,
    syncingLibraryId: clearSyncingLibraryId
        ? null
        : (syncingLibraryId ?? this.syncingLibraryId),
    lastResults: lastResults ?? this.lastResults,
  );
}

/// Runs club library syncs (issue #2567): on launch and resume under the
/// personal auto-sync preferences, after a debounce when a library site or
/// suggestion changes locally, and on Sync now. Every run goes through
/// [SyncCoordinator], so it never overlaps the personal sync.
class SharedLibrarySyncNotifier extends StateNotifier<SharedLibrarySyncState> {
  SharedLibrarySyncNotifier(this._ref) : super(const SharedLibrarySyncState()) {
    _changes = SyncEventBus.changes.listen((_) => _scheduleAutoSync());
  }

  final Ref _ref;
  final _log = LoggerService.forClass(SharedLibrarySyncNotifier);
  StreamSubscription<void>? _changes;
  Timer? _debounce;
  bool _inFlight = false;
  bool _queued = false;

  static const autoSyncDebounce = Duration(seconds: 5);

  SharedLibraryService get _service => _ref.read(sharedLibraryServiceProvider);
  SharedLibraryStore get _store => _ref.read(sharedLibraryStoreProvider);

  void _scheduleAutoSync() {
    final bool enabled;
    try {
      enabled = _ref.read(syncBehaviorProvider).autoSyncEnabled;
    } catch (e) {
      // Preferences not readable yet: the launch sync covers it.
      _log.debug('Auto sync skipped, preferences unavailable: $e');
      return;
    }
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(autoSyncDebounce, () async {
      if (!mounted) return;
      if (!await _hasLocalWork()) return;
      if (!mounted) return;
      await syncAll(auto: true);
    });
  }

  Future<bool> _hasLocalWork() async {
    for (final library in await _store.getLibraries()) {
      if ((await _store.dirtySites(library.id)).isNotEmpty) return true;
      final pending = await _store.suggestions(
        library.id,
        direction: SharedSiteSuggestion.outgoing,
        status: SharedSiteSuggestion.pending,
      );
      if (pending.isNotEmpty) return true;
    }
    return false;
  }

  /// Every library the active profile belongs to and that is connected on
  /// this device, one after the other. A call made while one runs is
  /// folded into one more run afterwards.
  Future<void> syncAll({bool auto = false}) async {
    if (_inFlight) {
      _queued = true;
      return;
    }
    _inFlight = true;
    try {
      do {
        _queued = false;
        await _syncAllOnce();
      } while (_queued && mounted);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _syncAllOnce() async {
    // Everything the Ref gives, read before the first await: the notifier
    // may be disposed during any of them, after which the Ref may not be
    // used (a queued run starts even later).
    final store = _store;
    final service = _service;
    final membershipService = _ref.read(sharedLibraryMembershipServiceProvider);
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    // A library the profile left on another device: its rows go here too.
    await membershipService.releaseOrphanedLibraries(
      fallbackOwnerDiverId: diverId,
    );
    if (!mounted) return;
    final memberships = await store.membershipsForDiver(diverId);
    final connected = {for (final l in await store.getLibraries()) l.id};
    if (!mounted) return;
    final results = Map<String, SharedLibrarySyncResult>.from(
      state.lastResults,
    );
    try {
      for (final m in memberships) {
        if (!connected.contains(m.libraryId) || !mounted) continue;
        state = state.copyWith(syncing: true, syncingLibraryId: m.libraryId);
        final result = await SyncCoordinator.run(
          () => service.sync(m.libraryId, diverId: diverId),
        );
        results[m.libraryId] = result;
        if (!result.isHealthy) {
          _log.warning(
            'Library ${m.libraryId} sync ended ${result.status}: '
            '${result.error}',
          );
        }
        if (!mounted) return;
        state = state.copyWith(lastResults: Map.unmodifiable(results));
      }
    } finally {
      // A throw must not leave Sync now disabled until the app restarts.
      if (mounted) {
        state = state.copyWith(syncing: false, clearSyncingLibraryId: true);
      }
    }
  }

  /// One library, now.
  Future<SharedLibrarySyncResult> syncOne(String libraryId) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) {
      return const SharedLibrarySyncResult(
        status: SharedLibrarySyncStatus.notConnected,
      );
    }
    final service = _service;
    state = state.copyWith(syncing: true, syncingLibraryId: libraryId);
    try {
      final result = await SyncCoordinator.run(
        () => service.sync(libraryId, diverId: diverId),
      );
      if (mounted) {
        state = state.copyWith(
          lastResults: Map.unmodifiable({
            ...state.lastResults,
            libraryId: result,
          }),
        );
      }
      return result;
    } finally {
      if (mounted) {
        state = state.copyWith(syncing: false, clearSyncingLibraryId: true);
      }
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

final sharedLibrarySyncProvider =
    StateNotifierProvider<SharedLibrarySyncNotifier, SharedLibrarySyncState>(
      SharedLibrarySyncNotifier.new,
    );
