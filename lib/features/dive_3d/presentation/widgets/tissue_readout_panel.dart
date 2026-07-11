import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/tissue/tissue_replay_result.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Live tissue readout at the scrub instant: the controlling compartment,
/// its supersaturation %, and per-gas loading. Listens to the frame-rate
/// ValueListenable directly so scrubbing never rebuilds the page tree.
class TissueReadoutPanel extends StatelessWidget {
  final TissueReplayResult result;
  final ValueListenable<double> position;
  final bool splitHelium;

  const TissueReadoutPanel({
    super.key,
    required this.result,
    required this.position,
    required this.splitHelium,
  });

  int _columnAt(double normalized) {
    if (result.columnCount == 0) return 0;
    final total = result.totalClockSeconds <= 0
        ? 1.0
        : result.totalClockSeconds;
    final t = (normalized.clamp(0.0, 1.0)) * total;
    // Nearest column by chain-clock time.
    var lo = 0, hi = result.times.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (result.times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (t - result.times[lo]).abs() <= (result.times[hi] - t).abs()
        ? lo
        : hi;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final col = _columnAt(value);
        final comp = result.controlling[col];
        final pctM = (result.gradient(col, comp) * 100).clamp(0, 999);
        final parts = <String>[
          '${context.l10n.dive3d_tissue_controlling}: #${comp + 1}',
          '${pctM.toStringAsFixed(0)}% M',
        ];
        if (result.isSurface[col]) {
          parts.insert(0, context.l10n.dive3d_tissue_surfaceInterval);
        }
        if (splitHelium && result.hasHelium) {
          parts.add('N2 ${result.loadingN2(col, comp).toStringAsFixed(2)}');
          parts.add('He ${result.loadingHe(col, comp).toStringAsFixed(2)}');
        } else {
          parts.add('${result.combined(col, comp).toStringAsFixed(2)} bar');
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              parts.join('   '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}
