import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_condition_refresher.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

/// What a findings pass needs from the diver's settings, read once per
/// pass so every item is fingerprinted against the same thresholds.
class ConditionPassInputs {
  final String? diverId;
  final ExposureThresholds thresholds;
  final bool engineEnabled;

  const ConditionPassInputs({
    required this.diverId,
    required this.thresholds,
    required this.engineEnabled,
  });
}

/// Outcome of an [EquipmentFindingsPass.run].
class EquipmentFindingsPassResult {
  /// Items visited, including those that failed.
  final int items;

  /// Items whose refresh threw. Their marker stays stale and they
  /// recompute lazily on first view.
  final int failed;

  /// True when the caller's isCancelled callback stopped the pass early.
  final bool cancelled;

  const EquipmentFindingsPassResult({
    required this.items,
    required this.failed,
    required this.cancelled,
  });

  static const empty = EquipmentFindingsPassResult(
    items: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Brings every active item's condition findings up to date through the
/// review marker, one item at a time. Shared by the settings sweep and
/// the sensor summary scheduler so both visit the same gear the same way.
/// An unchanged item still has its inputs read, since that is how the
/// fingerprint is built, but it runs no engine and writes nothing.
class EquipmentFindingsPass {
  final EquipmentRepository _equipment;
  final EquipmentConditionRefresher _refresher;

  /// The default refresher is built from the SAME repository this pass
  /// visits gear with. Defaulting each field on its own made two of them
  /// whenever neither was passed, which is two sets of watch streams and
  /// two things to reason about for no gain.
  ///
  /// [requestSummaries] reaches the default refresher, which calls it with
  /// the exposed dives that have no current sensor summary, so a pass run
  /// off any item page can still get them built.
  factory EquipmentFindingsPass({
    EquipmentRepository? equipment,
    EquipmentConditionRefresher? refresher,
    void Function(Set<String> diveIds)? requestSummaries,
  }) {
    final repository = equipment ?? EquipmentRepository();
    return EquipmentFindingsPass._(
      repository,
      refresher ??
          EquipmentConditionRefresher(
            equipment: repository,
            observations: EquipmentObservationRepository(),
            incidents: IncidentRepository(),
            transmitters: TransmitterRepository(),
            summaries: DiveSensorSummaryRepository(),
            findings: EquipmentFindingsRepository(),
            requestSummaries: requestSummaries,
          ),
    );
  }

  EquipmentFindingsPass._(this._equipment, this._refresher);

  /// The gear a pass visits: active, not retired, scoped to [diverId] when
  /// given. Loaded separately from [run] so a caller can size a progress
  /// bar before starting.
  Future<List<EquipmentItem>> activeItems({String? diverId}) =>
      _equipment.getActiveEquipment(diverId: diverId);

  /// The items named by [ids] that still exist, for a pass over just
  /// the gear a write touched. With [diverId], only that diver's, as
  /// [activeItems] scopes them: the pass runs with one diver's thresholds,
  /// and must not recompute another diver's gear with them.
  Future<List<EquipmentItem>> itemsById(
    Iterable<String> ids, {
    String? diverId,
  }) async => [
    for (final id in ids)
      if (await _equipment.getEquipmentById(id) case final item?
          when diverId == null || item.diverId == diverId)
        item,
  ];

  /// Visits [items] in order. [onProgress] fires once with (0, total),
  /// then after each item. [isCancelled] is polled before each item.
  Future<EquipmentFindingsPassResult> run({
    required List<EquipmentItem> items,
    required ExposureThresholds thresholds,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = items.length;
    onProgress?.call(0, total);
    var done = 0;
    var failed = 0;
    for (final item in items) {
      if (isCancelled?.call() ?? false) {
        return EquipmentFindingsPassResult(
          items: done,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        await _refresher.ensureCurrentItem(
          item,
          thresholds: thresholds,
          engineEnabled: true,
        );
      } catch (_) {
        // One item's bad evidence must not abort the pass; it is counted
        // so the caller can say so, and recomputes lazily on first view.
        failed++;
      }
      done++;
      onProgress?.call(done, total);
    }
    return EquipmentFindingsPassResult(
      items: done,
      failed: failed,
      cancelled: false,
    );
  }

  /// The active diver's pass inputs, read without Riverpod for the
  /// scheduler. Read-only on purpose: a diver with no settings row gets
  /// the same defaults the app would show them, and no row is minted.
  static Future<ConditionPassInputs> loadActiveDiverInputs() async {
    final diverId = await DiverRepository().getActiveDiverIdFromSettings();
    final stored = diverId == null
        ? null
        : await DiverSettingsRepository().getSettingsForDiver(diverId);
    final settings = stored ?? const AppSettings();
    return ConditionPassInputs(
      diverId: diverId,
      thresholds: exposureThresholdsFromSettings(settings),
      engineEnabled: settings.conditionEngineEnabled,
    );
  }
}
