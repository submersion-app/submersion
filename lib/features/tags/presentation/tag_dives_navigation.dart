import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Opens the dive list showing only the dives tagged [tagId] (#1833).
///
/// The one place a tap on a tag becomes "show me those dives", used by the
/// tag chips on a dive. Manage Tags rows do not navigate: it is a settings
/// page.
///
/// The filter is replaced rather than merged, like the site, buddy and dive
/// computer "view dives" links: a leftover date, depth or site filter would
/// hide some of the tag's dives, and the list would stop matching the dive
/// count Manage Tags shows for the tag. The filter chip on the dive list
/// clears it again.
///
/// The list is pushed over the dive the chip was on, so its back arrow
/// returns to that dive (#3292).
void openDivesWithTag(BuildContext context, WidgetRef ref, String tagId) {
  openDiveList(context, ref, DiveFilterState(tagIds: [tagId]));
}
