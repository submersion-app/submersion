import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

/// Every in-scope dive's vertical distance, in dive order (issue #4569).
/// Keyed on the diver and the Insights filter only, so a unit change does
/// not re-query; refreshed whenever a table Insights reads is written.
final verticalDistanceTimelineProvider =
    FutureProvider<VerticalDistanceTimeline>((ref) async {
      final repository = ref.watch(insightsRepositoryProvider);
      final filter = ref.watch(insightsFilterProvider);
      ref.invalidateSelfWhen(repository.watchInsightsChanges(filter: filter));
      final diverId = ref.watch(currentDiverIdProvider);
      await awaitInsightsFilterCaches(ref);
      return repository.getVerticalDistanceTimeline(
        diverId: diverId,
        filter: filter,
      );
    });

/// Every in-scope dive's max depth, in dive order: the same scale counting
/// each dive straight down to its deepest point and back. Keyed and
/// refreshed like [verticalDistanceTimelineProvider].
final maxDepthTimelineProvider = FutureProvider<VerticalDistanceTimeline>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  final filter = ref.watch(insightsFilterProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges(filter: filter));
  final diverId = ref.watch(currentDiverIdProvider);
  await awaitInsightsFilterCaches(ref);
  return repository.getMaxDepthTimeline(diverId: diverId, filter: filter);
});
