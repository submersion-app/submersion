import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The warnings list at the foot of the results sheet. When a marker tapped
/// on the chart picks out warnings that are scrolled out of the sheet, it
/// brings the whole list into view, or, when the list is taller than the
/// sheet, just enough to show the picked rows (#3738).
class PlanWarningsSection extends ConsumerStatefulWidget {
  const PlanWarningsSection({
    super.key,
    required this.issues,
    required this.units,
  });

  final List<PlanIssue> issues;
  final UnitFormatter units;

  @override
  ConsumerState<PlanWarningsSection> createState() =>
      _PlanWarningsSectionState();
}

class _PlanWarningsSectionState extends ConsumerState<PlanWarningsSection> {
  final _rowKeys = <PlanIssueKey, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    ref.listen(planIssueRevealRequestProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    });
    final theme = Theme.of(context);
    final groups = groupPlanIssues(widget.issues);
    final shown = {for (final group in groups) group.key};
    _rowKeys.removeWhere((key, _) => !shown.contains(key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanSectionHeader(context.l10n.divePlanner_label_warnings),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              context.l10n.divePlanner_label_empty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final group in groups)
            KeyedSubtree(
              key: _rowKeys.putIfAbsent(group.key, GlobalKey.new),
              child: _IssueRow(group: group, units: widget.units),
            ),
      ],
    );
  }

  /// Scrolls the sheet no further than it must to show the whole list, or
  /// the picked rows when the list cannot fit. Does nothing when they are
  /// already in view, or when the sheet does not scroll on its own (the
  /// phone's Results tab, where it would scroll the chart away).
  void _reveal() {
    if (!mounted) return;
    final section = context.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (section is! RenderBox || position == null || !section.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(section);
    if (viewport == null) return;

    var target = Offset.zero & section.size;
    if (target.height > position.viewportDimension) {
      final picked = _pickedRowRects(section);
      if (picked.isEmpty) return;
      final span = picked.reduce((a, b) => a.expandToInclude(b));
      target = span.height > position.viewportDimension ? picked.first : span;
    }

    final alignTop = viewport.getOffsetToReveal(section, 0, rect: target);
    final alignBottom = viewport.getOffsetToReveal(section, 1, rect: target);
    final double to;
    if (position.pixels < alignBottom.offset) {
      to = alignBottom.offset;
    } else if (position.pixels > alignTop.offset) {
      to = alignTop.offset;
    } else {
      return;
    }
    position.animateTo(
      to.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Where the picked rows sit within [section], in list order.
  List<Rect> _pickedRowRects(RenderBox section) {
    final picked = ref.read(highlightedPlanIssuesProvider);
    return [
      for (final MapEntry(:key, value: rowKey) in _rowKeys.entries)
        if (picked.contains(key))
          if (rowKey.currentContext?.findRenderObject() case final RenderBox row
              when row.hasSize)
            row.localToGlobal(Offset.zero, ancestor: section) & row.size,
    ]..sort((a, b) => a.top.compareTo(b.top));
  }
}

/// One warnings-list row. A row with a marker on the chart (#3738) picks
/// that marker out when tapped, and is tinted while it is picked, whether
/// from here or from the chart.
class _IssueRow extends ConsumerWidget {
  const _IssueRow({required this.group, required this.units});

  final GroupedPlanIssue group;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final issue = group.issue;
    final color = planIssueSeverityColor(theme.colorScheme, issue.severity);
    final message = planIssueMessage(context, issue, units);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PlanWarningRow(
        icon: planIssueIcon(issue.severity),
        color: color,
        message: group.count > 1
            ? context.l10n.plannerCanvas_issue_repeated(message, group.count)
            : message,
      ),
    );
    final onChart = ref.watch(
      planIssueMarkersProvider.select(
        (markers) => markers.any((m) => m.keys.contains(group.key)),
      ),
    );
    if (!onChart) return row;
    final picked = ref.watch(
      highlightedPlanIssuesProvider.select((keys) => keys.contains(group.key)),
    );
    return Material(
      key: ValueKey('planIssueRow-${issue.type.name}-${issue.severity.name}'),
      color: picked ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ref.read(highlightedPlanIssuesProvider.notifier).state =
            picked ? const {} : {group.key},
        child: row,
      ),
    );
  }
}
