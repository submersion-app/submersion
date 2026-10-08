import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Every template stamps the moment the logbook was generated. The stamp
/// comes from the caller rather than a live clock read inside the template,
/// so two exports of the same data can be made identical (#2446): a stamp
/// that ticked over a minute between them changed the embedded glyph subset,
/// and with it the file size a test compared.
void main() {
  // Far past any day this test could run on, so a stamp read from the live
  // clock cannot pass for it.
  final generatedAt = DateTime(2199, 7, 14, 10, 59);

  // Without PdfFonts the templates fall back to Helvetica, whose text
  // pdfVisibleText can read. Resetting makes that explicit rather than relying
  // on nothing in this isolate having loaded Roboto.
  setUp(PdfFonts.instance.reset);

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );

  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 45),
    maxDepth: 24.0,
  );

  Future<String> render(PdfTemplateBuilder template) async => pdfVisibleText(
    await template.buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: const UnitFormatter(AppSettings()),
      generatedAt: generatedAt,
    ),
  );

  // Simple stamps the date alone in its page footer; the others stamp the
  // date and time on the cover.
  final templates = <String, (PdfTemplateBuilder Function(), String)>{
    'Detailed': (PdfTemplateDetailed.new, 'Generated on 14/07/2199 10:59'),
    'PADI': (PdfTemplatePadi.new, 'Generated 14/07/2199 10:59'),
    'NAUI': (PdfTemplateNaui.new, 'Generated 14/07/2199 10:59'),
    'Simple': (PdfTemplateSimple.new, 'Generated 14/07/2199'),
  };

  for (final MapEntry(key: name, value: (make, stamp)) in templates.entries) {
    test('$name stamps the instant it is given', () async {
      expect(await render(make()), contains(stamp));
    });
  }
}
