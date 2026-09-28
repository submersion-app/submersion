import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The one id-set runner the site, equipment and trip lists share (#2365).
final queryIdSetRunnerProvider = Provider<QueryIdSetRunner>(
  (ref) => QueryIdSetRunner(DatabaseService.instance.database),
);

/// The body every list's id-set provider shares: waits for any cache the
/// query reads (the service-due verdicts), refreshes the calling provider
/// on a write to any table the query read, and runs it with the caller's
/// [scope].
Future<Set<String>> watchQueryIds(
  Ref ref,
  CompiledQuery compiled, {
  QueryScope? scope,
}) async {
  final runner = ref.watch(queryIdSetRunnerProvider);
  await awaitServiceStatusIfRead(ref, compiled.tablesTouched);
  ref.invalidateSelfWhen(runner.watchTables(compiled.tablesTouched));
  return runner.ids(compiled, scope: scope);
}

/// A list's query and the entity it roots at: the key of
/// [entityQueryIdsProvider]. Registry entities are single instances, so the
/// record compares by the query's value.
typedef EntityQueryKey = ({QueryEntity root, QueryNode query});

/// The ids [EntityQueryKey.query] selects for any list that has no filter
/// state of its own (#2365 PR 4). A query the compiler refuses is this
/// provider's error, which the list shows as its error state.
final entityQueryIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, EntityQueryKey>(
      (ref, key) async => watchQueryIds(
        ref,
        compileQuery(key.query, key.root, appQueryRegistry),
      ),
    );
