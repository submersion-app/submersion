// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #3107: the German UI named the giant stride
/// entry "Großschritt", which is not a German word. The established term is
/// "Großer Schritt".
void main() {
  test('giant stride reads Großer Schritt in German', () {
    final de = lookupAppLocalizations(const Locale('de'));

    expect(de.enum_entryMethod_giantStride, 'Großer Schritt');
  });

  test('no German string still says Großschritt', () {
    // Matches the ss spelling too, so an ASCII-only rewrite cannot slip by.
    final oldTerm = RegExp('gro(ß|ss)schritt', caseSensitive: false);
    final arb =
        json.decode(
              File(
                p.join('lib', 'l10n', 'arb', 'app_de.arb'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    final offenders = [
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@') &&
            entry.value is String &&
            oldTerm.hasMatch(entry.value as String))
          entry.key,
    ];

    expect(offenders, isEmpty, reason: 'use Großer Schritt in: $offenders');
  });
}
