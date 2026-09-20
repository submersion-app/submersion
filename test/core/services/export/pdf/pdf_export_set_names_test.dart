import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart' show DiversCompanion;
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The dive list and dive detail exports reach the Detailed template through
/// [PdfExportService], which must hand it the set names the Set row prints
/// (#2031).
///
/// Compares document sizes rather than text: once PdfFonts loads Roboto the
/// text is written as a TrueType subset and no longer extracts as literal
/// strings (see pdf_export_template_routing_test.dart). Nor bytes: each
/// document carries its own id, so two exports of the same dive differ.
void main() {
  late PdfExportService service;

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());
  const detailed = PdfExportOptions(template: PdfTemplate.detailed);

  setUp(() async {
    final db = await setUpTestDatabase();
    service = PdfExportService();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  // Gear applied from the winter set, plus a mask added by hand.
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 45),
    maxDepth: 24.0,
    gear: gearLinksFor(
      const [
        EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator),
        EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
      ],
      const [GearProvenance(equipmentId: 'reg', viaSetId: 'winter')],
    ),
  );

  Future<int> exportSize() async => (await service.generateDivePdfBytes(
    [dive],
    dates: dates,
    units: units,
    options: detailed,
  )).bytes.length;

  test('the exported logbook names the set the gear came from', () async {
    // Two exports of the same data are the same size, which is what lets a
    // size difference below stand for the Set row.
    final unnamed = await exportSize();
    expect(await exportSize(), unnamed);

    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 'winter',
        diverId: 'd1',
        name: 'Winter kit',
        equipmentIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    expect(
      await exportSize(),
      greaterThan(unnamed),
      reason: 'the service must pass the stored set names to the template',
    );
  });
}
