import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_builder.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_importer.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Builds the current diver's buddy card (issue #3728).
final buddyCardBuilderProvider = Provider<BuddyCardBuilder>((ref) {
  return BuddyCardBuilder(
    divers: ref.watch(diverRepositoryProvider),
    certifications: ref.watch(certificationRepositoryProvider),
    dives: ref.watch(diveRepositoryProvider),
    catalog: () => ref.read(certificationCatalogProvider.future),
  );
});

/// Saves received buddy cards.
final buddyCardImporterProvider = Provider<BuddyCardImporter>((ref) {
  return BuddyCardImporter(
    buddies: ref.watch(buddyRepositoryProvider),
    certifications: ref.watch(certificationRepositoryProvider),
  );
});

/// What the current diver shares on their card, from their diver row.
final myBuddyCardChoicesProvider = FutureProvider<BuddyCardShareChoices>((
  ref,
) async {
  final diver = await ref.watch(currentDiverProvider.future);
  return BuddyCardShareChoices.fromJson(diver?.buddyCardShare);
});

/// The fields the current diver has something to share for.
final myBuddyCardFieldsProvider = FutureProvider<Set<BuddyCardField>>((
  ref,
) async {
  final diver = await ref.watch(currentDiverProvider.future);
  if (diver == null) return const {};
  return ref.watch(buddyCardBuilderProvider).availableFields(diver.id);
});

/// The current diver's full card under their share choices; null with no
/// diver.
final myBuddyCardProvider = FutureProvider<BuddyCard?>((ref) async {
  final diver = await ref.watch(currentDiverProvider.future);
  if (diver == null) return null;
  final choices = await ref.watch(myBuddyCardChoicesProvider.future);
  return ref.watch(buddyCardBuilderProvider).build(diver.id, choices);
});

/// [diver] with [choices] stored as its share choices.
Diver withShareChoices(Diver diver, BuddyCardShareChoices choices) =>
    diver.copyWith(buddyCardShare: choices.toJson());

/// Saves [choices] on the current diver's row, where they sync with it.
Future<void> saveMyBuddyCardChoices(
  WidgetRef ref,
  BuddyCardShareChoices choices,
) async {
  final diver = await ref.read(currentDiverProvider.future);
  if (diver == null) return;
  await ref
      .read(diverListNotifierProvider.notifier)
      .updateDiver(withShareChoices(diver, choices));
}
