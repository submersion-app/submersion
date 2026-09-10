import 'package:submersion/core/providers/provider.dart';
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
