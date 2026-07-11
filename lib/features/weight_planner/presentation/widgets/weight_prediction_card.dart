import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Renders a weight prediction: big total, suggested placement, confidence
/// line, transient delta chip, and the expandable term-by-term breakdown.
class WeightPredictionCard extends StatelessWidget {
  final WeightPrediction prediction;
  final Map<String, double>? placement;
  final UnitFormatter units;
  final String? deltaText;

  const WeightPredictionCard({
    super.key,
    required this.prediction,
    this.placement,
    required this.units,
    this.deltaText,
  });

  String _confidenceLabel(BuildContext context) =>
      switch (prediction.confidence) {
        PredictionConfidence.high => context.l10n.tools_weight_confidence_high,
        PredictionConfidence.medium =>
          context.l10n.tools_weight_confidence_medium,
        PredictionConfidence.low => context.l10n.tools_weight_confidence_low,
      };

  String _sourceLabel(BuildContext context, TermSource source) =>
      switch (source) {
        TermSource.measured => context.l10n.tools_weight_source_measured,
        TermSource.userSpec => context.l10n.tools_weight_source_userSpec,
        TermSource.typeDefault => context.l10n.tools_weight_source_typeDefault,
        TermSource.physics => context.l10n.tools_weight_source_physics,
      };

  String _termLabel(BuildContext context, PredictionTerm term) {
    if (term.label == 'personal') {
      return context.l10n.tools_weight_personalTerm;
    }
    if (term.label == 'water') return context.l10n.tools_weight_waterTerm;
    return term.label;
  }

  String _placementLabel(String weightTypeName) {
    final type = WeightType.values
        .where((t) => t.name == weightTypeName)
        .firstOrNull;
    return type?.displayName ?? weightTypeName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tools_weight_predictedWeight,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  units.formatWeight(prediction.totalKg),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (deltaText != null) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        context.l10n.tools_weight_deltaVsPrevious(deltaText!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '${_confidenceLabel(context)} · '
              '${context.l10n.tools_weight_basedOnDives(prediction.supportingDives)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            if (placement != null && placement!.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.tools_weight_placementTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              for (final entry in placement!.entries)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _placementLabel(entry.key),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      units.formatWeight(entry.value),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 4),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.tools_weight_breakdownTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                children: [
                  for (final term in prediction.terms)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_termLabel(context, term)} '
                              '(${_sourceLabel(context, term.source)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Text(
                            (term.kg >= 0 ? '+' : '') +
                                units.formatWeight(term.kg),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
