import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';

/// One thing the diver can insert at the caret.
@immutable
class Completion {
  const Completion(
    this.text, {
    required this.replaceStart,
    required this.replaceLength,
  });

  /// What to insert, already quoted when a name needs it.
  final String text;

  /// The span of the host string it replaces (the partial word).
  final int replaceStart;
  final int replaceLength;
}

const _valueOperators = {'=', '!=', '<', '<=', '>', '>=', '~'};
const _maxCompletions = 8;

/// What the editor offers at [caret] in [text] (#2365):
///
/// * at the start of a term, the field and relation keys of the root, and
///   after a dot, the keys of the entity the path so far reaches;
/// * after `:`, `none`, `any` and the enum values of the field;
/// * after an operator (or inside `in [...]`), the enum values of the field
///   or the ref names of the relation, quoted;
/// * after a complete condition, the keywords.
///
/// Pure: the widget decides how to show them. An unterminated quote or any
/// other text the tokenizer refuses offers nothing.
List<Completion> completionsAt(
  String text,
  int caret,
  QueryEditorContext context,
) {
  final head = text.substring(0, caret.clamp(0, text.length));
  final List<Token> tokens;
  try {
    tokens = tokenize(head);
  } on TokenizeException {
    return const [];
  }
  final body = tokens.where((t) => t.kind != TokenKind.end).toList();
  if (body.isEmpty) return const [];

  // The word being typed, if the caret sits right at the end of a word or
  // quoted token; otherwise the caret follows whitespace or a symbol.
  final last = body.last;
  final touching = last.offset + last.length == head.length;
  final partial =
      touching && (last.kind == TokenKind.word || last.kind == TokenKind.quoted)
      ? last
      : null;
  final prior = partial == null ? body : body.sublist(0, body.length - 1);
  final typed = partial?.text ?? '';
  final replaceStart = partial?.offset ?? head.length;
  final replaceLength = partial?.length ?? 0;

  List<Completion> emit(Iterable<String> options, {bool quote = false}) {
    final lower = typed.toLowerCase();
    final out = <Completion>[];
    for (final o in options) {
      if (lower.isNotEmpty && !o.toLowerCase().startsWith(lower)) continue;
      out.add(
        Completion(
          quote ? '"${o.replaceAll('"', r'\"')}"' : o,
          replaceStart: replaceStart,
          replaceLength: replaceLength,
        ),
      );
      if (out.length == _maxCompletions) break;
    }
    return out;
  }

  // A dotted path being typed: complete the last segment against the
  // entity the earlier segments reach.
  if (partial != null &&
      partial.kind == TokenKind.word &&
      partial.text.contains('.')) {
    final segments = partial.text.split('.');
    final entity = _entityAtEnd(
      context,
      segments.sublist(0, segments.length - 1),
    );
    if (entity == null) return const [];
    final start = partial.offset + partial.text.length - segments.last.length;
    return [
      for (final k in _keysOf(entity, segments.last))
        Completion(k, replaceStart: start, replaceLength: segments.last.length),
    ];
  }

  final before = prior.isEmpty ? null : prior.last;

  // `path:` or `path:val`.
  if (before != null && _isSymbol(before, ':')) {
    final field = _fieldAt(context, prior, prior.length - 2);
    return emit(['none', 'any', ...?field?.enumValues]);
  }

  // `path op`, `path in [`, `path in [a, `.
  if (before != null &&
      before.kind == TokenKind.symbol &&
      (_valueOperators.contains(before.text) ||
          before.text == '[' ||
          before.text == ',')) {
    final anchor = _pathIndexBeforeValue(prior);
    if (anchor == null) return const [];
    final resolved = _resolveWord(context, prior[anchor].text);
    if (resolved?.field?.enumValues case final values?) return emit(values);
    if (resolved?.terminalRelation case final rel?) {
      if (context.names case final NameEntries names) {
        return emit({
          for (final r in names.refEntries(rel.target)) r.label,
        }, quote: true);
      }
      return const [];
    }
    return const [];
  }

  // A bare word: a key of the root at the start of a term, or a keyword
  // after a complete condition.
  if (partial != null && partial.kind == TokenKind.word) {
    final atTermStart =
        before == null ||
        _isSymbol(before, '(') ||
        _isKeyword(before, 'and') ||
        _isKeyword(before, 'or') ||
        _isKeyword(before, 'not');
    if (atTermStart) return emit(_keysOf(context.root, typed));
    return emit(const ['and', 'or']);
  }
  return const [];
}

bool _isKeyword(Token t, String kw) =>
    t.kind == TokenKind.word && t.text.toLowerCase() == kw;

bool _isSymbol(Token t, String s) => t.kind == TokenKind.symbol && t.text == s;

/// Keys (fields then relations, declared order) starting with [prefix].
List<String> _keysOf(QueryEntity entity, String prefix) {
  final lower = prefix.toLowerCase();
  return [
    for (final f in entity.fields)
      if (f.key.toLowerCase().startsWith(lower)) f.key,
    for (final r in entity.relations)
      if (r.key.toLowerCase().startsWith(lower)) r.key,
  ].take(_maxCompletions).toList();
}

QueryEntity? _entityAtEnd(QueryEditorContext context, List<String> segments) {
  if (segments.isEmpty) return context.root;
  final res = resolvePath(context.registry, context.root, FieldPath(segments));
  return res.error == null && res.terminalRelation != null
      ? res.entities.last
      : null;
}

PathResolution? _resolveWord(QueryEditorContext context, String pathText) {
  if (pathText.isEmpty) return null;
  final res = resolvePath(
    context.registry,
    context.root,
    FieldPath(pathText.split('.')),
  );
  return res.error == null ? res : null;
}

QueryField? _fieldAt(QueryEditorContext context, List<Token> tokens, int i) {
  if (i < 0 || i >= tokens.length) return null;
  final t = tokens[i];
  if (t.kind != TokenKind.word) return null;
  return _resolveWord(context, t.text)?.field;
}

/// The index of the path token that owns the value being typed: the word
/// before a value operator, or before `in [` (skipping earlier list items).
int? _pathIndexBeforeValue(List<Token> tokens) {
  for (var i = tokens.length - 1; i >= 0; i--) {
    final t = tokens[i];
    if (t.kind != TokenKind.symbol) continue;
    if (_valueOperators.contains(t.text)) {
      return i >= 1 && tokens[i - 1].kind == TokenKind.word ? i - 1 : null;
    }
    if (t.text == '[') {
      final ok =
          i >= 2 &&
          _isKeyword(tokens[i - 1], 'in') &&
          tokens[i - 2].kind == TokenKind.word;
      return ok ? i - 2 : null;
    }
  }
  return null;
}
