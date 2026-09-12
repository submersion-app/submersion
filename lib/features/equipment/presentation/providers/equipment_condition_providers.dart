import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_condition_refresher.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

final equipmentFindingsRepositoryProvider =
    Provider<EquipmentFindingsRepository>(
      (ref) => EquipmentFindingsRepository(),
    );

final equipmentConditionRefresherProvider =
    Provider<EquipmentConditionRefresher>(
      (ref) => EquipmentConditionRefresher(
        equipment: ref.watch(equipmentRepositoryProvider),
        observations: ref.watch(equipmentObservationRepositoryProvider),
        incidents: ref.watch(incidentRepositoryProvider),
        transmitters: ref.watch(transmitterRepositoryProvider),
        summaries: ref.watch(diveSensorSummaryRepositoryProvider),
        findings: ref.watch(equipmentFindingsRepositoryProvider),
        requestSummaries: scheduleSensorSummaryRefresh,
      ),
    );

/// The item's condition findings, computed when its inputs changed and
/// served from the review marker otherwise. Null when the item does not
/// exist. Hidden rules are NOT filtered here; the display layer filters
/// by `AppSettings.conditionDisabledRules`, like the safety review.
///
/// Self-invalidates on every stream an input can arrive through: the
/// equipment and attribute tables (type, parent, cell slot, install
/// date), the transmitter registry (the serials the dropout rules match),
/// the observation, incident and findings tables, and the dive detail
/// stream (which carries the sensor summaries). A sync pull or a sweep
/// write therefore reaches an open item page without a restart.
final equipmentConditionProvider =
    FutureProvider.family<List<EquipmentFinding>?, String>((
      ref,
      equipmentId,
    ) async {
      final refresher = ref.watch(equipmentConditionRefresherProvider);
      ref.invalidateSelfWhen(
        ref.watch(equipmentRepositoryProvider).watchEquipmentChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(equipmentRepositoryProvider).watchAttributeChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(transmitterRepositoryProvider).watchTransmittersChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(equipmentObservationRepositoryProvider).watchChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(incidentRepositoryProvider).watchChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(equipmentFindingsRepositoryProvider).watchChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return refresher.ensureCurrent(
        equipmentId,
        thresholds: ref.watch(exposureThresholdsProvider),
        engineEnabled: ref.watch(conditionEngineEnabledProvider),
      );
    });

/// Dismisses or restores a finding. The repository bumps the parent
/// equipment row so the change syncs; the findings stream then refreshes
/// every open consumer.
Future<void> setConditionFindingDismissed(
  WidgetRef ref, {
  required EquipmentFinding finding,
  required bool dismissed,
}) async {
  await ref
      .read(equipmentFindingsRepositoryProvider)
      .setDismissed(
        findingId: finding.id,
        dismissed: dismissed,
        now: DateTime.now().toUtc(),
      );
  ref.invalidate(equipmentConditionProvider(finding.equipmentId));
}
