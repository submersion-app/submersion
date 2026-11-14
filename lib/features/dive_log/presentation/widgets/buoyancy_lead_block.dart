import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_history_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The lead answer on the Buoyancy card: what the diver carried, what the
/// model would have had them carry, and how recent dives in the same suit
/// compared.
///
/// It never restates how heavy or buoyant the diver was; the card says that
/// once, above its chart. The suggestion is that same figure applied to the
/// lead carried.
class BuoyancyLeadBlock extends StatelessWidget {
  final String diveId;
  final BuoyancyTwinOutcome outcome;
  final UnitFormatter units;

  const BuoyancyLeadBlock({
    super.key,
    required this.diveId,
    required this.outcome,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final carriedKg = outcome.result.input.leadKg;
    // With no lead recorded the model has nothing to compare against, and
    // calling the dive underweighted would be a guess about missing data.
    final recorded = carriedKg > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.buoyancy_leadTitle,
                style: theme.textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (recorded) ...[
              const SizedBox(width: 8),
              _chip(context, outcome.outputs.verdict.netKg),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: _figure(
                    context,
                    l10n.buoyancy_leadCarried,
                    recorded
                        ? units.formatWeight(carriedKg)
                        : l10n.buoyancy_leadNotRecorded,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
                Flexible(
                  child: _figure(
                    context,
                    l10n.buoyancy_leadSuggested,
                    units.formatWeight(outcome.outputs.idealLeadKg),
                  ),
                ),
              ],
            ),
            BuoyancyHistoryStrip(diveId: diveId, units: units),
          ],
        ),
      ],
    );
  }

  Widget _figure(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        // A long figure on a narrow card shrinks rather than overflowing; the
        // label above it wraps.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: theme.textTheme.titleLarge),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, double netKg) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scheme = theme.colorScheme;
    final well = netKg.abs() <= TwinBalance.neutralBandKg;
    final String text;
    if (well) {
      text = l10n.buoyancy_statusWell;
    } else if (netKg < 0) {
      text = l10n.diveLog_edit_weightFeedback_over;
    } else {
      text = l10n.diveLog_edit_weightFeedback_under;
    }
    // Neither state is an error, so neither borrows the error colour.
    final fill = well ? scheme.primaryContainer : scheme.tertiaryContainer;
    final ink = well ? scheme.onPrimaryContainer : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: ink),
      ),
    );
  }
}
