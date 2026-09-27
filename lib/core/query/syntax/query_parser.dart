import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

export 'package:submersion/core/query/domain/query_errors.dart'
    show ParseFailure, ParseOk, ParseResult;

/// Resolves a typed name to a row of [kind]. The NameIndex from Explore
/// implements this in PR 5 of #2365; PR 2's editor builds one from the
/// repositories.
abstract class NameResolver {
  RefValue? resolve(QuerySubject kind, String text);
  List<String> candidates(QuerySubject kind, String text);
}

/// Implemented by resolvers that can list every row of a subject, which
/// the editor's completions and ref pickers use; the parser itself needs
/// only [NameResolver]. Rows, not labels: two sites can share a name
/// ("Blue Hole"), and each must stay pickable by its own id.
abstract class NameEntries {
  Iterable<RefValue> refEntries(QuerySubject kind);
}

/// Exact, case-insensitive label lookup over an in-memory map. For tests
/// and for callers that already hold the labels.
class MapNameResolver implements NameResolver, NameEntries {
  final Map<QuerySubject, Map<String, String>> labelsToIds;
  const MapNameResolver(this.labelsToIds);

  @override
  Iterable<RefValue> refEntries(QuerySubject kind) => [
    for (final e in (labelsToIds[kind] ?? const <String, String>{}).entries)
      RefValue(e.value, e.key),
  ];

  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final labels = labelsToIds[kind] ?? const {};
    for (final e in labels.entries) {
      if (e.key.toLowerCase() == text.toLowerCase()) {
        return RefValue(e.value, e.key);
      }
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, (labelsToIds[kind] ?? const {}).keys);
}

@immutable
class ParseContext {
  final UnitPrefs prefs;
  final DateTime now;
  final NameResolver names;
  const ParseContext({
    required this.prefs,
    required this.now,
    required this.names,
  });
}

class _Abort implements Exception {
  final QueryError error;
  _Abort(this.error);
}

/// Words the parser reads as syntax; the printer quotes text equal to one.
const Set<String> kQueryKeywords = {
  'and',
  'or',
  'not',
  'in',
  'between',
  'none',
  'any',
  'true',
  'false',
};

const _operatorSymbols = {'=', '!=', '<', '<=', '>', '>=', '~', ':', '['};

/// Recursive-descent parser for the typed syntax (spec Unit 2). Returns a
/// tree or a positioned [ParseFailure]; never throws to the caller.
class QueryParser {
  final QueryRegistry registry;
  final QueryEntity root;
  final ParseContext context;

  QueryParser(this.registry, this.root, this.context);

  late List<Token> _tokens;
  int _pos = 0;

  /// The entity a path is resolved against; a scoped group pushes its
  /// relation's target while parsing the bracketed inner query.
  late List<QueryEntity> _scope;

  /// Relation hops the open scoped groups already crossed.
  int _hopDepth = 0;

  ParseResult parse(String text) {
    try {
      _tokens = tokenize(text);
    } on TokenizeException catch (e) {
      return ParseFailure(
        QueryError(e.code, args: e.args, offset: e.offset, length: 1),
      );
    }
    _pos = 0;
    _scope = [root];
    _hopDepth = 0;
    try {
      if (_peek.kind == TokenKind.end) return const ParseOk(null);
      final node = _or();
      if (_peek.kind != TokenKind.end) {
        throw _Abort(
          _err(
            QueryErrorCode.unexpectedToken,
            _peek,
            args: {'text': _peek.text},
          ),
        );
      }
      return ParseOk(node);
    } on _Abort catch (a) {
      return ParseFailure(a.error);
    }
  }

  Token get _peek => _tokens[_pos];
  Token _next() => _tokens[_pos++];
  QueryEntity get _entity => _scope.last;

  QueryError _err(
    QueryErrorCode code,
    Token at, {
    Map<String, String> args = const {},
    List<String> suggestions = const [],
  }) => QueryError(
    code,
    args: args,
    offset: at.offset,
    length: at.length == 0 ? 1 : at.length,
    suggestions: suggestions,
  );

  bool _isKeyword(Token t, String kw) =>
      t.kind == TokenKind.word && t.text.toLowerCase() == kw;
  bool _isSymbol(Token t, String s) =>
      t.kind == TokenKind.symbol && t.text == s;

