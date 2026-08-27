import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_professional.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/pdf_text.dart';

/// A logbook PDF is a document a diver prints or hands to a buddy, so every
/// template has to render dates and times the way that diver reads them
/// instead of the ISO `yyyy-MM-dd` / 24-hour `HH:mm` that used to be hardcoded
/// into the shared components (#964).
void main() {
  // 14:30 local, which a day-first 12-hour diver reads as "28/03/2026 2:30 PM"
  // and a month-first 24-hour diver reads as "03/28/2026 14:30". The hour is
  // deliberately past noon so the two clock formats cannot coincide.
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 14, 30),
    runtime: const Duration(minutes: 50),
    maxDepth: 25.0,
    avgDepth: 18.0,
    waterTemp: 22.0,
  );

  final dayFirst12Hour = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twelveHour,
  );

  Future<String> render(PdfTemplateBuilder template) async => pdfVisibleText(
    await template.buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dayFirst12Hour,
    ),
  );

  final templates = <String, PdfTemplateBuilder Function()>{
    'Simple': PdfTemplateSimple.new,
    'Detailed': PdfTemplateDetailed.new,
    'Professional': PdfTemplateProfessional.new,
    'PADI': PdfTemplatePadi.new,
    'NAUI': PdfTemplateNaui.new,
  };

  for (final entry in templates.entries) {
    test('${entry.key} prints the dive date day-first, never ISO', () async {
      final text = await render(entry.value());

      expect(text, contains('28/03/2026'));
      expect(
        text,
        isNot(contains('2026-03-28')),
        reason: 'ISO belongs in file names and machine-readable exports only',
      );
    });
  }

  // The simple template is a date-only table, so it has no clock to check.
  final templatesWithTime = Map.of(templates)..remove('Simple');

  for (final entry in templatesWithTime.entries) {
    test('${entry.key} prints the dive time on a 12-hour clock', () async {
      final text = await render(entry.value());

      expect(text, contains('2:30'));
      expect(text, contains('PM'));
      expect(text, isNot(contains('14:30')));
    });
  }
}
