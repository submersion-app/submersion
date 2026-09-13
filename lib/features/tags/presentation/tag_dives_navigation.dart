import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Opens the dive list showing only the dives tagged [tagId] (#1833).
///
/// The one place a tap on a tag becomes "show me those dives", shared by the
/// Manage Tags rows and the tag chips on a dive, so every tag surface behaves
/// the same.
///
/// The filter is replaced rather than merged, like the site, buddy and dive
/// computer "view dives" links: a leftover date, depth or site filter would
/// hide some of the tag's dives, and the list would stop matching the dive
/// count Manage Tags shows for the tag. The filter chip on the dive list
/// clears it again.
void openDivesWithTag(BuildContext context, WidgetRef ref, String tagId) {
  ref.read(diveFilterProvider.notifier).state = DiveFilterState(
    tagIds: [tagId],
  );
  context.go('/dives');
}
