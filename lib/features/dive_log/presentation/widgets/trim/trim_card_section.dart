import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_gauges.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';

/// The trim figure's part of the Weights and buoyancy card (issue #5028):
/// the logged rig in the standard pose at the profile cursor (the model's
/// final stop with no cursor), with its gauges.
///
/// [stored] is the saved dive, as the model reads it, so nothing typed in a
/// sitting reworks the figure before Save.
class TrimCardSection extends ConsumerWidget {
  const TrimCardSection({
    super.key,
    required this.stored,
    required this.outcome,
    required this.units,
    this.trailing,
  });

  final Dive stored;
  final BuoyancyTwinOutcome outcome;
  final UnitFormatter units;

  /// Shown under the gauges (the "Try placements" button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = ref.watch(latestDiverHeightProvider).value;
    final mass = ref.watch(latestDiverWeightProvider).value?.weightKg;
    final profile = watchChartProfile(ref, stored);
    final cursor = ref.watch(profileTrackingIndexProvider(stored.id));
    final seconds = cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;
    final scene = buildTrimScene(
      dive: stored,
      outcome: outcome,
      timestamp: seconds,
      heightCm: height,
      bodyMassKg: mass,
    );
    final result = scene.trimIn(TrimPose.standard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TrimFigure(
          scene: scene,
          pose: TrimPose.standard,
          result: result,
          units: units,
        ),
        const SizedBox(height: 8),
        TrimGauges(result: result),
        ?trailing,
      ],
    );
  }
}
