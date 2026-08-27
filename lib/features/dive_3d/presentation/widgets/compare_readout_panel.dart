import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/profile_resampler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Live comparison readout at the scrub instant. Listens to the frame-rate
/// ValueListenable directly (not via Riverpod) so playback never rebuilds the
/// tree above it. Shows each profile's depth and its delta from the reference.
class CompareReadoutPanel extends ConsumerWidget {
  final List<ComparisonProfile> profiles;
  final int referenceIndex;
  final ValueListenable<double> position;
  final double durationSeconds;

  const CompareReadoutPanel({
    super.key,
    required this.profiles,
    required this.referenceIndex,
    required this.position,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final t = value * durationSeconds;
        final refDepth = profiles.isEmpty
            ? 0.0
            : ProfileResampler.depthAt(profiles[referenceIndex], t);
        final totalSeconds = t.round();
        final minutes = totalSeconds ~/ 60;
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$minutes:$seconds', style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                for (var i = 0; i < profiles.length; i++)
                  _line(theme, units, i, t, refDepth),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(
    ThemeData theme,
    UnitFormatter units,
    int i,
    double t,
    double refDepth,
  ) {
    final p = profiles[i];
    final depth = ProfileResampler.depthAt(p, t);
    final isRef = i == referenceIndex;
    final delta = depth - refDepth;
    final deltaText = isRef
        ? ''
        : '  (${delta >= 0 ? '+' : '-'}${units.formatDepth(delta.abs())})';
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${p.label}  ${units.formatDepth(depth)}$deltaText',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
