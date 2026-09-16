import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Opens the site list showing only the sites tagged [tagId] (issue #1765),
/// the site twin of `openDivesWithTag`.
///
/// The filter is replaced rather than merged, for the same reason: a
/// leftover country, depth or type filter would hide some of the tag's
/// sites, and the list would stop matching the site count Manage Tags shows.
/// The filter chip on the site list clears it again.
void openSitesWithTag(BuildContext context, WidgetRef ref, String tagId) {
  ref.read(siteFilterProvider.notifier).state = SiteFilterState(
    tagIds: {tagId},
  );
  context.go('/sites');
}
