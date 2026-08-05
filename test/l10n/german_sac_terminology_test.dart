import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #640: the German UI showed the English "SAC"
/// for surface air consumption. The established German term is AMV
/// (Atemminutenvolumen), which parts of the app already used.
void main() {
  late AppLocalizations de;

  setUpAll(() {
    de = lookupAppLocalizations(const Locale('de'));
  });

  /// "BSAC" is the British Sub-Aqua Club, a proper noun that legitimately
  /// contains the letters and must not be rewritten.
  const properNouns = {'enum_certificationAgency_bsac'};

  test('no German string still says SAC', () {
    final arb =
        json.decode(File('lib/l10n/arb/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;

    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || properNouns.contains(key)) return;
      if (value is String && value.contains('SAC')) {
        offenders.add('$key = $value');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'German strings must use AMV, not SAC. Offending keys:\n'
          '${offenders.join('\n')}',
    );
  });

  test('BSAC survives as an agency name', () {
    expect(de.enum_certificationAgency_bsac, 'BSAC');
  });

  test('the key surfaces from the issue report read AMV', () {
    // The dive detail row and the statistics page, both shown in #640.
    expect(de.diveLog_detail_label_sacRate, 'AMV');
    expect(de.statistics_gas_sacRecords_title, contains('AMV'));
    expect(de.statistics_gas_sacTrend_title, contains('AMV'));
    expect(de.settings_units_sacRate, 'AMV');
  });

  test('AMV is not pleonastically suffixed with Rate', () {
    // AMV already means Atemminutenvolumen, so "AMV-Rate" reads as
    // "breathing-minute-volume rate".
    final arb =
        json.decode(File('lib/l10n/arb/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;

    final offenders = [
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@') &&
            entry.value is String &&
            (entry.value as String).contains('AMV-Rate'))
          entry.key,
    ];

    expect(offenders, isEmpty, reason: 'use bare AMV in: $offenders');
  });

  test('the profile chart tooltip label is localized', () {
    // The key existed but the widget hardcoded 'SAC' (issue #640).
    expect(de.diveLog_tooltip_sac, 'AMV');
  });
}
