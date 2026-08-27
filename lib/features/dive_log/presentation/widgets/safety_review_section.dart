import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive detail section listing the post-dive safety review findings.
///
/// Tone rules (safety-features spec): neutral wording and iconography, no
/// alarm red, per-finding dismiss plus a footer action that dismisses (or
/// restores) the whole dive at once. Collapses to nothing when the review is
/// disabled, absent, or has no findings to show.
class SafetyReviewSection extends ConsumerStatefulWidget {
  final String diveId;

  const SafetyReviewSection({required this.diveId, super.key});

  @override
  ConsumerState<SafetyReviewSection> createState() =>
      _SafetyReviewSectionState();
}

class _SafetyReviewSectionState extends ConsumerState<SafetyReviewSection> {
  bool _expanded = true;
  bool _showDismissed = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (!settings.safetyReviewEnabled) return const SizedBox.shrink();

    final reviewAsync = ref.watch(safetyReviewProvider(widget.diveId));
    final review = reviewAsync.value;
    if (review == null) return const SizedBox.shrink();

    final disabled = settings.safetyReviewDisabledRules;
    final visible = review.findings
        .where((f) => !disabled.contains(f.ruleId.dbValue))
        .toList();
    final active = visible.where((f) => !f.isDismissed).toList();
    final dismissed = visible.where((f) => f.isDismissed).toList();
    if (active.isEmpty && dismissed.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final units = UnitFormatter(settings);
    final selectedFinding = ref.watch(
      selectedSafetyFindingProvider(widget.diveId),
    );

    // Top spacing lives here (not in the section builder) so the section
    // occupies no space at all when it renders nothing.
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: CollapsibleSection(
        title: l10n.safetyReview_sectionTitle,
        icon: Icons.health_and_safety_outlined,
        trailing: Text(
          l10n.safetyReview_findingCount(active.length),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        isExpanded: _expanded,
        onToggle: (expanded) => setState(() => _expanded = expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final finding in active)
              _FindingTile(
                finding: finding,
                units: units,
                selected: selectedFinding?.id == finding.id,
                onTap: _tapHandlerFor(finding),
                onDismissChanged: (dismissed) =>
                    _setDismissed(finding, dismissed),
              ),
            // Footer: the dismissed-findings toggle on the left, the bulk
            // action on the right. The bulk action flips to "restore all"
            // once nothing active is left, so the row never offers a no-op.
            //
            // OverflowBar, not Row: after a "dismiss all" both controls are on
            // screen at once, and in the longer locales that pair does not fit
            // a narrow phone. OverflowBar stacks them instead of overflowing.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OverflowBar(
                alignment: dismissed.isEmpty
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  if (dismissed.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showDismissed = !_showDismissed),
                      child: Text(
                        l10n.safetyReview_showDismissed(dismissed.length),
                      ),
                    ),
                  TextButton(
                    onPressed: () => _onBulkPressed(active.isNotEmpty),
                    child: Text(
                      active.isNotEmpty
                          ? l10n.safetyReview_dismissAll
                          : l10n.safetyReview_restoreAll,
                    ),
                  ),
                ],
              ),
            ),
            if (dismissed.isNotEmpty && _showDismissed)
              for (final finding in dismissed)
                Opacity(
                  opacity: 0.6,
                  child: _FindingTile(
                    finding: finding,
                    units: units,
                    selected: selectedFinding?.id == finding.id,
                    onTap: _tapHandlerFor(finding),
                    onDismissChanged: (dismissed) =>
                        _setDismissed(finding, dismissed),
                  ),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Tap toggles chart highlighting; findings without a start timestamp
  /// (nullable in storage) cannot be placed on the time axis and stay inert.
  /// A missing end timestamp is fine: the chart treats it as an instant.
  VoidCallback? _tapHandlerFor(SafetyFinding finding) {
    if (finding.startTimestamp == null) return null;
    return () => _toggleSelected(finding);
  }

  void _toggleSelected(SafetyFinding finding) {
    final notifier = ref.read(
      selectedSafetyFindingProvider(widget.diveId).notifier,
    );
    final wasSelected = notifier.state?.id == finding.id;
    notifier.state = wasSelected ? null : finding;
    if (wasSelected) return;
    // Bring the profile chart (fixed near the top of the page) into view so
    // the highlight is visible immediately. Works for both the master-detail
    // retained controller and a standalone page's internal controller.
    Scrollable.maybeOf(context)?.position.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _setDismissed(SafetyFinding finding, bool dismissed) {
    return setSafetyFindingDismissed(
      ref,
      finding: finding,
      dismissed: dismissed,
    );
  }

  /// Dismisses every active finding on the dive, or restores every dismissed
  /// one when nothing is active. Scoped to the enabled rules, so findings the
  /// diver has hidden in settings are left as they are.
  ///
  /// The button callback cannot await, so a failed write would otherwise reach
  /// the zone handler with no clue where it came from; logFailure attributes
  /// it. The list simply does not change, which is the user-visible signal.
  void _onBulkPressed(bool dismissed) {
    logFailure(
      setAllSafetyFindingsDismissed(
        ref,
        diveId: widget.diveId,
        dismissed: dismissed,
      ),
      _SafetyReviewSectionState,
      dismissed ? 'dismiss all safety findings' : 'restore all safety findings',
    );
  }
}

class _FindingTile extends StatelessWidget {
  final SafetyFinding finding;
  final UnitFormatter units;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<bool> onDismissChanged;

  const _FindingTile({
    required this.finding,
    required this.units,
    required this.selected,
    required this.onTap,
    required this.onDismissChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final severityColor = safetySeverityColor(finding.severity, colorScheme);

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: severityColor.withValues(alpha: 0.08),
      onTap: onTap,
      leading: Icon(_iconFor(finding.severity), size: 20, color: severityColor),
      title: Text(safetyFindingTitle(finding, l10n, units)),
      subtitle: finding.startTimestamp != null && finding.endTimestamp != null
          ? Text(
              l10n.safetyReview_timeRange(
                _runTime(finding.startTimestamp!),
                _runTime(finding.endTimestamp!),
              ),
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          finding.isDismissed ? Icons.undo : Icons.close,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        tooltip: finding.isDismissed
            ? l10n.safetyReview_restore
            : l10n.safetyReview_dismiss,
        onPressed: () => onDismissChanged(!finding.isDismissed),
      ),
    );
  }

  IconData _iconFor(SafetySeverity severity) {
    return switch (severity) {
      SafetySeverity.info => Icons.info_outline,
      SafetySeverity.caution => Icons.report_problem_outlined,
      SafetySeverity.significant => Icons.report_problem_outlined,
    };
  }

  String _runTime(int timestampSeconds) {
    final minutes = timestampSeconds ~/ 60;
    final seconds = timestampSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
