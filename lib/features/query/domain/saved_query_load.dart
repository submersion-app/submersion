import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

/// Why a saved row cannot be used as saved (spec Unit 7): unreadable JSON
/// (corrupt, or a newer version), a tree this build's registry rejects, a
/// subject this build lacks, or a ref whose row is gone. Only the last one
/// still applies; it opens with the row flagged rather than dropping the
/// condition.
enum SavedQueryProblem { unreadable, invalid, unknownSubject, unresolvedRef }

@immutable
class SavedQueryLoad {
  const SavedQueryLoad(
    this.saved, {
    this.node,
    this.problem,
    this.detail,
    this.error,
  });

  final SavedQuery saved;
  final QueryNode? node;
  final SavedQueryProblem? problem;
  final String? detail;

  /// The validator's error for [SavedQueryProblem.invalid], so the UI can
  /// word it in the diver's language; [detail] holds its English text.
  final QueryError? error;

  bool get isApplicable => node != null;
}

/// Every condition whose ref (or list of refs) names an id the index does
/// not know, as its path from [root]. Walks scoped groups against the
/// relation's entity.
List<FieldPath> unresolvedRefPaths(
  QueryNode node,
  QueryEntity root,
  QueryRegistry registry,
  NameIndex names,
) {
  final out = <FieldPath>[];
  void walk(QueryNode n, QueryEntity scope, List<String> prefix) {
    switch (n) {
      case AndNode(:final children) || OrNode(:final children):
        for (final c in children) {
          walk(c, scope, prefix);
        }
      case NotNode(:final child):
        walk(child, scope, prefix);
      case ScopedNode(:final path, :final inner):
        final res = resolvePath(registry, scope, path);
        if (res.error != null || res.terminalRelation == null) return;
        walk(inner, res.entities.last, [...prefix, ...path.segments]);
      case ConditionNode(:final path, :final value):
        final res = resolvePath(registry, scope, path);
        final rel = res.terminalRelation;
        if (res.error != null || rel == null) return;
        final refs = switch (value) {
          RefValue() => [value],
          ListValue(:final items) => items.whereType<RefValue>().toList(),
          _ => const <RefValue>[],
        };
        if (refs.any((r) => names.labelOf(rel.target, r.id) == null)) {
          out.add(FieldPath([...prefix, ...path.segments]));
        }
      case TextNode():
        return;
    }
  }

  walk(node, root, const []);
  return out;
}

/// [node] with every ref's label replaced by its current name in [names]
/// (spec: a saved query stores the id; the label is refreshed on load), so
/// a site or buddy renamed since the query was saved shows its new name.
/// Refs inside lists, NOT and scoped groups are included; a ref the index
/// does not know keeps its stored label, which is how the diver recognises
/// what went missing. Walks the same shapes as [unresolvedRefPaths].
QueryNode refreshRefLabels(
  QueryNode node,
  QueryEntity root,
  QueryRegistry registry,
  NameIndex names,
) {
  RefValue fresh(QuerySubject target, RefValue ref) {
    final label = names.labelOf(target, ref.id);
    return label == null || label == ref.label ? ref : RefValue(ref.id, label);
  }

  QueryNode walk(QueryNode n, QueryEntity scope) {
    switch (n) {
      case AndNode(:final children):
        return AndNode([for (final c in children) walk(c, scope)]);
      case OrNode(:final children):
        return OrNode([for (final c in children) walk(c, scope)]);
      case NotNode(:final child):
        return NotNode(walk(child, scope));
      case ScopedNode(:final path, :final inner):
        final res = resolvePath(registry, scope, path);
        if (res.error != null || res.terminalRelation == null) return n;
        return ScopedNode(path, walk(inner, res.entities.last));
      case ConditionNode(:final path, :final op, :final value):
        final res = resolvePath(registry, scope, path);
        final rel = res.terminalRelation;
        if (res.error != null || rel == null) return n;
        return switch (value) {
          final RefValue r => ConditionNode(path, op, fresh(rel.target, r)),
          ListValue(:final items) => ConditionNode(
            path,
            op,
            ListValue([
              for (final i in items) i is RefValue ? fresh(rel.target, i) : i,
            ]),
          ),
          _ => n,
        };
      case TextNode():
        return n;
    }
  }

  return walk(node, root);
}

/// Decodes [saved] against this build's [registry] and the live [names]:
/// readable, flagged, or unreadable, never an exception.
SavedQueryLoad loadSavedQuery(
  SavedQuery saved,
  QueryRegistry registry,
  NameIndex names,
) {
  final subject = saved.querySubject;
  final root = subject == null ? null : registry.maybeEntityFor(subject);
  if (root == null) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unknownSubject,
      detail: saved.subject,
    );
  }
  final QueryNode node;
  try {
    final decoded = jsonDecode(saved.queryJson);
    if (decoded is! Map<String, dynamic>) {
      return SavedQueryLoad(
        saved,
        problem: SavedQueryProblem.unreadable,
        detail: 'not an object',
      );
    }
    node = queryNodeFromJson(decoded);
  } on QueryJsonException catch (e) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unreadable,
      detail: e.message,
    );
  } on FormatException catch (e) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.unreadable,
      detail: e.message,
    );
  }
  final errors = validateQuery(node, root, registry);
  if (errors.isNotEmpty) {
    return SavedQueryLoad(
      saved,
      problem: SavedQueryProblem.invalid,
      detail: errors.first.message,
      error: errors.first,
    );
  }
  final current = refreshRefLabels(node, root, registry, names);
  final missing = unresolvedRefPaths(current, root, registry, names);
  if (missing.isNotEmpty) {
    return SavedQueryLoad(
      saved,
      node: current,
      problem: SavedQueryProblem.unresolvedRef,
      detail: missing.map((p) => p.toString()).join(', '),
    );
  }
  return SavedQueryLoad(saved, node: current);
}
