import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';

void main() {
  test('items that were never ambiguous are written unchanged', () {
    for (final v in ['plain', r'C:\files', 'a=b', '']) {
      expect(escapeCsvListItem(v), v, reason: v);
    }
  });

  test('every item round trips through join and split', () {
    final items = [
      'plain',
      'Shop; Two',
      'a;b',
      r'C:\dir\',
      r'x\;y',
      r'\',
      'k=v; z=1',
    ];
    final cell = joinCsvList(items);
    expect(splitCsvList(cell).map(unescapeCsvListItem).toList(), items);
  });

  test('a plain join is unchanged, so older files still split', () {
    expect(joinCsvList(['Mk25', 'Long hose']), 'Mk25; Long hose');
    expect(splitCsvList('Mk25; Long hose'), ['Mk25', 'Long hose']);
    expect(splitCsvList(''), isEmpty);
  });
}
