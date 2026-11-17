import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

/// A UDDF buddy's address country comes back as the buddy's country
/// (issue #4457).
void main() {
  Map<String, dynamic> parse(String xml) =>
      UddfImportParsers.parseFullBuddy(XmlDocument.parse(xml).rootElement);

  test('reads the country from the buddy address', () {
    final buddy = parse(
      '<buddy id="b1"><personal><firstname>Marco</firstname></personal>'
      '<address><country>Italy</country></address></buddy>',
    );
    expect(buddy['name'], 'Marco');
    expect(buddy['country'], 'Italy');
  });

  test('a buddy without an address has no country', () {
    final buddy = parse(
      '<buddy id="b1"><personal><firstname>Marco</firstname></personal>'
      '</buddy>',
    );
    expect(buddy['country'], isNull);
  });
}
