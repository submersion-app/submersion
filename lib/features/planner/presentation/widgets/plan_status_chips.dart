import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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
    final outcome = ref.watch(activePlanOutcomeProvider);
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
        const ContingencyPreviewChip(),
        const FollowingChip(),
      ],
    );
  }
}

/// "Previewing: {label}" indicator with tap-to-clear; renders nothing unless
/// a contingency (deviation or lost-gas) is selected. Every headline stat
/// above switches to that contingency's own outcome while one is selected --
/// losing a deco/stage/travel gas changes the whole deco schedule, not just
/// the chart ghost -- so this makes clear the numbers are a "what if", not
/// the live plan.
///
/// Gated on [selectedContingencyProvider], not on the raw selection ids: a
/// selection can go stale (the tank was removed, or stopped being losable)
/// while its id lingers, and the stats fall back to the live plan in that
/// case. Reading the same provider the stats read keeps the chip from
/// claiming a preview that is not in effect.
class ContingencyPreviewChip extends ConsumerWidget {
  const ContingencyPreviewChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(selectedContingencyProvider);
    if (preview == null) return const SizedBox.shrink();

    final state = ref.watch(divePlanNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    final lostTank = preview.lostTank;
    final String label;
    if (lostTank != null) {
      label = context.l10n.plannerCanvas_contingency_lostGas(
        lostTank.gasMix.name,
      );
    } else {
      final depth =
          '+${units.formatDepth(state.deviationDepthDelta, decimals: 0)}';
      final time = '+${state.deviationTimeMinutes}′';
      label = switch (ref.watch(selectedDeviationProvider)) {
        'deeper' => depth,
        'longer' => time,
        _ => '$depth $time',
      };
    }

    return PlanChip(
      label: context.l10n.plannerCanvas_contingency_previewing(label),
      value: '✕',
      tint: Theme.of(context).colorScheme.tertiary,
      onTap: () {
        ref.read(selectedDeviationProvider.notifier).state = null;
        ref.read(selectedLostGasTankIdProvider.notifier).state = null;
      },
    );
  }
}

/// "Following {dive}" indicator with tap-to-clear; renders nothing when the
/// plan does not follow a logged dive.
class FollowingChip extends ConsumerWidget {
  const FollowingChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceDiveId = ref.watch(
      divePlanNotifierProvider.select((s) => s.sourceDiveId),
    );
    if (sourceDiveId == null) return const SizedBox.shrink();

    final dive = ref.watch(diveProvider(sourceDiveId)).valueOrNull;
    final name = (dive?.name?.isNotEmpty ?? false)
        ? dive!.name!
        : (dive?.diveNumber != null ? '#${dive!.diveNumber}' : '…');

    return PlanChip(
      label: context.l10n.plannerCanvas_follow_chip(name),
      value: '✕',
      tint: Theme.of(context).colorScheme.tertiary,
      onTap: () =>
          ref.read(divePlanNotifierProvider.notifier).clearFollowedDive(),
    );
  }
}
