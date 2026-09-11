import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's gear arrangement, shared by every surface that lists the gear
/// on a dive (#1486, #1576).
///
/// One preference rather than one per surface: the diver sets how they like
/// to read their rig once, and the dive view, the edit form, the picker, the
/// equipment sets and the printed logbook all honour it.
final equipmentArrangementNotifierProvider =
    StateNotifierProvider<EquipmentArrangementNotifier, EquipmentArrangement>((
      ref,
    ) {
      return EquipmentArrangementNotifier(
        ref.watch(appSettingsRepositoryProvider),
      );
    });

/// Convenience alias for surfaces that only read.
final equipmentArrangementProvider = Provider<EquipmentArrangement>((ref) {
  return ref.watch(equipmentArrangementNotifierProvider);
});

/// Owns the persisted gear arrangement.
///
/// Starts at [EquipmentArrangement.defaults] synchronously and adopts the
/// stored value when the read completes, so no surface has to render an
/// AsyncValue for what is only a display preference. The same shape as
/// `NavOrderNotifier`, which persists nav order through the same key-value
/// settings table.
class EquipmentArrangementNotifier extends StateNotifier<EquipmentArrangement> {
  EquipmentArrangementNotifier(this._repository)
    : super(EquipmentArrangement.defaults) {
    _load();
    // A change arriving from sync ticks the settings table. Re-read so an
    // arrangement chosen on a phone reaches an open desktop without a
    // restart. The tick fires for every settings key, not just this one, so
    // this re-reads more often than strictly needed; the read is a single
    // indexed row and state only changes when the value does, so an unrelated
    // tick costs one query and no rebuild.
    _settingsSubscription = _repository.watchSettingsChanges().listen((_) {
      _load();
    });
  }

  static final _log = LoggerService.forClass(EquipmentArrangementNotifier);

  final AppSettingsRepository _repository;

  StreamSubscription<void>? _settingsSubscription;

  /// Numbers each read in the order it STARTED.
  ///
  /// The settings subscription fires a read per tick without awaiting the
  /// previous one, so several can be in flight at once and they are not
  /// guaranteed to finish in the order they began. A read publishes only
  /// when no newer read is still out, so a slow earlier one cannot overwrite
  /// a fresher value with a stale one.
  int _loadSeq = 0;

  /// Reads started and not yet finished.
  final Set<int> _readsInFlight = {};

  /// The newest read that has published, so an older one landing later is
  /// dropped.
  int _publishedLoadSeq = 0;

  /// Completes when the reads in flight drain, for a queued edit waiting on
  /// them; null while none is waiting.
  Completer<void>? _readsDrained;

  /// A successful read that stood aside for a newer one still in flight.
  ///
  /// Kept because the newer one can still FAIL, and a failed read decides
  /// nothing: this value is then the freshest thing storage gave.
  ({int seq, EquipmentArrangement? stored})? _deferredRead;

  final Completer<void> _firstLoad = Completer<void>();

  /// Completes once a load has actually DECIDED the arrangement.
  ///
  /// Not simply the first `_load()` future: the sequence guard makes a
  /// superseded load return without publishing, so binding to that future
  /// would let an awaiting caller resume while the state was still the
  /// defaults. It settles when a load publishes, when a read fails and the
  /// current state therefore stands, or on dispose so nobody hangs.
  ///
  /// Screens do not await it: they start on the defaults and rebuild when the
  /// stored value lands, which is invisible. A one-shot consumer must await
  /// it, because for them "not loaded yet" is indistinguishable from "the
  /// diver chose the defaults" and the difference is baked into the output.
  /// The PDF export path does exactly that.
  Future<void> get loaded => _firstLoad.future;

  /// Marks the first load decided. Idempotent: later loads settle nothing new.
  void _settleFirstLoad() {
    if (!_firstLoad.isCompleted) _firstLoad.complete();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    // Release a queued edit waiting on reads that will no longer publish.
    _readsDrained?.complete();
    _readsDrained = null;
    // Nothing further will publish, so release anyone still awaiting rather
    // than leaving them hanging on a notifier that is gone.
    _settleFirstLoad();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    _readsInFlight.add(seq);
    try {
      await _read(seq);
    } finally {
      // Every path out of a read, published, deferred or failed, lets a
      // queued edit re-check whether storage has finished speaking.
      if (_readsInFlight.isEmpty) {
        _readsDrained?.complete();
        _readsDrained = null;
      }
    }
  }

