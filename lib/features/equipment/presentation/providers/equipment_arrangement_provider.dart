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
    loaded = _load();
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

  /// Completes when the stored value has been read. Exposed for tests; the UI
  /// does not await it because the defaults are already a valid state.
  late final Future<void> loaded;

  @override
  void dispose() {
    _settingsSubscription?.cancel();
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
      return;
    }
    // A newer read started while this one was in flight; that one owns the
    // outcome, whether or not it has landed yet.
    if (seq != _loadSeq) return;
    if (stored != null && mounted) state = stored;
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
