import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
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

  group('dive type labels', () {
    test('an empty key reads as the unknown placeholder', () {
      expect(diveTypeDistributionLabel('', en), 'Unknown');
    });

    test('a built-in slug resolves through the translation table', () {
      expect(diveTypeDistributionLabel('wreck', en), 'Wreck');
    });

    // Issue #3075: with no typesById, a custom slug fell through to plain
    // slug capitalization instead of the diver's own name.
    test('a custom slug with no typesById falls back to slug '
        'capitalization', () {
      expect(diveTypeDistributionLabel('dpv', en), 'Dpv');
    });

    test('a custom slug resolves to the diver\'s own name when typesById '
        'is given', () {
      final typesById = {
        'dpv': DiveTypeEntity(
          id: 'dpv',
          diverId: 'diver-1',
          name: 'DPV',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      };
      expect(diveTypeDistributionLabel('dpv', en, typesById: typesById), 'DPV');
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
