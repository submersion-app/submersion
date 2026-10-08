import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The shared trips and sites each profile has hidden (issue #2594).
final profileHidesRepositoryProvider = Provider<ProfileHidesRepository>(
  (ref) => ProfileHidesRepository(),
);

/// The active profile's hidden trips and sites whose hides still keep them
/// from it (see [ProfileHidesRepository.hiddenItems]), for Settings >
/// Shared data. Refreshes when a hide, a trip or a site changes, including
/// an unshare and changes by sync.
final hiddenItemsProvider = FutureProvider<List<HiddenItem>>((ref) async {
  final repository = ref.watch(profileHidesRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  return repository.hiddenItems(diverId);
});

/// Whether the active profile has hidden a shared trip or site from itself,
/// so its page offers Unhide instead of Remove (issue #2679). Refreshes
/// when a hide changes, including by sync.
final isHiddenProvider =
    FutureProvider.family<bool, ({SharedItemKind kind, String id})>((
      ref,
      item,
    ) async {
      final repository = ref.watch(profileHidesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return false;
      return repository.isHidden(item.kind, item.id, diverId);
    });