  /// Waits until the launch read has decided and no re-read is still out.
  ///
  /// A queued edit builds on `state`, so it must not run while a read that
  /// may replace `state` is in flight: after launch that is a change synced
  /// from another device, and building on the pre-sync state would write
  /// the old axes back over the synced ones.
  Future<void> _readsSettled() async {
    await loaded;
    while (_readsInFlight.isNotEmpty && mounted) {
      await (_readsDrained ??= Completer<void>()).future;
    }
  }

  Future<void> _read(int seq) async {
    EquipmentArrangement? stored;
    try {
      stored = await _repository.getEquipmentArrangement();
    } catch (e, stackTrace) {
      _readsInFlight.remove(seq);
      // The repository logs and swallows its own read errors, so this only
      // fires when the read could not be attempted at all. Keep the defaults
      // rather than failing: the diver falls back to the default arrangement,
      // which is a far better outcome than a gear list that will not render.
      _log.error(
        'Failed to load equipment arrangement',
        error: e,
        stackTrace: stackTrace,
      );
      // "Could not read" decides nothing, so it must not supersede another
      // read. While any read is still out, that one decides. Otherwise the
      // freshest read that stood aside publishes now, and failing that,
      // whatever is already published stands and [loaded] settles on it. An
      // edit queued behind [loaded] would otherwise build on the defaults.
      if (_readsInFlight.isNotEmpty) return;
      final deferred = _deferredRead;
      _deferredRead = null;
      if (deferred != null) {
        _publishLoad(deferred.seq, deferred.stored);
      } else {
        _settleFirstLoad();
      }
      return;
    }
    _readsInFlight.remove(seq);
    // A newer read started while this one was in flight; that one owns the
    // outcome, whether or not it has landed yet, and it is the one that will
    // settle [loaded]. Settling here would resume an awaiting caller on a
    // value this load is not allowed to publish. The value is kept, though,
    // in case the newer read fails.
    if (_readsInFlight.any((other) => other > seq)) {
      if (seq > (_deferredRead?.seq ?? 0)) {
        _deferredRead = (seq: seq, stored: stored);
      }
      return;
    }
    _publishLoad(seq, stored);
  }

  /// Publishes the result of read [seq] unless a newer read already has.
  void _publishLoad(int seq, EquipmentArrangement? stored) {
    if (seq > _publishedLoadSeq) {
      _publishedLoadSeq = seq;
      if (_deferredRead != null && _deferredRead!.seq <= seq) {
        _deferredRead = null;
      }
      // A successful read of null means the key is absent or its blob was
      // unreadable, which is exactly what a fresh launch would find, and a
      // launch shows the defaults. Keeping the loaded value here would leave
      // the session showing an arrangement storage no longer has, and the
      // diver would get the defaults on next launch anyway. A read that
      // THREW is different and never reaches here: "could not read" is not
      // "nothing stored", so that path keeps what is already loaded.
      if (mounted) state = stored ?? EquipmentArrangement.defaults;
    }
    _settleFirstLoad();
  }

  /// Runs arrangement changes one at a time, in the order they were asked
  /// for.
  ///
  /// Each change is computed when its turn comes, not when it is asked for:
  /// by then the stored arrangement has loaded and every earlier change has
  /// either published or failed, so `state` is exactly what storage holds.
  Future<void> _writes = Future<void>.value();

  /// Persists [arrangement] and updates state.
  Future<void> setArrangement(EquipmentArrangement arrangement) =>
      updateArrangement((_) => arrangement);

  /// Applies [change] to the stored arrangement, persists the result and
  /// updates state.
  ///
  /// The sort sheet stays open for several changes, so a second one can be
  /// asked for before the first write lands, and the sheet can even open
  /// before the launch read has loaded the stored arrangement. Both are why
  /// [change] is a function applied at its turn in the queue, after the
  /// first load and after every earlier change has settled:
  ///
  /// - it builds on the stored arrangement, never on the launch defaults, so
  ///   one edit cannot write the defaults over every axis it did not touch;
  /// - it builds on the previous change once that has landed, so quick
  ///   successive edits all survive;
  /// - a change whose write failed never published, so the next one builds
  ///   on what storage actually holds and the failure cannot ride along.
  ///
  /// State moves only after the write succeeds, so a failed save does not
  /// leave the diver looking at an order that will be gone on next launch.
  /// Rethrows so the caller can surface the failure.
  Future<void> updateArrangement(
    EquipmentArrangement Function(EquipmentArrangement current) change,
  ) {
    final step = _writes.then((_) async {
      await _readsSettled();
      if (!mounted) return;
      final next = change(state);
      await _repository.setEquipmentArrangement(next);
      if (mounted) state = next;
    });
    // The queue must keep moving after a failure; the caller still sees it
    // through the returned future.
    _writes = step.then((_) {}, onError: (Object _) {});
    return step;
  }
}
