import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every rental gear memory string (issue #2075) exists in every locale, so
/// gen-l10n never falls back to English for one of them.
void main() {
  const keys = [
    'diveCenters_rental_sectionTitle',
    'diveCenters_rental_lastTimeAt',
    'diveCenters_rental_lastDiveOn',
    'diveCenters_rental_noHistory',
    'diveCenters_rental_empty',
    'diveCenters_rental_addNote',
    'diveCenters_rental_applyLastDive',
    'diveCenters_rental_applied',
    'diveCenters_rental_applyConfirmTitle',
    'diveCenters_rental_applyConfirmBody',
    'diveCenters_rental_applyConfirmReplace',
    'diveCenters_rental_leadTotal',
    'diveCenters_rental_feedbackOver',
    'diveCenters_rental_feedbackUnder',
    'diveCenters_rental_tanksLabel',
    'diveCenters_rental_verdictWorked',
    'diveCenters_rental_verdictAvoid',
    'diveCenters_rental_extraLead',
    'diveCenters_rental_lessLead',
    'diveCenters_rental_actualCapacity',
    'diveCenters_rental_sheetTitleNew',
    'diveCenters_rental_sheetTitleEdit',
    'diveCenters_rental_gearTypeLabel',
    'diveCenters_rental_labelLabel',
    'diveCenters_rental_sizeLabel',
    'diveCenters_rental_leadAdjustmentLabel',
    'diveCenters_rental_volumeLabel',
    'diveCenters_rental_noteLabel',
    'diveCenters_rental_deleteConfirm',
  ];
  const locales = [
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'he',
    'hu',
    'it',
    'nl',
    'pt',
    'zh',
  ];

  for (final locale in locales) {
    test('app_$locale.arb carries every rental gear memory key', () {
      final file = File('lib/l10n/arb/app_$locale.arb');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final missing = [
        for (final key in keys)
          if (json[key] is! String || (json[key] as String).isEmpty) key,
      ];
      expect(missing, isEmpty, reason: 'missing in $locale');
    });
  }

  test('the English placeholders are declared', () {
    final json =
        jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in const [
      'diveCenters_rental_lastTimeAt',
      'diveCenters_rental_lastDiveOn',
      'diveCenters_rental_leadTotal',
      'diveCenters_rental_feedbackOver',
      'diveCenters_rental_feedbackUnder',
      'diveCenters_rental_extraLead',
      'diveCenters_rental_lessLead',
      'diveCenters_rental_actualCapacity',
      'diveCenters_rental_leadAdjustmentLabel',
      'diveCenters_rental_volumeLabel',
    ]) {
      expect(json['@$key'], isA<Map<String, dynamic>>(), reason: key);
      expect(
        (json['@$key'] as Map<String, dynamic>)['placeholders'],
        isNotNull,
        reason: key,
      );
    }
  });
}
