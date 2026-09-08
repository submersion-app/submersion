import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/formatters/profile_event_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1608: the dive-profile event markers rendered the hardcoded English
/// `ProfileEventType.displayName`. [ProfileEventTypeDisplay.localizedName]
/// routes the same values through the active locale; the switch is exhaustive.
void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  test('every ProfileEventType resolves to a non-empty label', () {
    for (final type in ProfileEventType.values) {
      expect(type.localizedName(en), isNotEmpty, reason: '${type.name} (en)');
      expect(type.localizedName(fr), isNotEmpty, reason: '${type.name} (fr)');
    }
  });

  test('the label follows the active locale', () {
    expect(
      ProfileEventType.bookmark.localizedName(fr),
      isNot(equals(ProfileEventType.bookmark.localizedName(en))),
    );
  });
}
