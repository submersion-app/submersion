import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';

void main() {
  test('encode names the table, the record and the cards, sorted', () {
    expect(
      RecordEditLabel.encode(
        table: 'dives',
        id: 'd1',
        cardIds: ['tags', 'notes'],
      ),
      'record_edit:dives:d1:notes,tags',
    );
  });

  test('encode drops a card id listed twice', () {
    expect(
      RecordEditLabel.encode(
        table: 'dives',
        id: 'd1',
        cardIds: ['notes', 'notes'],
      ),
      'record_edit:dives:d1:notes',
    );
  });

  test('encode refuses an empty id or one with a colon', () {
    expect(
      () => RecordEditLabel.encode(table: 'dives', id: '', cardIds: ['notes']),
      throwsArgumentError,
    );
    expect(
      () =>
          RecordEditLabel.encode(table: 'dives', id: 'a:b', cardIds: ['notes']),
      throwsArgumentError,
    );
  });

  test('decode reverses encode, id included', () {
    final label = RecordEditLabel.encode(
      table: 'dives',
      id: 'd1',
      cardIds: {'tags', 'notes'},
    );

    final decoded = RecordEditLabel.decode(label)!;

    expect(decoded.table, 'dives');
    expect(decoded.id, 'd1');
    expect(decoded.cardIds, ['notes', 'tags']);
  });

  test('decode reads a label written before the id, with a null id', () {
    final decoded = RecordEditLabel.decode('record_edit:dives:notes,tags')!;

    expect(decoded.table, 'dives');
    expect(decoded.id, isNull);
    expect(decoded.cardIds, ['notes', 'tags']);
  });

  test('decode returns null for any label this class did not write', () {
    expect(RecordEditLabel.decode('bulk_edit'), isNull);
    expect(RecordEditLabel.decode('Perdix 2'), isNull);
    expect(RecordEditLabel.decode('record_edit'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives'), isNull);
    expect(RecordEditLabel.decode('record_edit::notes'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives:'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives::notes'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives:d1:'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives:d1:notes:x'), isNull);
    expect(RecordEditLabel.decode(''), isNull);
  });
}
