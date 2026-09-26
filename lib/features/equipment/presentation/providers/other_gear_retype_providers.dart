import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/other_gear_retype_service.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

final otherGearRetypeServiceProvider = Provider<OtherGearRetypeService>(
  (ref) => OtherGearRetypeService(ref.watch(equipmentRepositoryProvider)),
);

/// The Retype gear page's items (#1886); null when there is no diver.
/// Auto-disposed, so every visit reads afresh, and it follows the equipment
/// ticks, so an applied or undone retype drops out of, or back into, the list.
final otherGearRetypeCandidatesProvider =
    FutureProvider.autoDispose<List<RetypeCandidate>?>((ref) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return null;
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      // The proposed thickness depends on the item's attributes, which
      // saveAttributes and a sync pull write without touching `equipment`.
      ref.invalidateSelfWhen(repository.watchAttributeChanges());
      return ref.watch(otherGearRetypeServiceProvider).findCandidates(diverId);
    });

/// Refreshes what a retype or its undo changes that does not follow the
/// equipment ticks on its own: the equipment list notifier, and the Suit
/// Thickness statistic, which counts dives by their suits' type and is kept
/// alive without watching `equipment`. Takes the [ProviderContainer], not a
/// `WidgetRef`, because Undo can run after the page is gone.
void refreshAfterOtherGearRetype(ProviderContainer container) {
  container.invalidate(divesBySuitThicknessProvider);
  if (container.exists(equipmentListNotifierProvider)) {
    unawaited(container.read(equipmentListNotifierProvider.notifier).refresh());
  }
}
