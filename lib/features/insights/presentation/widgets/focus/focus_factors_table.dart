import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_quiet_rows.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Below this width the difference column folds under the group value.
const double focusTableNarrowWidth = 600;

/// The group against its baseline, factor by factor: headed columns,
/// standouts first in each group, and rows that say nothing folded away.
class FocusFactorsTable extends ConsumerStatefulWidget {
  const FocusFactorsTable({
    super.key,
    required this.report,
    required this.metric,
  });

  final FocusFactorReport report;
  final FocusMetric metric;

  @override
  ConsumerState<FocusFactorsTable> createState() => _FocusFactorsTableState();
}

class _FocusFactorsTableState extends ConsumerState<FocusFactorsTable> {
  bool _showQuiet = false;

  @override
  void didUpdateWidget(FocusFactorsTable old) {
    super.didUpdateWidget(old);
    // A new selection folds the quiet rows again.
    if (!identical(old.report, widget.report)) _showQuiet = false;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (report.tooFewDives) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final typesById = watchDiveTypesById(ref);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final narrow = MediaQuery.sizeOf(context).width < focusTableNarrowWidth;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Formatted once per factor: the quiet decision and the rendered cell
    // read the same string.
    final differences = <FocusFactorId, String>{
      for (final f in report.factors)
        if (f is NumericFactor && f.difference != null)
          f.id: focusNumericDifference(f.id, f.difference!, units, l10n),
    };
    final quiet = {
      for (final f in report.factors)
        if (focusFactorIsQuiet(f, formattedDifference: differences[f.id])) f.id,
    };
    final visible = [
      for (final f in report.factors)
        if (_showQuiet || !quiet.contains(f.id)) f,
    ];

    return StatSectionCard(
      title: l10n.insights_focus_comparison_title,
      subtitle: l10n.insights_focus_comparison_subtitle(
        focusMetricLabel(widget.metric, l10n),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visible.isNotEmpty)
            _Columns(
              narrow: narrow,
              label: const SizedBox.shrink(),
              these: Text(l10n.insights_focus_column_these, style: muted),
              all: Text(l10n.insights_focus_column_all, style: muted),
              // Narrow rows carry the difference under the group value,
              // where a header would only mislead.
              difference: narrow
                  ? const SizedBox.shrink()
                  : Text(l10n.insights_focus_column_difference, style: muted),
            ),
          for (final group in FocusFactorGroup.values)
            if (visible.any((f) => f.id.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  focusFactorGroupName(group, l10n),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final f in _ordered(
                visible.where((f) => f.id.group == group),
              ))
                _FactorRow(
                  factor: f,
                  units: units,
                  percent: percent,
                  typesById: typesById,
                  narrow: narrow,
                  difference: differences[f.id],
                ),
            ],
          if (quiet.isNotEmpty && !_showQuiet)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                key: const ValueKey('focus-factors-show-more'),
                onPressed: () => setState(() => _showQuiet = true),
                child: Text(
                  l10n.insights_focus_comparison_showMore(quiet.length),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Standouts first, the rest in display order.
  static List<FocusFactor> _ordered(Iterable<FocusFactor> factors) => [
    ...factors.where((f) => f.standsOut),
    ...factors.where((f) => !f.standsOut),
  ];
}

/// One row's four cells; on a narrow screen the difference moves under the
/// group cell and the fourth column disappears.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.narrow,
    required this.label,
    required this.these,
    required this.all,
    required this.difference,
  });

  final bool narrow;
  final Widget label;
  final Widget these;
  final Widget all;
  final Widget difference;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: label),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [these, difference],
                )
              : these,
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: all),
        if (!narrow) ...[
          const SizedBox(width: 8),
          Expanded(flex: 2, child: difference),
        ],
      ],
    ),
  );
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.factor,
    required this.units,
    required this.percent,
    required this.typesById,
    required this.narrow,
    required this.difference,
  });

  final FocusFactor factor;
  final UnitFormatter units;
  final NumberFormat percent;
  final Map<String, DiveTypeEntity> typesById;
  final bool narrow;
  final String? difference;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bold = factor.standsOut
        ? const TextStyle(fontWeight: FontWeight.w600)
        : null;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (factor.standsOut)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  label: l10n.insights_focus_factors_standsOut,
                  child: Container(
                    key: ValueKey('focus-standout-marker-${factor.id.name}'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: Text(focusFactorName(factor.id, l10n), style: bold),
            ),
          ],
        ),
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
      ],
    );

    switch (factor) {
      case NumericFactor(:final groupMean, :final baselineMean)
          when groupMean != null && baselineMean != null:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Text(
            focusNumericValue(factor.id, groupMean, units, l10n),
            style: bold,
          ),
          all: Text(focusNumericValue(factor.id, baselineMean, units, l10n)),
          difference: Text(difference ?? '', style: muted),
        );
      case CategoricalFactor(:final top) when top.isNotEmpty:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in top)
                Text(
                  '${focusCategoryLabel(factor.id, s, l10n, units, typesById: typesById)} '
                  '${percent.format(s.groupShare)}',
                  style: s.standsOut
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
            ],
          ),
          all: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in top) Text(percent.format(s.baselineShare)),
            ],
          ),
          difference: const SizedBox.shrink(),
        );
      default:
        return _Columns(
          narrow: narrow,
          label: label,
          these: Text(l10n.insights_chart_notRecorded, style: muted),
          all: const SizedBox.shrink(),
          difference: const SizedBox.shrink(),
        );
    }
  }
}
