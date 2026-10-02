import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_repository_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

/// The legacy `dives.buddy` texts, sentence-only buddies only Explore reads
/// (#2641). They follow the dives tick here rather than in the shared index,
/// which every query surface keeps alive: a sync writing many dives reloads
/// this short list, not every name the diver has. Unlistened once Explore
/// closes, so the ticks then only mark it due.
final exploreLegacyBuddyNamesProvider = FutureProvider<List<NameEntry>>((
  ref,
) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repo = ref.watch(exploreRepositoryProvider);
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  return repo.legacyBuddyNames(diverId: diverId);
});

/// The names Explore resolves a sentence against: the shared index, then the
/// legacy buddy names. They come last, so a linked buddy is always tried
/// before a legacy text of the same name, as when the shared index held them.
final exploreNameIndexProvider = FutureProvider<NameIndex>((ref) async {
  final (shared, legacy) = await (
    ref.watch(queryNameIndexProvider.future),
    ref.watch(exploreLegacyBuddyNamesProvider.future),
  ).wait;
  return shared.followedBy(legacy);
});
