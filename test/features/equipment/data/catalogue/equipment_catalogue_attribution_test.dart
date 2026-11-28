import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_attribution.dart';

void main() {
  test('the licence entry names the catalogue and libdivecomputer', () {
    const entry = EquipmentCatalogueAttribution.licenceEntry;
    expect(entry.packages, ['Equipment data']);
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    expect(
      text,
      contains('https://github.com/submersion-app/equipment-catalogue'),
    );
    expect(text, contains('libdivecomputer'));
  });
}
