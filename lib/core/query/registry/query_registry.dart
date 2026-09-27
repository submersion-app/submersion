import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';

/// A path may cross at most this many relations. A hard cap, so a typo like
/// `site.dives.site.dives` cannot fan out.
const int kMaxPathHops = 4;

@immutable
class QueryRegistry {
  final Map<QuerySubject, QueryEntity> _entities;

  QueryRegistry(List<QueryEntity> entities)
    : _entities = {for (final e in entities) e.subject: e};

  QueryEntity entityFor(QuerySubject subject) {
    final e = _entities[subject];
    if (e == null) throw StateError('no query entity for $subject');
    return e;
  }

  QueryEntity? maybeEntityFor(QuerySubject subject) => _entities[subject];

  Iterable<QueryEntity> get entities => _entities.values;
}

/// What a [FieldPath] names, walked from the root through the registry.
///
/// Exactly one of [field] and [terminalRelation] is set on success; on
/// failure [error] is set and [errorSegment] indexes the bad segment.
@immutable
class PathResolution {
  final List<QueryRelation> hops;
  final List<QueryEntity> entities;
  final QueryField? field;
  final QueryRelation? terminalRelation;
  final QueryError? error;
  final int? errorSegment;

  const PathResolution({
    this.hops = const [],
    this.entities = const [],
    this.field,
    this.terminalRelation,
    this.error,
    this.errorSegment,
  });

  /// The path with every alias replaced by its canonical key, so a tree
  /// holds one spelling whatever the diver typed.
  FieldPath get canonicalPath =>
      FieldPath([for (final h in hops) h.key, if (field != null) field!.key]);
}

PathResolution resolvePath(
  QueryRegistry registry,
  QueryEntity root,
  FieldPath path,
) {
  if (path.segments.isEmpty) {
    return const PathResolution(
      error: QueryError(QueryErrorCode.emptyPath),
      errorSegment: 0,
    );
  }
  final hops = <QueryRelation>[];
  final entities = <QueryEntity>[root];
  var current = root;
  for (var i = 0; i < path.segments.length; i++) {
    final seg = path.segments[i];
    final isLast = i == path.segments.length - 1;
    final field = current.field(seg);
    if (field != null) {
      if (!isLast) {
        return PathResolution(
          hops: hops,
          entities: entities,
          error: QueryError(
            QueryErrorCode.fieldNotPath,
            path: path,
            args: {'name': seg, 'next': path.segments[i + 1]},
          ),
          errorSegment: i + 1,
        );
      }
      return PathResolution(hops: hops, entities: entities, field: field);
    }
    final relation = current.relation(seg);
    if (relation == null) {
      return PathResolution(
        hops: hops,
        entities: entities,
        error: QueryError(
          QueryErrorCode.unknownField,
          path: path,
          suggestions: suggestNames(seg, current.segmentNames),
          args: {'name': seg},
        ),
        errorSegment: i,
      );
    }
    hops.add(relation);
    if (hops.length > kMaxPathHops) {
      return PathResolution(
        hops: hops,
        entities: entities,
        error: QueryError(
          QueryErrorCode.pathTooLong,
          path: path,
          args: {'max': '$kMaxPathHops'},
        ),
        errorSegment: i,
      );
    }
    final next = registry.maybeEntityFor(relation.target);
    if (next == null) {
      throw StateError(
        'relation ${relation.key} targets ${relation.target}, '
        'which has no query entity',
      );
    }
    entities.add(next);
    current = next;
    if (isLast) {
      return PathResolution(
        hops: hops,
        entities: entities,
        terminalRelation: relation,
      );
    }
  }
  throw StateError('unreachable');
}
