import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// How many of the active diver's routes still wait for the diver to pick a
/// dive: every unlinked one, since nothing links a route but the diver
/// (#2394). Drives the Tracks list's "N underwater tracks need your choice"
/// hint. Counted straight from [unlinkedNavTracksProvider], so it follows
/// every write to the routes table, synced ones included, and never depends
/// on the dive table: a newly downloaded or synced dive cannot change it
/// (#2851).
final navTrackPendingChoiceCountProvider = FutureProvider<int>((ref) async {
  final unlinked = await ref.watch(unlinkedNavTracksProvider.future);
  return unlinked.length;
});
