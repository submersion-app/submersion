import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/query_name_index.dart';

/// The ref names the parser, the builder's pickers and saved-query loading
/// resolve against (#2365). Reloads when any ref table changes, through the
/// dive repository's table tick, so a synced site or a renamed buddy shows
/// up without a restart.
final queryNameIndexProvider = FutureProvider<QueryNameIndex>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTables(QueryNameIndexLoader.tables));
  return QueryNameIndexLoader(
    DatabaseService.instance.database,
  ).load(diverId: diverId);
});
