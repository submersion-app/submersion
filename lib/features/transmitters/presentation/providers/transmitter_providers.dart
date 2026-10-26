import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';

import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_gear_linker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

final transmitterRepositoryProvider = Provider<TransmitterRepository>(
  (ref) => TransmitterRepository(),
);

/// Registers the transmitter serials a download turns up (issue #3676),
/// naming each new item in the diver's language.
final transmitterAutoRegistrarProvider = Provider<TransmitterAutoRegistrar>(
  (ref) => TransmitterAutoRegistrar(
    nameFor: (serial) =>
        l10nForLocaleTag(ref.read(localeProvider)).transmitters_serial(serial),
  ),
);

/// Puts each transmitter's item on the dives that carry it (issue #3676).
final transmitterGearLinkerProvider = Provider<TransmitterGearLinker>(
  (ref) => TransmitterGearLinker(),
);

/// The registry of [diverId] (the active diver when null or empty, issue
/// #2050) as a matcher. Read at import time, not at provider build time, so an
/// entry saved a moment ago applies to the very next download or re-parse.
Future<TransmitterMatcher> loadTransmitterMatcher(
  Ref ref, {
  String? diverId,
}) async {
  final target = diverId == null || diverId.isEmpty
      ? await ref.read(validatedCurrentDiverIdProvider.future)
      : diverId;
  final entries = await ref
      .read(transmitterRepositoryProvider)
      .getForDiver(target);
  return TransmitterMatcher.fromEntries(entries);
}

/// The registry keys behind one Transmitter item (issue #3676), for its
/// Transmitter section. Self-invalidates on registry changes.
final transmittersForEquipmentProvider =
    FutureProvider.family<List<Transmitter>, String>((ref, equipmentId) async {
      final repository = ref.watch(transmitterRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTransmittersChanges());
      return repository.getForEquipment(equipmentId);
    });

/// The active diver's registry entries, label order. Self-invalidates on
/// table changes so a sync write refreshes the page.
final transmittersProvider = FutureProvider<List<Transmitter>>((ref) async {
  final repository = ref.watch(transmitterRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchTransmittersChanges());
  return repository.getForDiver(diverId);
});

final transmitterProvider = FutureProvider.family<Transmitter?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(transmitterRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTransmittersChanges());
  return repository.getById(id);
});

/// Known versus unassigned serials seen on one computer's dives, for the
/// detail page row.
final transmitterComputerSummaryProvider =
    FutureProvider.family<({int known, int unassigned}), String>((
      ref,
      computerId,
    ) async {
      final repository = ref.watch(transmitterRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchUnassignedChanges());
      return repository.serialCountsForComputer(computerId, diverId: diverId);
    });
