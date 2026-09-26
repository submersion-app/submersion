import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
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
  // Years away from any day this test could run on, so a stamp read from the
  // live clock cannot pass for it.
  final generatedAt = DateTime(2031, 7, 14, 10, 59);

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
    'Detailed': (PdfTemplateDetailed.new, 'Generated on 14/07/2031 10:59'),
    'PADI': (PdfTemplatePadi.new, 'Generated 14/07/2031 10:59'),
    'NAUI': (PdfTemplateNaui.new, 'Generated 14/07/2031 10:59'),
    'Simple': (PdfTemplateSimple.new, 'Generated 14/07/2031'),
  };

  for (final MapEntry(key: name, value: (make, stamp)) in templates.entries) {
    test('$name stamps the instant it is given', () async {
      expect(await render(make()), contains(stamp));
    });
  }
}
