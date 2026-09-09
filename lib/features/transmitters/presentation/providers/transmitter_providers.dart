import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

final transmitterRepositoryProvider = Provider<TransmitterRepository>(
  (ref) => TransmitterRepository(),
);

/// The active diver's registry as a matcher. Read at import time, not at
/// provider build time, so an entry saved a moment ago applies to the very
/// next download or re-parse.
@visibleForTesting
Future<TransmitterMatcher> loadTransmitterMatcher(Ref ref) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final entries = await ref
      .read(transmitterRepositoryProvider)
      .getForDiver(diverId);
  return TransmitterMatcher.fromEntries(entries);
}
