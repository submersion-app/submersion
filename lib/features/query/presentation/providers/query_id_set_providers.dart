import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
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
