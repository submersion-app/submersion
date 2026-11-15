import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1608: the altitude-group name and range rendered the hardcoded
/// English `displayName` / `rangeDescription`. Both switches are exhaustive by
/// enum value.
void main() {
  late AppLocalizations en;
  late AppLocalizations fr;
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(altitudeUnit: AltitudeUnit.feet));

  // The ranges group digits by the process-wide Intl.defaultLocale, which
  // another test may have changed. Pin English so "2,953" keeps its comma.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  test('every AltitudeGroup resolves to a non-empty name and range', () {
    for (final group in AltitudeGroup.values) {
      expect(group.localizedName(en), isNotEmpty, reason: '${group.name} name');
      expect(
        group.localizedRange(en, metric),
        isNotEmpty,
        reason: '${group.name} range',
      );
      expect(group.localizedName(fr), isNotEmpty);
      expect(group.localizedRange(fr, metric), isNotEmpty);
    }
  });

  test('the name follows the active locale', () {
    expect(
      AltitudeGroup.seaLevel.localizedName(fr),
      isNot(equals(AltitudeGroup.seaLevel.localizedName(en))),
    );
  });

  // The range is given once, in the diver's own unit, as every other
  // altitude on the page is.
  group('the range is in the diver\'s unit', () {
    for (final (group, metres, feet) in [
      (AltitudeGroup.seaLevel, '0-300 m', '0-984 ft'),
      (AltitudeGroup.group1, '300-900 m', '984-2,953 ft'),
      (AltitudeGroup.group2, '900-1,800 m', '2,953-5,906 ft'),
      (AltitudeGroup.group3, '1,800-2,700 m', '5,906-8,858 ft'),
      (AltitudeGroup.extreme, '>2,700 m', '>8,858 ft'),
    ]) {
      test(group.name, () {
        expect(group.localizedRange(en, metric), metres);
        expect(group.localizedRange(en, imperial), feet);
      });
    }
  });
}
