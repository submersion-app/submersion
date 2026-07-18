import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// One historical dive's carried-versus-modeled lead comparison.
class BuoyancyHistoryEntry {
  final String diveId;
  final DateTime diveDateTime;
  final double carriedKg;
  final double idealKg;
  final String? feedback;
  const BuoyancyHistoryEntry({
    required this.diveId,
    required this.diveDateTime,
    required this.carriedKg,
    required this.idealKg,
    this.feedback,
  });
}

/// Carried-vs-modeled lead across the most recent (up to 10) weight-bearing
/// dives that share the current dive's exposure-suit item. Oldest first.
///
/// Cross-dive lookbacks use `ref.read` (not watch) so loading many dives does
/// not wire this provider to every one of their change streams.
final buoyancyHistoryProvider =
    FutureProvider.family<List<BuoyancyHistoryEntry>, String>((
      ref,
      currentDiveId,
    ) async {
      final currentDive = await ref.watch(diveProvider(currentDiveId).future);
      final model = await ref.watch(weightCalibrationProvider.future);
      final observations = await ref.watch(weightObservationsProvider.future);
      final latestWeight = await ref.watch(latestDiverWeightProvider.future);

      final suitId = currentDive?.equipment
          .where(
            (e) =>
                e.type == EquipmentType.wetsuit ||
                e.type == EquipmentType.drysuit,
          )
          .map((e) => e.id)
          .firstOrNull;

      final matching = observations
          .where((o) => o.diveId != currentDiveId)
          .where((o) => suitId == null || o.equipmentIds.contains(suitId))
          .toList();
      final recent = matching.length > 10
          ? matching.sublist(matching.length - 10)
          : matching;

      final entries = <BuoyancyHistoryEntry>[];
      for (final obs in recent) {
        final dive = await ref.read(diveProvider(obs.diveId).future);
        if (dive == null) continue;
        final profile = await ref.read(diveProfileProvider(obs.diveId).future);
        final tankPressures = await ref.read(
          tankPressuresProvider(obs.diveId).future,
        );
        final input = BuoyancyTwinAssembler.assemble(
          dive: dive.copyWith(profile: profile),
          tankPressures: tankPressures,
          model: model,
          bodyWeightKg: latestWeight?.weightKg,
        );
        if (input == null) continue;
        final outputs = TwinAnalyzer.analyze(runBuoyancyTwin(input));
        entries.add(
          BuoyancyHistoryEntry(
            diveId: obs.diveId,
            diveDateTime: obs.diveDateTime,
            carriedKg: obs.carriedKg,
            idealKg: outputs.idealLeadKg,
            feedback: obs.feedback,
          ),
        );
      }
      return entries;
    });
