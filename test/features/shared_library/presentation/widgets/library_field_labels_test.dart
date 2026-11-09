import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_field_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4339: a suggestion's expected species list read "European Perch"
/// under a German locale, because a shared document carries the stored
/// English names.
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  const species = [
    {'name': 'European Perch', 'scientificName': 'Perca fluviatilis'},
    {'name': 'Mein Barsch', 'scientificName': null},
  ];

  test('expected species name catalog rows in the active language', () {
    expect(
      libraryFieldValue(de, units, 'species', species),
      'Flussbarsch, Mein Barsch',
    );
    expect(
      libraryFieldValue(en, units, 'species', species),
      'European Perch, Mein Barsch',
    );
  });

  test('other list fields are shown as stored', () {
    expect(
      libraryFieldValue(de, units, 'tags', const ['European Perch', 'Steg']),
      'European Perch, Steg',
    );
  });
}
