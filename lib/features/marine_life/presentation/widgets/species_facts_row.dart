import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The facts under a species' hero (issue #5027): dives, sites, first and
/// last seen, and its rarity badge.
class SpeciesFactsRow extends ConsumerWidget {
  const SpeciesFactsRow({super.key, required this.insights, this.rarity});

  final SpeciesInsights insights;
  final SpeciesRarity? rarity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.marineLife_speciesDetail_noSightings,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final units = ref.watch(unitFormatterProvider);
    final rarity = this.rarity;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Fact(
          label: l10n.marineLife_speciesDetail_divesLabel,
          value: '${insights.diveCount}',
        ),
        _Fact(
          label: l10n.marineLife_speciesDetail_sitesLabel,
          value: '${insights.siteCount}',
        ),
        _Fact(
          label: l10n.marineLife_speciesDetail_firstSeenLabel,
          value: units.formatDate(insights.firstSeen),
        ),
        _Fact(
          label: l10n.marineLife_speciesDetail_lastSeenLabel,
          value: units.formatDate(insights.lastSeen),
        ),
        if (rarity != null)
          Chip(
            label: Text(rarityLabel(l10n, rarity)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
