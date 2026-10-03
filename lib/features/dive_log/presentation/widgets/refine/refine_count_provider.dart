import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// How many dives a Refine panel draft matches, for its "Show N dives"
/// button (#2773). Keyed on the draft's value, so an unchanged draft reuses
/// its answer and every edit asks once.
final refineMatchCountProvider = FutureProvider.autoDispose
    .family<int, DiveFilterState>((ref, draft) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      return repository.getDiveCount(diverId: diverId, filter: draft);
    });
