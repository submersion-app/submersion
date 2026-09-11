import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_evidence_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether [findings] has anything [settings] would show once the master
/// toggle and the disabled-rule filter are applied. Rules always compute;
/// hiding happens here, so a toggle flip is instant and reversible.
bool hasVisibleConditionFindings(
  AppSettings settings,
  List<EquipmentFinding>? findings,
) {
  if (!settings.conditionEngineEnabled || findings == null) return false;
  final disabled = settings.conditionDisabledRules;
  return findings.any((f) => !disabled.contains(f.ruleId.dbValue));
}

/// The item's condition findings: active ones first with their sentence
/// and evidence window, the dismissed folded behind a button. Tapping a
/// row shades its window on the trend chart. Same tone rules as the
/// safety review: neutral wording, no alarm red beyond the severity dot.
class ConditionFindingsCard extends ConsumerStatefulWidget {
  final EquipmentItem equipment;

  const ConditionFindingsCard({super.key, required this.equipment});

  @override
  ConsumerState<ConditionFindingsCard> createState() =>
      _ConditionFindingsCardState();
}

class _ConditionFindingsCardState extends ConsumerState<ConditionFindingsCard> {
  bool _showDismissed = false;

  String get _id => widget.equipment.id;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // The card hides while the engine's first read is in flight: a rule
    // engine never earns a spinner on a gear page.
    final findings = ref.watch(equipmentConditionProvider(_id)).value;
    if (!hasVisibleConditionFindings(settings, findings)) {
      return const SizedBox.shrink();
    }
    final disabled = settings.conditionDisabledRules;
    final visible = findings!
        .where((f) => !disabled.contains(f.ruleId.dbValue))
        .toList();
    final active = visible.where((f) => f.dismissedAt == null).toList();
    final dismissed = visible.where((f) => f.dismissedAt != null).toList();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(settings);
    final thresholds = ref.watch(exposureThresholdsProvider);
    final selected = ref.watch(selectedConditionFindingProvider(_id));
    // The chart shades the selected finding's window, so the selection has
    // to leave with the row: dismissed by a sync or a recompute rather than
    // this card's button, or folded away with the dismissed rows. Cleared
    // after the frame, since a provider cannot change during build.
    final shown = [...active, if (_showDismissed) ...dismissed];
    if (selected != null && !shown.any((f) => f.id == selected.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(
          selectedConditionFindingProvider(_id).notifier,
        );
        if (notifier.state?.id == selected.id) notifier.state = null;
      });
    }

    Widget tile(EquipmentFinding f) => _FindingTile(
      finding: f,
      sentence: conditionFindingTitle(f, l10n, units, thresholds: thresholds),
      window: conditionFindingWindow(f, l10n, units),
      selected: selected?.id == f.id,
      onTap: () => _toggleSelected(f),
      // A finding with no dives (an incident logged on the bench) has
      // nothing to list, so it offers no evidence sheet.
      onEvidence: f.evidence.diveIds.isEmpty
          ? null
          : () => showConditionEvidenceSheet(
              context,
              equipment: widget.equipment,
              finding: f,
            ),
      onDismissChanged: (dismissed) => _setDismissed(f, dismissed),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.equipmentCondition_findings_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.equipmentCondition_findings_count(active.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Divider(),
              for (final f in active) tile(f),
              if (dismissed.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showDismissed = !_showDismissed),
                    child: Text(
                      l10n.equipmentCondition_findings_showDismissed(
                        dismissed.length,
                      ),
                    ),
                  ),
                ),
              if (_showDismissed)
                for (final f in dismissed)
                  Opacity(opacity: 0.6, child: tile(f)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelected(EquipmentFinding finding) {
    final notifier = ref.read(selectedConditionFindingProvider(_id).notifier);
    notifier.state = notifier.state?.id == finding.id ? null : finding;
  }

  /// The button callback cannot await; logFailure attributes a failed
  /// write, and the unchanged list is the user-visible signal.
  void _setDismissed(EquipmentFinding finding, bool dismissed) {
    if (ref.read(selectedConditionFindingProvider(_id))?.id == finding.id) {
      ref.read(selectedConditionFindingProvider(_id).notifier).state = null;
    }
    logFailure(
      setConditionFindingDismissed(ref, finding: finding, dismissed: dismissed),
      _ConditionFindingsCardState,
      dismissed ? 'dismiss condition finding' : 'restore condition finding',
    );
  }
}

class _FindingTile extends StatelessWidget {
  final EquipmentFinding finding;
  final String sentence;
  final String window;
  final bool selected;
  final VoidCallback onTap;

  /// Null when the finding names no dive, which hides the action.
  final VoidCallback? onEvidence;
  final ValueChanged<bool> onDismissChanged;

  const _FindingTile({
    required this.finding,
    required this.sentence,
    required this.window,
    required this.selected,
    required this.onTap,
    required this.onEvidence,
    required this.onDismissChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = conditionSeverityColor(finding.severity, scheme);
    final dismissed = finding.dismissedAt != null;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      selectedTileColor: color.withValues(alpha: 0.08),
      onTap: onTap,
      leading: Icon(
        finding.severity == ConditionSeverity.info
            ? Icons.info_outline
            : Icons.report_problem_outlined,
        size: 20,
        color: color,
      ),
      title: Text(sentence),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(window),
          if (onEvidence case final open?)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: open,
                icon: const Icon(Icons.scuba_diving, size: 16),
                label: Text(l10n.equipmentCondition_findings_evidence),
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          dismissed ? Icons.undo : Icons.close,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        tooltip: dismissed
            ? l10n.equipmentCondition_findings_restore
            : l10n.equipmentCondition_findings_dismiss,
        onPressed: () => onDismissChanged(!dismissed),
      ),
    );
  }
}
