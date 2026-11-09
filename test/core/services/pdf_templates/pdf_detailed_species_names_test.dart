import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// #4339: the Marine Life section of the Detailed report printed each
/// sighting under its stored English name, whatever the report's language.
void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  final dive = Dive(
    id: 'd1',
    diveNumber: 3,
    dateTime: DateTime(2026, 9, 20, 10),
    runtime: const Duration(minutes: 40),
    maxDepth: 12,
    sightings: const [
      MarineSighting(
        id: 's1',
        speciesId: 'sp_european_perch',
        speciesName: 'European Perch',
        count: 4,
      ),
      MarineSighting(
        id: 's2',
        speciesId: '3f2b6c1e-0d4a-4b7e-9c1a-2e5f8d9b0a11',
        speciesName: 'Mein Barsch',
      ),
    ],
  );

  Future<String> render(String languageCode) async => pdfVisibleText(
    await PdfTemplateDetailed().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
      localization: PdfLocalization.forLanguageCode(languageCode),
    ),
  );

  test('a catalog species prints under its German name', () async {
    final text = await render('de');

    expect(text, contains('Flussbarsch x4'));
    expect(text, isNot(contains('European Perch')));
  });

  test('a custom species prints the name the diver gave it', () async {
    final text = await render('de');

    expect(text, contains('Mein Barsch'));
  });

  test('English still prints the catalog name', () async {
    final text = await render('en');

    expect(text, contains('European Perch x4'));
  });
}
