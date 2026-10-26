import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/data_source_strand.dart';

DiveDataSourcesData _row(
  String id, {
  String? computerId,
  int? mergeSourceSlot,
  String? sourceFileName,
  DateTime? importedAt,
  bool isPrimary = false,
  DateTime? createdAt,
  String? model = 'Perdix 2',
  String? serial,
  DateTime? entryTime,
  int? duration = 440,
  double? maxDepth = 6.2,
}) => DiveDataSourcesData(
  id: id,
  diveId: 'dive-1',
  computerId: computerId,
  isPrimary: isPrimary,
  computerModel: model,
  computerSerial: serial,
  entryTime: entryTime ?? DateTime.utc(2026, 7, 1, 9, 30, 12),
  duration: duration,
  maxDepth: maxDepth,
  mergeSourceSlot: mergeSourceSlot,
  sourceFileName: sourceFileName,
  importedAt: importedAt ?? DateTime.utc(2026, 7, 2),
  createdAt: createdAt ?? DateTime.utc(2026, 7, 2),
);

void main() {
  test('compareDataSourcesInShownOrder puts the primary first, then the '
      'oldest, then breaks a createdAt tie on id', () {
    final rows = [
      _row('b-tie'),
      _row('newer', createdAt: DateTime.utc(2026, 7, 3)),
      _row('a-tie'),
      _row('primary', isPrimary: true, createdAt: DateTime.utc(2026, 7, 9)),
    ]..sort(compareDataSourcesInShownOrder);

    expect(rows.map((r) => r.id), ['primary', 'a-tie', 'b-tie', 'newer']);
  });

  group('dataSourceStrandKeysById', () {
    test('keeps the per-row key for rows with a computer or a merge slot', () {
      final keys = dataSourceStrandKeysById([
        _row('a', computerId: 'dc-1'),
        _row('b', mergeSourceSlot: 0),
        _row('c', model: 'Teric', duration: 999),
      ]);

      expect(keys, {'a': 'computer:dc-1', 'b': 'mergeSlot:0', 'c': 'row:c'});
    });

    // Issue #3654: one Perdix 2 download stored twice, once spelled with its
    // vendor and no serial, once bare with the serial the computer shows.
    test('collapses two computer-less rows of one recording whose model '
        'differs only by the vendor prefix', () {
      final keys = dataSourceStrandKeysById([
        _row('vendor', model: 'Shearwater Perdix 2'),
        _row('bare', model: 'Perdix 2', serial: 'A5433DEA'),
      ]);

      expect(keys['bare'], keys['vendor']);
      expect(keys['vendor'], 'row:vendor');
    });

    test('treats a Shearwater hex serial and its decimal as one serial', () {
      final keys = dataSourceStrandKeysById([
        _row('hex', model: 'Teric', serial: '8629AC48'),
        _row('dec', model: 'Shearwater Teric', serial: '2250878024'),
      ]);

      expect(keys['dec'], keys['hex']);
    });

    test('keeps two units of one model apart when their serials differ', () {
      final keys = dataSourceStrandKeysById([
        _row('one', serial: 'A5433DEA'),
        _row('two', serial: 'B1234567'),
      ]);

      expect(keys['two'], isNot(keys['one']));
    });

    test('keeps two units of one model apart when the recordings differ', () {
      final keys = dataSourceStrandKeysById([
        _row('one'),
        _row('later-start', entryTime: DateTime.utc(2026, 7, 1, 9, 30, 15)),
        _row('longer', duration: 450),
        _row('deeper', maxDepth: 6.6),
      ]);

      expect(keys.values.toSet(), hasLength(4));
    });

    test('allows depth rounding between two parsers of one recording', () {
      final keys = dataSourceStrandKeysById([
        _row('full', maxDepth: 30.4812),
        _row('rounded', maxDepth: 30.5),
      ]);

      expect(keys['rounded'], keys['full']);
    });

    // One file listing two computers of one model: the importer starts each
    // at the dive's own start, so a shared start proves nothing there.
    test('keeps apart two rows written by one import of one file', () {
      final once = DateTime.utc(2026, 7, 2, 8);
      final keys = dataSourceStrandKeysById([
        _row('first', sourceFileName: 'log.ssrf', importedAt: once),
        _row('second', sourceFileName: 'log.ssrf', importedAt: once),
      ]);

      expect(keys['second'], 'row:second');
    });

    test('still collapses one recording imported from two files, or from one '
        'file twice', () {
      final once = DateTime.utc(2026, 7, 2, 8);
      final keys = dataSourceStrandKeysById([
        _row('ssrf', sourceFileName: 'log.ssrf', importedAt: once),
        _row('uddf', sourceFileName: 'log.uddf', importedAt: once),
        _row(
          'again',
          sourceFileName: 'log.ssrf',
          importedAt: once.add(const Duration(days: 1)),
        ),
      ]);

      expect(keys.values.toSet(), {'row:ssrf'});
    });

    test('keeps different models apart', () {
      final keys = dataSourceStrandKeysById([
        _row('perdix', model: 'Perdix 2'),
        _row('petrel', model: 'Petrel 3'),
      ]);

      expect(keys['petrel'], isNot(keys['perdix']));
    });

    test('needs a model, a duration and a depth, even when both rows lack '
        'the same one', () {
      for (final (field, pair) in [
        ('model', [_row('a', model: null), _row('x', model: null)]),
        ('duration', [_row('a', duration: null), _row('x', duration: null)]),
        ('depth', [_row('a', maxDepth: null), _row('x', maxDepth: null)]),
      ]) {
        final keys = dataSourceStrandKeysById(pair);
        expect(keys['x'], 'row:x', reason: 'no $field');
      }
    });

    test('never moves a row onto a strand that has a computer or a slot', () {
      final keys = dataSourceStrandKeysById([
        _row('download', computerId: 'dc-1', serial: 'A5433DEA'),
        _row('combined', mergeSourceSlot: 0),
        _row('file'),
      ]);

      expect(keys['file'], 'row:file');
    });

    test('joins a strand only when it agrees with every row on it', () {
      final keys = dataSourceStrandKeysById([
        _row('no-serial'),
        _row('serial-a', serial: 'A5433DEA'),
        _row('serial-b', serial: 'B1234567'),
      ]);

      expect(keys['serial-a'], 'row:no-serial');
      expect(keys['serial-b'], 'row:serial-b');
    });

    test('joins the strand of the first matching row', () {
      final keys = dataSourceStrandKeysById([
        _row('first', model: 'Shearwater Perdix 2'),
        _row('second', model: 'Perdix 2', serial: 'A5433DEA'),
        _row('third', model: 'perdix  2'),
      ]);

      expect(keys.values.toSet(), {'row:first'});
    });
  });
}