  QueryNode _or() {
    final parts = [_and()];
    while (_isKeyword(_peek, 'or') || _isSymbol(_peek, '|')) {
      _next();
      parts.add(_and());
    }
    return parts.length == 1 ? parts.first : OrNode(parts);
  }

  bool _startsPrimary(Token t) =>
      (t.kind == TokenKind.word &&
          !_isKeyword(t, 'or') &&
          !_isKeyword(t, 'and')) ||
      t.kind == TokenKind.quoted ||
      t.kind == TokenKind.number ||
      _isSymbol(t, '(') ||
      _isSymbol(t, '-');

  QueryNode _and() {
    final parts = [_not()];
    while (true) {
      if (_isKeyword(_peek, 'and') || _isSymbol(_peek, '&')) {
        _next();
        parts.add(_not());
      } else if (_startsPrimary(_peek)) {
        parts.add(_not());
      } else {
        break;
      }
    }
    return parts.length == 1 ? parts.first : AndNode(parts);
  }

  QueryNode _not() {
    if (_isKeyword(_peek, 'not') || _isSymbol(_peek, '-')) {
      _next();
      return NotNode(_not());
    }
    return _primary();
  }

  QueryNode _primary() {
    final t = _peek;
    if (_isSymbol(t, '(')) {
      _next();
      final inner = _or();
      if (!_isSymbol(_peek, ')')) {
        throw _Abort(_err(QueryErrorCode.expectedCloseParen, _peek));
      }
      _next();
      return inner;
    }
    if (t.kind == TokenKind.quoted) {
      _next();
      final words = t.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (words.isEmpty) throw _Abort(_err(QueryErrorCode.emptyText, t));
      return TextNode(words.toList());
    }
    if (t.kind == TokenKind.number) {
      _next();
      return TextNode([t.text]);
    }
    if (t.kind == TokenKind.word) {
      final after = _tokens[_pos + 1];
      if (_operatorFollows(after)) {
        return _condition();
      }
      _next();
      return TextNode([t.text]);
    }
    throw _Abort(_err(QueryErrorCode.expectedConditionOrText, t));
  }

  bool _operatorFollows(Token t) =>
      (t.kind == TokenKind.symbol && _operatorSymbols.contains(t.text)) ||
      _isKeyword(t, 'in') ||
      _isKeyword(t, 'between');

