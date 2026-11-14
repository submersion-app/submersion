import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// The custom colours on the current diver's own gear, newest first (issue
/// #4537): the item colour sheet offers them as recent colours. Refreshes
/// when an item or its attributes change, a sync pull included.
final equipmentGearColorsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(repository.watchAttributeChanges());
  return repository.getGearColors(diverId);
});
