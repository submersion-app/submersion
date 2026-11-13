import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/suit_type.dart';
import 'package:submersion/features/insights/presentation/formatters/suit_type_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('suitTypeLabel (issue #4490)', () {
    test('a drysuit reads Drysuit', () {
      expect(suitTypeLabel(const SuitType.drysuit(), en), 'Drysuit');
    });

    test('a wetsuit names itself, then its thickness and style', () {
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 5, style: 'full'), en),
        'Wetsuit · 5 mm full',
      );
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 3, style: 'shorty'), en),
        'Wetsuit · 3 mm shorty',
      );
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 7, style: 'two_piece'), en),
        'Wetsuit · 7 mm two-piece',
      );
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 6.5, style: 'semi_dry'), en),
        'Wetsuit · 6.5 mm semi-dry',
      );
    });

    test('a missing part drops out of the label', () {
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 5), en),
        'Wetsuit · 5 mm',
      );
      expect(
        suitTypeLabel(const SuitType.wetsuit(style: 'shorty'), en),
        'Wetsuit · shorty',
      );
      expect(suitTypeLabel(const SuitType.wetsuit(), en), 'Wetsuit');
    });

    test('a style outside the catalog shows as stored', () {
      expect(
        suitTypeLabel(const SuitType.wetsuit(mm: 5, style: 'hooded'), en),
        'Wetsuit · 5 mm hooded',
      );
    });

    test('every locale puts thickness and style in their own places', () {
      // Generated methods take placeholders in @placeholders order, so a
      // swapped pair would compile and print "full mm 5" silently.
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        final label = suitTypeLabel(
          const SuitType.wetsuit(mm: 5, style: 'shorty'),
          l10n,
        );
        expect(label, contains('5 mm'), reason: '$locale');
        expect(label, isNot(contains('shorty mm')), reason: '$locale');
        expect(
          label,
          startsWith(suitTypeLabel(const SuitType.wetsuit(), l10n)),
          reason: '$locale',
        );
      }
    });
  });
}
