import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';

/// Records the gear arrangement the export service hands the template.
class _RecordingSimple extends PdfTemplateSimple {
  EquipmentArrangement? gearArrangement;

  @override
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    String? title,
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    CertificationCatalog? certificationCatalog,
    Diver? diver,
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
    EquipmentArrangement gearArrangement = EquipmentArrangement.defaults,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    Map<String, DiveRole> diveRolesById = const {},
    Map<String, String> equipmentSetNamesById = const {},
    PdfLocalization? localization,
    DateTime? generatedAt,
  }) {
    this.gearArrangement = gearArrangement;
    return super.buildPdf(
      dives: dives,
      pageSize: pageSize,
      dates: dates,
      units: units,
      generatedAt: generatedAt,
    );
  }
}

/// The printed logbook follows the diver's own gear arrangement (issue
/// #3748). The caller resolves it for the active diver and passes it in;
/// the service no longer reads the app-wide setting itself.
void main() {
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

  test('export prints in the passed arrangement', () async {
    const flat = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.none,
      groupByType: false,
      itemSortField: EquipmentItemSortField.purchaseDate,
      itemSortDirection: SortDirection.descending,
    );
    await service.generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: const PdfExportOptions(template: PdfTemplate.simple),
      gearArrangement: flat,
    );
    expect(template.gearArrangement, flat);
  });
}
