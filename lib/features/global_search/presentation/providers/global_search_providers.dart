import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/data/global_search_repository.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';

/// Bumped by whatever wants the caret in the search field while the page is
/// already up (Cmd/Ctrl+K pressed on it).
final globalSearchFocusTickProvider = StateProvider<int>((ref) => 0);

final globalSearchRepositoryProvider = Provider<GlobalSearchRepository>(
  (ref) => GlobalSearchRepository(DatabaseService.instance.database),
);

/// Thrown when no record type can read the typed text, for the page to show
/// why. Not a failure: the diver is mid-way through typing a query.
class GlobalSearchRefused implements Exception {
  const GlobalSearchRefused(this.error);

  final QueryError error;
}

/// Every record type's matches for the typed text (#3882), leaving out the
/// types with none. A write to any table the search read refreshes it in
/// place, so a record edited from a result is right on the way back.
final globalSearchProvider = FutureProvider.autoDispose
    .family<List<GlobalSearchSection>, String>((ref, text) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final names = await ref.watch(queryNameIndexProvider.future);
      final plan = planGlobalSearch(
        text,
        context: ParseContext(
          prefs: ref.watch(queryUnitPrefsProvider),
          now: DateTime.now(),
          names: names,
        ),
        diverId: diverId,
      );
      if (plan.refusal case final refusal?) throw GlobalSearchRefused(refusal);

      final touched = {for (final r in plan.runs) ...r.compiled.tablesTouched};
      if (touched.isEmpty) return const [];
      await awaitServiceStatusIfRead(ref, touched);
      ref.invalidateSelfWhen(
        ref.watch(queryIdSetRunnerProvider).watchTables(touched),
      );
      final repository = ref.watch(globalSearchRepositoryProvider);
      final sections = await Future.wait(
        plan.runs.map((run) => repository.search(run, diverId: diverId)),
      );
      return [
        for (final section in sections)
          if (section.total > 0) section,
      ];
    });
