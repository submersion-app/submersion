// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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
    final arb =
        json.decode(File('lib/l10n/arb/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;

    final offenders = [
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@') &&
            entry.value is String &&
            (entry.value as String).toLowerCase().contains('großschritt'))
          entry.key,
    ];

    expect(offenders, isEmpty, reason: 'use Großer Schritt in: $offenders');
  });
}
