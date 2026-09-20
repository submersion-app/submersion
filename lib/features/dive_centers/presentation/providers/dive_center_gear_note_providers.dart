import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final diveCenterGearNoteRepositoryProvider =
    Provider<DiveCenterGearNoteRepository>((ref) {
      return DiveCenterGearNoteRepository();
    });

/// A center's rental gear notes, newest first. Self-invalidates on any
/// write to the table, local or synced.
final diveCenterGearNotesProvider =
    FutureProvider.family<List<DiveCenterGearNote>, String>((
      ref,
      centerId,
    ) async {
      final repository = ref.watch(diveCenterGearNoteRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getForCenter(centerId);
    });

/// Which center, and which dive to leave out (the one being edited).
typedef LastDiveAtCenterQuery = ({String centerId, String? excludingDiveId});

/// The diver's most recent other dive at a center, fully hydrated, or null.
/// Reads the `dives` table, so it self-invalidates on dive changes.
final lastDiveAtCenterProvider =
    FutureProvider.family<LastDiveAtCenter?, LastDiveAtCenterQuery>((
      ref,
      query,
    ) async {
      final centers = ref.watch(diveCenterRepositoryProvider);
      final dives = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(dives.watchDivesChanges());
      final id = await centers.latestDiveIdAtCenter(
        query.centerId,
        excludingDiveId: query.excludingDiveId,
      );
      if (id == null) return null;
      final dive = await dives.getDiveById(id);
      return dive == null ? null : LastDiveAtCenter.fromDive(dive);
    });
