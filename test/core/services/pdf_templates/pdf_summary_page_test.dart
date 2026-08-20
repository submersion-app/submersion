import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// #1017 asks for the first and last dive dates and the total dive time in the
/// logbook summary. The summary previously carried counts and depths only.
void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  Dive diveOn(DateTime when, {required Duration runtime}) => Dive(
    id: when.toIso8601String(),
    diveNumber: 1,
    dateTime: when,
    runtime: runtime,
    maxDepth: 30.0,
  );

  Future<String> render(List<Dive> dives) async => pdfVisibleText(
    await PdfTemplateDetailed().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    ),
  );

  test('reports the first and last dive dates and the total time', () async {
    // getAllDives returns newest first, so the earliest dive is last in the
    // list. The summary must not assume either ordering.
    final text = await render([
      diveOn(DateTime(2026, 8, 17), runtime: const Duration(minutes: 40)),
      diveOn(DateTime(2024, 1, 3), runtime: const Duration(minutes: 50)),
    ]);

    expect(text, contains('First Dive'));
    expect(text, contains('03/01/2024'));
    expect(text, contains('Last Dive'));
    expect(text, contains('17/08/2026'));
    expect(text, contains('1h 30m'));
  });

  test('the cover date range agrees with the summary in either order', () async {
    // The cover took dives.last / dives.first, which reverses the range for an
    // oldest-first caller and then contradicts the summary, which sorts.
    final oldestFirst = await render([
      diveOn(DateTime(2024, 1, 3), runtime: const Duration(minutes: 50)),
      diveOn(DateTime(2026, 8, 17), runtime: const Duration(minutes: 40)),
    ]);

    expect(oldestFirst, contains('03/01/2024 - 17/08/2026'));
    expect(oldestFirst, isNot(contains('17/08/2026 - 03/01/2024')));
  });

  test('finds the range even when the dives arrive oldest first', () async {
    final text = await render([
      diveOn(DateTime(2024, 1, 3), runtime: const Duration(minutes: 50)),
      diveOn(DateTime(2026, 8, 17), runtime: const Duration(minutes: 40)),
    ]);

    // Asserted as label-plus-value pairs: both dates appear on the cover page
    // regardless, so bare date assertions would pass even if the summary read
    // the ends of the list and got the range backwards.
    expect(text, contains('First Dive 03/01/2024'));
    expect(text, contains('Last Dive 17/08/2026'));
  });
}
