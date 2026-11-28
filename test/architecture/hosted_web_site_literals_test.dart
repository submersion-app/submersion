import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

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

/// What a line names a site's host by: the constants, or the host itself.
/// Beside an `https://` on the same line they make the full address once
/// dart2js folds a constant interpolation, concatenation or pair of
/// adjacent literals into one string.
const _hostSpellings = [
  'kstablewebsitehost',
  'kbetawebsitehost',
  'web.submersion.app',
];

/// A host constant interpolated into a string (`$k...`, `${k...`) or joined
/// with `+` (or `+=`) on either side, in lowercased code.
final _hostConstantInString = RegExp(
  r'(\$\{?|\+=?\s*)k(?:stable|beta)websitehost\b'
  r'|\bk(?:stable|beta)websitehost\s*\+',
);

/// The 1-based line numbers of [text] that spell, or build at compile time,
/// either site's address.
///
/// In Dart ([dart], the default) comments are blanked first, since they never
/// reach the compiled app, and each `https://` is checked against the rest
/// of its statement, since adjacent literals and concatenations fold into one
/// string across line breaks. Anything else (an ARB file) is checked line by
/// line for the full address.
List<int> addressLines(String text, {bool dart = true}) {
  final lines = <int>{};
  if (!dart) {
    final raw = text.split('\n');
    for (var i = 0; i < raw.length; i++) {
      if (_addresses.any(raw[i].toLowerCase().contains)) lines.add(i + 1);
    }
    return lines.toList()..sort();
  }
  final masked = MaskedSource(text);
  final code = masked.text.toLowerCase();
  for (final address in _addresses) {
    for (
      var at = code.indexOf(address);
      at >= 0;
      at = code.indexOf(address, at + 1)
    ) {
      lines.add(masked.lineOf(at));
    }
  }
  for (
    var at = code.indexOf('https://');
    at >= 0;
    at = code.indexOf('https://', at + 1)
  ) {
    final end = code.indexOf(';', at);
    final statement = code.substring(at, end < 0 ? code.length : end);
    if (_hostSpellings.any(statement.contains)) lines.add(masked.lineOf(at));
  }
  // The app only ever hands the host constants to `Uri(host: ...)`, so any
  // interpolation or concatenation of one is building a string with it,
  // whatever holds the scheme.
  for (final match in _hostConstantInString.allMatches(code)) {
    lines.add(masked.lineOf(match.start));
  }
  return lines.toList()..sort();
}

void main() {
  test('the scan finds an address when one is there', () {
    expect(
      addressLines("const a = 1;\nconst url = 'https://web.submersion.app';"),
      [2],
    );
    expect(addressLines("const u = 'HTTPS://Beta.Web.Submersion.App/x';"), [1]);
    expect(addressLines("const host = 'beta.web.submersion.app';"), isEmpty);
    // dart2js folds a constant interpolation or concatenation into one
    // literal, so these put the full address in main.dart.js too.
    expect(addressLines(r"final u = 'https://$kBetaWebSiteHost';"), [1]);
    expect(addressLines(r"final u = 'https://${kStableWebSiteHost}/';"), [1]);
    expect(addressLines("const u = 'https://' + kStableWebSiteHost;"), [1]);
    expect(addressLines("const u = 'https://' 'beta.web.submersion.app';"), [
      1,
    ]);
    // Adjacent literals and concatenations fold across line breaks too.
    expect(
      addressLines(
        "const a = 1;\nconst u = 'https://'\n    'beta.web.submersion.app';",
      ),
      [2],
    );
    expect(
      addressLines("final u =\n    'https://' +\n    kStableWebSiteHost;"),
      [2],
    );
    // A scheme held in a constant of its own folds in just the same, with
    // no https:// beside the host.
    expect(
      addressLines(
        "const _https = 'https://';\n"
        r"final u = '$_https$kBetaWebSiteHost';",
      ),
      [2],
    );
    expect(
      addressLines(
        "const _https = 'https://';\nconst u = _https +\n    kStableWebSiteHost;",
      ),
      [2],
    );
    expect(addressLines(r"final s = '${kStableWebSiteHost}x';"), [1]);
    expect(addressLines("var u = _https;\nu += kBetaWebSiteHost;"), [2]);
    // A comment never reaches the compiled app.
    expect(
      addressLines(
        '/// Finds `https://<host>` in main.dart.js.\n'
        "const kStableWebSiteHost = 'web.submersion.app';",
      ),
      isEmpty,
    );
    // ARB and other non-Dart files: the full address only.
    expect(addressLines('"k": "https://web.submersion.app"', dart: false), [1]);
    // Building the Uri at runtime is what the app does, and is allowed.
    expect(
      addressLines("Uri(scheme: 'https', host: kBetaWebSiteHost)"),
      isEmpty,
    );
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
      for (final line in addressLines(
        text,
        dart: file.path.endsWith('.dart'),
      )) {
        offenders.add('${file.path}:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Spell the host name and build the address at runtime '
          '(HostedWebSiteLinks.uri), or stage_hosted_site.py can no longer '
          'tell whether a bundle is authorised for its site. To show a host '
          'on its own, use HostedWebSite.beta.uri!.host (or .stable), not '
          'the constant in a string.',
    );
  });
}
