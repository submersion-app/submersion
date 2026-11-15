import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_undived_plan_queries.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The read that names a trip's plans nobody has dived.
final tripUndivedPlanQueriesProvider = Provider<TripUndivedPlanQueries>(
  (ref) => TripUndivedPlanQueries(),
);

/// The ids of a trip's dives that have not happened, for the day picker's
/// dashed outlines. Re-reads on any dive or trip write: a download filling a
/// plan, or a side trip linked, changes the answer.
///
/// Auto-disposed, so with no trip story on screen dive writes elsewhere do
/// not keep re-running its query.
final tripUndivedPlanIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, tripId) {
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(tripRepositoryProvider).watchTripsChanges(),
      );
      return ref.watch(tripUndivedPlanQueriesProvider).undivedPlanIds(tripId);
    });
