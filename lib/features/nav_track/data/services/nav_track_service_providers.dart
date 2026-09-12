import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
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
  ),
);
