import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

final weightPresetRepositoryProvider = Provider<WeightPresetRepository>((ref) {
  return WeightPresetRepository();
});

/// The current diver's saved weighting rigs, ordered, each with its entries.
///
/// Self-invalidates on any write to `weight_presets` / `weight_preset_entries`
/// (including a sync applying remote changes), like [tankPresetsProvider].
final weightPresetsProvider = FutureProvider<List<WeightPreset>>((ref) async {
  final repository = ref.watch(weightPresetRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchWeightPresetsChanges());
  return repository.getPresets(diverId: diverId);
});
