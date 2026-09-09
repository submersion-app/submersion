import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('o2Cell carries a slot and an install date', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.o2Cell,
    ).map((d) => d.key).toList();
    expect(keys, containsAll(['cell_slot', 'installed_date']));
    expect(
      EquipmentAttributeCatalog.defFor('cell_slot')!.kind,
      AttributeKind.number,
    );
    expect(
      EquipmentAttributeCatalog.defFor('installed_date')!.kind,
      AttributeKind.date,
    );
  });

  test('battery carries install date, chemistry and rechargeable flag', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.battery,
    ).map((d) => d.key).toList();
    expect(
      keys,
      containsAll(['installed_date', 'battery_type', 'rechargeable']),
    );
    expect(
      EquipmentAttributeCatalog.defFor('battery_type')!.choiceKeys,
      containsAll([
        'lithium_ion',
        'nimh',
        'lead_acid',
        'alkaline',
        'lithium_primary',
      ]),
    );
  });

  test('the new types have localized names', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(EquipmentType.o2Cell.localizedName(l10n), 'O2 cell');
    expect(EquipmentType.battery.localizedName(l10n), 'Battery');
  });
}
