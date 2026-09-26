import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_spec_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  // UnitFormatter localises the decimal separator from Intl.defaultLocale,
  // so pin it for the English-formatted expectations below.
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const id = 'eq-1';
  const al80 = EquipmentItem(
    id: id,
    name: 'AL80',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute(
        id: 'a1',
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: 11.1,
      ),
      EquipmentAttribute(
        id: 'a2',
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 207,
      ),
    ],
  );

  /// Pumps the card for [al80] and returns the text in its volume row. The
  /// free-gas row also reads in the volume unit, so the value is looked up
  /// beside the volume label rather than anywhere on the card.
  Future<String> volumeRow(
    WidgetTester tester, {
    MockSettingsNotifier? settings,
  }) async {
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          newestFillProvider.overrideWith((ref, equipmentId) async => null),
        ],
        child: const PassportSpecCard(equipment: al80),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportSpecCard)),
    );
    final row = find.ancestor(
      of: find.text(attributeLabel(l10n, EquipmentAttrKeys.volumeL)),
      matching: find.byType(Row),
    );
    final texts = tester.widgetList<Text>(
      find.descendant(of: row.first, matching: find.byType(Text)),
    );
    return texts.last.data!;
  }

  testWidgets('tank volume keeps its decimal in liters', (tester) async {
    expect(await volumeRow(tester), '11.1 L');
  });

  testWidgets('tank volume reads as rated gas capacity in cubic feet', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    final rated = TankPresets.matchBySpecs(11.1, 207)!.ratedCapacityCuft!;
    expect(
      await volumeRow(tester, settings: settings),
      '${rated.round()} cuft',
    );
  });
}
