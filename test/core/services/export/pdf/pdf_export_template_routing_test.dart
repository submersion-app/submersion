import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// The dive-list bulk export and the single-dive export never saw a template
/// and used a duplicated copy of the old layout inside PdfExportService. That
/// copy hardcoded A4 and built `pw.Document()` with no font theme, so accented
/// site names came out mangled. Both callers now route through the factory.
///
/// These assertions deliberately avoid [pdfVisibleText]: once PdfFonts loads
/// Roboto the text is written as a TrueType subset and no longer extracts as
/// literal strings. Page structure and byte equality are font-agnostic.
void main() {
  late PdfExportService service;

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  setUp(() async {
    await setUpTestDatabase();
    service = PdfExportService();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive makeDive({String id = 'dive-1', DiveSite? site}) => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 45),
    maxDepth: 24.0,
    waterTemp: 21.0,
    site: site,
  );

  test('honours the selected template', () async {
    final dives = [makeDive(), makeDive(id: 'dive-2')];

    final simple = await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.simple),
    );
    final detailed = await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.detailed),
    );

    // Simple puts both dives in one table; detailed gives each its own page.
    expect(
      pdfPageCount(simple.bytes),
      lessThan(pdfPageCount(detailed.bytes)),
      reason: 'both levels used to produce the same single-layout document',
    );
  });

  test('produces the same document the template builds directly', () async {
    final dives = [makeDive()];

    final routed = await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.detailed),
    );

    await PdfFonts.instance.initialize();
    final direct = await PdfTemplateDetailed().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );

    expect(
      pdfPageCount(routed.bytes),
      pdfPageCount(direct),
      reason: 'the service must delegate rather than build its own layout',
    );
  });

  test('the simple route matches the simple template', () async {
    final dives = [makeDive()];

    final routed = await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.simple),
    );

    await PdfFonts.instance.initialize();
    final direct = await PdfTemplateSimple().buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );

    expect(pdfPageCount(routed.bytes), pdfPageCount(direct));
  });

  test('honours the requested page size', () async {
    final letter = await service.generateDivePdfBytes(
      [makeDive()],
      dates: dates,
      units: units,
      options: const PdfExportOptions(pageSize: PdfPageSize.letter),
    );
    final a4 = await service.generateDivePdfBytes(
      [makeDive()],
      dates: dates,
      units: units,
      options: const PdfExportOptions(pageSize: PdfPageSize.a4),
    );

    expect(
      letter.bytes,
      isNot(a4.bytes),
      reason: 'the legacy builder hardcoded A4 and ignored the page size',
    );
  });

  test('embeds a Unicode font so accented site names survive', () async {
    const site = DiveSite(id: 's1', name: 'Café Réunion');

    final result = await service.generateDivePdfBytes(
      [makeDive(site: site)],
      dates: dates,
      units: units,
    );

    // The legacy builder used `pw.Document()` with no theme, so it fell back
    // to Helvetica and embedded no font program at all.
    expect(PdfFonts.instance.isInitialized, isTrue);
    expect(
      String.fromCharCodes(result.bytes.map((b) => b & 0xFF)),
      contains('FontFile'),
      reason: 'no embedded font means no Unicode support',
    );
  });

  test('honours includeCertificationCards on the bulk route', () async {
    final certs = [
      Certification(
        id: 'c1',
        name: 'Rescue Diver',
        agency: CertificationAgency.padi,
        cardNumber: 'CARD-9',
        issueDate: DateTime(2021, 4, 2),
        createdAt: DateTime(2021, 4, 2),
        updatedAt: DateTime(2021, 4, 2),
      ),
    ];

    final withCards = await service.generateDivePdfBytes(
      [makeDive()],
      dates: dates,
      units: units,
      options: const PdfExportOptions(includeCertificationCards: true),
      certifications: certs,
    );
    final without = await service.generateDivePdfBytes(
      [makeDive()],
      dates: dates,
      units: units,
      certifications: certs,
    );

    expect(
      pdfPageCount(withCards.bytes),
      greaterThan(pdfPageCount(without.bytes)),
      reason: 'the option was silently ignored on this route',
    );
  });

  test('names the file after the template, keeping the date ISO', () async {
    final result = await service.generateDivePdfBytes(
      [makeDive()],
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.simple),
    );

    expect(result.fileName, startsWith('dive_logbook_simple_'));
    expect(result.fileName, endsWith('.pdf'));
  });
}
