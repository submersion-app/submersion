import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_stop_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';

/// Dive-computer-style readouts overlaid on the phone planner chart,
/// replacing the phone chip rows: runtime (with the following pill beneath
/// it) top-left; TTS-or-NDL, deco, CNS, the stop list and the issues pill
/// top-right. Passive readouts sit under [IgnorePointer] so chart gestures
/// pass through; only the stop list, which scrolls, and the pills take
/// pointers.
///
/// Renders a [Positioned.fill], so it must be a direct child of the chart
/// [Stack].
class PlanChartReadouts extends ConsumerWidget {
  const PlanChartReadouts({super.key, required this.onIssuesTap});

  /// Invoked when the issues pill is tapped (phone: switch to Results tab).
  final VoidCallback onIssuesTap;

  /// The strip along the chart's foot that the stop list gives up rows to
  /// keep clear: the contingency chips and the full-screen button live
  /// there. The button is a fixed 56; the chips (8 up from the foot, 16 of
  /// padding round a label line) grow with the text, so at large text sizes
  /// the strip grows with them.
  static double bottomClearanceFor(TextScaler textScaler) =>
      math.max(56, 8 + 16 + textScaler.scale(16) + 4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(activePlanOutcomeProvider);
    final cnsThreshold = ref.watch(cnsWarningThresholdProvider);
    final stopTags = ref.watch(planChartStopTagsProvider);
    final bottomClearance = bottomClearanceFor(
      MediaQuery.textScalerOf(context),
    );
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);

    String minutes(int seconds) => '${(seconds / 60).ceil()}′';
    final inDeco = outcome.ndlAtBottom < 0;
    final maxSeverity = outcome.issues.isEmpty
        ? null
        : outcome.issues
              .map((i) => i.severity)
              .reduce((a, b) => a.index >= b.index ? a : b);

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Scrim panel keeps the numbers legible over grid lines in both themes.
    const panelPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
    Widget panel(Widget child) => Container(
      padding: panelPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );

    Widget row(String label, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 5),
        Text(value, style: valueStyle),
      ],
    );

    final cnsWarn = outcome.cnsEnd >= cnsThreshold;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    child: panel(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            minutes(outcome.runtimeSeconds),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            context.l10n.divePlanner_label_runtime,
                            style: labelStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Stack(
                      children: [
                        // The scrim alone lets chart gestures through; the
                        // stop list on it takes its own swipes.
                        Positioned.fill(
                          child: IgnorePointer(child: panel(const SizedBox())),
                        ),
                        Padding(
                          padding: panelPadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IgnorePointer(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (inDeco)
                                      row(
                                        context.l10n.divePlanner_label_tts,
                                        minutes(outcome.ttsAtBottom),
                                      )
                                    else
                                      row(
                                        context.l10n.divePlanner_label_ndl,
                                        minutes(
                                          outcome.ndlAtBottom.clamp(0, 1 << 30),
                                        ),
                                      ),
                                    if (outcome.totalDecoSeconds > 0)
                                      row(
                                        context.l10n.divePlanner_label_deco,
                                        minutes(outcome.totalDecoSeconds),
                                      ),
                                    Text(
                                      context.l10n.plannerCanvas_chip_cns(
                                        outcome.cnsEnd.toStringAsFixed(0),
                                      ),
                                      style: labelStyle?.copyWith(
                                        color: cnsWarn ? Colors.orange : null,
                                        fontWeight: cnsWarn
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: PlanStopList(
                                  tags: stopTags,
                                  topGap: 3,
                                  // Less the inset this overlay already has.
                                  bottomReserve: bottomClearance - 8,
                                  formatDepth: (m) =>
                                      units.formatDepth(m, decimals: 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (maxSeverity != null) ...[
                    const SizedBox(height: 4),
                    PlanChip(
                      label: context.l10n.plannerCanvas_chip_issues(
                        groupPlanIssues(outcome.issues).length,
                      ),
                      tint: planIssueSeverityColor(
                        theme.colorScheme,
                        maxSeverity,
                      ),
                      onTap: onIssuesTap,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
