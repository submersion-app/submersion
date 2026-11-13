import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_position_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The detail page names an item's chosen spot only while the figure would
/// honour it (issue #4493).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  EquipmentItem item(EquipmentType type, Map<String, String> attributes) =>
      EquipmentItem(
        id: 'i',
        name: 'Item',
        type: type,
        attributes: [
          for (final e in attributes.entries)
            EquipmentAttribute.curated(
              equipmentId: 'i',
              key: e.key,
              valueText: e.value,
            ),
        ],
      );

  test('names a chosen spot', () {
    expect(
      figurePositionLabelOf(
        l10n,
        item(EquipmentType.tank, {
          EquipmentAttrKeys.figurePosition: 'sidemount_left',
        }),
      ),
      'Sidemount, left',
    );
  });

  test('is null with no spot, an unknown one, or one without artwork', () {
    expect(figurePositionLabelOf(l10n, item(EquipmentType.tank, {})), isNull);
    expect(
      figurePositionLabelOf(
        l10n,
        item(EquipmentType.tank, {EquipmentAttrKeys.figurePosition: 'roof'}),
      ),
      isNull,
    );
    expect(
      figurePositionLabelOf(
        l10n,
        item(EquipmentType.computer, {
          'mount': 'console',
          EquipmentAttrKeys.figurePosition: 'wrist_left',
        }),
      ),
      isNull,
    );
  });
}
