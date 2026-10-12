import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Whether the page holding [context] has a page under it to go back to.
///
/// Page-local on purpose: the router as a whole can pop whenever anything on
/// the stack can, which says nothing about this page.
bool isPushedRoute(BuildContext context) =>
    ModalRoute.of(context)?.canPop ?? false;

/// The match for the page actually on top of [match]: a shell reports its own
/// prefix, so descend through shells to the leaf.
RouteMatchBase leafMatch(RouteMatchBase match) {
  var current = match;
  while (current is ShellRouteMatch && current.matches.isNotEmpty) {
    current = current.matches.last;
  }
  return current;
}

/// Whether the page holding [context] was put on the stack by a push, as
/// opposed to built from a URL by go().
///
/// Stricter than [isPushedRoute]: go('/equipment/e1') builds the equipment
/// list under the item (the detail route is the list's child), so the item
/// can pop without having been pushed. A pushed page's state carries its
/// imperative match's own page key, which a later replace() keeps.
bool isImperativelyPushed(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return false;
  return _hasImperativeMatch(
    router.routerDelegate.currentConfiguration.matches,
    GoRouterState.of(context).pageKey,
  );
}

bool _hasImperativeMatch(List<RouteMatchBase> matches, ValueKey<String> key) {
  for (final match in matches) {
    if (match is ImperativeRouteMatch) {
      if (match.pageKey == key) return true;
      if (_hasImperativeMatch(match.matches.matches, key)) return true;
    } else if (match is ShellRouteMatch) {
      if (_hasImperativeMatch(match.matches, key)) return true;
    }
  }
  return false;
}

/// Whether a standalone detail page should move itself into its section's
/// master-detail split (`/<section>?selected=<id>`).
///
/// A page reached by URL does: a deep link, or an item opened at phone width
/// before the window was widened. A page pushed from somewhere else (a dive's
/// linked gear, a buddy's shared dive) stays put, or the redirect's `go` would
/// erase the page it came from and its back arrow with it (#764, #3292).
/// Embedded pages, phone widths, table mode (which has no split to move into)
/// and pages outside a router never redirect. Nor does a page that is not on
/// top: one animating out after a pop rebuilds once its push has already left
/// the router's stack, and would otherwise take itself for a URL visit.
bool shouldRedirectToMasterDetail(
  BuildContext context, {
  required bool embedded,
  required ListViewMode viewMode,
}) =>
    // Cheap checks first: the router walk below runs on every build.
    !embedded &&
    viewMode != ListViewMode.table &&
    ResponsiveBreakpoints.isMasterDetail(context) &&
    GoRouter.maybeOf(context) != null &&
    (ModalRoute.of(context)?.isCurrent ?? true) &&
    !isImperativelyPushed(context);
