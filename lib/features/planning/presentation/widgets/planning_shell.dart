import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/planning/presentation/widgets/planning_rail.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Shell for the Planning section.
///
/// Narrow screens: pass-through (push navigation).
/// Wide screens, hub route (/planning): the hub renders full width, its
/// content centered at a comfortable reading width.
/// Wide screens, tool route: a 52px [PlanningRail] beside the tool, so the
/// tool (especially the planner) gets effectively the whole window.
class PlanningShell extends StatelessWidget {
  final Widget child;

  const PlanningShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.isMasterDetail(context)) {
      return child;
    }

    final path = GoRouterState.of(context).uri.path;
    final onHub = path == '/planning';
    if (onHub) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          PlanningRail(currentPath: path),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
