import 'package:flutter/material.dart';

import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class QualityFindingCard extends StatefulWidget {
  const QualityFindingCard({
    super.key,
    required this.finding,
    required this.formatters,
    required this.onRepair,
    required this.onDismiss,
    required this.onGoToDive,
    this.evidence,
  });

  final QualityFinding finding;
  final QualityUnitFormatters formatters;
  final void Function(QualityRepairAction action) onRepair;
  final VoidCallback onDismiss;
  final void Function(String diveId) onGoToDive;

  /// Optional expanded-state evidence (before/after chart, sparklines...),
  /// injected by the page so this widget stays synchronous.
  final Widget? evidence;

  @override
  State<QualityFindingCard> createState() => _QualityFindingCardState();
}

class _QualityFindingCardState extends State<QualityFindingCard> {
  bool _expanded = false;

  IconData get _icon => switch (widget.finding.severity) {
    QualitySeverity.info => Icons.info_outline,
    QualitySeverity.warning => Icons.warning_amber_outlined,
    QualitySeverity.critical => Icons.error_outline,
  };

  Color _color(ColorScheme scheme) => switch (widget.finding.severity) {
    QualitySeverity.info => scheme.primary,
    QualitySeverity.warning => scheme.tertiary,
    QualitySeverity.critical => scheme.error,
  };

  String _repairLabel(BuildContext context, QualityRepairAction action) {
    final l10n = context.l10n;
    return switch (action) {
      TimeShiftRepair(:final suggestedOffset) =>
        suggestedOffset == Duration.zero
            ? l10n.dataQuality_repairLabel_shiftTime('...')
            : l10n.dataQuality_repairLabel_shiftTime(
                '${suggestedOffset.isNegative ? '' : '+'}'
                '${suggestedOffset.inHours} h',
              ),
      ConsolidateDuplicateRepair() => l10n.dataQuality_repairLabel_consolidate,
      CombineSplitRepair() => l10n.dataQuality_repairLabel_combine,
      SetPrimarySourceRepair() => l10n.dataQuality_repairLabel_setPrimary,
      SplitSourceRepair() => l10n.dataQuality_repairLabel_split,
      DespikeRepair() => l10n.dataQuality_repairLabel_despike,
      FillGapsRepair() => l10n.dataQuality_repairLabel_fillGaps,
      SmoothTemperatureRepair() => l10n.dataQuality_repairLabel_smoothTemp,
      ConvertTemperatureRepair() => l10n.dataQuality_repairLabel_convertTemp,
      RecomputeMetricsRepair() => l10n.dataQuality_repairLabel_recompute,
      SwapTankRecordPressuresRepair() =>
        l10n.dataQuality_repairLabel_swapPressures,
      SetTankRecordFromSeriesRepair() =>
        l10n.dataQuality_repairLabel_setFromSeries,
      SwapPressureSeriesRepair() => l10n.dataQuality_repairLabel_swapSeries,
      ReassignPressureSeriesRepair() =>
        l10n.dataQuality_repairLabel_reassignSeries,
      CompareSourcesRepair() => l10n.dataQuality_repairLabel_compare,
      GoToDiveRepair() => l10n.dataQuality_action_goToDive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = buildFindingMessage(
      context.l10n,
      widget.finding,
      widget.formatters,
    );
    // The card always renders its own "Go to dive" footer button, so drop any
    // GoToDiveRepair actions from the repair list to avoid a duplicate link.
    final actions = [
      for (final a in repairOptionsFor(widget.finding))
        if (a is! GoToDiveRepair) a,
    ];
    final primary = actions.isNotEmpty ? actions.first : null;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(_icon, color: _color(scheme)),
            title: Text(message.title),
            subtitle: Text(
              message.detail,
              maxLines: _expanded ? null : 1,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            trailing: primary == null
                ? null
                : FilledButton.tonal(
                    onPressed: () => widget.onRepair(primary),
                    child: Text(_repairLabel(context, primary)),
                  ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            if (widget.evidence != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: widget.evidence,
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                for (final action in actions.skip(primary != null ? 1 : 0))
                  TextButton(
                    onPressed: () => widget.onRepair(action),
                    child: Text(_repairLabel(context, action)),
                  ),
                TextButton(
                  onPressed: () => widget.onGoToDive(widget.finding.diveId),
                  child: Text(context.l10n.dataQuality_action_goToDive),
                ),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(context.l10n.dataQuality_action_dismiss),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
