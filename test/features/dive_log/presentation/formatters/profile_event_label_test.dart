import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/suunto_native_event.dart';
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

  group('markerLabel (#1523)', () {
    ProfileEvent event(
      ProfileEventType type, {
      double? value,
      EventSource source = EventSource.imported,
    }) => ProfileEvent(
      id: 'e',
      diveId: 'd',
      timestamp: 60,
      eventType: type,
      value: value,
      source: source,
      computerId: 'c1',
      computerManufacturer: 'Suunto',
      createdAt: DateTime.utc(2026),
    );

    test('a Suunto event shows the watch\'s exact wording', () {
      final alarm = event(
        ProfileEventType.ascentRateWarning,
        value: ((0x18 << 8) | 5).toDouble(),
      );
      expect(alarm.markerLabel(en), 'Ascent Rate Alarm');
      expect(alarm.markerLabel(fr), isNot('Ascent Rate Alarm'));

      final reached = event(
        ProfileEventType.decoStopStart,
        value: ((0x1B << 8) | 35).toDouble(),
      );
      expect(reached.markerLabel(en), 'Deco Stop Reached');
    });

    test('any other event keeps its type\'s label', () {
      expect(
        event(ProfileEventType.ascentRateWarning).markerLabel(en),
        ProfileEventType.ascentRateWarning.localizedName(en),
      );
      expect(
        event(
          ProfileEventType.ascentRateWarning,
          value: ((0x18 << 8) | 5).toDouble(),
          source: EventSource.computed,
        ).markerLabel(en),
        ProfileEventType.ascentRateWarning.localizedName(en),
      );
    });

    test('every Suunto event resolves to a distinct, localized label', () {
      final enLabels = <String>{};
      for (final suunto in SuuntoNativeEvent.values) {
        final label = suunto.localizedName(en);
        expect(label, isNotEmpty, reason: suunto.name);
        expect(enLabels.add(label), isTrue, reason: 'duplicate: $label');
        expect(suunto.localizedName(fr), isNotEmpty, reason: suunto.name);
      }
    });
  });
}
