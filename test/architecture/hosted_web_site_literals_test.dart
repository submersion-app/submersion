import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Issue #4481: `scripts/web/stage_hosted_site.py` warns when a bundle is not
/// authorised for the site it is deployed to by looking for `https://<host>`
/// in the compiled app. That proves something only while the
/// `GOOGLE_WEB_CLIENT_ORIGINS` define is the one place that spells either
/// site's address, so nothing under lib/ may spell it: the app keeps host
/// names (`hosted_web_site.dart`) and builds the address at runtime.
const _addresses = [
  'https://web.submersion.app',
  'https://beta.web.submersion.app',
];

/// The 1-based line numbers of [text] that spell either site's address.
List<int> addressLines(String text) {
  final lines = text.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_addresses.any(lines[i].toLowerCase().contains)) i + 1,
  ];
}

void main() {
  test('the scan finds an address when one is there', () {
    expect(
      addressLines("const a = 1;\nconst url = 'https://web.submersion.app';"),
      [2],
    );
    expect(addressLines('see HTTPS://Beta.Web.Submersion.App/x'), [1]);
    expect(addressLines("const host = 'beta.web.submersion.app';"), isEmpty);
  });

  test('nothing under lib/ spells either web site address', () {
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final String text;
      try {
        text = file.readAsStringSync();
      } on FileSystemException {
        continue; // A binary asset: the compiled app never reads it as code.
      }
      for (final line in addressLines(text)) {
        offenders.add('${file.path}:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Spell the host name and build the address at runtime '
          '(HostedWebSiteLinks.uri), or stage_hosted_site.py can no longer '
          'tell whether a bundle is authorised for its site.',
    );
  });
}
