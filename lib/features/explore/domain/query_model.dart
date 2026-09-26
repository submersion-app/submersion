/// The JSON contract between the native model adapter and the compiler.
///
/// Schema version 1. Every payload the adapter returns is validated here
/// before anything reads it; a mismatch is a [QuerySchemaException], never a
/// guess. Pure Dart, no Flutter imports.
library;

import 'dart:convert';

const int kQuerySchemaVersion = 1;

enum QuerySubject { dives, equipment, sites, buddies, species, trips, centers }

enum ClauseOp {
  lt('lt'),
  lte('lte'),
  gt('gt'),
  gte('gte'),
  eq('eq'),
  between('between'),
  inList('in'),
  not('not');

  final String jsonName;
  const ClauseOp(this.jsonName);
}

enum ClauseUnit {
  m('m'),
  ft('ft'),
  c('c'),
  f('f'),
  bar('bar'),
  psi('psi'),
  min('min'),
  lMin('l_min'),
  cuftMin('cuft_min');

  final String jsonName;
  const ClauseUnit(this.jsonName);
}

enum MentionKind {
  site,
  place,
  species,
  gear,
  buddy,
  tag,
  center,
  trip,
  computer,
}

class QuerySchemaException implements Exception {
  final String message;
  const QuerySchemaException(this.message);
  @override
  String toString() => 'QuerySchemaException: $message';
}

class QueryClause {
  final String field;
  final ClauseOp op;

  /// A num, a String, a bool (flags), a List of num (between) or a List of
  /// String (in).
  final Object value;
  final ClauseUnit? unit;
  final String text;

  const QueryClause({
    required this.field,
    required this.op,
    required this.value,
    this.unit,
    required this.text,
  });

  Map<String, Object?> toJson() => {
    'field': field,
    'op': op.jsonName,
    'value': value,
    if (unit != null) 'unit': unit!.jsonName,
    'text': text,
  };
}

class QueryMention {
  final MentionKind kind;
  final String text;
  const QueryMention({required this.kind, required this.text});
  Map<String, Object?> toJson() => {'kind': kind.name, 'text': text};
}

class QueryTime {
  final String text;
  const QueryTime(this.text);
  Map<String, Object?> toJson() => {'text': text};
}

class ParsedQuery {
  final int schemaVersion;
  final QuerySubject subject;
  final List<QueryClause> clauses;
  final List<QueryMention> mentions;
  final QueryTime? time;
  final List<String> unplaced;

  const ParsedQuery({
    this.schemaVersion = kQuerySchemaVersion,
    required this.subject,
    this.clauses = const [],
    this.mentions = const [],
    this.time,
    this.unplaced = const [],
  });

  /// Parses whatever the adapter returned. [raw] is the decoded JSON root,
  /// which a prompt-only adapter can make any type at all, so it is checked
  /// rather than cast: a list or a bare string is a schema mismatch, not a
  /// TypeError escaping to the caller.
  factory ParsedQuery.fromDecoded(Object? raw) {
    if (raw is! Map) {
      throw QuerySchemaException('root is ${raw.runtimeType}, expected object');
    }
    return ParsedQuery.fromJson(raw.cast<String, Object?>());
  }

