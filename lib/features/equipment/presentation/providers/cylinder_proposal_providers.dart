import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/equipment/data/services/cylinder_from_tank_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final cylinderFromTankServiceProvider = Provider<CylinderFromTankService>(
  (ref) => CylinderFromTankService(
    equipment: ref.watch(equipmentRepositoryProvider),
    dives: ref.watch(diveRepositoryProvider),
  ),
);

/// The cylinders the diver owns for matching (issue #4494): their tank
/// gear, shared gear and spares included, without a lost one. Retired, sold
/// and wanted gear is already out of [activeEquipmentProvider].
List<EquipmentItem> _ownedCylinders(List<EquipmentItem> gear) => [
  for (final item in gear)
    if (item.type == EquipmentType.tank && item.status != EquipmentStatus.lost)
      item,
];

/// The cylinders a download could add to the diver's gear: its new dives'
/// tanks that no owned cylinder or twin set covers (each covers one tank per
/// dive), grouped by spec. Ticks
/// on the diver's gear and on any tank write, so the summary tile goes away
/// once the diver has added or linked them.
final importCylinderProposalsProvider = FutureProvider.autoDispose
    .family<List<CylinderProposal>, ImportedDiveIds>((ref, arg) async {
      if (arg.ids.isEmpty) return const [];
      final dives = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(dives.watchDiveHydrationWrites());
      final owned = _ownedCylinders(
        await ref.watch(activeEquipmentProvider.future),
      );
      final byId = {for (final item in owned) item.id: item};
      // Watched, so a twin set paired while the summary is open counts.
      final pairings = await ref.watch(allPairingsProvider.future);
      final ownedPairs = [
        for (final p in pairings)
          if ((byId[p.cylinderAId], byId[p.cylinderBId]) case (
            final a?,
            final b?,
          ))
            (a, b),
      ];
      final loaded = await dives.getDivesByIdsWithoutSamples(arg.ids);
      return proposeCylinders(
        [
          for (final dive in loaded)
            for (final tank in dive.tanks) TankRef(diveId: dive.id, tank: tank),
        ],
        owned: owned,
        ownedPairs: ownedPairs,
      );
    });
