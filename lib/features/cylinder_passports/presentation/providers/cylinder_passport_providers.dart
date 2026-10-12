import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/cylinder_passports/data/services/tag_fill_importer.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/passport_usage_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_manager_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_adoption_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final cylinderFillRepositoryProvider = Provider<CylinderFillRepository>(
  (ref) => CylinderFillRepository(),
);

final cylinderPassportRepositoryProvider = Provider<CylinderPassportRepository>(
  (ref) => CylinderPassportRepository(),
);

final passportUsageRepositoryProvider = Provider<PassportUsageRepository>(
  (ref) => PassportUsageRepository(),
);

/// The active diver's dives with a tank from the cylinder whose passport id
/// is the key, newest first (issue #2650). Auto-disposed: the key is any tag
/// the diver scans, so a kept provider per stranger's cylinder would pile up
/// change subscriptions.
final passportUsageProvider = FutureProvider.autoDispose
    .family<List<PassportUsageDive>, String>((ref, passportId) async {
      final repository = ref.watch(passportUsageRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repository.usageFor(passportId, diverId: diverId);
    });

final tagFillImporterProvider = Provider<TagFillImporter>(
  (ref) => TagFillImporter(fills: ref.watch(cylinderFillRepositoryProvider)),
);

final passportAdoptionServiceProvider = Provider<PassportAdoptionService>(
  (ref) => PassportAdoptionService(),
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

/// Every fill of the cylinder, newest first: under its passport id (so fills
/// logged before a re-created row still show) or linked to its gear row (so
/// a fill stays put when the id changes).
final fillsForEquipmentProvider =
    FutureProvider.family<List<CylinderFill>, String>((ref, equipmentId) async {
      final repository = ref.watch(cylinderFillRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchFillsChanges());
      final passportId = await ref.watch(
        passportIdProvider(equipmentId).future,
      );
      return repository.getForCylinder(
        passportId: passportId,
        equipmentId: equipmentId,
      );
    });

final newestFillProvider = FutureProvider.family<CylinderFill?, String>((
  ref,
  equipmentId,
) async {
  final fills = await ref.watch(fillsForEquipmentProvider(equipmentId).future);
  return fills.isEmpty ? null : fills.first;
});

/// Whether this platform has NFC tag reading at all: phones only
/// (spec 13.3). An iPad reports itself unsupported through the service.
bool nfcPlatform() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

final nfcTagServiceProvider = Provider<NfcTagService>(
  (ref) =>
      nfcPlatform() ? NfcManagerTagService() : const UnsupportedNfcTagService(),
);

/// Re-checked when a screen first asks and whenever the app resumes (the
/// app root invalidates it), since the diver can turn NFC on and off in the
/// system settings.
final nfcSupportProvider = FutureProvider.autoDispose<NfcSupport>(
  (ref) => ref.watch(nfcTagServiceProvider).support(),
);