  factory ParsedQuery.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != kQuerySchemaVersion) {
      throw QuerySchemaException(
        'schemaVersion $version, expected $kQuerySchemaVersion',
      );
    }
    final subject = _enumByName(
      QuerySubject.values,
      json['subject'],
      'subject',
    );
    final clauses = <QueryClause>[];
    for (final raw in _list(json['clauses'], 'clauses')) {
      final map = _map(raw, 'clause');
      final field = map['field'];
      final text = map['text'];
      if (field is! String || field.isEmpty) {
        throw const QuerySchemaException('clause.field missing');
      }
      if (text is! String) {
        throw const QuerySchemaException('clause.text missing');
      }
      final value = _coerceValue(map['value']);
      if (value == null) {
        throw const QuerySchemaException('clause.value missing');
      }
      if (value is! num &&
          value is! String &&
          value is! bool &&
          value is! List) {
        throw QuerySchemaException(
          'clause.value has type ${value.runtimeType}',
        );
      }
      final op = _byJsonName(
        ClauseOp.values,
        (o) => o.jsonName,
        map['op'],
        'op',
      );
      final rawUnit = map['unit'];
      final unit = rawUnit == null || rawUnit == 'none' || rawUnit == ''
          ? null
          : _byJsonName(ClauseUnit.values, (u) => u.jsonName, rawUnit, 'unit');
      clauses.add(
        QueryClause(field: field, op: op, value: value, unit: unit, text: text),
      );
    }
    final mentions = <QueryMention>[];
    for (final raw in _list(json['mentions'], 'mentions')) {
      final map = _map(raw, 'mention');
      final text = map['text'];
      if (text is! String || text.isEmpty) {
        throw const QuerySchemaException('mention.text missing');
      }
      mentions.add(
        QueryMention(
          kind: _enumByName(MentionKind.values, map['kind'], 'kind'),
          text: text,
        ),
      );
    }
    final rawTime = json['time'];
    QueryTime? time;
    if (rawTime != null) {
      final text = _map(rawTime, 'time')['text'];
      if (text is String && text.trim().isNotEmpty) time = QueryTime(text);
    }
    final unplaced = _list(
      json['unplaced'],
      'unplaced',
    ).whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return ParsedQuery(
      subject: subject,
      clauses: clauses,
      mentions: mentions,
      time: time,
      unplaced: unplaced,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'subject': subject.name,
    'clauses': clauses.map((c) => c.toJson()).toList(),
    'mentions': mentions.map((m) => m.toJson()).toList(),
    'time': time?.toJson(),
    'unplaced': unplaced,
  };

  ParsedQuery withoutClause(int index) => ParsedQuery(
    schemaVersion: schemaVersion,
    subject: subject,
    clauses: [
      for (var i = 0; i < clauses.length; i++)
        if (i != index) clauses[i],
    ],
    mentions: mentions,
    time: time,
    unplaced: unplaced,
  );

  ParsedQuery withoutMention(int index) => ParsedQuery(
    schemaVersion: schemaVersion,
    subject: subject,
    clauses: clauses,
    mentions: [
      for (var i = 0; i < mentions.length; i++)
        if (i != index) mentions[i],
    ],
    time: time,
    unplaced: unplaced,
  );

  ParsedQuery withoutTime() => ParsedQuery(
    schemaVersion: schemaVersion,
    subject: subject,
    clauses: clauses,
    mentions: mentions,
    unplaced: unplaced,
  );
}

/// A constrained decoder with one type per property may quote a number, a
/// list or a boolean. Unquote what parses; leave real strings alone.
Object? _coerceValue(Object? raw) {
  if (raw is! String) return raw;
  final s = raw.trim();
  if (s == 'true') return true;
  if (s == 'false') return false;
  final n = num.tryParse(s);
  if (n != null) return n;
  if (s.startsWith('[') && s.endsWith(']')) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded;
    } on FormatException {
      return raw;
    }
  }
  return raw;
}

List<Object?> _list(Object? raw, String name) {
  if (raw == null) return const [];
  if (raw is List) return raw;
  throw QuerySchemaException('$name is not a list');
}

Map<String, Object?> _map(Object? raw, String name) {
  if (raw is Map) return raw.cast<String, Object?>();
  throw QuerySchemaException('$name is not an object');
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String name) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  throw QuerySchemaException('unknown $name: $raw');
}

T _byJsonName<T>(
  List<T> values,
  String Function(T) jsonName,
  Object? raw,
  String name,
) {
  for (final v in values) {
    if (jsonName(v) == raw) return v;
  }
  throw QuerySchemaException('unknown $name: $raw');
}
