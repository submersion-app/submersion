import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// How many ids one `IN (...)` list binds, well under SQLite's variable
/// limit, so a rule run over a whole logbook stays valid.
const int kRuleIdChunk = 500;

/// Which dives and sites a diver's rules may change (#3513): only what the
/// diver could change by hand. Dives they own that are not unlogged plans;
/// sites they own that are not shared library sites. The scope sits beside
/// the rule's compiled condition, never inside it, so no condition can
/// reach past it.
class RuleTargetScope {
  AppDatabase get _db => DatabaseService.instance.database;

  QueryIdSetRunner get _runner => QueryIdSetRunner(_db);

  String _eligibleSql(RuleSubject s) => switch (s) {
    RuleSubject.dives => 'r0.diver_id = ? AND COALESCE(r0.is_planned, 0) = 0',
    RuleSubject.sites => 'r0.diver_id = ? AND r0.shared_library_id IS NULL',
  };

  /// The scope for one chunk of target ids, or every eligible row when
  /// [chunkIds] is null.
  QueryScope scopeFor(
    RuleSubject s,
    String diverId, [
    Iterable<String>? chunkIds,
  ]) {
    final ids = chunkIds?.toList();
    final idSql = ids == null
        ? ''
        : ' AND r0.id IN (${List.filled(ids.length, '?').join(', ')})';
    return (
      sql: '${_eligibleSql(s)}$idSql',
      params: <Object>[diverId, ...?ids],
    );
  }

  CompiledQuery _compile(QueryNode? condition, RuleSubject s, String diverId) =>
      compileQuery(
        condition,
        appQueryRegistry.entityFor(s.querySubject),
        appQueryRegistry,
        diverId: diverId,
      );

  /// The ids among [targetIds] that [condition] matches and the diver may
  /// change, queried in chunks of [kRuleIdChunk]. A null condition matches
  /// every eligible target.
  Future<Set<String>> matches(
    QueryNode? condition,
    RuleSubject s,
    String diverId,
    Set<String> targetIds,
  ) async {
    if (targetIds.isEmpty) return {};
    final compiled = _compile(condition, s, diverId);
    final out = <String>{};
    for (final chunk in ruleIdChunks(targetIds.toList())) {
      out.addAll(
        await _runner.ids(compiled, scope: scopeFor(s, diverId, chunk)),
      );
    }
    return out;
  }

  /// Whether [condition] reads [table].
  bool reads(
    QueryNode? condition,
    RuleSubject s,
    String diverId,
    String table,
  ) =>
      condition != null &&
      _compile(condition, s, diverId).tablesTouched.contains(table);

  /// Every dive or site the diver's rules may change.
  Future<Set<String>> allEligibleIds(RuleSubject s, String diverId) =>
      _runner.ids(_compile(null, s, diverId), scope: scopeFor(s, diverId));

  /// How many eligible targets [condition] matches, for the editor's live
  /// count: counted by the database, not fetched.
  Future<int> countMatches(
    QueryNode? condition,
    RuleSubject s,
    String diverId,
  ) => _runner.count(
    _compile(condition, s, diverId),
    scope: scopeFor(s, diverId),
  );
}
