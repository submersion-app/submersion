import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_profile_writes.dart';
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
/// Auto-disposed, so with no trip page open dive writes elsewhere do not
/// keep re-running its query. The trip page's tabs hold it while the page is
/// up, so a visit to another tab does not drop the answer.
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

/// Where the day picker hears of a stored profile being written.
final tripProfileWritesSourceProvider = Provider<TripProfileWrites>(
  (ref) => TripProfileWrites(),
);

/// Counts the writes of a dive's stored profile: a download or an import
/// filling in a dive that was logged by hand, a reparse, a merge. Only a dive
/// the picker drew as an estimate changes shape on one: see
/// [TripProfileWrites].
///
/// The trip story asks for its profiles again on each one. The story itself
/// cannot say when: it is read without samples, so a dive that gains a
/// profile can leave the story exactly as it was. A count, because a stream
/// of nothing would repeat one value and notify nobody.
final tripProfileWritesProvider = StreamProvider.autoDispose<int>((ref) {
  var count = 0;
  return ref.watch(tripProfileWritesSourceProvider).watch().map((_) => ++count);
});
