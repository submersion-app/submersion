import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// An entry in the dashboard's responsive grid.
sealed class DashboardEntry {
  const DashboardEntry();
}

/// Spans all columns at every width.
class FullBlock extends DashboardEntry {
  final Widget child;
  const FullBlock(this.child);
}

/// Spans one column; consecutive [ThirdBlock]s share a row. A leftover
/// block on an incomplete row expands to fill the remaining width.
class ThirdBlock extends DashboardEntry {
  final Widget child;
  const ThirdBlock(this.child);
}

/// A lead widget with side widgets stacked in the remaining column.
/// At 3 columns the lead spans 2; at 2 columns it spans 1; at 1 column
/// the group dissolves into the plain ordered stack.
class LeadSideGroup extends DashboardEntry {
  final Widget lead;
  final List<Widget> side;
  const LeadSideGroup({required this.lead, required this.side});
}

/// Responsive dashboard layout: one ordered entry list drives phone and
/// desktop. Column count follows [ResponsiveBreakpoints]: 1 below 800,
/// 2 at 800-1199, 3 at >=1200.
class DashboardGrid extends StatelessWidget {
  final List<DashboardEntry> entries;
  final double spacing;

  const DashboardGrid({required this.entries, this.spacing = 12, super.key});

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveBreakpoints.isDesktopExtended(context)
        ? 3
        : ResponsiveBreakpoints.isDesktop(context)
        ? 2
        : 1;

    final rows = <Widget>[];
    final pendingThirds = <Widget>[];

    void flushThirds() {
      if (pendingThirds.isEmpty) return;
      if (columns == 1) {
        rows.addAll(pendingThirds);
      } else {
        for (var i = 0; i < pendingThirds.length; i += columns) {
          final end = i + columns > pendingThirds.length
              ? pendingThirds.length
              : i + columns;
          final chunk = pendingThirds.sublist(i, end);
          // No IntrinsicHeight: cards keep natural heights, top-aligned.
          // Intrinsic measurement is unsafe over arbitrary card content
          // (charts, internal flex) and caused layout failures.
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < chunk.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: chunk[j]),
                ],
              ],
            ),
          );
        }
      }
      pendingThirds.clear();
    }

    for (final entry in entries) {
      switch (entry) {
        case ThirdBlock(:final child):
          pendingThirds.add(child);
        case FullBlock(:final child):
          flushThirds();
          rows.add(child);
        case LeadSideGroup(:final lead, :final side):
          flushThirds();
          if (columns == 1) {
            rows.add(lead);
            rows.addAll(side);
          } else {
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: columns == 3 ? 2 : 1, child: lead),
                  SizedBox(width: spacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < side.length; i++) ...[
                          if (i > 0) SizedBox(height: spacing),
                          side[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
      }
    }
    flushThirds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          rows[i],
        ],
      ],
    );
  }
}
