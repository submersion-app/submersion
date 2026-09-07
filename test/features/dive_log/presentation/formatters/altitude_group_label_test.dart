import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1608: the altitude-group name and range rendered the hardcoded
/// English `displayName` / `rangeDescription`. Both switches are exhaustive by
/// enum value.
void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  test('every AltitudeGroup resolves to a non-empty name and range', () {
    for (final group in AltitudeGroup.values) {
      expect(group.localizedName(en), isNotEmpty, reason: '${group.name} name');
      expect(
        group.localizedRange(en),
        isNotEmpty,
        reason: '${group.name} range',
      );
      expect(group.localizedName(fr), isNotEmpty);
      expect(group.localizedRange(fr), isNotEmpty);
    }
  });

  test('the name follows the active locale', () {
    expect(
      AltitudeGroup.seaLevel.localizedName(fr),
      isNot(equals(AltitudeGroup.seaLevel.localizedName(en))),
    );
  });
}
