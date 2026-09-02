import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Last group of the dive form: the statistics-exclusion toggles (#526 /
/// #1272). Collapsed by default because most dives are never excluded, so the
/// header carries the state instead: a summary naming the exclusion, or the
/// fainter "counted" hint when there is none.
///
/// Nothing in here is a validated field, so unlike the other collapsible
/// groups it does not need force-expanding before `Form.validate()`; the two
/// flags live on the page, not in the collapsed subtree.
class StatisticsSection extends StatelessWidget {
  const StatisticsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.excludedFromStats,
    required this.excludedFromGasStats,
    required this.onExcludedFromStatsChanged,
    required this.onExcludedFromGasStatsChanged,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// The gas toggle renders inert while [excludedFromStats] is on, because
  /// the master flag already implies it.
  final bool excludedFromStats;
  final bool excludedFromGasStats;
  final ValueChanged<bool> onExcludedFromStatsChanged;
  final ValueChanged<bool> onExcludedFromGasStatsChanged;

  bool get _isExcluded => excludedFromStats || excludedFromGasStats;

  /// Header text for the collapsed group. The master flag wins: it already
  /// implies the gas one, so naming both would read as two separate settings.
  String _summary(AppLocalizations l10n) {
    if (excludedFromStats) return l10n.diveLog_edit_summary_excluded;
    if (excludedFromGasStats) return l10n.diveLog_edit_summary_gasExcluded;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_statistics,
      icon: Icons.bar_chart_outlined,
      expanded: expanded,
      onToggle: onToggle,
      // An exclusion has to be readable with the group shut, or the only
      // trace of it is behind a closed section.
      summary: _summary(l10n),
      isEmpty: !_isExcluded,
      emptyInvitation: l10n.diveLog_edit_statisticsIncludedHint,
      children: [
        FormRow.toggle(
          key: const Key('dive-edit-exclude-from-stats'),
          label: l10n.diveLog_edit_excludeFromStats,
          value: excludedFromStats,
          onChanged: onExcludedFromStatsChanged,
          // The label alone does not say the dive count is affected, which
          // is the part that surprises people later.
          helpText: l10n.diveLog_edit_excludeFromStatsHelp,
        ),
        FormRow.toggle(
          key: const Key('dive-edit-exclude-from-gas-stats'),
          label: l10n.diveLog_edit_excludeFromGasStats,
          // Show the effective state: the master flag implies this one.
          value: excludedFromStats || excludedFromGasStats,
          onChanged: onExcludedFromGasStatsChanged,
          enabled: !excludedFromStats,
          helpText: l10n.diveLog_edit_excludeFromGasStatsHelp,
        ),
      ],
    );
  }
}