  QueryNode _condition() {
    final pathTok = _next();
    final typed = FieldPath(pathTok.text.split('.'));
    final res = resolvePath(registry, _entity, typed);
    if (res.error != null) {
      final seg = res.errorSegment ?? 0;
      final segOffset =
          pathTok.offset +
          typed.segments.take(seg).fold<int>(0, (n, s) => n + s.length + 1);
      throw _Abort(
        QueryError(
          res.error!.code,
          args: res.error!.args,
          offset: segOffset,
          length: typed.segments[seg].length,
          suggestions: res.error!.suggestions,
        ),
      );
    }
    // The tree holds canonical keys, whatever alias was typed.
    final path = res.canonicalPath;
    if (_hopDepth + res.hops.length > kMaxPathHops) {
      throw _Abort(
        _err(
          QueryErrorCode.tooManyHops,
          pathTok,
          args: {'max': '$kMaxPathHops'},
        ),
      );
    }
    final opTok = _next();

    if (_isSymbol(opTok, '[')) {
      final rel = res.terminalRelation;
      if (rel == null) {
        throw _Abort(
          _err(
            QueryErrorCode.scopeNeedsRelationQuoted,
            pathTok,
            args: {'path': '$path'},
          ),
        );
      }
      _scope.add(registry.entityFor(rel.target));
      _hopDepth += res.hops.length;
      final inner = _or();
      _hopDepth -= res.hops.length;
      _scope.removeLast();
      if (!_isSymbol(_peek, ']')) {
        throw _Abort(_err(QueryErrorCode.expectedCloseBracket, _peek));
      }
      _next();
      return ScopedNode(path, inner);
    }

    if (_isSymbol(opTok, ':')) {
      final v = _peek;
      if (_isKeyword(v, 'none')) {
        final noneValue = res.field?.enumValues?.contains('none') ?? false;
        if (noneValue) {
          // `current:none` would read as "unrecorded" while the diver may
          // mean the stored value "none": refuse the ambiguity and name
          // both spellings.
          throw _Abort(
            _err(
              QueryErrorCode.noneAmbiguous,
              v,
              args: {'field': path.segments.last},
            ),
          );
        }
        _next();
        return ConditionNode(path, QueryOp.isEmpty, null);
      }
      if (_isKeyword(v, 'any')) {
        _next();
        return ConditionNode(path, QueryOp.isSet, null);
      }
      if (res.terminalRelation != null) {
        return _relationRef(path, res.terminalRelation!, opTok);
      }
      final field = _fieldOrAbort(res, pathTok);
      final op = field.type == FieldType.text ? QueryOp.contains : QueryOp.eq;
      _requireOp(field, op, opTok);
      if (field.type == FieldType.date) {
        return _dateCondition(path, QueryOp.eq, field);
      }
      return ConditionNode(path, op, _value(field, op));
    }

    if (res.terminalRelation != null) {
      return _relationRef(path, res.terminalRelation!, opTok);
    }
    final field = _fieldOrAbort(res, pathTok);
    if (_isKeyword(opTok, 'in')) {
      _requireOp(field, QueryOp.inList, opTok);
      if (field.type == FieldType.date && !_isSymbol(_peek, '[')) {
        return _dateCondition(path, QueryOp.inList, field);
      }
      if (!_isSymbol(_peek, '[')) {
        throw _Abort(_err(QueryErrorCode.expectedOpenBracketAfterIn, _peek));
      }
      final open = _next();
      if (field.type == FieldType.date) {
        // A list of days or periods: each is its own condition, ORed, so
        // `date in [2025-01-05, 2025-03]` keeps the whole of March.
        final days = <QueryNode>[];
        while (!_isSymbol(_peek, ']')) {
          if (_peek.kind == TokenKind.end) {
            throw _Abort(_err(QueryErrorCode.expectedCloseBracket, _peek));
          }
          days.add(_dateCondition(path, QueryOp.eq, field));
          if (_isSymbol(_peek, ',')) _next();
        }
        _next();
        if (days.isEmpty) throw _Abort(_err(QueryErrorCode.emptyList, open));
        return days.length == 1 ? days.first : OrNode(days);
      }
      final items = <QueryValue>[];
      while (!_isSymbol(_peek, ']')) {
        if (_peek.kind == TokenKind.end) {
          throw _Abort(_err(QueryErrorCode.expectedCloseBracket, _peek));
        }
        items.add(_value(field, QueryOp.inList));
        if (_isSymbol(_peek, ',')) _next();
      }
      _next();
      if (items.isEmpty) throw _Abort(_err(QueryErrorCode.emptyList, open));
      return ConditionNode(path, QueryOp.inList, ListValue(items));
    }
    if (_isKeyword(opTok, 'between')) {
      _requireOp(field, QueryOp.between, opTok);
      final isDate = field.type == FieldType.date;
      final a = isDate ? _singleDay() : _value(field, QueryOp.between);
      if (!_isKeyword(_peek, 'and')) {
        throw _Abort(_err(QueryErrorCode.expectedAnd, _peek));
      }
      _next();
      final b = isDate ? _singleDay() : _value(field, QueryOp.between);
      // Reversed bounds still mean the range between them; the tree keeps
      // them in order so the printed text is canonical.
      return ConditionNode(path, QueryOp.between, ListValue(_ordered(a, b)));
    }
    final op = switch (opTok.text) {
      '=' => QueryOp.eq,
      '!=' => QueryOp.neq,
      '<' => QueryOp.lt,
      '<=' => QueryOp.lte,
      '>' => QueryOp.gt,
      '>=' => QueryOp.gte,
      '~' => QueryOp.contains,
      _ => null,
    };
    if (op == null) throw _Abort(_err(QueryErrorCode.expectedOperator, opTok));
    _requireOp(field, op, opTok);
    if (field.type == FieldType.date) return _dateCondition(path, op, field);
    return ConditionNode(path, op, _value(field, op));
  }

  QueryField _fieldOrAbort(PathResolution res, Token pathTok) {
    final f = res.field;
    if (f == null) {
      throw _Abort(
        _err(
          QueryErrorCode.relationNeedsRefOp,
          pathTok,
          args: {'path': pathTok.text},
        ),
      );
    }
    return f;
  }

  /// Checked BEFORE the value is read, so `favorite ~ x` reports the
  /// operator, not a missing true/false.
  void _requireOp(QueryField field, QueryOp op, Token opTok) {
    if (!field.ops.contains(op)) {
      throw _Abort(
        _err(
          QueryErrorCode.opNotForFieldQuoted,
          opTok,
          args: {'op': opTok.text, 'field': field.key},
        ),
      );
    }
  }

