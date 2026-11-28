import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// English says "cylinder" for a diver's cylinder, never "tank" or "bottle"
/// (issue #5106), so the app reads the same on every screen.
///
/// The keys below keep the other word on purpose: a computer's own event
/// name, a replica of a computer's screen, and the search words that list
/// the old words so a search for them still finds cylinders.
const _keptOnPurpose = {
  'enum_profileEvent_suunto_tankPressureAlarm',
  'enum_profileEvent_suunto_tankPressureNotification',
  'enum_profileEvent_suunto_tankPressureWarning',
  'media_perdixOverlay_labelTank',
  'equipment_searchWords_cylinder',
  'equipment_searchWords_tankBand',
};

final _otherWord = RegExp(r'\b(tanks?|bottles?)\b', caseSensitive: false);

/// A placeholder's name (`{tank}`, `{tanks, plural, ...}`) is an identifier
/// the code passes, not text a diver reads.
final _placeholderName = RegExp(r'\{\w+(?=[,}])');

bool _saysOtherWord(String value) =>
    _otherWord.hasMatch(value.replaceAll(_placeholderName, '{'));

Map<String, dynamic> _english() =>
    jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('English values say cylinder, not tank or bottle', () {
    final offenders = [
      for (final MapEntry(:key, :value) in _english().entries)
        if (!key.startsWith('@') &&
            value is String &&
            !_keptOnPurpose.contains(key) &&
            _saysOtherWord(value))
          '$key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every key kept on purpose still exists and still needs it', () {
    final english = _english();
    for (final key in _keptOnPurpose) {
      expect(english[key], isA<String>(), reason: key);
      expect(_saysOtherWord(english[key] as String), isTrue, reason: key);
    }
  });

  test('the wording the design fixes', () {
    final english = _english();
    expect(english['enum_equipmentType_tank'], 'Cylinder');
    expect(english['enum_equipmentType_tankBand'], 'Cylinder Band');
    expect(english['enum_tankRole_pony'], 'Pony');
    expect(english['trips_cylinders_bottle'], 'Cylinder {label}');
    expect(english['trips_cylinders_fill_bottle'], 'Cylinder number');
    expect(english['settings_conflict_field_bottleLabel'], 'Cylinder number');
  });
}
