import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// The match-service provider for [NavTrackMatchService]'s backend sweep
/// trigger (a dive-computer download, `download_providers.dart`), mirroring
/// `gpsTrackMatchServiceProvider` in `gps_log_providers.dart`. Reuses
/// `navTrackRepositoryProvider` from
/// `nav_track_providers.dart` rather than redefining it.
///
/// `navTrackImportServiceProvider` (the other prepare()/commit() service
/// this feature needs) is defined in
/// `presentation/providers/nav_track_import_flow_providers.dart` instead of
/// here, on purpose -- see that file's own comment.
final navTrackMatchServiceProvider = Provider<NavTrackMatchService>(
  (ref) => NavTrackMatchService(
    routeRepository: ref.watch(navTrackRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
    currentDiverId: () => ref.read(validatedCurrentDiverIdProvider.future),
  ),
);

/// How many of the active diver's routes still wait for the diver to pick a
/// dive: every unlinked one, since a sweep no longer links anything by
/// itself (#2394). Drives the Tracks list's "N underwater tracks need your
/// choice" hint. Counted straight from [unlinkedNavTracksProvider] (the same
/// `getUnlinked` query a sweep starts from), so it refreshes on every route
/// change without re-reading the whole dive table the way a sweep would.
final navTrackPendingChoiceCountProvider = FutureProvider<int>((ref) async {
  final unlinked = await ref.watch(unlinkedNavTracksProvider.future);
  return unlinked.length;
});