  /// `site = "Salt Pier"`, `site != x`, `site in [a, b]`, `site:name`: a
  /// relation named by a row of its target.
  QueryNode _relationRef(FieldPath path, QueryRelation rel, Token opTok) {
    if (_isKeyword(opTok, 'in')) {
      if (!_isSymbol(_peek, '[')) {
        throw _Abort(_err(QueryErrorCode.expectedOpenBracketAfterIn, _peek));
      }
      final open = _next();
      final items = <QueryValue>[];
      while (!_isSymbol(_peek, ']')) {
        if (_peek.kind == TokenKind.end) {
          throw _Abort(_err(QueryErrorCode.expectedCloseBracket, _peek));
        }
        items.add(_refValue(rel));
        if (_isSymbol(_peek, ',')) _next();
      }
      _next();
      if (items.isEmpty) throw _Abort(_err(QueryErrorCode.emptyList, open));
      return ConditionNode(path, QueryOp.inList, ListValue(items));
    }
    final op = switch (opTok.text) {
      '=' || ':' => QueryOp.eq,
      '!=' => QueryOp.neq,
      _ => throw _Abort(
        _err(
          QueryErrorCode.relationOpNotAllowed,
          opTok,
          args: {'op': opTok.text},
        ),
      ),
    };
    return ConditionNode(path, op, _refValue(rel));
  }

  RefValue _refValue(QueryRelation rel) {
    final tok = _next();
    if (tok.kind == TokenKind.symbol || tok.kind == TokenKind.end) {
      throw _Abort(_err(QueryErrorCode.expectedName, tok));
    }
    final ref = context.names.resolve(rel.target, tok.text);
    if (ref == null) {
      throw _Abort(
        _err(
          QueryErrorCode.noRefNamed,
          tok,
          suggestions: context.names.candidates(rel.target, tok.text),
          args: {'relation': rel.key, 'text': tok.text},
        ),
      );
    }
    return ref;
  }

  /// [a] and [b] in ascending order, for numbers and days.
  static List<QueryValue> _ordered(QueryValue a, QueryValue b) {
    final reversed = switch ((a, b)) {
      (final NumberValue x, final NumberValue y) => x.value > y.value,
      (final DateValue x, final DateValue y) => x.day.isAfter(y.day),
      _ => false,
    };
    return reversed ? [b, a] : [a, b];
  }

  /// One side of `date between a and b`: a single calendar day.
  DateValue _singleDay() {
    final t = _next();
    if (t.kind == TokenKind.end || t.kind == TokenKind.symbol) {
      throw _Abort(_err(QueryErrorCode.expectedDate, t));
    }
    final range = parseDateText(t.text, now: context.now);
    final start = range?.start;
    if (range == null || start == null || range.end != start) {
      throw _Abort(
        _err(QueryErrorCode.notSingleDay, t, args: {'text': t.text}),
      );
    }
    return DateValue(start);
  }

  /// A date value is one token; a range collapses to `inList` and an
  /// open-ended phrase ("since 2024") to the bound it has.
  QueryNode _dateCondition(FieldPath path, QueryOp op, QueryField field) {
    final t = _next();
    if (t.kind == TokenKind.end || t.kind == TokenKind.symbol) {
      throw _Abort(_err(QueryErrorCode.expectedDateValue, t));
    }
    final range = parseDateText(t.text, now: context.now);
    if (range == null) {
      throw _Abort(_err(QueryErrorCode.notADate, t, args: {'text': t.text}));
    }
    final (:start, :end) = range;
    if (start != null && end != null) {
      if (start == end) return ConditionNode(path, op, DateValue(start));
      if (op == QueryOp.eq || op == QueryOp.inList) {
        return ConditionNode(path, QueryOp.inList, DateRangeValue(start, end));
      }
      if (op == QueryOp.neq) {
        return NotNode(
          ConditionNode(path, QueryOp.inList, DateRangeValue(start, end)),
        );
      }
      // An ordering op against a range takes the edge the op faces.
      final edge = (op == QueryOp.lt || op == QueryOp.gte) ? start : end;
      return ConditionNode(path, op, DateValue(edge));
    }
    // An open-ended phrase ("since 2024", "before 2024") is one bound.
    // `in`, `=` take the bound, `!=` its complement; an ordering op has no
    // single reading, so it names the day to write instead.
    final bound = start != null
        ? ConditionNode(path, QueryOp.gte, DateValue(start))
        : ConditionNode(path, QueryOp.lte, DateValue(end!));
    switch (op) {
      case QueryOp.eq:
      case QueryOp.inList:
        return bound;
      case QueryOp.neq:
        return NotNode(bound);
      default:
        final day = _dayText(
          start ?? DateTime(end!.year, end.month, end.day + 1),
        );
        throw _Abort(
          _err(
            QueryErrorCode.openEndedDate,
            t,
            args: {
              'text': t.text,
              'field': path.segments.last,
              'symbol': op == QueryOp.lt || op == QueryOp.lte ? '<' : '>=',
              'day': day,
            },
          ),
        );
    }
  }

