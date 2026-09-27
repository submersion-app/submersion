import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';

/// Service provider for [NavTrackImportService], the prepare()/commit() two
/// step flow the import review page drives. Kept in its own file (rather
/// than alongside `nav_track_service_providers.dart`, where
/// `navTrackMatchServiceProvider` already lives) so this and
/// `NavTrackImportReviewPage` could be built concurrently in the same
/// worktree without both changes touching the same provider file.
final navTrackImportServiceProvider = Provider<NavTrackImportService>(
  (ref) => NavTrackImportService(),
);
