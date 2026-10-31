import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The words for a plan deeper than every bailout gas it carries (#3961). The
/// depth rounds up and the MOD down, so the two can never read as equal.
String bailoutGasGapMessage(
  AppLocalizations l10n,
  UnitFormatter units, {
  required double depthMeters,
  required double deepestModMeters,
}) => l10n.plannerCanvas_issue_noEligibleBailoutGas(
  units.formatDepthCeil(depthMeters, decimals: 0),
  units.formatDepthFloor(deepestModMeters, decimals: 0),
);

/// What a background plan result is doing, in words. Always text, so it
/// reaches a screen reader and never rests on dimming alone. Nothing for a
/// current result.
class PlanResultStatusText extends StatelessWidget {
  const PlanResultStatusText(this.status, {super.key});

  final PlanResultStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = switch (status) {
      PlanResultStatus.current => null,
      PlanResultStatus.updating => l10n.plannerCanvas_results_updating,
      PlanResultStatus.calculating => l10n.plannerCanvas_results_calculating,
      PlanResultStatus.failed => l10n.plannerCanvas_results_failed,
    };
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: status == PlanResultStatus.failed
            ? theme.colorScheme.error
            : null,
      ),
    );
  }
}

/// A section built from a background plan result: its status above it, and
/// its figures dimmed while they are not the current answer.
class PlanResultSection<T extends Object> extends StatelessWidget {
  const PlanResultSection({
    super.key,
    required this.view,
    required this.builder,
  });

  final PlanResultView<T?> view;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = view.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view.isMarked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: PlanResultStatusText(view.status),
          ),
        if (value != null)
          view.isMarked
              ? Opacity(opacity: 0.5, child: builder(value))
              : builder(value),
      ],
    );
  }
}

/// Says on the chart itself when its bailout picture is not current, or when
/// there is none to draw because no carried gas reaches the plan (#3961). It
/// is here, not on the mode toggle, because the fullscreen chart has no toggle
/// and a phone can scroll the toggle out of its strip.
class PlanChartBailoutStatus extends ConsumerWidget {
  const PlanChartBailoutStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(planChartBailoutProvider.select((c) => c.status));
    final gap = ref.watch(planChartBailoutProvider.select((c) => c.gasGap));
    if (status == null && gap == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: status != null
            ? PlanResultStatusText(status)
            : Text(
                bailoutGasGapMessage(
                  context.l10n,
                  UnitFormatter(ref.watch(settingsProvider)),
                  depthMeters: gap!.depthMeters,
                  deepestModMeters: gap.deepestModMeters,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
      ),
    );
  }
}
