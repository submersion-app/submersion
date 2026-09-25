import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

final navTrackRepositoryProvider = Provider<NavTrackRepository>(
  (ref) => NavTrackRepository(),
);

/// Every route, for the routes area's list page: unlinked first, then most
/// recently recorded within each group (the repository already sorts this).
final allNavTracksProvider = FutureProvider<List<NavTrack>>((ref) async {
  final repository = ref.watch(navTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getAll();
});

/// Every route with no dive link, for the routes area and the manual link
/// pickers.
final unlinkedNavTracksProvider = FutureProvider<List<NavTrack>>((ref) async {
  final repository = ref.watch(navTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getUnlinked();
});

/// Every route linked to [diveId], primary first (the dive detail section's
/// list).
final navTracksForDiveProvider = FutureProvider.family<List<NavTrack>, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(navTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getForDive(diveId);
});

/// The route a dive's 3D seascape draws, or null when no route is linked.
/// This is what `spatialReckonedPathProvider` consumes ahead of dead
/// reckoning.
///
/// Rebuilds only when the dive's primary route changes identity or its own
/// row changes: `getForDive` lists the primary first (ties broken the same
/// way on every device), and selecting just its id keeps a write to a
/// sibling route from reloading the scene.
final primaryNavTrackForDiveProvider = FutureProvider.family<NavTrack?, String>(
  (ref, diveId) async {
    final primaryId = await ref.watch(
      navTracksForDiveProvider(
        diveId,
      ).selectAsync((routes) => routes.firstOrNull?.id),
    );
    if (primaryId == null) return null;
    return ref.watch(navTrackByIdProvider(primaryId).future);
  },
);

/// One route, hydrated with its points, for the detail and alignment pages.
///
/// Refreshes on changes to this route only (see
/// [NavTrackRepository.watchRouteChanges]).
final navTrackByIdProvider = FutureProvider.family<NavTrack?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(navTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRouteChanges(id));
  return repository.getById(id, includePoints: true);
});
