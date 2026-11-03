import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/sql/sql_read_catalog_io.dart';
import 'package:submersion/features/agent_access/data/sql/sql_statement_guard.dart';

const _dives = 10;
const _divesIndex = 11;
const _accounts = 20;
const _stores = 30;
const _storesCredIndex = 31;
const _storesNameIndex = 32;

SqlReadCatalog _catalog() => const SqlReadCatalog({
  _dives: SqlRoot(table: 'dives'),
  _divesIndex: SqlRoot(table: 'dives'),
  _accounts: SqlRoot(table: 'connected_accounts', denied: true),
  _stores: SqlRoot(
    table: 'media_subscriptions',
    deniedColumns: {6: 'credentials_host_id'},
  ),
  _storesCredIndex: SqlRoot(
    table: 'media_subscriptions',
    denied: true,
    indexOfReadableTable: true,
  ),
  _storesNameIndex: SqlRoot(table: 'media_subscriptions'),
});

SqlExplainStep _step(
  String opcode, {
  int p1 = 0,
  int p2 = 0,
  int p3 = 0,
  int p5 = 0,
}) => SqlExplainStep(opcode: opcode, p1: p1, p2: p2, p3: p3, p5: p5);

SqlRefusal? _inspect(List<SqlExplainStep> steps) =>
    inspectSqlProgram(steps, _catalog());

void main() {
  group('inspectSqlProgram', () {
    test('an allowed read passes', () {
      expect(
        _inspect([
          _step('Init'),
          _step('OpenRead', p1: 0, p2: _dives),
          _step('Column', p1: 0, p2: 3, p3: 1),
          _step('ResultRow', p1: 1, p2: 1),
          _step('Halt'),
        ]),
        isNull,
      );
    });

    test('a read laid out above the open of its cursor is still checked', () {
      final refusal = _inspect([
        _step('Init', p2: 3),
        _step('Column', p1: 0, p2: 6, p3: 1),
        _step('Halt'),
        _step('OpenRead', p1: 0, p2: _stores),
        _step('Goto', p2: 1),
      ]);
      expect(refusal?.message, contains('credentials_host_id'));
    });

    test('a denied table is refused by name', () {
      final refusal = _inspect([_step('OpenRead', p2: _accounts)]);
      expect(refusal?.message, contains('connected_accounts'));
    });

    test('an index holding a denied column is refused', () {
      final refusal = _inspect([_step('OpenRead', p2: _storesCredIndex)]);
      expect(refusal?.message, contains('index on media_subscriptions'));
    });

    test('an index without a denied column passes', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 1, p2: _storesNameIndex),
          _step('Column', p1: 1, p2: 0),
        ]),
        isNull,
      );
    });

    test('an unknown root is refused', () {
      expect(_inspect([_step('OpenRead', p2: 9999)]), isNotNull);
    });

    test('a root in another database is refused', () {
      expect(_inspect([_step('OpenRead', p2: _dives, p3: 1)]), isNotNull);
    });

    test('a root held in a register is refused', () {
      expect(_inspect([_step('OpenRead', p2: _dives, p5: 0x10)]), isNotNull);
    });

    test('ReopenIdx is checked like OpenRead', () {
      expect(_inspect([_step('ReopenIdx', p2: _accounts)]), isNotNull);
    });

    test('a virtual table is refused', () {
      expect(_inspect([_step('VOpen')]), isNotNull);
    });

    test('a write cursor is refused', () {
      expect(_inspect([_step('OpenWrite', p2: _dives)]), isNotNull);
    });

    test('a denied column is refused by name', () {
      final refusal = _inspect([
        _step('OpenRead', p1: 2, p2: _stores),
        _step('Column', p1: 2, p2: 6, p3: 1),
      ]);
      expect(refusal?.message, contains('credentials_host_id'));
    });

    test('the other columns of that table pass', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('Column', p1: 2, p2: 5, p3: 1),
        ]),
        isNull,
      );
    });

    test('a whole record from a guarded table is refused', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('RowData', p1: 2, p2: 1),
        ]),
        isNotNull,
      );
    });

    test('a whole record from anywhere else passes', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _dives),
          _step('RowData', p1: 2, p2: 1),
          _step('RowData', p1: 7, p2: 1),
        ]),
        isNull,
      );
    });

    test('a type test on a denied column is refused', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('IsType', p1: 2, p2: 9, p3: 6),
        ]),
        isNotNull,
      );
    });

    test('a type test on a register passes', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('IsType', p1: -1, p2: 9, p3: 6),
        ]),
        isNull,
      );
    });

    test('OpenDup carries its source root', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('OpenDup', p1: 3, p2: 2),
          _step('Column', p1: 3, p2: 6),
        ]),
        isNotNull,
      );
    });

    test('a cursor no OpenRead opened passes', () {
      expect(
        _inspect([_step('SorterOpen', p1: 4), _step('Column', p1: 4, p2: 6)]),
        isNull,
      );
    });

    test('a later cursor number reuse does not keep the old root', () {
      expect(
        _inspect([
          _step('OpenRead', p1: 2, p2: _stores),
          _step('OpenRead', p1: 2, p2: _dives),
          _step('Column', p1: 2, p2: 6),
        ]),
        isNull,
      );
    });
  });

  group('sqlLeadingKeyword', () {
    test('reads the first keyword in upper case', () {
      expect(sqlLeadingKeyword('select 1'), 'SELECT');
      expect(sqlLeadingKeyword('  WITH x AS (SELECT 1) SELECT 1'), 'WITH');
      expect(sqlLeadingKeyword('\n\tVALUES (1)'), 'VALUES');
    });

    test('skips comments as SQLite does', () {
      expect(sqlLeadingKeyword('-- note\nSELECT 1'), 'SELECT');
      expect(sqlLeadingKeyword('/* a */ /* b */ SELECT 1'), 'SELECT');
      expect(sqlLeadingKeyword('/* PRAGMA */\n-- x\n SELECT 1'), 'SELECT');
    });

    test('finds what a comment was hiding', () {
      expect(sqlLeadingKeyword('/* SELECT */ PRAGMA x'), 'PRAGMA');
      expect(sqlLeadingKeyword('-- SELECT\nATTACH x'), 'ATTACH');
    });

    test('answers null when there is no keyword', () {
      expect(sqlLeadingKeyword(''), isNull);
      expect(sqlLeadingKeyword('   '), isNull);
      expect(sqlLeadingKeyword('/* never closed SELECT 1'), isNull);
      expect(sqlLeadingKeyword('-- only a comment'), isNull);
      expect(sqlLeadingKeyword('(SELECT 1)'), isNull);
    });

    test('allows only statements that return rows', () {
      expect(kSqlAllowedKeywords, {'SELECT', 'WITH', 'VALUES'});
    });
  });
}
