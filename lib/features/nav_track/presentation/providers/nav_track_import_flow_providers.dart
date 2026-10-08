import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';

/// Service provider for [NavTrackImportService], the prepare()/commit() two
/// step flow the import review page drives.
final navTrackImportServiceProvider = Provider<NavTrackImportService>(
  (ref) => NavTrackImportService(
    currentDiverId: () => ref.read(validatedCurrentDiverIdProvider.future),
  ),
);
