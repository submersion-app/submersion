import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/fake_hosts.dart';

/// Records what the export service hands the template, then builds as usual.
class _RecordingSimple extends PdfTemplateSimple {
  PdfLocalization? localization;
  String? title;
  PdfDateFormatter? dates;

  @override
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    String? title,
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
    EquipmentArrangement gearArrangement = EquipmentArrangement.defaults,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    Map<String, String> equipmentSetNamesById = const {},
    PdfLocalization? localization,
    DateTime? generatedAt,
  }) {
    this.localization = localization;
    this.title = title;
    this.dates = dates;
    return super.buildPdf(
      dives: dives,
      pageSize: pageSize,
      dates: dates,
      units: units,
      title: title,
      localization: localization,
      generatedAt: generatedAt,
    );
  }
}

/// #2252: the dive-list and single-dive exports receive the language picked
/// in the export sheet through [PdfExportOptions.languageCode].
void main() {
  // PdfFonts downloads Roboto on first use. The font host answers as
  // offline, so the PDF falls back to Helvetica, as it would on a device
  // without a network, and its text stays readable for the assertions.
  setUp(() {
    serveFakeHost('fonts.gstatic.com');
  });

  late _RecordingSimple template;
  late PdfExportService service;

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());
  final dives = [
    Dive(id: 'd1', diveNumber: 1, dateTime: DateTime(2026, 3, 28, 10)),
  ];

  setUp(() async {
    await setUpTestDatabase();
    template = _RecordingSimple();
    service = PdfExportService(templateFor: (_) => template);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('passes the chosen language to the template', () async {
    await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(
        template: PdfTemplate.simple,
        languageCode: 'de',
      ),
    );

    expect(template.localization?.languageCode, 'de');
    expect(
      template.title,
      isNull,
      reason: 'the template titles the document in its own language',
    );
  });

  test('dates use the chosen language\'s month names', () async {
    await initializeDateFormatting('fr');
    await service.generateDivePdfBytes(
      dives,
      dates: PdfDateFormatter(
        dateFormat: DateFormatPreference.mmmDYYYY,
        timeFormat: TimeFormat.twentyFourHour,
      ),
      units: units,
      options: const PdfExportOptions(
        template: PdfTemplate.simple,
        languageCode: 'fr',
      ),
    );

    expect(template.dates!.date(DateTime(2026, 8, 17)), contains('août'));
  });

  test('no language prints English, as before', () async {
    await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.simple),
    );

    expect(template.localization?.languageCode, 'en');
  });
}
