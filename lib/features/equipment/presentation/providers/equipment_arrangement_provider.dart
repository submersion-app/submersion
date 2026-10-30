import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The app-wide arrangement older builds saved under the
/// `equipment_arrangement` settings key, before it moved into each diver's
/// settings (issue #3748).
///
/// Read only as a fallback for a diver who has not changed the arrangement
/// since: nothing writes the key any more, but an older build on another
/// device still may, so it follows a sync like any other settings change.
final legacyEquipmentArrangementProvider =
    FutureProvider<EquipmentArrangement?>((ref) async {
      final repository = ref.watch(appSettingsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSettingsChanges());
      return repository.getEquipmentArrangement();
    });

/// The diver's gear arrangement, shared by every surface that lists the gear
/// on a dive (#1486, #1576).
///
/// One preference rather than one per surface: the diver sets how they like
/// to read their rig once, and the dive view, the edit form, the picker, the
/// equipment sets and the printed logbook all honour it.
///
/// Per diver since issue #3748: the active diver's saved arrangement, else
/// the app-wide one older builds saved, else [EquipmentArrangement.defaults].
/// Synchronous, so no surface renders a loading state for a display
/// preference; it settles on the fallback once that read lands. Change it
/// through `ListArrangementWrites.updateEquipmentArrangement`.
final equipmentArrangementProvider = Provider<EquipmentArrangement>((ref) {
  return pickEquipmentArrangement(
    ref.watch(
      settingsProvider.select((s) => s.listArrangements.equipmentArrangement),
    ),
    () => ref.watch(legacyEquipmentArrangementProvider).value,
  );
});

/// The arrangement for a one-shot reader such as the PDF export, which must
/// not print the defaults while the diver's settings or the app-wide value
/// are still loading: for it, "not loaded yet" would be baked into the
/// document. Same order as [equipmentArrangementProvider]. A failed read of
/// the app-wide value falls back to the defaults, so the export still
/// prints.
///
/// Takes the caller's `ref.read`, which a `Ref`, a `WidgetRef` and a
/// `ProviderContainer` all offer, and uses it only before the first await:
/// a widget that started an export may be gone by the time it resumes.
Future<EquipmentArrangement> resolveEquipmentArrangement(
  T Function<T>(ProviderListenable<T> provider) read,
) async {
  final settings = read(settingsProvider.notifier);
  final repository = read(appSettingsRepositoryProvider);
  try {
    await settings.settingsLoaded;
  } catch (_) {
    // Already logged by the load; the state it left stands.
  }
  final saved = settings.currentListArrangements.equipmentArrangement;
  EquipmentArrangement? legacy;
  if (decodeEquipmentArrangement(saved) == null) {
    try {
      legacy = await repository.getEquipmentArrangement();
    } catch (_) {
      // Unreadable: the export still prints, in the default order.
    }
  }
  return pickEquipmentArrangement(saved, () => legacy);
}
