import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';
import 'csv/csv_test_fixtures.dart';

/// #3683: exports that cannot draw formatting get plain words; PDFs draw it.
void main() {
  const markdown = '# Plan\n**Bring torch**';

  group('Excel', () {
    Future<String?> cell(
      String sheetName,
      String column, {
      List<Dive> dives = const [],
      List<DiveSite> sites = const [],
    }) async {
      final bytes = await ExcelExportService().generateExcelBytes(
        dives: dives,
        sites: sites,
        equipment: const [],
        depthUnit: DepthUnit.meters,
        temperatureUnit: TemperatureUnit.celsius,
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );
      final sheet = xl.Excel.decodeBytes(bytes)[sheetName];
      final headers = sheet.rows.first.map((c) => c?.value.toString()).toList();
      return sheet.rows[1][headers.indexOf(column)]?.value.toString();
    }

    test('dive notes are plain words', () async {
      final dive = goldenDives().first.copyWith(notes: markdown);
      expect(await cell('Dives', 'Notes', dives: [dive]), 'Plan Bring torch');
    });

    test('site description, access notes and notes are plain words', () async {
      final site = goldenSite.copyWith(
        description: markdown,
        accessNotes: markdown,
        notes: markdown,
      );
      for (final column in ['Description', 'Access Notes', 'Notes']) {
        expect(
          await cell('Sites', column, sites: [site]),
          'Plan Bring torch',
          reason: column,
        );
      }
    });
  });

  test('KML writes site descriptions as plain words', () async {
    final site = goldenSite.copyWith(
      description: markdown,
      accessNotes: markdown,
    );
    final (kml, _) = await KmlExportService().generateKmlContent(
      sites: [site],
      dives: const [],
      depthUnit: DepthUnit.meters,
      dateFormat: DateFormatPreference.yyyymmdd,
    );
    expect(kml, contains('Plan<br>Bring torch'));
    expect(kml, isNot(contains('**')));
  });

  group('PDF', () {
    final dates = PdfDateFormatter(
      dateFormat: DateFormatPreference.ddmmyyyy,
      timeFormat: TimeFormat.twentyFourHour,
    );
    const units = UnitFormatter(AppSettings());
    final dive = Dive(
      id: 'd1',
      diveNumber: 7,
      dateTime: DateTime(2026, 8, 17, 11, 7),
      runtime: const Duration(minutes: 26),
      maxDepth: 9.8,
    );

    test('the detailed template draws notes without their marks', () async {
      final bytes = await PdfTemplateDetailed().buildPdf(
        dives: [dive.copyWith(notes: markdown)],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
      );
      final text = pdfVisibleText(bytes);
      expect(text, contains('Bring'));
      expect(text, isNot(contains('**')));
    });

    test('a very long Markdown note still exports (#2056)', () async {
      final long = List.generate(
        300,
        (i) => '- item **$i** of a list',
      ).join('\n');
      final bytes = await PdfTemplateDetailed().buildPdf(
        dives: [dive.copyWith(notes: long)],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
      );
      expect(pdfPageCount(bytes), greaterThan(1));
    });

    test('the capped PADI notes line drops the marks', () async {
      final bytes = await PdfTemplatePadi().buildPdf(
        dives: [dive.copyWith(notes: markdown)],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
      );
      final text = pdfVisibleText(bytes);
      expect(text, contains('Bring'));
      expect(text, isNot(contains('**')));
    });
  });
}
