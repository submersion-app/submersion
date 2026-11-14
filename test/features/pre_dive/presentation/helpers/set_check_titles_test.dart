import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/pre_dive/presentation/helpers/set_check_titles.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The pre-dive checks a set's lead and cylinders become (issue #4525).
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const pounds = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));
  final t = DateTime(2026, 11, 1);

  CylinderConfigItem cylinder({String? label, double o2 = 32}) =>
      CylinderConfigItem(
        id: 'c',
        configId: 'cfg',
        label: label,
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        workingPressureBar: 207,
        o2Percent: o2,
        createdAt: t,
        updatedAt: t,
      );

  test('the lead is one check with its total and breakdown, in the '
      'diver\'s unit', () {
    final titles = setCheckTitles(
      l,
      pounds,
      const SetBundle(
        setId: 's',
        weights: [
          (
            weightType: WeightType.backplate,
            amountKg: 2.72,
            notes: '',
            label: 'BP pockets',
          ),
          (weightType: WeightType.belt, amountKg: 2.72, notes: '', label: ''),
        ],
      ),
    );
    expect(titles, [
      'Weights: 12.0 lbs (BP pockets 6.0 lbs, ${l.enum_weightType_belt} '
          '6.0 lbs)',
    ]);
  });

  test('each cylinder is its own check, by label or by size, with its '
      'mix', () {
    final titles = setCheckTitles(
      l,
      pounds,
      SetBundle(
        setId: 's',
        cylinders: [
          cylinder(label: 'Left tank'),
          cylinder(o2: 21),
        ],
      ),
    );
    expect(titles, hasLength(2));
    expect(titles.first, 'Left tank · EAN32');
    expect(titles.last, endsWith('· Air'));
    expect(titles.last, isNot(startsWith('·')));
  });

  test('a cylinder with no label and no size is named by its mix', () {
    final titles = setCheckTitles(
      l,
      pounds,
      SetBundle(
        setId: 's',
        cylinders: [
          CylinderConfigItem(
            id: 'c',
            configId: 'cfg',
            tankRole: TankRole.backGas,
            o2Percent: 32,
            createdAt: t,
            updatedAt: t,
          ),
        ],
      ),
    );
    expect(titles, ['EAN32']);
  });

  test('a bundle with neither gives no checks', () {
    expect(
      setCheckTitles(l, pounds, const SetBundle(setId: 's', gearIds: ['g'])),
      isEmpty,
    );
  });
}
