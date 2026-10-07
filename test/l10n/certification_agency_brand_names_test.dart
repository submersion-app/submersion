// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Regression coverage for issue #3070: `app_de.arb` spelled the GUE
/// certification agency as "GÜ" instead of "GUE". Agency names are brand
/// names (see the comments on [CertificationAgency] in
/// `lib/core/constants/certification_enums.dart`) and must stay identical to
/// the canonical English spelling in every locale, "other" excepted since
/// that one is a genuine translation.
void main() {
  test('every locale spells certification agency names like English', () {
    final arbDir = p.join('lib', 'l10n', 'arb');
    final englishPath = p.join(arbDir, 'app_en.arb');
    final english =
        json.decode(File(englishPath).readAsStringSync())
            as Map<String, dynamic>;

    final locales = Directory(arbDir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((path) => path.endsWith('.arb') && path != englishPath);

    final offenders = <String>[];
    for (final path in locales) {
      final arb =
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
      english.forEach((key, englishValue) {
        if (!key.startsWith('enum_certificationAgency_')) return;
        if (key == 'enum_certificationAgency_other') return;
        final localValue = arb[key];
        if (localValue != null && localValue != englishValue) {
          offenders.add(
            '$path: $key = "$localValue", expected "$englishValue"',
          );
        }
      });
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Certification agency names are brand names and must not be '
          'translated:\n${offenders.join('\n')}',
    );
  });
}
