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

  /// Completes when a read finishes, for a queued edit waiting on reads;
  /// null while none is waiting.
  Completer<void>? _readFinished;

  /// Whether `state` is known to match storage.
  ///
  /// False until a read publishes, and false again after a write fails (it
  /// can fail after changing the settings row, as the pending-sync mark
  /// comes second) or a re-read fails (it may have been reading a change
  /// synced from another device): either way storage may hold a value state
  /// does not. An edit built on an unknown base could save stale axes over
  /// it.
  bool _baseKnown = false;

  /// The newest successful read not yet published.
  ///
  /// It waits while a newer read is still in flight, and is kept because that
  /// newer one can still FAIL: a failed read decides nothing, so this value
  /// is then the freshest thing storage gave.
  ({int seq, EquipmentArrangement? stored})? _bestRead;

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
    _readFinished?.complete();
    _readFinished = null;
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
      // queued edit re-check whether any read that matters is still out.
      _readFinished?.complete();
      _readFinished = null;
    }
  }

  /// Waits until the launch read has decided and no re-read is still out.
  ///
  /// A queued edit builds on `state`, so it must not run while a read that
  /// may replace `state` is in flight: after launch that is a change synced
  /// from another device, and building on the pre-sync state would write
  /// the old axes back over the synced ones.
  ///
  /// Only reads newer than the last one published can still change state
  /// (an older one landing later is dropped), so an older read that stalls
  /// does not hold up an edit.
  Future<void> _readsSettled() async {
    await loaded;
    while (mounted && _readsInFlight.any((seq) => seq > _publishedLoadSeq)) {
      await (_readFinished ??= Completer<void>()).future;
    }
  }

  Future<void> _read(int seq) async {
    try {
      final stored = await _repository.getEquipmentArrangement();
      // Kept as the best candidate if it is the newest success so far. It
      // publishes below only once no newer read is still out: that one owns
      // the outcome, and settling [loaded] early would resume an awaiting
      // caller on a value that is about to be replaced.
      if (seq > (_bestRead?.seq ?? 0)) _bestRead = (seq: seq, stored: stored);
    } catch (e, stackTrace) {
      // The repository rethrows a read that fails (and logs it), as distinct
      // from returning null for "nothing usable stored". Keep what is loaded
      // rather than failing: a gear list that will not render is far worse.
      // "Could not read" decides nothing, so a failed read leaves no
      // candidate and never supersedes another read.
      _log.error(
        'Failed to load equipment arrangement',
        error: e,
        stackTrace: stackTrace,
      );
      // What is on screen stays, but it may now be behind storage: a tick
      // can follow a change synced from another device. Mark it unknown so
      // the next edit reads again rather than save stale axes over the
      // synced ones. A failure older than what already published says
      // nothing newer than that read did, so it leaves the base alone.
      if (seq > _publishedLoadSeq) _baseKnown = false;
    }
    _readsInFlight.remove(seq);
    _decideLoad();
  }

  /// Settles what the reads so far have told us, after any read finishes.
  ///
  /// The newest successful read publishes once no newer read is still in
  /// flight, whichever order they landed in; an older success arriving later
  /// is dropped. With no success to publish and nothing left in flight,
  /// whatever is already published stands and [loaded] settles on it.
  void _decideLoad() {
    final best = _bestRead;
    if (best != null) {
      if (_readsInFlight.any((other) => other > best.seq)) return;
      _bestRead = null;
      if (best.seq > _publishedLoadSeq) {
        _publishedLoadSeq = best.seq;
        // A successful read of null means the key is absent or its blob was
        // unreadable, which is exactly what a fresh launch would find, and a
        // launch shows the defaults. Keeping the loaded value here would
        // leave the session showing an arrangement storage no longer has,
        // and the diver would get the defaults on next launch anyway. A read
        // that THREW is different and never becomes a candidate: "could not
        // read" is not "nothing stored", so it keeps what is already loaded.
        if (mounted) state = best.stored ?? EquipmentArrangement.defaults;
        _baseKnown = true;
      }
      _settleFirstLoad();
      return;
    }
    if (_readsInFlight.isEmpty) _settleFirstLoad();
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
  ///   on what storage actually holds and the failure cannot ride along;
  /// - if no read has ever succeeded, or the last write failed (possibly
  ///   after changing the row), state is not known to match storage, so it
  ///   reads again and refuses the change if storage cannot say.
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
      // When state is not known to match storage (no read has succeeded, or
      // the last write failed, possibly after changing the row), building
      // on it could save stale axes over the stored ones: the defaults over
      // a customization, or the old value over a half-written change. Read
      // again first, and refuse the change if storage still cannot say what
      // it holds.
      if (!_baseKnown) {
        await _load();
        await _readsSettled();
        if (!mounted) return;
        if (!_baseKnown) {
          throw StateError(
            'The stored gear arrangement could not be read, so a change '
            'cannot be applied to it',
          );
        }
      }
      final next = change(state);
      try {
        await _repository.setEquipmentArrangement(next);
      } catch (_) {
        _baseKnown = false;
        rethrow;
      }
      if (mounted) state = next;
    });
    // The queue must keep moving after a failure; the caller still sees it
    // through the returned future.
    _writes = step.then((_) {}, onError: (Object _) {});
    return step;
  }
}
