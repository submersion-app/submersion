import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/root_scope.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// A WHERE fragment over the table aliased [alias] that limits it to what
/// [diverId] may see. Null means every row.
///
/// Each builder copies the filter of a repository's own list method, so the
/// agent sees what the app shows that profile.
typedef RecordScope = QueryScope? Function(String diverId, String alias);

/// Shared by every profile: species, GPS tracks, smart albums.
RecordScope everyone() =>
    (diverId, alias) => null;

/// `diver_id = ?`.
RecordScope owned({String column = 'diver_id'}) =>
    (diverId, alias) => (sql: '$alias.$column = ?', params: [diverId]);

/// The diver's rows plus the ones no profile owns.
RecordScope ownedOrNull() =>
    (diverId, alias) => (
      sql: '($alias.diver_id = ? OR $alias.diver_id IS NULL)',
      params: [diverId],
    );

/// The diver's rows plus the built-ins every profile sees.
RecordScope ownedOrBuiltIn() =>
    (diverId, alias) => (
      sql: '($alias.is_built_in = 1 OR $alias.diver_id = ?)',
      params: [diverId],
    );

/// [ownedOrBuiltIn] plus the ownerless rows.
RecordScope ownedNullOrBuiltIn() =>
    (diverId, alias) => (
      sql:
          '($alias.is_built_in = 1 OR $alias.diver_id IS NULL OR '
          '$alias.diver_id = ?)',
      params: [diverId],
    );

/// The diver's rows plus what another profile marked as shared.
RecordScope ownedOrShared() =>
    (diverId, alias) => (
      sql: '($alias.diver_id = ? OR $alias.is_shared = 1)',
      params: [diverId],
    );

/// The rule `query` applies to [subject], so a query and a fetch agree.
RecordScope rootScope(QuerySubject subject) =>
    (diverId, alias) => rootScopeFor(
      appQueryRegistry.entityFor(subject),
      diverId,
      alias: alias,
    );

/// A child row is visible when its parent is: [column] names a row of
/// [parentTable] that passes [parent].
RecordScope viaParent(String parentTable, String column, RecordScope parent) =>
    (diverId, alias) {
      final inner = '${alias}p';
      final scope = parent(diverId, inner);
      return (
        sql:
            '$alias.$column IN (SELECT $inner.id FROM $parentTable $inner'
            '${scope == null ? '' : ' WHERE ${scope.sql}'})',
        params: scope?.params ?? const [],
      );
    };
