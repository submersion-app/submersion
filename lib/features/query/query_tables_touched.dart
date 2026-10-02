import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The tables [tree] reads from [root], for change ticks and for deciding
/// which caches a list needs (#2365). Computed inside provider listeners, so
/// it never throws: an advanced query the validator or compiler rejects
/// falls back to the root table, and the SQL path reports the error through
/// its AsyncValue, where the diver can see it.
Set<String> tablesTouchedOrRoot(QueryNode? tree, QueryEntity root) {
  // The advanced tree is public data: validate it first, so a structurally
  // wrong node (a text value on a bool field) never reaches the compiler's
  // casts from a listener.
  if (validateQuery(tree, root, appQueryRegistry).isNotEmpty) {
    return {root.table};
  }
  try {
    return compileQuery(tree, root, appQueryRegistry).tablesTouched;
  } on QueryCompileError {
    return {root.table};
  }
}
