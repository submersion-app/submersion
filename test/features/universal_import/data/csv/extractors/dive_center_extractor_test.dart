import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/dive_center_extractor.dart';

void main() {
  test('one dive centre per name, whatever its case or spacing', () {
    final extractor = DiveCenterExtractor();
    final rows = [
      {'diveCenter': 'Example Dive Centre'},
      {'diveCenter': 'example dive centre '},
      {'diveCenter': 'Other Shop'},
      <String, dynamic>{},
    ];

    final centers = extractor.extractFromRows(rows);

    expect(centers.map((c) => c['name']), [
      'Example Dive Centre',
      'Other Shop',
    ]);
    expect(extractor.centerIdForRow(rows[1]), centers.first['id']);
    expect(extractor.centerIdForRow(rows[2]), centers.last['id']);
    expect(extractor.centerIdForRow(rows[3]), isNull);
  });
}
