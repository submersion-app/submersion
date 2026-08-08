import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helper for jumping to a detail page from a section the user
/// expects to be returned to.
///
/// `context.go(...)` is declarative: it discards the current stack and rebuilds
/// it from the target location. For a child route such as `/dives/:diveId` that
/// also materializes the `/dives` ancestor, so Back lands the user on a list
/// they never visited and the section they came from -- with its filters and
/// scroll position -- is gone.
///
/// `push` keeps that section underneath, but unlike `go` it is not idempotent:
/// a double tap, or a navigation loop that can reach the same page twice,
/// stacks duplicate live copies that each need their own Back press.
extension SectionNavigation on BuildContext {
  /// Navigate to [location], keeping the current section underneath.
  ///
  /// Pushes when [location] is not already on the stack. When it is, walks
  /// back to the existing page instead of stacking a second copy of it.
  void pushOrReturnTo(String location) {
    final router = GoRouter.of(this);
    if (!_stackContains(
      router.routerDelegate.currentConfiguration.matches,
      location,
    )) {
      router.push(location);
      return;
    }

    // Bounded: each iteration pops one page, and the guard keeps a router
    // state we did not anticipate from spinning rather than failing visibly.
    for (var guard = 0; guard < 32; guard++) {
      final matches = router.routerDelegate.currentConfiguration.matches;
      if (matches.isEmpty) return;
      if (_leafLocation(matches.last) == location) return;
      if (!router.canPop()) return;
      router.pop();
    }
  }
}

/// Whether any page in [matches] resolves to [location].
///
/// Shell matches nest their children, and an imperative (pushed) match carries
/// the whole match list that produced it, so both have to be descended into.
bool _stackContains(List<RouteMatchBase> matches, String location) {
  for (final match in matches) {
    if (match is ShellRouteMatch) {
      if (_stackContains(match.matches, location)) return true;
      continue;
    }
    if (match is ImperativeRouteMatch) {
      if (_stackContains(match.matches.matches, location)) return true;
      continue;
    }
    if (match.matchedLocation == location) return true;
  }
  return false;
}

/// The location of the page actually on top for [match].
///
/// A shell reports its own prefix, so descend to the leaf. An
/// [ImperativeRouteMatch] already reports the leaf of the list that produced
/// it, so it needs no descent.
String _leafLocation(RouteMatchBase match) {
  var current = match;
  while (current is ShellRouteMatch && current.matches.isNotEmpty) {
    current = current.matches.last;
  }
  return current.matchedLocation;
}
