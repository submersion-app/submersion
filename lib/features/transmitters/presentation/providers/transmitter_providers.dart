import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';

import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

final transmitterRepositoryProvider = Provider<TransmitterRepository>(
  (ref) => TransmitterRepository(),
);

/// The active diver's registry as a matcher. Read at import time, not at
/// provider build time, so an entry saved a moment ago applies to the very
/// next download or re-parse.
Future<TransmitterMatcher> loadTransmitterMatcher(Ref ref) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final entries = await ref
      .read(transmitterRepositoryProvider)
      .getForDiver(diverId);
  return TransmitterMatcher.fromEntries(entries);
}

/// The active diver's registry entries, label order. Self-invalidates on
/// table changes so a sync write refreshes the page.
final transmittersProvider = FutureProvider<List<Transmitter>>((ref) async {
  final repository = ref.watch(transmitterRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchTransmittersChanges());
  return repository.getForDiver(diverId);
});

/// Serials seen on the diver's downloaded tanks that have no entry yet.
final unassignedTransmitterSerialsProvider =
    FutureProvider<List<UnassignedTransmitterSerial>>((ref) async {
      final repository = ref.watch(transmitterRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchUnassignedChanges());
      return repository.getUnassignedSerials(diverId);
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
