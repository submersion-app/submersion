import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attr_condition_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('names the field and lists the options in catalog order', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      attrConditionLabel(
        l10n,
        const EquipmentAttrCondition(key: 'hose_type', choices: {'lpi', 'hp'}),
      ),
      'Hose type: HP (high pressure), LPI (inflator)',
    );
  });
}
