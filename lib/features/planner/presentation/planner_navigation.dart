import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Where the dive planner lives.
const divePlannerLocation = '/planning/dive-planner';

/// Opens the dive planner from elsewhere in the app, such as a dive in the
/// log: pushed, so Back returns to where the diver was.
///
/// When the planner is already in the stack (a dive opened from the planner,
/// say), a second push would put the planning shell in the stack twice and
/// go_router would fail on its duplicate page keys. The stack is replaced
/// with the planner instead.
void openDivePlanner(BuildContext context) {
  final router = GoRouter.of(context);
  if (plannerInStack(router.routerDelegate.currentConfiguration)) {
    router.go(divePlannerLocation);
  } else {
    router.push(divePlannerLocation);
  }
}

/// Whether any route of [matches], pushed ones and those inside shells
/// included, is in the planning section.
@visibleForTesting
bool plannerInStack(RouteMatchList matches) => _anyPlanning(matches.matches);

bool _anyPlanning(List<RouteMatchBase> matches) {
  for (final match in matches) {
    if (match.matchedLocation.startsWith('/planning')) return true;
    if (match is ShellRouteMatch && _anyPlanning(match.matches)) return true;
    if (match is ImperativeRouteMatch && plannerInStack(match.matches)) {
      return true;
    }
  }
  return false;
}
