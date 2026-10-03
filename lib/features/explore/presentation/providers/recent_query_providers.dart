import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final recentQueryRepositoryProvider = Provider<RecentQueryRepository>(
  (ref) => RecentQueryRepository(),
);

/// Recorded after a successful compile; overridable so provider tests need
/// no local cache database. [diverId] is the diver who asked, fixed when the
/// request started, so a switch while the model works cannot refile it.
typedef RecentQueryRecorder =
    Future<void> Function(
      String sentence,
      String locale,
      ParsedQuery parsed,
      String diverId,
    );

// no-tick: the value is a write function, not data; nothing here is cached
// and the list provider follows the table's own tick.
final recentQueryRecorderProvider = Provider<RecentQueryRecorder>((ref) {
  final repo = ref.watch(recentQueryRepositoryProvider);
  return (sentence, locale, parsed, diverId) =>
      repo.record(sentence, locale, parsed, diverId: diverId);
});

/// The active diver's recent sentences for the active locale, newest first.
final recentQueriesProvider = FutureProvider<List<RecentQuery>>((ref) async {
  final repo = ref.watch(recentQueryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  final locale = ref.watch(localeProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repo.list(diverId: diverId ?? '', locale: locale);
});
