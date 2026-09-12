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
final primaryNavTrackForDiveProvider = FutureProvider.family<NavTrack?, String>(
  (ref, diveId) async {
    final routes = await ref.watch(navTracksForDiveProvider(diveId).future);
    if (routes.isEmpty) return null;
    final primary =
        routes.where((r) => r.isPrimary).firstOrNull ?? routes.first;
    final repository = ref.watch(navTrackRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchChanges());
    return repository.getById(primary.id, includePoints: true);
  },
);

/// One route, hydrated with its points, for the detail and alignment pages.
final navTrackByIdProvider = FutureProvider.family<NavTrack?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(navTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getById(id, includePoints: true);
});
