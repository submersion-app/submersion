/// Up-navigation rules for the Android system back button.
///
/// The app uses a single [ShellRoute], so every tab shares one Navigator
/// stack. `context.go()` *replaces* that stack rather than pushing onto it,
/// which leaves the Navigator one route deep with nothing to pop. Android's
/// system back then falls through to `SystemNavigator.pop()` and closes the
/// app instead of going back (#647).
///
/// [resolveUpLocation] supplies the fallback the shell uses in that case:
/// walk one step up the location hierarchy instead of exiting.
library;

/// The app's root location. System back exits the app from here.
const String kRootLocation = '/dashboard';

/// Query parameters that represent a drill-down within a master-detail page,
/// ordered innermost first so each back press unwinds exactly one level.
///
/// `mode` opens a create/edit form over a list; `selected` opens a detail
/// pane. `/dives?selected=42&mode=edit` therefore unwinds to
/// `/dives?selected=42`, then to `/dives`, then to the dashboard.
const List<String> _drillDownParams = ['mode', 'selected'];

/// Returns the location one level above [uri], or null when [uri] is the app
/// root and the system back press should be allowed to exit the app.
///
/// Resolution order:
/// 1. Unwind a master-detail query parameter, if present.
/// 2. Drop the last path segment, for genuinely nested routes.
/// 3. Fall back to the dashboard from any top-level tab.
String? resolveUpLocation(Uri uri) {
  for (final param in _drillDownParams) {
    if (uri.queryParameters.containsKey(param)) {
      final remaining = Map<String, String>.from(uri.queryParameters)
        ..remove(param);
      return _formatLocation(uri.path, remaining);
    }
  }

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (segments.length > 1) {
    return '/${segments.take(segments.length - 1).join('/')}';
  }

  if (segments.length == 1 && '/${segments.first}' == kRootLocation) {
    return null;
  }

  return kRootLocation;
}

String _formatLocation(String path, Map<String, String> queryParameters) {
  if (queryParameters.isEmpty) return path;
  return Uri(path: path, queryParameters: queryParameters).toString();
}
