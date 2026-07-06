import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour for a plan-issue severity (shared by chips and the results sheet).
Color planIssueSeverityColor(ColorScheme scheme, PlanIssueSeverity severity) {
  switch (severity) {
    case PlanIssueSeverity.critical:
      return scheme.error;
    case PlanIssueSeverity.alert:
    case PlanIssueSeverity.warning:
      return Colors.orange;
    case PlanIssueSeverity.info:
      return scheme.outline;
  }
}

/// A small pill chip; tinted and tappable when [tint]/[onTap] are supplied.
class PlanChip extends StatelessWidget {
  const PlanChip({
    super.key,
    required this.label,
    this.value,
    this.tint,
    this.emphasized = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final Color? tint;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = tint != null
        ? tint!.withValues(alpha: 0.15)
        : emphasized
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final border = tint != null
        ? tint!.withValues(alpha: 0.6)
        : Colors.transparent;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint ?? theme.colorScheme.outline,
              fontWeight: emphasized ? FontWeight.w600 : null,
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 5),
            Text(
              value!,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: tint,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: chip,
    );
  }
}

/// The always-visible headline numbers above the segment list: runtime,
/// NDL/TTS, deco time, CNS, and a tappable issue count.
class PlanStatusChips extends ConsumerWidget {
  const PlanStatusChips({super.key, required this.onIssuesTap});

  /// Opens the results sheet to the issues section.
  final VoidCallback onIssuesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(planOutcomeProvider);
    final cnsThreshold = ref.watch(cnsWarningThresholdProvider);
    final theme = Theme.of(context);

    String minutes(int seconds) => '${(seconds / 60).ceil()}′';

    final inDeco = outcome.ndlAtBottom < 0;
    final maxSeverity = outcome.issues.isEmpty
        ? null
        : outcome.issues
              .map((i) => i.severity)
              .reduce((a, b) => a.index >= b.index ? a : b);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PlanChip(
          label: context.l10n.divePlanner_label_runtime,
          value: minutes(outcome.runtimeSeconds),
          emphasized: true,
        ),
        if (inDeco)
          PlanChip(
            label: context.l10n.divePlanner_label_tts,
            value: minutes(outcome.ttsAtBottom),
          )
        else
          PlanChip(
            label: context.l10n.divePlanner_label_ndl,
            value: minutes(outcome.ndlAtBottom.clamp(0, 1 << 30)),
          ),
        if (outcome.totalDecoSeconds > 0)
          PlanChip(
            label: context.l10n.divePlanner_label_deco,
            value: minutes(outcome.totalDecoSeconds),
          ),
        PlanChip(
          label: context.l10n.plannerCanvas_chip_cns(
            outcome.cnsEnd.toStringAsFixed(0),
          ),
          tint: outcome.cnsEnd >= cnsThreshold ? Colors.orange : null,
        ),
        if (maxSeverity != null)
          PlanChip(
            label: context.l10n.plannerCanvas_chip_issues(
              outcome.issues.length,
            ),
            tint: planIssueSeverityColor(theme.colorScheme, maxSeverity),
            onTap: onIssuesTap,
          ),
      ],
    );
  }
}
