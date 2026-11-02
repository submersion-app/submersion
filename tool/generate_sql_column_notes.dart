// Writes the column notes `submersion://schema` shows, from the comments in
// the Drift table definitions. Drift keeps no descriptions at runtime, so the
// source is the only place they exist. Run after changing a table:
//
//   dart run tool/generate_sql_column_notes.dart
//
// A freshness test compares the committed file with this output.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';

final String kSqlTablesPath = p.join('lib', 'core', 'database', 'tables');

final String kSqlColumnNotesPath = p.join(
  'lib',
  'features',
  'agent_access',
  'data',
  'resources',
  'sql_column_notes.generated.dart',
);

const int _maxNoteLength = 160;

final _tableClass = RegExp(r'^class (\w+) extends Table\b');
final _tableOverride = RegExp(r"String get tableName => '(\w+)'");
final _column = RegExp(r'^\s*\w+Column(?:<[^>]*>)?\s+get (\w+)\b');
final _named = RegExp(r"\.named\('(\w+)'\)");
final _trailing = RegExp(r"\)\s*;?\s*//\s*(.+)$");
final _commentLine = RegExp(r'^\s*//+\s?(.*)$');
final _issueRef = RegExp(r'\s*\((?:issue |see )?#\d+[^)]*\)');
final _version = RegExp(r'^v\d+\s*[:,]?\s*');
final _versionTag = RegExp(r'\s*\((?:schema )?v\d[^)]*\)');
final _heading = RegExp(r'\b(?:fields|metadata)$', caseSensitive: false);
final _docLink = RegExp(r'\[(\w+(?:\.\w+)*)\]');
final _sentenceEnd = RegExp(r'(?<!e\.g|i\.e|etc|approx|vs)[.;](?:\s|$)');
final _noise = RegExp(r'^(?:coverage:|ignore:|TODO|FIXME|-{3}|={3}|\*{3})');

/// `notes[table][column]` for every commented column under [tablesDirectory].
Map<String, Map<String, String>> readSqlColumnNotes(Directory tablesDirectory) {
  final notes = <String, Map<String, String>>{};
  final files = tablesDirectory.listSync(recursive: true).whereType<File>();
  for (final file in files.toList()..sort((a, b) => a.path.compareTo(b.path))) {
    if (!file.path.endsWith('.dart')) continue;
    _readFile(file.readAsLinesSync(), notes);
  }
  return notes;
}

void _readFile(List<String> lines, Map<String, Map<String, String>> notes) {
  String? table;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final opened = _tableClass.firstMatch(line);
    if (opened != null) {
      table = _snake(opened.group(1)!);
      for (var j = i + 1; j < lines.length && lines[j] != '}'; j++) {
        final override = _tableOverride.firstMatch(lines[j]);
        if (override != null) table = override.group(1);
      }
      continue;
    }
    if (line == '}') table = null;
    if (table == null) continue;
    final column = _column.firstMatch(line);
    if (column == null) continue;

    final statement = _statementAt(lines, i);
    final name =
        _named.firstMatch(statement.join(' '))?.group(1) ??
        _snake(column.group(1)!);
    final note = _noteFor(lines, i, statement);
    if (note != null) (notes[table] ??= {})[name] = note;
  }
}

/// The lines of the column declaration starting at [start].
List<String> _statementAt(List<String> lines, int start) {
  final statement = <String>[];
  for (var i = start; i < lines.length; i++) {
    statement.add(lines[i]);
    if (lines[i].contains(';')) break;
  }
  return statement;
}

String? _noteFor(List<String> lines, int index, List<String> statement) {
  final above = <String>[];
  for (var i = index - 1; i >= 0; i--) {
    final text = lines[i].trim();
    if (text.startsWith('@')) continue;
    final comment = _commentLine.firstMatch(lines[i]);
    if (comment == null) break;
    above.insert(0, comment.group(1)!.trim());
  }
  final source = above.isNotEmpty
      ? above.join(' ')
      : _trailing.firstMatch(statement.last)?.group(1);
  return source == null ? null : _clean(source);
}

String? _clean(String raw) {
  var text = raw
      .replaceAll(_issueRef, '')
      .replaceAll(_versionTag, '')
      .replaceAll(_version, '')
      .replaceAllMapped(_docLink, (m) => m.group(1)!)
      .replaceAll(' \u2014 ', ', ')
      .replaceAll('\u2014', ', ')
      .replaceAll(' \u2013 ', ', ')
      .replaceAll('/min', ' per minute')
      .trim();
  if (text.isEmpty || _noise.hasMatch(text)) return null;
  final end = _sentenceEnd.firstMatch(text);
  if (end != null) text = text.substring(0, end.start);
  // A heading over a group of columns says nothing about this one.
  if (text.length > _maxNoteLength || _heading.hasMatch(text)) return null;
  return text;
}

String _snake(String name) => name
    .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .replaceAllMapped(RegExp('([A-Z])([A-Z][a-z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();

String _quote(String text) {
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'");
  return "'$escaped'";
}

/// Nothing the SQL window refuses gets a note, and no note names what it
/// refuses. `hlc` is on most tables, and the schema header covers it once.
bool _keep(String table, String column, String note) =>
    sqlTableReadable(table) &&
    column != 'hlc' &&
    !kSqlDeniedColumns.contains(column) &&
    ![...kSqlDeniedTables, ...kSqlDeniedColumns].any(note.contains);

/// The generated file for [notes].
String renderSqlColumnNotes(Map<String, Map<String, String>> notes) {
  final text = StringBuffer()
    ..writeln(
      '// GENERATED by tool/generate_sql_column_notes.dart. Do not edit.',
    )
    ..writeln('// dart format off')
    ..writeln('// coverage:ignore-file')
    ..writeln()
    ..writeln('/// Table to column to the comment on it in the table source.')
    ..writeln('const Map<String, Map<String, String>> kSqlColumnNotes = {');
  for (final table in notes.keys.toList()..sort()) {
    final columns = [
      for (final MapEntry(key: column, value: note) in notes[table]!.entries)
        if (_keep(table, column, note)) column,
    ]..sort();
    if (columns.isEmpty) continue;
    text.writeln('  ${_quote(table)}: {');
    for (final column in columns) {
      text.writeln('    ${_quote(column)}: ${_quote(notes[table]![column]!)},');
    }
    text.writeln('  },');
  }
  text.writeln('};');
  return text.toString();
}

void main() {
  File(kSqlColumnNotesPath).writeAsStringSync(
    renderSqlColumnNotes(readSqlColumnNotes(Directory(kSqlTablesPath))),
  );
}
