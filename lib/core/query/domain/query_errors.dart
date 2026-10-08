import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_node.dart';

/// A positioned problem with a query. [offset] and [length] locate it in
/// typed text; they are null for a tree the builder made, where [path]
/// names the row instead. [code] and [args] are what the UI localizes;
/// [message] is the engine's English text.
@immutable
class QueryError {
  final QueryErrorCode code;

  /// The words the message quotes: typed tokens and field keys, shown
  /// verbatim in every language because they are query syntax.
  final Map<String, String> args;
  final int? offset;
  final int? length;
  final FieldPath? path;
  final List<String> suggestions;

  const QueryError(
    this.code, {
    this.args = const {},
    this.offset,
    this.length,
    this.path,
    this.suggestions = const [],
  });

  /// The English text, for logs and tests; the UI shows
  /// `describeQueryError` in the diver's language.
  String get message => englishQueryMessage(code, args);

  @override
  bool operator ==(Object other) =>
      other is QueryError &&
      other.code == code &&
      _mapEquals(other.args, args) &&
      other.offset == offset &&
      other.length == length &&
      other.path == path;

  @override
  int get hashCode => Object.hash(
    code,
    Object.hashAllUnordered(
      args.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    offset,
    length,
    path,
  );

  @override
  String toString() => 'QueryError($message @$offset+$length $suggestions)';
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

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
