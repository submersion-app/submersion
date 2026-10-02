import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Explains why the Gas consumption by segment card has no segments: the dive
/// recorded only start and end tank pressures (issue #2505).
///
/// Shown in place of the segment list, styled like `SacVolumeHint`, so a diver
/// who turned the section on sees the reason rather than a missing card.
class SacSegmentsNoPressureNote extends StatelessWidget {
  const SacSegmentsNoPressureNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.diveLog_detail_sacSegmentsNoPressure,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
