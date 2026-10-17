import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/list_return_scope.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// What a pushed trip list puts back when it goes away: the trip filter and
/// highlighted trip that were in place before it opened.
///
/// Carried as the `/trips` route's `extra`. The highlight matters as much as
/// the filter: it is global, and a table-mode list under the pushed one
/// replays it into its own URL once uncovered (#3350).
class TripListReturn implements ListReturn {
  const TripListReturn({required this.filter, required this.highlightedTripId});

  final TripFilterState filter;
  final String? highlightedTripId;

  @override
  VoidCallback bindRestore(WidgetRef ref) {
    final filterController = ref.read(tripFilterProvider.notifier);
    final highlightController = ref.read(highlightedTripIdProvider.notifier);
    return () {
      if (filterController.mounted) filterController.state = filter;
      if (highlightController.mounted) {
        highlightController.state = highlightedTripId;
      }
    };
  }
}

/// Shows the trips matching [filter] on a trip list pushed over the current
/// page, so its back arrow returns here (#3350).
///
/// The filter is replaced rather than merged: a leftover query would hide
/// some of the trips the link promised. The filter and highlight in place
/// before are handed to the pushed list, which puts them back when it goes
/// away.
///
/// A second tap that lands before the first push has drawn finds that list
/// already on top, showing these trips, and opens nothing: one Back must
/// still return here.
void openTripList(BuildContext context, WidgetRef ref, TripFilterState filter) {
  const location = '/trips';
  if (isPushedOnTop(context, location) &&
      ref.read(tripFilterProvider) == filter) {
    return;
  }
  final returnTo = TripListReturn(
    filter: ref.read(tripFilterProvider),
    highlightedTripId: ref.read(highlightedTripIdProvider),
  );
  ref.read(tripFilterProvider.notifier).state = filter;
  context.push(location, extra: returnTo);
}
