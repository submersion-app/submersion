import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final cylinderFillRepositoryProvider = Provider<CylinderFillRepository>(
  (ref) => CylinderFillRepository(),
);

final cylinderPassportRepositoryProvider = Provider<CylinderPassportRepository>(
  (ref) => CylinderPassportRepository(),
);

/// The cylinder's passport id, or null until the passport page mints one.
/// Self-invalidates on attribute writes, which is where the id lives.
final passportIdProvider = FutureProvider.family<String?, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(cylinderPassportRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(equipmentRepositoryProvider).watchAttributeChanges(),
  );
  return repository.getPassportId(equipmentId);
});

/// Every fill of the cylinder, newest first: by passport id when it has one
/// (so fills logged before a re-created row still show), by gear link
/// otherwise.
final fillsForEquipmentProvider =
    FutureProvider.family<List<CylinderFill>, String>((ref, equipmentId) async {
      final repository = ref.watch(cylinderFillRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchFillsChanges());
      final passportId = await ref.watch(
        passportIdProvider(equipmentId).future,
      );
      if (passportId == null) return repository.getForEquipment(equipmentId);
      return repository.getForPassport(passportId);
    });

final newestFillProvider = FutureProvider.family<CylinderFill?, String>((
  ref,
  equipmentId,
) async {
  final fills = await ref.watch(fillsForEquipmentProvider(equipmentId).future);
  return fills.isEmpty ? null : fills.first;
});
