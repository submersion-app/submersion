import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';

/// What the current diver puts on their emergency tag, from their diver row.
final myEmergencyTagChoicesProvider = FutureProvider<EmergencyTagChoices>((
  ref,
) async {
  final diver = await ref.watch(currentDiverProvider.future);
  return EmergencyTagChoices.fromJson(diver?.emergencyTagShare);
});

/// [diver] with [choices] stored as its emergency tag choices.
Diver withEmergencyTagChoices(Diver diver, EmergencyTagChoices choices) =>
    diver.copyWith(emergencyTagShare: choices.toJson());

/// Saves [choices] on the current diver's row, where they sync with it.
Future<void> saveMyEmergencyTagChoices(
  WidgetRef ref,
  EmergencyTagChoices choices,
) async {
  final diver = await ref.read(currentDiverProvider.future);
  if (diver == null) return;
  await ref
      .read(diverListNotifierProvider.notifier)
      .updateDiver(withEmergencyTagChoices(diver, choices));
}
