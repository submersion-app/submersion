import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Live metric readout at the scrub instant. Listens to the frame-rate
/// ValueListenable directly (NOT via Riverpod) so playback never rebuilds
/// the page tree above it. Interpolates the FULL-resolution series;
/// geometry decimation never affects readouts.
class SceneReadoutPanel extends ConsumerWidget {
  final Dive3dSceneData data;
  final ValueListenable<double> position;

  const SceneReadoutPanel({
    super.key,
    required this.data,
    required this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final lookup = ProfileLookup(data.times);
    // Cache the nullable-depth view once: the builder below runs at frame rate
    // during playback, so allocating a CastList per tick is avoidable.
    final nullableDepths = data.depths.cast<double?>();
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final t = value * data.durationSeconds;
        double? at(List<double?> series) => lookup.interpolate(series, t);
        final depth = at(nullableDepths);
        final temp = at(data.temperatures);
        final ascent = at(data.ascentRates);
        final ppO2 = at(data.ppO2s);
        final cns = at(data.cnss);
        final entries = <String>[
          if (depth != null) units.formatDepth(depth),
          if (temp != null) units.formatTemperature(temp),
          if (ascent != null)
            '${units.convertDepth(ascent).toStringAsFixed(1)} ${units.depthSymbol}/min',
          if (ppO2 != null) 'ppO2 ${ppO2.toStringAsFixed(2)}',
          if (cns != null) 'CNS ${cns.toStringAsFixed(0)}%',
        ];
        final totalSeconds = t.round();
        final minutes = totalSeconds ~/ 60;
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '$minutes:$seconds  ${entries.join('   ')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}
