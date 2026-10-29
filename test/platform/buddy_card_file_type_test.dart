import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'plist_test_helpers.dart';

/// The buddy card file type Apple platforms export (issue #3728). It is
/// known by its `.subbuddy` extension alone: claiming the public
/// `application/json` MIME type would let the system map other apps' JSON
/// to it.
void main() {
  for (final plist in [
    p.join('ios', 'Runner', 'Info.plist'),
    p.join('macos', 'Runner', 'Info.plist'),
  ]) {
    test('$plist exports the card type by extension, not by a public MIME', () {
      final declarations = plistValue(plist, 'UTExportedTypeDeclarations')!;
      final card = declarations.childElements.singleWhere(
        (d) =>
            dictValue(d, 'UTTypeIdentifier')?.innerText ==
            'app.submersion.buddy-card',
      );
      final tags = dictValue(card, 'UTTypeTagSpecification')!;
      expect(
        dictValue(
          tags,
          'public.filename-extension',
        )?.childElements.map((e) => e.innerText),
        ['subbuddy'],
      );
      expect(dictValue(tags, 'public.mime-type'), isNull);
    });
  }
}
