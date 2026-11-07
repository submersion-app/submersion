import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';

final cylinderPairingRepositoryProvider = Provider<CylinderPairingRepository>(
  (ref) => CylinderPairingRepository(),
);

/// Every twin set pairing, resolved, newest first (issue #4242). Refreshed
/// on any pairing write, local or synced.
final allPairingsProvider = FutureProvider<List<CylinderPairing>>((ref) async {
  final repository = ref.watch(cylinderPairingRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getAll();
});

/// The pairings one cylinder has been in, newest first: its Twin set card's
/// current partner and history.
final pairingsForCylinderProvider =
    FutureProvider.family<List<CylinderPairing>, String>((
      ref,
      equipmentId,
    ) async {
      final all = await ref.watch(allPairingsProvider.future);
      return [
        for (final p in all)
          if (p.involves(equipmentId)) p,
      ];
    });

/// The cylinder's open pairing, if any.
final currentPairingProvider = FutureProvider.family<CylinderPairing?, String>(
  (ref, equipmentId) async =>
      currentPairing(await ref.watch(allPairingsProvider.future), equipmentId),
);

/// The pairing a cylinder was in on a day: what a fill or a dive dated then
/// uses (spec, "Which pairing counts").
final pairingOnProvider = FutureProvider.autoDispose
    .family<CylinderPairing?, ({String equipmentId, DateTime day})>(
      (ref, key) async => pairingOn(
        await ref.watch(allPairingsProvider.future),
        key.equipmentId,
        key.day,
      ),
    );
