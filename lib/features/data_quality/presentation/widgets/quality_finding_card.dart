import 'package:flutter/material.dart';

import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/domain/services/finding_ownership.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class QualityFindingCard extends StatefulWidget {
  const QualityFindingCard({
    super.key,
    required this.finding,
    required this.formatters,
    required this.onRepair,
    required this.onDismiss,
    required this.onGoToDive,
    this.relatedDive,
    this.computerName,
    this.tanks = const [],
    this.evidence,
    this.foreignDiveId,
  });

  final QualityFinding finding;
  final QualityUnitFormatters formatters;
  final void Function(QualityRepairAction action) onRepair;
  final VoidCallback onDismiss;
  final void Function(String diveId) onGoToDive;

  /// Identity of the second dive in a cross-dive finding (a likely duplicate
  /// or an accidental split). The message itself only ever says "a dive 1 min
  /// apart", because [buildFindingMessage] renders numeric params and must
  /// stay free of any one library's prose; this names which dive that is, so
  /// consolidating or combining is a decision and not a guess.
  final DiveIdentityLabel? relatedDive;

  /// Display name of the computer that recorded the flagged data, when the
  /// finding records one. This is what makes "same computer resumed after an
  /// 8 min surface interval" checkable. For a finding about one data source
  /// it also names the repairs acting on that source, so the row and the
  /// button never disagree about which recording they mean (issue #4209).
  final String? computerName;

  /// The tank or tanks the finding is about, as the dive numbers them. Empty
  /// for a finding that names no tank, or whose tanks no longer exist.
  final List<QualityTankRef> tanks;

  /// Optional expanded-state evidence (before/after chart, sparklines...),
  /// injected by the page so this widget stays synchronous.
  final Widget? evidence;

  /// The dive of this finding that belongs to another profile, if any (see
  /// `foreignDiveIdOf`). The card then names it but neither opens it nor
  /// offers a repair on it, and "Go to dive" opens the active diver's own
  /// dive; [relatedDive] labels the foreign one (issue #3049).
  final String? foreignDiveId;

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

  /// A signed whole-hour shift, or an ellipsis when the diver picks it.
  static String _offsetLabel(Duration offset) => offset == Duration.zero
      ? '...'
      : '${offset.isNegative ? '' : '+'}${offset.inHours} h';

  String _repairLabel(BuildContext context, QualityRepairAction action) {
    final l10n = context.l10n;
    final source = widget.computerName;
    return switch (action) {
      TimeShiftRepair(:final suggestedOffset) =>
        l10n.dataQuality_repairLabel_shiftLogbookTime(
          _offsetLabel(suggestedOffset),
        ),
      SourceClockShiftRepair(:final suggestedOffset) =>
        source == null
            ? l10n.dataQuality_repairLabel_fixSourceClock(
                _offsetLabel(suggestedOffset),
              )
            : l10n.dataQuality_repairLabel_fixSourceClockNamed(
                source,
                _offsetLabel(suggestedOffset),
              ),
      SourceProfileShiftRepair() =>
        source == null
            ? l10n.dataQuality_repairLabel_alignSourceProfile
            : l10n.dataQuality_repairLabel_alignSourceProfileNamed(source),
      ConsolidateDuplicateRepair() => l10n.dataQuality_repairLabel_consolidate,
      DeleteDuplicateRepair() => l10n.dataQuality_repairLabel_deleteDuplicate,
      CombineSplitRepair() => l10n.dataQuality_repairLabel_combine,
      SetPrimarySourceRepair() =>
        source == null
            ? l10n.dataQuality_repairLabel_setPrimary
            : l10n.dataQuality_repairLabel_setPrimaryNamed(source),
      SplitSourceRepair() =>
        source == null
            ? l10n.dataQuality_repairLabel_split
            : l10n.dataQuality_repairLabel_splitNamed(source),
      DespikeRepair() => l10n.dataQuality_repairLabel_despike,
      SmoothRatesRepair() => l10n.dataQuality_repairLabel_smoothRates,
      ClampNegativeDepthsRepair() => l10n.dataQuality_repairLabel_clampNegative,
      FillGapsRepair() => l10n.dataQuality_repairLabel_fillGaps,
      SmoothTemperatureRepair() => l10n.dataQuality_repairLabel_smoothTemp,
      ConvertTemperatureRepair() => l10n.dataQuality_repairLabel_convertTemp,
      ConvertWaterTempRepair() => l10n.dataQuality_repairLabel_convertTemp,
      RecomputeMetricsRepair() => l10n.dataQuality_repairLabel_recompute,
      SwapTankRecordPressuresRepair() =>
        l10n.dataQuality_repairLabel_swapPressures,
      SetTankRecordFromSeriesRepair() =>
        l10n.dataQuality_repairLabel_setFromSeries,
      SwapPressureSeriesRepair() => l10n.dataQuality_repairLabel_swapSeries,
      ReassignPressureSeriesRepair() =>
        l10n.dataQuality_repairLabel_reassignSeries,
      AddGasSwitchesRepair(:final switches) =>
        l10n.dataQuality_repairLabel_addGasSwitches(switches.length),
      CompareSourcesRepair() => l10n.dataQuality_repairLabel_compare,
      GoToDiveRepair() => l10n.dataQuality_action_goToDive,
      SetUpTransmitterRepair() =>
        l10n.dataQuality_repairLabel_assignTransmitter,
      UseAsBailoutRepair() => l10n.dataQuality_repairLabel_useAsBailout,
      RemoveGearFromDiveRepair(:final diverName) =>
        l10n.dataQuality_repairLabel_removeGearFromDive(
          diverName.isEmpty ? l10n.sharedItems_ownerUnknown : diverName,
        ),
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
    final finding = widget.finding;
    final foreign = widget.foreignDiveId;
    final actions = [
      for (final a in repairOptionsFor(finding))
        if (a is! GoToDiveRepair &&
            !(a is RemoveGearFromDiveRepair && a.diveId == foreign))
          a,
    ];
    final primary = actions.isNotEmpty ? actions.first : null;
    final related = widget.relatedDive;
    final (own: ownDiveId, paired: pairedId) = diveSidesOf(finding, foreign);
    final computerName = widget.computerName;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The primary repair sits on its own line under the detail rather
          // than in trailing: a ListTile lays trailing out at its natural
          // width first, so a long translated repair label there starves the
          // finding title to one fragment per line (issue #2717).
          ListTile(
            leading: Icon(_icon, color: _color(scheme)),
            title: Text(message.title),
            subtitle: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.detail,
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                if (primary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => widget.onRepair(primary),
                      child: Text(_repairLabel(context, primary)),
                    ),
                  ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (related != null)
            _ContextRow(
              icon: Icons.link_outlined,
              text: context.l10n.dataQuality_dive_pairedWith(related.headline),
              onTap: pairedId == null || pairedId == foreign
                  ? null
                  : () => widget.onGoToDive(pairedId),
            ),
          if (computerName != null)
            _ContextRow(
              icon: Icons.watch_outlined,
              text: context.l10n.dataQuality_dive_recordedBy(computerName),
            ),
          if (widget.tanks.isNotEmpty)
            _ContextRow(
              icon: Icons.propane_tank_outlined,
              text: context.l10n.dataQuality_dive_tanks(
                qualityTanksLabel(context.l10n, widget.tanks),
              ),
            ),
          // Some findings are a judgment call the app must not make for the
          // diver, so no repair converges and the trailing button is absent.
          // Say that plainly: an unexplained bare row reads as a broken
          // button (issue #1035).
          if (primary == null)
            _ContextRow(
              icon: Icons.build_circle_outlined,
              text: context.l10n.dataQuality_repair_needsReview,
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
                  onPressed: () => widget.onGoToDive(ownDiveId),
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

/// A tank as the dive's own screens number it ("Tank 2"), with the diver's
/// name for it when there is one ("Tank 2 · Stage"), the separator the
/// dive headers above the cards use too.
String qualityTankLabel(AppLocalizations l10n, QualityTankRef tank) {
  final number = l10n.diveLog_tank_title(tank.number);
  final name = tank.name;
  return name == null ? number : '$number · $name';
}

/// The tanks of one finding: one tank, or the pair of a twin-tank finding
/// joined the way the locale joins two items ("Tank 1 and Tank 2").
String qualityTanksLabel(AppLocalizations l10n, List<QualityTankRef> tanks) {
  final labels = [for (final t in tanks) qualityTankLabel(l10n, t)];
  return switch (labels) {
    [final first, final second] => l10n.dataQuality_dive_tankPair(
      first,
      second,
    ),
    _ => labels.join(', '),
  };
}

/// A quiet, icon-led line of context under a finding's message: which dive it
/// is paired with, which computer recorded it, or why no repair is offered.
class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;

  /// Non-null makes the row a link. Null leaves it as plain context, with no
  /// tap target to promise something that would not happen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = onTap == null ? scheme.onSurfaceVariant : scheme.primary;
    final row = Padding(
      // Indented to the ListTile's title, so context reads as belonging to the
      // message above it rather than as a new item.
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
