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
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_tryout_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trim figure's part of the Weights and buoyancy card (issue #5028):
/// the logged rig in the standard pose at the profile cursor (the model's
/// final stop with no cursor), with its gauges.
///
/// [stored] is the saved dive, as the model reads it, so nothing typed in a
/// sitting reworks the figure before Save.
class TrimCardSection extends ConsumerStatefulWidget {
  const TrimCardSection({
    super.key,
    required this.stored,
    required this.outcome,
    required this.units,
  });

  final Dive stored;
  final BuoyancyTwinOutcome outcome;
  final UnitFormatter units;

  @override
  ConsumerState<TrimCardSection> createState() => _TrimCardSectionState();
}

class _TrimCardSectionState extends ConsumerState<TrimCardSection> {
  TrimSceneBase? _base;

  /// The base for this dive, outcome and body, rebuilt only when one of them
  /// changes, so scrubbing the cursor does not recompose the gear.
  TrimSceneBase _baseFor(double? height, double? mass) {
    final b = _base;
    if (b != null &&
        identical(b.dive, widget.stored) &&
        identical(b.outcome, widget.outcome) &&
        b.heightCm == height &&
        b.bodyMassKg == mass) {
      return b;
    }
    return _base = TrimSceneBase(
      dive: widget.stored,
      outcome: widget.outcome,
      heightCm: height,
      bodyMassKg: mass,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = ref.watch(latestDiverHeightProvider).value;
    final mass = ref.watch(latestDiverWeightProvider).value?.weightKg;
    final profile = watchChartProfile(ref, widget.stored);
    final cursor = ref.watch(profileTrackingIndexProvider(widget.stored.id));
    final seconds = cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;
    final base = _baseFor(height, mass);
    TrimScene sceneAt(int? t) => base.at(t);
    final scene = sceneAt(seconds);
    final result = scene.trimIn(TrimPose.standard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TrimFigure(
          scene: scene,
          pose: TrimPose.standard,
          result: result,
          units: widget.units,
        ),
        const SizedBox(height: 8),
        TrimGauges(result: result),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            icon: const Icon(Icons.open_with),
            label: Text(context.l10n.trim_tryout_button),
            onPressed: () => showTrimTryoutSheet(
              context,
              sceneAt: sceneAt,
              openingTimestamp: seconds,
              moments: [
                for (final s in widget.outcome.result.samples)
                  TrimMoment(timestamp: s.timestamp, depthM: s.depthM),
              ],
              units: widget.units,
            ),
          ),
        ),
      ],
    );
  }
}
