import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/services/condition_trend_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

/// Family key: the item and, for a page that shows more than one chart
/// (a rebreather's cells and its scrubber), which trend. Null kind means
/// the type's default.
typedef ConditionTrendKey = ({String equipmentId, ConditionTrendKind? kind});

/// The per-dive series for the item's condition chart, from the same
/// samples, summaries and check-ins the engine reads. Null when the type
/// has no trend or the item does not exist. Rebuilds through the exposure
/// inputs provider (equipment and dive detail streams) and the
/// observations provider.
final conditionTrendProvider =
    FutureProvider.family<ConditionTrend?, ConditionTrendKey>((ref, key) async {
      final inputs = await ref.watch(
        equipmentExposureInputsProvider(key.equipmentId).future,
      );
      if (inputs == null) return null;
      final kind = key.kind ?? defaultConditionTrendKind(inputs.item.type);
      if (kind == null) return null;
      final observations = await ref.watch(
        observationsForEquipmentProvider(key.equipmentId).future,
      );
      final summaries = await ref
          .watch(diveSensorSummaryRepositoryProvider)
          .getSummaries([for (final s in inputs.samples) s.diveId]);
      final serials = inputs.item.type == EquipmentType.transmitter
          ? await ref
                .watch(transmitterRepositoryProvider)
                .getSerialsForEquipment(key.equipmentId)
          : const <String>{};
      return buildConditionTrend(
        item: inputs.item,
        parent: inputs.parent,
        samples: inputs.samples,
        summariesByDive: summaries,
        observations: observations,
        transmitterSerials: serials,
        kind: kind,
      );
    });

/// The finding whose evidence window the chart shades. Toggled by the
/// findings card; null when nothing is selected.
final selectedConditionFindingProvider =
    StateProvider.family<EquipmentFinding?, String>((ref, equipmentId) => null);