  String _dayText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  QueryValue _value(QueryField field, QueryOp op) {
    final t = _peek;
    if (t.kind == TokenKind.end ||
        (t.kind == TokenKind.symbol && !_isSymbol(t, '-'))) {
      throw _Abort(_err(QueryErrorCode.expectedValue, t));
    }
    switch (field.type) {
      case FieldType.number:
        var negative = false;
        var tok = _next();
        if (_isSymbol(tok, '-')) {
          negative = true;
          tok = _next();
        }
        if (tok.kind != TokenKind.number) {
          throw _Abort(_err(QueryErrorCode.expectedNumber, tok));
        }
        final m = RegExp(r'^(\d+(?:\.\d+)?)([A-Za-z]*)$').firstMatch(tok.text)!;
        // Canonical at four decimals in the typed unit, the precision the
        // printer keeps, so parse(print(x)) == parse(x) for any typed text.
        final raw =
            (double.parse(m[1]!) * 10000).round() / 10000 * (negative ? -1 : 1);
        final suffix = m[2]!;
        QueryUnit? unit;
        if (suffix.isNotEmpty) {
          unit = QueryUnit.fromSuffix(suffix);
          if (unit == null) {
            throw _Abort(
              _err(QueryErrorCode.unknownUnit, tok, args: {'unit': suffix}),
            );
          }
          final unitless = const {
            FieldDimension.none,
            FieldDimension.percent,
            FieldDimension.count,
          }.contains(field.dimension);
          if (unitless) {
            throw _Abort(
              _err(
                QueryErrorCode.noUnitAllowed,
                tok,
                args: {'field': field.key},
              ),
            );
          }
          if (dimensionOfUnit(unit) != field.dimension) {
            throw _Abort(
              _err(
                QueryErrorCode.wrongUnitForField,
                tok,
                args: {
                  'unit': suffix,
                  'dimension': field.dimension.name,
                  'field': field.key,
                },
              ),
            );
          }
        }
        if (_isSymbol(_peek, ',') && op != QueryOp.inList) {
          throw _Abort(_err(QueryErrorCode.decimalComma, _peek));
        }
        return NumberValue(
          groundToStorage(raw, unit, field.dimension, context.prefs),
          unit,
        );
      case FieldType.text:
      case FieldType.id:
        final tok = _next();
        if (tok.kind == TokenKind.symbol) {
          throw _Abort(_err(QueryErrorCode.expectedText, tok));
        }
        if (tok.text.trim().isEmpty) {
          throw _Abort(_err(QueryErrorCode.emptyText, tok));
        }
        return StringValue(tok.text);
      case FieldType.bool:
        final tok = _next();
        if (_isKeyword(tok, 'true')) return const BoolValue(true);
        if (_isKeyword(tok, 'false')) return const BoolValue(false);
        throw _Abort(_err(QueryErrorCode.expectedBool, tok));
      case FieldType.enumName:
        final tok = _next();
        final values = field.enumValues ?? const [];
        final match = values
            .where((v) => v.toLowerCase() == tok.text.toLowerCase())
            .firstOrNull;
        if (match == null) {
          // A short closed list: when nothing is close, every value is a
          // better hint than none.
          final near = suggestNames(tok.text, values);
          throw _Abort(
            _err(
              QueryErrorCode.notEnumValue,
              tok,
              suggestions: near.isEmpty ? values.take(5).toList() : near,
              args: {'text': tok.text, 'field': field.key},
            ),
          );
        }
        return EnumValue(match);
      case FieldType.date:
        throw StateError('dates are parsed by _dateCondition');
    }
  }
}
