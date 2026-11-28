import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/species_id/data/repositories/dive_media_batch_repository.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/species_batch_planner.dart';
import 'package:submersion/features/species_id/data/services/species_batch_run.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// The media of many dives at once (issue #5127).
final diveMediaBatchRepositoryProvider = Provider<DiveMediaBatchRepository>(
  (ref) => DiveMediaBatchRepository(),
);

/// Counts what Find species over many dives will do (issue #5127).
final speciesBatchPlannerProvider = Provider<SpeciesBatchPlanner>((ref) {
  final media = ref.watch(diveMediaBatchRepositoryProvider);
  return SpeciesBatchPlanner(
    mediaForDives: media.mediaForDives,
    placesOf: ref.read(divePlaceRepositoryProvider).placesOf,
    upToDate: (items, locationOf) async {
      final installed = await ref.read(installedSpeciesPackProvider.future);
      if (installed == null) return const {};
      return ref
          .read(mediaIdentificationServiceProvider)
          .upToDate(
            items,
            manifest: installed.manifest,
            locationOf: locationOf,
          );
    },
    withOpenSuggestions: (ids) async =>
        (await ref
                .read(mediaIdentificationRepositoryProvider)
                .mediaIdsWithSuggestions(among: ids))
            .toSet(),
    canApply: () => ref.read(autoApplierProvider).isOn,
    libraryOriginalHere: ref.read(libraryOriginalHereProvider),
  );
});

/// Find species over many dives (issue #5127). Lives for the app session,
/// like the dives' own run, so leaving the page does not stop it.
final speciesBatchRunProvider =
    StateNotifierProvider<SpeciesBatchRun, SpeciesBatchRunState?>((ref) {
      return SpeciesBatchRun(
        runs: () => ref.read(diveSpeciesRunProvider.notifier),
        databaseGeneration: () => DatabaseService.instance.generation,
        isReverted: (operationId) async {
          final db = DatabaseService.instance.databaseOrNull;
          if (db == null) return false;
          final row = await (db.select(
            db.changeLogOperations,
          )..where((o) => o.id.equals(operationId))).getSingleOrNull();
          return row?.revertedById != null;
        },
        newOperationId: () => const Uuid().v4(),
      );
    });

/// The progress line of the batch running now, or null with none.
final speciesBatchProgressProvider = Provider<SpeciesBatchProgress?>((ref) {
  final batch = ref.watch(speciesBatchRunProvider);
  if (batch == null || !batch.isActive) return null;
  final current = batch.currentDiveId;
  final run = current == null
      ? null
      : ref.watch(diveSpeciesRunProvider.select((runs) => runs[current]));
  return SpeciesBatchProgress.of(batch, run);
});

/// Whether Find species over many dives is offered here: the feature is
/// on, this device can run the models and a pack is installed.
final speciesBatchAvailableProvider = Provider<bool>((ref) {
  if (!marineLifeIdEnabled) return false;
  return ref.watch(installedSpeciesPackProvider).value != null;
});
