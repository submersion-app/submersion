import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

/// Service that applies and undoes bulk edits across the selected dives.
final bulkDiveEditServiceProvider = Provider<BulkDiveEditService>((ref) {
  return BulkDiveEditService(
    ref.watch(diveRepositoryProvider),
    ref.watch(buddyRepositoryProvider),
    ref.watch(speciesRepositoryProvider),
  );
});
