import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

final savedQueryRepositoryProvider = Provider<SavedQueryRepository>(
  (ref) => SavedQueryRepository(),
);

/// The current diver's saved queries for [subject] (a `QuerySubject.name`),
/// or every subject when null (the Manage page). Refreshes when the table
/// changes, including a sync applying a remote row.
final savedQueriesProvider = FutureProvider.family<List<SavedQuery>, String?>((
  ref,
  subject,
) async {
  final repository = ref.watch(savedQueryRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSavedQueriesChanges());
  return repository.getAll(subject: subject, diverId: diverId);
});

/// The same rows decoded against this build's registry and the live name
/// index, so a chip row or the Manage page can show each one readable,
/// flagged or unreadable (spec Unit 7).
final savedQueryLoadsProvider =
    FutureProvider.family<List<SavedQueryLoad>, String?>((ref, subject) async {
      final rows = await ref.watch(savedQueriesProvider(subject).future);
      final names = await ref.watch(queryNameIndexProvider.future);
      return [for (final r in rows) loadSavedQuery(r, appQueryRegistry, names)];
    });
