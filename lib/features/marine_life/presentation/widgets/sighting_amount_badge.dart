import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/presentation/sighting_abundance_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The pill beside a sighting that says how many animals it records:
/// nothing for Seen, `x<n>` for an exact count, or the REEF group's name.
class SightingAmountBadge extends StatelessWidget {
  final SightingAmount amount;

  const SightingAmountBadge({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final label = sightingAmountLabel(context.l10n, amount);
    if (label == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
