import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';

/// A positioned problem with a query. [offset] and [length] locate it in
/// typed text; they are null for a tree the builder made, where [path]
/// names the row instead.
@immutable
class QueryError {
  final String message;
  final int? offset;
  final int? length;
  final FieldPath? path;
  final List<String> suggestions;

  const QueryError(
    this.message, {
    this.offset,
    this.length,
    this.path,
    this.suggestions = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is QueryError &&
      other.message == message &&
      other.offset == offset &&
      other.length == length &&
      other.path == path;
  @override
  int get hashCode => Object.hash(message, offset, length, path);
  @override
  String toString() => 'QueryError($message @$offset+$length $suggestions)';
}

/// What `QueryParser.parse` returns: a tree ([ParseOk]) or a positioned
/// [ParseFailure]. Sealed here, beside the error type, so both halves live
/// in one library.
@immutable
sealed class ParseResult {
  const ParseResult();
}

class ParseOk extends ParseResult {
  /// Null for an empty query, which matches everything.
  final QueryNode? node;
  const ParseOk(this.node);
  @override
  String toString() => 'ParseOk($node)';
}

/// The parser's failure result. Never thrown.
class ParseFailure extends ParseResult {
  final QueryError error;
  const ParseFailure(this.error);
  @override
  String toString() => 'ParseFailure($error)';
}

/// Thrown by the compiler on a tree the validator would have rejected. A
/// programming error, surfaced through AsyncValue at the provider boundary.
class QueryCompileError extends Error {
  final String message;
  QueryCompileError(this.message);
  @override
  String toString() => 'QueryCompileError: $message';
}

class QueryJsonException implements Exception {
  final String message;
  const QueryJsonException(this.message);
  @override
  String toString() => 'QueryJsonException: $message';
}
