import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/formatters/distribution_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1998: the water type and entry method charts carry a segment for
/// dives with no value, keyed [kNotRecordedDistributionKey].
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('water type labels', () {
    test('the not recorded key reads as Not recorded', () {
      expect(
        waterTypeDistributionLabel(kNotRecordedDistributionKey, en),
        'Not recorded',
      );
    });

    test('a stored enum name still resolves to its name', () {
      expect(waterTypeDistributionLabel('brackish', en), 'Brackish');
    });
  });

  group('entry method labels', () {
    test('the not recorded key reads as Not recorded', () {
      expect(
        entryMethodDistributionLabel(kNotRecordedDistributionKey, en),
        'Not recorded',
      );
    });

    test('a stored enum name still resolves to its name', () {
      expect(entryMethodDistributionLabel('giantStride', en), 'Giant Stride');
    });
  });

  test('every locale translates Not recorded', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final label = waterTypeDistributionLabel(
        kNotRecordedDistributionKey,
        l10n,
      );
      expect(label, isNot(kNotRecordedDistributionKey), reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(label, isNot('Not recorded'), reason: '$locale');
      }
    }
  });
}
