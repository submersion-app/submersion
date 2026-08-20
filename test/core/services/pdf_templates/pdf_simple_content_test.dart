import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// #1017 reports the simple logbook is missing its key metrics (dive count,
/// first and last dive, total time, deepest) and cannot list certifications at
/// all. It carried only the compact table.
void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  Dive diveOn(DateTime when, {double depth = 30.0}) => Dive(
    id: when.toIso8601String(),
    diveNumber: 1,
    dateTime: when,
    runtime: const Duration(minutes: 45),
    maxDepth: depth,
  );

  final dives = [
    diveOn(DateTime(2026, 8, 17), depth: 38.5),
    diveOn(DateTime(2024, 1, 3)),
  ];

  final openWater = Certification(
    id: 'c1',
    name: 'Open Water Diver',
    agency: CertificationAgency.padi,
    cardNumber: 'CARD-1',
    issueDate: DateTime(2018, 6, 12),
    createdAt: DateTime(2018, 6, 12),
    updatedAt: DateTime(2018, 6, 12),
  );

  Future<String> render({List<Certification>? certifications}) async =>
      pdfVisibleText(
        await PdfTemplateSimple().buildPdf(
          dives: dives,
          pageSize: PdfPageSize.a4,
          dates: dates,
          units: units,
          certifications: certifications,
        ),
      );

  test('opens with the key metrics', () async {
    final text = await render();
    expect(text, contains('Total Dives'));
    expect(text, contains('First Dive'));
    expect(text, contains('03/01/2024'));
    expect(text, contains('Last Dive'));
    expect(text, contains('17/08/2026'));
    expect(text, contains('Total Dive Time'));
    expect(text, contains('Deepest Dive'));
    expect(text, contains('38.5m'));
  });

  test('lists certifications when supplied', () async {
    final text = await render(certifications: [openWater]);
    expect(text, contains('Open Water Diver'));
    expect(text, contains('CARD-1'));
    expect(text, contains('12/06/2018'));
  });

  test('omits the certification pages when none are supplied', () async {
    expect(await render(), isNot(contains('CARD-1')));
  });

  test('keeps the compact table', () async {
    final text = await render();
    expect(text, contains('Site'));
    expect(text, contains('Depth'));
    expect(text, contains('Temp'));
  });

  test('still supports certification cards per the template flag', () {
    expect(PdfTemplate.simple.supportsCertificationCards, isTrue);
  });
}
