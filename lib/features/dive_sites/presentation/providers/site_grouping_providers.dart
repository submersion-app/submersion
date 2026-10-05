import 'package:submersion/core/providers/provider.dart';

/// How the Dive Sites list is grouped (#1080). Session-only, like the list's
/// sort.
enum SiteGroupBy { none, location }

final siteGroupByProvider = StateProvider<SiteGroupBy>(
  (ref) => SiteGroupBy.none,
);

/// Country groups the diver has opened on the grouped Dive Sites list. Null
/// until the first toggle, so the list can open the selected site's country
/// without writing state during build. Kept in a provider so opening a site
/// and coming back keeps the list as the diver left it.
final siteListExpandedCountriesProvider = StateProvider<Set<String>?>(
  (ref) => null,
);
