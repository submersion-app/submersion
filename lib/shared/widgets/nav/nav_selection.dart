import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

/// How specifically [location] belongs to [destination]; 0 means not at all.
///
/// A path prefix scores its segment count, so a deeper page outscores the
/// section it sits in: `/planning/gas-calculators/blender` belongs to a
/// Blender shortcut (3) more than to Planning (1). Prefixes match whole
/// segments only, so `/dives` never claims `/dives-x`. A desktop selection
/// form scores one more than its path, so `/planning?tool=deco-calculator`
/// belongs to a Deco shortcut rather than to Planning.
int navMatchScore(NavDestination destination, Uri location) {
  final segments = _segments(location.path);
  var best = 0;
  for (final path in [destination.route, ...destination.extraMatchPaths]) {
    final prefix = _segments(path);
    if (prefix.isEmpty || prefix.length > segments.length) continue;
    var matches = true;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != segments[i]) {
        matches = false;
        break;
      }
    }
    if (matches && prefix.length > best) best = prefix.length;
  }

  final selection = destination.selection;
  if (selection != null &&
      location.path == selection.path &&
      location.queryParameters[selection.queryKey] == selection.queryValue) {
    final score = _segments(selection.path).length + 1;
    if (score > best) best = score;
  }
  return best;
}

/// The page a nav shortcut's alias location shows, at its canonical path and
/// carrying the alias's query; null for any other location.
///
/// Selection scores both, so a page opened as a shortcut still belongs to its
/// section when that shortcut is not on the surface being shown, and the Gas
/// calculators hub opened as a shortcut (`?calc=blender`) still selects a
/// calculator's own shortcut.
Uri? _canonicalOf(Uri location) {
  if (!location.path.startsWith('$kShortcutLocationPrefix/')) return null;
  final id = location.path.substring(kShortcutLocationPrefix.length + 1);
  final shortcut = navShortcutById(id);
  if (shortcut == null) return null;
  return Uri(
    path: shortcut.canonicalPath,
    queryParameters: location.queryParameters.isEmpty
        ? null
        : location.queryParameters,
  );
}

/// Index of the best-scoring destination for [location], the first one on a
/// tie, or null when none matches.
int? bestNavMatchIndex(List<NavDestination> destinations, Uri location) {
  final canonical = _canonicalOf(location);
  int? bestIndex;
  var bestScore = 0;
  for (var i = 0; i < destinations.length; i++) {
    final direct = navMatchScore(destinations[i], location);
    final viaCanonical = canonical == null
        ? 0
        : navMatchScore(destinations[i], canonical);
    final score = direct > viaCanonical ? direct : viaCanonical;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/// The rail's selected index: the most specific match, or Home (index 0).
int railSelectedIndex(List<NavDestination> rail, Uri location) =>
    bestNavMatchIndex(rail, location) ?? 0;

/// The bottom bar's selected index.
///
/// [primary] is `[Home, ...slots, More]`. The best match is taken across the
/// slots and [overflow] together, so a page whose most specific destination
/// sits in the More sheet selects More even when a less specific one (its
/// section) is in the bar. No match selects More, as it always has.
int phoneSelectedIndex({
  required List<NavDestination> primary,
  required List<NavDestination> overflow,
  required Uri location,
}) {
  final moreIndex = primary.length - 1;
  final best = bestNavMatchIndex([
    ...primary.take(moreIndex),
    ...overflow,
  ], location);
  if (best == null || best >= moreIndex) return moreIndex;
  return best;
}

List<String> _segments(String path) =>
    Uri.parse(path).pathSegments.where((s) => s.isNotEmpty).toList();
