import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/data/resources/sql_column_notes.generated.dart';
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';

const _header = '''
# Submersion SQL schema

The tables and columns `sql_query` may read. Generated from the live schema,
so it matches this database. Notes come from the comments in the table
definitions and are missing where the source has none.

Conventions:

- Values are stored in metric: lengths in metres, temperatures in Celsius,
  pressures in bar, weights in kg, volumes in litres, durations in seconds
  unless a note says otherwise.
- Times are integers. Dive and event times hold the local wall clock of the
  dive flagged as UTC, so do not shift them to another time zone. Most are
  milliseconds since 1970, but some are seconds, whatever an old note says:
  check the size of the value before dividing.
- Booleans are 0 and 1.
- Enum columns are plain text or integers. Read the values with
  `SELECT DISTINCT`.
- Most rows carry a `diver_id`; rows for every profile are here.
- `hlc` columns are sync clocks and say nothing about the data.
- `equipment_service_status` is a cache of the active profile's verdicts only.
  For another profile, use the `query` tool with `serviceDue`.
- `dive_deco_status` holds computed deco verdicts for dives whose computer
  recorded no deco data, once the app has analyzed them; another profile's
  may be missing or stale. For any profile, use the `query` tool with `deco`.
''';

/// `submersion://schema`: what the SQL window may read, from the live schema
/// so it cannot drift, without anything the window refuses.
class SchemaResource implements AgentResource {
  @override
  String get uri => 'submersion://schema';

  @override
  String get name => 'SQL schema';

  @override
  String get mimeType => 'text/markdown';

  @override
  Future<String> read(AgentToolContext context) async {
    final columns = await context.db.customSelect('''
      SELECT m.name AS tbl, x.name AS col, x.type AS type,
             x."notnull" AS required, x.pk AS pk
      FROM sqlite_schema m, pragma_table_xinfo(m.name) x
      WHERE m.type = 'table'
      ORDER BY m.name, x.cid
    ''').get();
    final keys = await context.db.customSelect('''
      SELECT m.name AS tbl, k."from" AS col, k."table" AS target,
             k."to" AS target_col
      FROM sqlite_schema m, pragma_foreign_key_list(m.name) k
      WHERE m.type = 'table'
      ORDER BY m.name, k."from"
    ''').get();

    final joins = <String, Map<String, String>>{};
    for (final row in keys) {
      final target = row.read<String>('target');
      if (!sqlTableReadable(target)) continue;
      // NULL when the key names only a table: its primary key is meant.
      final column = row.readNullable<String>('target_col');
      (joins[row.read<String>('tbl')] ??= {})[row.read<String>('col')] =
          column == null ? target : '$target.$column';
    }

    final tables = <String, List<String>>{};
    for (final row in columns) {
      final table = row.read<String>('tbl');
      final column = row.read<String>('col');
      if (!sqlTableReadable(table) || kSqlDeniedColumns.contains(column)) {
        continue;
      }
      final facts = [
        row.read<String>('type').toLowerCase(),
        if (row.read<int>('pk') > 0) 'primary key',
        if (row.read<int>('required') != 0) 'required',
        if (joins[table]?[column] case final target?) 'joins $target',
      ];
      final note = kSqlColumnNotes[table]?[column];
      (tables[table] ??= []).add(
        '- `$column` (${facts.join(', ')})${note == null ? '' : ': $note'}',
      );
    }

    final text = StringBuffer(_header);
    for (final MapEntry(key: table, value: lines) in tables.entries) {
      text
        ..writeln()
        ..writeln('## $table')
        ..writeln()
        ..writeln(lines.join('\n'));
    }
    return text.toString();
  }
}
