import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// [PdfExportService] reads its clock once per export, for the cover's
/// generation stamp and the file name alike, so a test can pin it (#2446).
///
/// Tests that compare export sizes rely on this. Roboto is embedded as a
/// TrueType subset holding only the glyphs the document uses, so when the
/// stamp's minute ticks over to digits printed nowhere else, the font subset,
/// and with it the file size, changes. That is how
/// pdf_export_set_names_test.dart failed in CI with 14944 against 14821 bytes.
void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 45),
    maxDepth: 24.0,
  );

  Future<({List<int> bytes, String fileName})> exportAt(DateTime at) =>
      PdfExportService(now: () => at).generateDivePdfBytes(
        [dive],
        dates: dates,
        units: units,
        options: const PdfExportOptions(template: PdfTemplate.detailed),
      );

  test('exports stamped the same minute are the same size', () async {
    final at = DateTime(2026, 3, 28, 10, 59);

    final first = await exportAt(at);
    final second = await exportAt(at);

    expect(second.bytes.length, first.bytes.length);
  });

  test('stamps the cover with the injected clock', () async {
    final result = await exportAt(DateTime(2031, 7, 14, 10, 59));

    expect(
      pdfSubsetTexts(result.bytes),
      anyElement(contains('Generated on 14/07/2031 10:59')),
      reason: 'the service must hand its clock to the template',
    );
  });

  test('names the file after the same instant', () async {
    final result = await exportAt(DateTime(2031, 7, 14, 10, 59));

    expect(result.fileName, 'dive_logbook_detailed_2031-07-14.pdf');
  });
}
