import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';

void main() {
  test('encode names the table and the cards, sorted', () {
    expect(
      RecordEditLabel.encode(table: 'dives', cardIds: ['tags', 'notes']),
      'record_edit:dives:notes,tags',
    );
  });

  test('encode drops a card id listed twice', () {
    expect(
      RecordEditLabel.encode(table: 'dives', cardIds: ['notes', 'notes']),
      'record_edit:dives:notes',
    );
  });

  test('decode reverses encode', () {
    final label = RecordEditLabel.encode(
      table: 'dives',
      cardIds: {'tags', 'notes'},
    );

    final decoded = RecordEditLabel.decode(label)!;

    expect(decoded.table, 'dives');
    expect(decoded.cardIds, ['notes', 'tags']);
  });

  test('decode returns null for any label this class did not write', () {
    expect(RecordEditLabel.decode('bulk_edit'), isNull);
    expect(RecordEditLabel.decode('Perdix 2'), isNull);
    expect(RecordEditLabel.decode('record_edit'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives'), isNull);
    expect(RecordEditLabel.decode('record_edit::notes'), isNull);
    expect(RecordEditLabel.decode('record_edit:dives:'), isNull);
    expect(RecordEditLabel.decode(''), isNull);
  });
}
