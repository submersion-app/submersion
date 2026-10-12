import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Issue #3119: a dive after a long break has a surface interval of thousands
/// of hours, which the logbooks printed as hours or raw minutes.
void main() {
  const units = UnitFormatter(AppSettings());
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.yyyymmdd,
    timeFormat: TimeFormat.twentyFourHour,
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 50),
    surfaceInterval: const Duration(hours: 157, minutes: 42),
    maxDepth: 25.0,
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  test('detailed logbook prints a long surface interval in days', () async {
    final bytes = await PdfTemplateDetailed().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );
    expect(pdfVisibleText(bytes), contains('6d 13h'));
  });

  test('NAUI logbook prints a long surface interval in days', () async {
    final bytes = await PdfTemplateNaui().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );
    final text = pdfVisibleText(bytes);
    expect(text, contains('SI: 6d 13h'));
    expect(text, isNot(contains('9462min')));
  });
}
