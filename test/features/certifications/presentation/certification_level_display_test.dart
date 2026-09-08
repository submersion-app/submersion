import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1608: on-screen certification levels rendered the hardcoded English
/// `displayName`. [CertificationLevelDisplay.localizedName] routes the same
/// values through the active locale; the switch is exhaustive by enum value.
void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  test(
    'every CertificationLevel resolves to a non-empty label in en and fr',
    () {
      for (final level in CertificationLevel.values) {
        expect(
          level.localizedName(en),
          isNotEmpty,
          reason: '${level.name} (en)',
        );
        expect(
          level.localizedName(fr),
          isNotEmpty,
          reason: '${level.name} (fr)',
        );
      }
    },
  );

  test('a generic ladder grade is translated between locales', () {
    expect(
      CertificationLevel.masterDiver.localizedName(fr),
      isNot(equals(CertificationLevel.masterDiver.localizedName(en))),
    );
  });

  test('proprietary agency grade names stay English in every locale', () {
    for (final level in [
      CertificationLevel.bsacOceanDiver,
      CertificationLevel.gueFundamentals,
      CertificationLevel.gueTech1,
      CertificationLevel.extendedRange,
    ]) {
      expect(level.localizedName(fr), equals(level.localizedName(en)));
    }
  });

  test('FFESSM cursus grades keep their French federation names', () {
    for (final level in [
      CertificationLevel.ffessmN2,
      CertificationLevel.ffessmMf1,
      CertificationLevel.ffessmPlongeurBronze,
      CertificationLevel.ffessmRifap,
    ]) {
      expect(level.localizedName(en), equals(level.displayName));
      expect(level.localizedName(fr), equals(level.displayName));
    }
  });
}
