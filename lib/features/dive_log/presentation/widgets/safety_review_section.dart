import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive detail section listing the post-dive safety review findings.
///
/// Tone rules (safety-features spec): neutral wording and iconography, no
/// alarm red, per-finding dismiss. Collapses to nothing when the review is
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
                onDismissChanged: (dismissed) =>
                    _setDismissed(finding, dismissed),
              ),
            if (dismissed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showDismissed = !_showDismissed),
                  child: Text(
                    l10n.safetyReview_showDismissed(dismissed.length),
                  ),
                ),
              ),
              if (_showDismissed)
                for (final finding in dismissed)
                  Opacity(
                    opacity: 0.6,
                    child: _FindingTile(
                      finding: finding,
                      units: units,
                      onDismissChanged: (dismissed) =>
                          _setDismissed(finding, dismissed),
                    ),
                  ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _setDismissed(SafetyFinding finding, bool dismissed) async {
    await ref
        .read(safetyFindingsRepositoryProvider)
        .setDismissed(
          findingId: finding.id,
          dismissed: dismissed,
          now: DateTime.now(),
        );
    ref.invalidate(safetyReviewProvider(widget.diveId));
  }
}

class _FindingTile extends StatelessWidget {
  final SafetyFinding finding;
  final UnitFormatter units;
  final ValueChanged<bool> onDismissChanged;

  const _FindingTile({
    required this.finding,
    required this.units,
    required this.onDismissChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(
        _iconFor(finding.severity),
        size: 20,
        color: finding.severity == SafetySeverity.significant
            ? colorScheme.tertiary
            : colorScheme.onSurfaceVariant,
      ),
      title: Text(_titleFor(l10n)),
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

  String _titleFor(AppLocalizations l10n) {
    // value is nullable in storage; a missing number (older/corrupt/malformed
    // sync row) must render a neutral placeholder rather than a fabricated 0
    // that would read as e.g. "Ascent exceeded 0/min".
    final value = finding.value;
    const unknown = '--';
    return switch (finding.ruleId) {
      SafetyRuleId.rapidAscent => l10n.safetyReview_rapidAscent_title(
        value == null
            ? unknown
            : '${units.formatDepth(value, decimals: 0)}/min',
        _duration(),
      ),
      SafetyRuleId.missedDecoStop => l10n.safetyReview_missedDecoStop_title(
        value == null ? unknown : units.formatDepth(value),
        _duration(),
      ),
      SafetyRuleId.omittedSafetyStop =>
        l10n.safetyReview_omittedSafetyStop_title(
          value == null ? unknown : _seconds(value.round()),
        ),
      // Sawtooth's only detail is the cycle count; with no value there is
      // nothing meaningful to interpolate, so fall back to the neutral rule
      // name instead of claiming "0 repeated up-and-down depth changes".
      SafetyRuleId.sawtoothProfile =>
        value == null
            ? l10n.safetySettings_rule_sawtoothProfile
            : l10n.safetyReview_sawtoothProfile_title(value.round()),
      SafetyRuleId.highSurfaceGf => l10n.safetyReview_highSurfaceGf_title(
        value == null ? unknown : '${value.toStringAsFixed(0)}%',
        // Pass a plain percentage (matching the surfaced-GF formatting) so the
        // localized template owns every word; no baked-in English "GF" token.
        '${units.settings.gfHigh}%',
      ),
    };
  }

  String _duration() {
    final start = finding.startTimestamp;
    final end = finding.endTimestamp;
    if (start == null || end == null) return '--';
    return _seconds(end - start);
  }

  String _seconds(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

  String _runTime(int timestampSeconds) {
    final minutes = timestampSeconds ~/ 60;
    final seconds = timestampSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
