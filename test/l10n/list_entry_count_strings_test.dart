import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The entry count under each list title (issue #2669).
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('English reads the count, singular and plural', () {
    expect(en.diveLog_listPage_count(812), '812 dives');
    expect(en.diveLog_listPage_count(1), '1 dive');
    expect(en.diveLog_listPage_count(0), '0 dives');
    expect(en.buddies_list_count(2), '2 buddies');
    expect(en.diveCenters_list_count(1), '1 dive center');
  });

  test('English reads shown of total, pluralised on the total', () {
    expect(en.diveLog_listPage_countFiltered(34, 812), '34 of 812 dives');
    expect(en.diveLog_listPage_countFiltered(1, 1), '1 of 1 dive');
    expect(en.diveLog_listPage_countFiltered(0, 5), '0 of 5 dives');
    expect(en.equipment_list_countFiltered(3, 40), '3 of 40 items');
  });

  // French puts zero in the CLDR `one` category, so the singular branch has
  // to interpolate its argument rather than print a literal 1.
  test('French renders zero as 0, not 1', () {
    expect(fr.diveLog_listPage_count(0), '0 plongée');
    expect(fr.diveLog_listPage_countFiltered(0, 0), '0 sur 0 plongée');
  });

  test('every locale defines every count string', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final strings = [
        l10n.diveLog_listPage_count(3),
        l10n.diveLog_listPage_countFiltered(2, 3),
        l10n.diveSites_list_count(3),
        l10n.diveSites_list_countFiltered(2, 3),
        l10n.buddies_list_count(3),
        l10n.buddies_list_countFiltered(2, 3),
        l10n.equipment_list_count(3),
        l10n.equipment_list_countFiltered(2, 3),
        l10n.trips_list_count(3),
        l10n.trips_list_countFiltered(2, 3),
        l10n.certifications_list_count(3),
        l10n.certifications_list_countFiltered(2, 3),
        l10n.diveCenters_list_count(3),
        l10n.diveCenters_list_countFiltered(2, 3),
        l10n.courses_list_count(3),
        l10n.courses_list_countFiltered(2, 3),
      ];
      for (final (i, s) in strings.indexed) {
        expect(s, contains('3'), reason: '$locale string $i lost its total');
        if (i.isOdd) {
          expect(s, contains('2'), reason: '$locale string $i lost shown');
        }
      }
    }
  });
}
