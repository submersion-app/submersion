import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The printed logbook keeps an assembly's parts under the assembly
/// (issue #1487): indented, in template order, after the row they belong to.
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
  );
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  final template = PdfTemplateDetailed();
  const units = UnitFormatter(AppSettings());

  test('parts print indented under their assembly, with their type', () {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      notes: '',
      gear: gearLinksFor(
        const [reg, hose, mask],
        const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg')],
      ),
    );
    final fields = template.equipmentFieldsForTest(
      dive,
      units: units,
      arrangement: EquipmentArrangement.defaults,
    );
    final labels = fields.map((f) => f.label).toList();
    final regAt = labels.indexOf('Regulator');
    expect(regAt, greaterThanOrEqualTo(0));
    expect(labels[regAt + 1], '  Hose');
    expect(fields[regAt + 1].value, 'Long hose');
    // The part is not also printed as a top-level row.
    expect(labels.where((l) => l == 'Hose'), isEmpty);
  });
}
