import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/list_return_scope.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

/// What a pushed dive list puts back when it goes away: the dive-list filter
/// and highlighted dive that were in place before it opened.
///
/// Carried as the `/dives` route's `extra`. The highlight matters as much as
/// the filter: it is global, and a table-mode list under the pushed one
/// replays it into its own URL once uncovered (#3292).
class DiveListReturn implements ListReturn {
  const DiveListReturn({
    required this.filter,
    required this.highlightedDiveId,
    this.closedPaneDiveId,
  });

  final DiveFilterState filter;
  final String? highlightedDiveId;

  /// The dive whose pane the tab had emptied, if any (see
  /// [closedPaneRecordProvider]). Put back so what the diver opens or empties
  /// in the pushed list does not decide whether the tab reopens its pane when
  /// returned to (#3301).
  final String? closedPaneDiveId;

  @override
  VoidCallback bindRestore(WidgetRef ref) {
    final filterController = ref.read(diveFilterProvider.notifier);
    final highlightController = ref.read(highlightedDiveIdProvider.notifier);
    final closedPanesController = ref.read(closedPaneRecordProvider.notifier);
    return () {
      if (filterController.mounted) filterController.state = filter;
      if (highlightController.mounted) {
        highlightController.state = highlightedDiveId;
      }
      if (closedPanesController.mounted) {
        final closed = {...closedPanesController.state}
          ..remove(RecordListSection.dives);
        final id = closedPaneDiveId;
        closedPanesController.state = id == null
            ? closed
            : {...closed, RecordListSection.dives: id};
      }
    };
  }
}

/// Shows the dives matching [filter] on a dive list pushed over the current
/// page, so its back arrow returns here (#2784, #3292).
///
/// The filter is replaced rather than merged: a leftover date, depth or site
/// filter would hide some of the dives the link promised. The filter and
/// highlight in place before are handed to the pushed list, which puts them
/// back when it goes away. [map] opens the list's map view.
///
/// A second tap that lands before the first push has drawn finds that list
/// already on top, showing these dives, and opens nothing: one Back must
/// still return here.
void openDiveList(
  BuildContext context,
  WidgetRef ref,
  DiveFilterState filter, {
  bool map = false,
}) {
  final location = map ? '/dives?view=map' : '/dives';
  if (isPushedOnTop(context, location) &&
      ref.read(diveFilterProvider) == filter) {
    return;
  }
  final returnTo = DiveListReturn(
    filter: ref.read(diveFilterProvider),
    highlightedDiveId: ref.read(highlightedDiveIdProvider),
    closedPaneDiveId: ref.read(
      closedPaneRecordProvider,
    )[RecordListSection.dives],
  );
  ref.read(diveFilterProvider.notifier).state = filter;
  context.push(location, extra: returnTo);
}
