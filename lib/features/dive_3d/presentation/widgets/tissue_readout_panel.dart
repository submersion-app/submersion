import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Live tissue readout at the scrub instant, from the same DecoStatus series
/// as the 3D heat map: the leading (controlling) compartment and its
/// gradient factor toward the M-value limit. Listens to the frame-rate
/// ValueListenable directly so scrubbing never rebuilds the page tree.
class TissueReadoutPanel extends StatelessWidget {
  final List<DecoStatus> statuses;
  final ValueListenable<double> position;

  const TissueReadoutPanel({
    super.key,
    required this.statuses,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final idx = (value.clamp(0.0, 1.0) * (statuses.length - 1)).round();
        final status = statuses[idx];
        final leading = status.gf99LeadingCompartmentNumber;
        final gf = status.gf99.clamp(0, 999);
        final parts = <String>[
          '${context.l10n.dive3d_tissue_controlling}: #$leading',
          'GF ${gf.toStringAsFixed(0)}%',
        ];
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
