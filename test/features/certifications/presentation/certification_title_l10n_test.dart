import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('certificationTitleFieldsL10n', () {
    // Issue #3366: a certification with no custom title stores an empty
    // name, and a surface reading the bare column showed it blank.
    test('an empty name takes the level', () {
      expect(
        certificationTitleFieldsL10n((
          name: '',
          agency: 'padi',
          level: 'advancedNitrox',
        ), en),
        'Advanced Nitrox',
      );
    });

    test('a name that only repeats the level takes the level', () {
      expect(
        certificationTitleFieldsL10n((
          name: 'Open Water',
          agency: 'padi',
          level: 'openWater',
        ), en),
        'Open Water',
      );
    });

    test('an empty name with no level takes the agency', () {
      expect(
        certificationTitleFieldsL10n((
          name: '',
          agency: 'ssi',
          level: null,
        ), en),
        'SSI',
      );
    });

    test('a custom name is kept', () {
      expect(
        certificationTitleFieldsL10n((
          name: ' Adv. Nitrox ',
          agency: 'padi',
          level: 'advancedNitrox',
        ), en),
        'Adv. Nitrox',
      );
    });
  });
}
