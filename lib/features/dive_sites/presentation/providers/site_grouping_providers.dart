import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How the diver grouped the Dive Sites list, as they left it (issue #3748):
/// the active diver's saved grouping, or ungrouped when there is none.
/// Change it through `ListArrangementWrites.setSiteGroupBy`.
final siteGroupByProvider = Provider<SiteGroupBy>(
  (ref) =>
      decodeEnumName(
        ref.watch(
          settingsProvider.select((s) => s.listArrangements.siteGroupBy),
        ),
        SiteGroupBy.values,
      ) ??
      SiteGroupBy.none,
);

/// Groups the diver has opened on the grouped Dive Sites list: outer groups
/// (countries for the two country-based modes, bodies of water for the
/// water-only mode) and subgroups (regions, or bodies of water nested under
/// a country) share this one set, keyed with [subGroupExpansionKey] for a
/// subgroup -- both start closed, so one mechanism serves both. Null until
/// the first toggle, so the list can open the selected site's groups
/// without writing state during build. Kept in a provider so opening a site
/// and coming back keeps the list as the diver left it.
///
/// Resets to null whenever [siteGroupByProvider] changes, since a stored key
/// from one grouping mode (a country) has no meaning in another (a body of
/// water). Watching the mode here, rather than resetting from a widget, keeps
/// that true however and wherever the mode changes.
final siteListExpandedGroupsProvider = StateProvider<Set<String>?>((ref) {
  ref.watch(siteGroupByProvider);
  return null;
});
