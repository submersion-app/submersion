import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_fold_summary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a folded group says it holds (issue #4184).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  String label(EquipmentType t) => t.localizedName(l10n);

  test('location summary lists types with counts', () {
    expect(
      foldedLocationSummary(l10n, const [
        (EquipmentType.bcd, 2),
        (EquipmentType.secondStage, 1),
        (EquipmentType.tank, 4),
      ]),
      '${label(EquipmentType.bcd)} 2 · '
      '${label(EquipmentType.secondStage)} 1 · '
      '${label(EquipmentType.tank)} 4',
    );
  });

  test('location summary stops at three types, then says how many more', () {
    expect(
      foldedLocationSummary(l10n, const [
        (EquipmentType.bcd, 2),
        (EquipmentType.secondStage, 1),
        (EquipmentType.tank, 4),
        (EquipmentType.wetsuit, 1),
        (EquipmentType.fins, 1),
      ]),
      '${label(EquipmentType.bcd)} 2 · '
      '${label(EquipmentType.secondStage)} 1 · '
      '${label(EquipmentType.tank)} 4 · and 2 more',
    );
  });

  test('no typed groups means no location summary', () {
    expect(foldedLocationSummary(l10n, const []), isNull);
  });

  test('type summary names service due, and only when there is some', () {
    expect(foldedTypeSummary(l10n, serviceDueCount: 0), isNull);
    expect(foldedTypeSummary(l10n, serviceDueCount: 1), '1 service due');
    expect(foldedTypeSummary(l10n, serviceDueCount: 3), '3 service due');
  });

  test('selection summary', () {
    expect(
      foldedSelectionSummary(l10n, selected: 2, total: 8),
      '2 of 8 selected',
    );
  });

  test('every locale renders the new strings with their numbers', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      expect(l.equipment_group_foldedServiceDue(5), contains('5'));
      expect(l.equipment_group_foldedMoreTypes(4), contains('4'));
      final selected = l.equipment_group_foldedSelected(3, 9);
      expect(selected, allOf(contains('3'), contains('9')));
      expect(l.equipment_group_foldedTypeCount(7, 'X'), contains('7'));
      expect(l.equipment_list_expandAllGroups, isNotEmpty);
      expect(l.equipment_list_collapseAllGroups, isNotEmpty);
    }
  });
}
