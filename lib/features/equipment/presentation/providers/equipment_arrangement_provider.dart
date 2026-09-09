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

  /// Identifies the most recently STARTED read.
  ///
  /// The settings subscription fires a read per tick without awaiting the
  /// previous one, so several can be in flight at once and they are not
  /// guaranteed to finish in the order they began. Only the newest read is
  /// allowed to publish, so a slow earlier one cannot overwrite a fresher
  /// value with a stale one.
  int _loadSeq = 0;

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
    // Nothing further will publish, so release anyone still awaiting rather
    // than leaving them hanging on a notifier that is gone.
    _settleFirstLoad();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    EquipmentArrangement? stored;
    try {
      stored = await _repository.getEquipmentArrangement();
    } catch (e, stackTrace) {
      // The repository logs and swallows its own read errors, so this only
      // fires when the read could not be attempted at all. Keep the defaults
      // rather than failing: the diver falls back to the default arrangement,
      // which is a far better outcome than a gear list that will not render.
      _log.error(
        'Failed to load equipment arrangement',
        error: e,
        stackTrace: stackTrace,
      );
      // Decisive for an awaiting caller: no value is coming from this read,
      // and whatever is already published stands.
      _settleFirstLoad();
      return;
    }
    // A newer read started while this one was in flight; that one owns the
    // outcome, whether or not it has landed yet, and it is the one that will
    // settle [loaded]. Settling here would resume an awaiting caller on a
    // value this load is not allowed to publish.
    if (seq != _loadSeq) return;
    // A successful read of null means the key is absent or its blob was
    // unreadable, which is exactly what a fresh launch would find, and a
    // launch shows the defaults. Keeping the loaded value here would leave
    // the session showing an arrangement storage no longer has, and the
    // diver would get the defaults on next launch anyway. A read that THREW
    // is different and returned above: "could not read" is not "nothing
    // stored", so that path keeps what is already loaded.
    if (mounted) state = stored ?? EquipmentArrangement.defaults;
    _settleFirstLoad();
  }

  /// Persists [arrangement] and updates state.
  ///
  /// State moves only after the write succeeds, so a failed save does not
  /// leave the diver looking at an order that will be gone on next launch.
  /// Rethrows so the caller can surface the failure.
  Future<void> setArrangement(EquipmentArrangement arrangement) async {
    await _repository.setEquipmentArrangement(arrangement);
    if (mounted) state = arrangement;
  }
}
