import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The printed logbook is a document a human reads, so it follows the diver's
/// arrangement (#1486, #1576), using English type labels because the template
/// has no localizations in scope.
void main() {
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );
  const aqualung = EquipmentItem(
    id: 'reg-2',
    name: 'Aqualung',
    type: EquipmentType.regulator,
  );

  final template = PdfTemplateDetailed();
  const units = UnitFormatter(AppSettings());

  Dive diveWith(List<EquipmentItem> gear) => Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    notes: '',
    equipment: gear,
  );

  test('equipment rows follow the chosen type order', () {
    final rows = template.equipmentFieldsForTest(
      diveWith(const [zeagle, faber, apeks, aqualung]),
      units: units,
      arrangement: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );

    expect(rows.map((r) => r.value).toList(), [
      'Faber',
      'Apeks',
      'Aqualung',
      'Zeagle',
    ]);
  });

  test('equipment rows follow the chosen item sort inside a type', () {
    final rows = template.equipmentFieldsForTest(
      diveWith(const [apeks, aqualung]),
      units: units,
      arrangement: EquipmentArrangement.defaults.copyWith(
        itemSortDirection: SortDirection.descending,
      ),
    );

    expect(rows.map((r) => r.value).toList(), ['Aqualung', 'Apeks']);
  });

  test('uses English type labels, not a localized name', () {
    final rows = template.equipmentFieldsForTest(
      diveWith(const [apeks]),
      units: units,
      arrangement: EquipmentArrangement.defaults,
    );

    expect(rows.single.label, 'Regulator');
  });
}
