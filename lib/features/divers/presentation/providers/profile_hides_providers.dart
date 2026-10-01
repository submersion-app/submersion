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
