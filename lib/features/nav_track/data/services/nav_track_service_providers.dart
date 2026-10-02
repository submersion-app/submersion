import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// The match-service provider for [NavTrackMatchService]'s two backend sweep
/// triggers (a dive-computer download, `download_providers.dart`; after
/// sync, `sync_providers.dart`) -- mirrors `gpsTrackMatchServiceProvider` in
/// `gps_log_providers.dart`. Reuses `navTrackRepositoryProvider` from
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

/// How many of the active diver's unlinked routes `NavTrackMatchService`
/// reports -- every one of them, since a sweep no longer links anything by
/// itself (#2394). Drives the routes list's "N routes need your choice"
/// hint; refreshes whenever the route list itself changes (a route
/// imported, linked or removed). A dive added or removed with no route-list
/// change of its own does not retrigger this until the next manual "Check
/// now", the same staleness window the hint already accepts elsewhere.
final navTrackPendingChoiceCountProvider = FutureProvider<int>((ref) async {
  ref.watch(allNavTracksProvider);
  final suggestions = await ref.watch(navTrackMatchServiceProvider).sweep();
  return suggestions.length;
});
