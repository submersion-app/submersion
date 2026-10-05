import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final equipmentLocationRepositoryProvider =
    Provider<EquipmentLocationRepository>(
      (ref) => EquipmentLocationRepository(),
    );

final equipmentLocationMoveRepositoryProvider =
    Provider<EquipmentLocationMoveRepository>(
      (ref) => EquipmentLocationMoveRepository(),
    );

/// The active diver's places, archived included (callers filter).
final equipmentLocationsProvider = FutureProvider<List<EquipmentLocation>>((
  ref,
) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(equipmentLocationRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getLocations(diverId: diverId);
});

/// Every place by id, whoever owns it: a shared or transferred item can sit
/// at another profile's place, and its name must still resolve.
final allEquipmentLocationsByIdProvider =
    FutureProvider<Map<String, EquipmentLocation>>((ref) async {
      final repository = ref.watch(equipmentLocationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return {for (final l in await repository.getLocations()) l.id: l};
    });

/// Item id to its current place. Items with no moves, a cleared location or
/// a deleted place are absent.
final currentEquipmentLocationsProvider =
    FutureProvider<Map<String, EquipmentLocation>>((ref) async {
      final moves = ref.watch(equipmentLocationMoveRepositoryProvider);
      ref.invalidateSelfWhen(moves.watchChanges());
      final places = await ref.watch(allEquipmentLocationsByIdProvider.future);
      final current = await moves.getCurrentLocationIds();
      return {
        for (final entry in current.entries) entry.key: ?places[entry.value],
      };
    });

/// One item's moves, newest first.
final equipmentLocationMovesProvider =
    FutureProvider.family<List<EquipmentLocationMove>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentLocationMoveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getMovesFor(equipmentId);
    });

/// The Equipment page's group-by-location switch.
final equipmentGroupByLocationProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(appSettingsRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchSettingsChanges());
  return repo.getEquipmentGroupByLocation();
});
