import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The table's Firmware column (issue #5104): the version each item runs,
/// and the newest listed release when there is one.
void main() {
  const units = UnitFormatter(AppSettings());
  final item = EquipmentItem(
    id: 'dc',
    name: 'Perdix 2',
    type: EquipmentType.computer,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'dc',
        key: 'firmware_version',
        valueText: 'V92',
      ),
    ],
  );

  test('firmware is appended last so saved layouts keep their order', () {
    expect(EquipmentField.values.last, EquipmentField.firmware);
    expect(
      EquipmentFieldAdapter.instance.fieldFromName('firmware'),
      EquipmentField.firmware,
    );
  });

  test('the column header is localized', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(EquipmentField.firmware.localizedDisplayName(en), 'Firmware');
    expect(EquipmentField.firmware.localizedShortLabel(en), 'Firmware');
    final de = lookupAppLocalizations(const Locale('de'));
    expect(EquipmentField.firmware.localizedDisplayName(de), 'Firmware');
  });

  test('firmware is a sortable details column', () {
    expect(EquipmentField.firmware.sortable, isTrue);
    expect(EquipmentField.firmware.categoryName, 'details');
    expect(EquipmentField.firmware.isRightAligned, isFalse);
  });

  test('the injected label wins, with the newest listed release', () {
    final adapter = EquipmentFieldAdapter(
      firmwareLabels: const {'dc': 'V92 (update: V95)'},
    );
    final value = adapter.extractValue(EquipmentField.firmware, item);
    expect(
      adapter.formatValue(EquipmentField.firmware, value, units),
      'V92 (update: V95)',
    );
  });

  test('without a label the recorded version shows, else the placeholder', () {
    final adapter = EquipmentFieldAdapter();
    expect(
      adapter.formatValue(
        EquipmentField.firmware,
        adapter.extractValue(EquipmentField.firmware, item),
        units,
      ),
      'V92',
    );
    const bare = EquipmentItem(id: 'f', name: 'Fins', type: EquipmentType.fins);
    final value = adapter.extractValue(EquipmentField.firmware, bare);
    expect(value, isNull);
    expect(adapter.formatValue(EquipmentField.firmware, value, units), '--');
  });
}
