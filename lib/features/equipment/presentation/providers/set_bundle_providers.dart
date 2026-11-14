import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/data/services/set_bundle_loader.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';

final setBundleLoaderProvider = Provider<SetBundleLoader>((ref) {
  return SetBundleLoader(
    sets: ref.watch(equipmentSetRepositoryProvider),
    presets: ref.watch(weightPresetRepositoryProvider),
    configs: ref.watch(cylinderConfigRepositoryProvider),
  );
});

/// Everything applying a set puts on a dive (issue #4525), or null when the
/// set is gone.
///
/// Re-reads when a set, a weight preset or a cylinder configuration changes,
/// including a sync applying remote changes: a bundle is built from all
/// three.
final setBundleProvider = FutureProvider.family<SetBundle?, String>((
  ref,
  setId,
) async {
  ref.invalidateSelfWhen(
    ref.watch(equipmentSetRepositoryProvider).watchSetChanges(),
  );
  ref.invalidateSelfWhen(
    ref.watch(weightPresetRepositoryProvider).watchWeightPresetsChanges(),
  );
  ref.invalidateSelfWhen(
    ref.watch(cylinderConfigRepositoryProvider).watchConfigsChanges(),
  );
  return ref.watch(setBundleLoaderProvider).loadOne(setId);
});

/// The headline numbers of a set's bundle, for a list row.
class SetBundleSummary {
  const SetBundleSummary({
    required this.gearCount,
    required this.leadKg,
    required this.cylinderCount,
  });

  factory SetBundleSummary.of(SetBundle bundle) => SetBundleSummary(
    gearCount: bundle.gearIds.length,
    leadKg: bundle.totalWeightKg,
    cylinderCount: bundle.cylinders.length,
  );

  final int gearCount;
  final double leadKg;
  final int cylinderCount;
}

final setBundleSummaryProvider =
    FutureProvider.family<SetBundleSummary?, String>((ref, setId) async {
      final bundle = await ref.watch(setBundleProvider(setId).future);
      return bundle == null ? null : SetBundleSummary.of(bundle);
    });
