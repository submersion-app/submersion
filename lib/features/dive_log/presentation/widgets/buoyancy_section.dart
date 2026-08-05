import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_history_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_what_if_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/twin_summary_rows.dart';

/// Dive-detail section presenting the modeled net buoyancy through the dive:
/// a plain-language final-stop verdict, an expandable term breakdown, and
/// summary metrics. Self-suppresses (renders nothing) while loading, on
/// error, or when the dive is unmodelable.
class BuoyancySection extends ConsumerWidget {
  final String diveId;
  final UnitFormatter units;

  const BuoyancySection({super.key, required this.diveId, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(buoyancyTwinProvider(diveId));
    return async.maybeWhen(
      data: (outcome) =>
          outcome == null ? const SizedBox.shrink() : _card(context, outcome),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _card(BuildContext context, BuoyancyTwinOutcome outcome) {
    final theme = Theme.of(context);
    final o = outcome.outputs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveDetailSection_buoyancy_name.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showBuoyancyWhatIfSheet(
                    context,
                    baseInput: outcome.result.input,
                    units: units,
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(context.l10n.buoyancy_adjust),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: context.l10n.buoyancy_tooltip,
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _verdict(context, o),
            if (o.verdict.anchor.kind == TwinAnchorKind.convention) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.buoyancy_verdictConvention,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 12),
            BuoyancyChart(result: outcome.result, units: units),
            const SizedBox(height: 12),
            _breakdown(context, o),
            const SizedBox(height: 12),
            TwinSummaryRows(
              outputs: o,
              units: units,
              wingLiftCapacityKg: outcome.wingLiftCapacityKg,
            ),
            const SizedBox(height: 16),
            BuoyancyHistoryStrip(diveId: diveId, units: units),
            ..._hints(context, outcome),
          ],
        ),
      ),
    );
  }

  Widget _verdict(BuildContext context, TwinOutputs o) {
    final l10n = context.l10n;
    final net = o.verdict.netKg;
    final amount = units.formatWeight(net.abs());
    final depth = units.formatDepth(o.verdict.anchor.depthM);
    final String text;
    if (net.abs() <= 0.5) {
      text = l10n.buoyancy_verdictNeutral;
    } else if (net > 0) {
      text = l10n.buoyancy_verdictBuoyant(depth, amount);
    } else {
      text = l10n.buoyancy_verdictHeavy(depth, amount);
    }
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _breakdown(BuildContext context, TwinOutputs o) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          context.l10n.buoyancy_breakdownTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        children: [for (final term in o.verdict.terms) _termRow(context, term)],
      ),
    );
  }

  Widget _termRow(BuildContext context, TwinStaticTerm term) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(_termLabel(context, term.label))),
          Text(
            '(${_sourceLabel(context, term.source)})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            units.formatWeight(term.kg),
            style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const []),
          ),
        ],
      ),
    );
  }

  List<Widget> _hints(BuildContext context, BuoyancyTwinOutcome outcome) {
    final theme = Theme.of(context);
    final hints = <String>[];
    if (outcome.result.pressuresEstimated) {
      hints.add(context.l10n.buoyancy_estimatedPressures);
    }
    if (outcome.result.input.suit.kind == TwinSuitKind.none) {
      hints.add(context.l10n.buoyancy_linkSuitHint);
    }
    return [
      for (final text in hints) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  String _termLabel(BuildContext context, String raw) {
    final l10n = context.l10n;
    return switch (raw) {
      'personal' => l10n.tools_weight_personalTerm,
      'water' => l10n.tools_weight_waterTerm,
      'suit' => l10n.buoyancy_suitTerm,
      'lead' => l10n.buoyancy_leadTerm,
      // Fallback for a tank with no preset/user name (see the assembler and
      // plan provider). Reuses the existing translated tanks-section term.
      'tank' => l10n.diveDetailSection_tanks_name,
      _ => raw,
    };
  }

  String _sourceLabel(BuildContext context, TermSource source) {
    final l10n = context.l10n;
    return switch (source) {
      TermSource.measured => l10n.tools_weight_source_measured,
      TermSource.userSpec => l10n.tools_weight_source_userSpec,
      TermSource.typeDefault => l10n.tools_weight_source_typeDefault,
      TermSource.physics => l10n.tools_weight_source_physics,
    };
  }
}
