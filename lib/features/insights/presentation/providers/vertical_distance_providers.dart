import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

/// The wiring both timelines share (issue #4569): keyed on the diver and
/// the Insights filter only, so a unit change does not re-query, and
/// refreshed whenever a table Insights reads is written. [read] is the
/// repository call that builds the timeline.
Future<VerticalDistanceTimeline> _watchTimeline(
  Ref ref,
  Future<VerticalDistanceTimeline> Function(
    InsightsRepository repository,
    String? diverId,
    DiveFilterState filter,
  )
  read,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  final filter = ref.watch(insightsFilterProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges(filter: filter));
  final diverId = ref.watch(currentDiverIdProvider);
  await awaitInsightsFilterCaches(ref);
  return read(repository, diverId, filter);
}

/// Every in-scope dive's vertical distance, in dive order (issue #4569).
final verticalDistanceTimelineProvider =
    FutureProvider<VerticalDistanceTimeline>(
      (ref) => _watchTimeline(
        ref,
        (repository, diverId, filter) => repository.getVerticalDistanceTimeline(
          diverId: diverId,
          filter: filter,
        ),
      ),
    );

/// Every in-scope dive's max depth, in dive order: the same scale counting
/// each dive straight down to its deepest point and back.
final maxDepthTimelineProvider = FutureProvider<VerticalDistanceTimeline>(
  (ref) => _watchTimeline(
    ref,
    (repository, diverId, filter) =>
        repository.getMaxDepthTimeline(diverId: diverId, filter: filter),
  ),
);
