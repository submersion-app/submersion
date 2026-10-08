import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The common-factors table: the group against its baseline, grouped by
/// kind, with standouts flagged and summarised above.
class FocusFactorsTable extends ConsumerWidget {
  const FocusFactorsTable({super.key, required this.report});

  final FocusFactorReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    if (report.tooFewDives) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.insights_focus_factors_tooFew,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final typesById = watchDiveTypesById(ref);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final standouts = report.standouts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (standouts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.insights_focus_factors_standoutsSummary(
                standouts.map((f) => focusFactorName(f.id, l10n)).join(', '),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (final group in FocusFactorGroup.values)
          if (report.factors.any((f) => f.id.group == group)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                focusFactorGroupName(group, l10n),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final factor in report.factors.where(
              (f) => f.id.group == group,
            ))
              _FactorRow(
                factor: factor,
                units: units,
                percent: percent,
                typesById: typesById,
              ),
          ],
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.factor,
    required this.units,
    required this.percent,
    required this.typesById,
  });

  final FocusFactor factor;
  final UnitFormatter units;
  final NumberFormat percent;
  final Map<String, DiveTypeEntity> typesById;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final List<Widget> values = switch (factor) {
      NumericFactor(:final groupMean, :final baselineMean, :final difference)
          when groupMean != null && baselineMean != null =>
        [
          Text(
            l10n.insights_focus_factors_versus(
              focusNumericValue(factor.id, groupMean, units, l10n),
              focusNumericValue(factor.id, baselineMean, units, l10n),
            ),
          ),
          if (difference != null)
            Text(
              focusNumericDifference(factor.id, difference, units, l10n),
              style: muted,
            ),
        ],
      CategoricalFactor(:final top) when top.isNotEmpty => [
        for (final share in top)
          Text(
            '${focusCategoryLabel(factor.id, share, l10n, units, typesById: typesById)}: '
            '${l10n.insights_focus_factors_versus(percent.format(share.groupShare), percent.format(share.baselineShare))}',
            style: share.standsOut
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
      ],
      _ => [Text(l10n.insights_chart_notRecorded, style: muted)],
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(focusFactorName(factor.id, l10n)),
                if (factor.groupCovered > 0 &&
                    factor.groupCovered < factor.groupSize &&
                    factor is NumericFactor)
                  Text(
                    l10n.insights_focus_factors_coverage(
                      factor.groupCovered,
                      factor.groupSize,
                    ),
                    style: muted,
                  ),
                if (factor.standsOut)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(l10n.insights_focus_factors_standsOut),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: values,
            ),
          ),
        ],
      ),
    );
  }
}
