import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

final equipmentObservationRepositoryProvider =
    Provider<EquipmentObservationRepository>(
      (ref) => EquipmentObservationRepository(),
    );

/// Every check-in on one item, newest first. Self-invalidates on the
/// observations table so a sync pull or a sheet write is reflected.
final observationsForEquipmentProvider =
    FutureProvider.family<List<EquipmentObservation>, String>((
      ref,
      equipmentId,
    ) async {
      final repo = ref.watch(equipmentObservationRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getForEquipment(equipmentId);
    });

/// Every check-in on one dive, across items; the dive detail rows derive
/// their chip from it with one read per dive rather than one per row.
final observationsForDiveProvider =
    FutureProvider.family<List<EquipmentObservation>, String>((
      ref,
      diveId,
    ) async {
      final repo = ref.watch(equipmentObservationRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getForDive(diveId);
    });

/// The dive numbers of the dives [equipmentId]'s check-ins name, keyed by
/// dive id, in one slim read: the item page's rows need a number, not the
/// hydrated dive, and an item can carry check-ins from many dives. A dive
/// that no longer exists is absent.
final observationDiveNumbersProvider =
    FutureProvider.family<Map<String, int?>, String>((ref, equipmentId) async {
      final observations = await ref.watch(
        observationsForEquipmentProvider(equipmentId).future,
      );
      final diveIds = {for (final o in observations) ?o.diveId};
      if (diveIds.isEmpty) return const {};
      final dives = ref.watch(diveRepositoryProvider);
      // A renumber writes only the dives table.
      ref.invalidateSelfWhen(dives.watchDivesChanges());
      final summaries = await dives.getSummariesByIds(diveIds.toList());
      return {for (final d in summaries) d.id: d.diveNumber};
    });
