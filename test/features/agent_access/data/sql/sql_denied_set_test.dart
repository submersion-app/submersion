import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';

void main() {
  final excluded = {
    for (final entry in changeLogTables.entries)
      if (entry.value == ChangeLogClass.excluded) entry.key,
  };

  test('every excluded table is either denied or readable, never both', () {
    final unclassified = excluded.difference({
      ...kSqlDeniedTables,
      ...kSqlReadableExcludedTables,
    });
    expect(
      unclassified,
      isEmpty,
      reason: 'Add each to kSqlDeniedTables or kSqlReadableExcludedTables.',
    );
    expect(kSqlDeniedTables.intersection(kSqlReadableExcludedTables), isEmpty);
  });

  test('both sets hold only tables the policy excludes', () {
    expect(kSqlDeniedTables.difference(excluded), isEmpty);
    expect(kSqlReadableExcludedTables.difference(excluded), isEmpty);
  });

  test('sync bookkeeping and the change log are denied', () {
    for (final table in changeLogTables.keys) {
      if (table.startsWith('sync_') || table.startsWith('change_log_')) {
        expect(kSqlDeniedTables, contains(table));
      }
    }
  });

  test('the denied columns are the policy credentials and feed URLs', () {
    expect(kSqlDeniedColumns, {
      ...changeLogCredentialColumns,
      'entry_key',
      'manifest_url',
      'url',
    });
  });

  test('a denied column is found as a whole name, in any case', () {
    expect(sqlNamesDeniedColumn('lower(url)'), isTrue);
    expect(sqlNamesDeniedColumn('LOWER(URL)'), isTrue);
    expect(sqlNamesDeniedColumn('lower("url")'), isTrue);
    expect(sqlNamesDeniedColumn('lower(curl)'), isFalse);
    expect(sqlNamesDeniedColumn('base64url'), isFalse);
    expect(sqlNamesDeniedColumn('media_url'), isFalse);
  });

  test('a table is readable only when the policy knows it', () {
    expect(sqlTableReadable('dives'), isTrue);
    expect(sqlTableReadable('dive_derived_metrics'), isTrue);
    expect(sqlTableReadable('sqlite_schema'), isTrue);
    expect(sqlTableReadable('connected_accounts'), isFalse);
    expect(sqlTableReadable('sqlite_stat1'), isFalse);
    expect(sqlTableReadable('a_table_nobody_classified'), isFalse);
  });
}
