import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/suunto_native_event.dart';

/// Issue #1523: a Suunto watch's own event code, `(sub-group << 8) | type`,
/// rides on the imported event's `value`. Decoding it gives back the exact
/// event the watch logged, which the generic [ProfileEventType] loses.
void main() {
  ProfileEvent event(
    ProfileEventType type, {
    double? value,
    EventSource source = EventSource.imported,
    String? manufacturer = 'Suunto',
  }) => ProfileEvent(
    id: 'e',
    diveId: 'd',
    timestamp: 60,
    eventType: type,
    value: value,
    source: source,
    computerId: 'c1',
    computerManufacturer: manufacturer,
    createdAt: DateTime.utc(2026),
  );

  group('SuuntoNativeEvent.fromCode', () {
    test('resolves a known code', () {
      expect(
        SuuntoNativeEvent.fromCode((0x18 << 8) | 5),
        SuuntoNativeEvent.ascentRateAlarm,
      );
      expect(
        SuuntoNativeEvent.fromCode((0x1B << 8) | 35),
        SuuntoNativeEvent.decoStopReached,
      );
    });

    test('returns null for an unknown code', () {
      expect(SuuntoNativeEvent.fromCode(0), isNull);
      expect(SuuntoNativeEvent.fromCode((0x18 << 8) | 99), isNull);
    });

    test('codes are unique', () {
      final codes = SuuntoNativeEvent.values.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('SuuntoNativeEvent.of', () {
    test('decodes an imported event whose type matches the code', () {
      expect(
        SuuntoNativeEvent.of(
          event(
            ProfileEventType.ascentRateWarning,
            value: ((0x18 << 8) | 5).toDouble(),
          ),
        ),
        SuuntoNativeEvent.ascentRateAlarm,
      );
    });

    test('tells a stop reached from a stop broken', () {
      expect(
        SuuntoNativeEvent.of(
          event(
            ProfileEventType.decoViolation,
            value: ((0x18 << 8) | 10).toDouble(),
          ),
        ),
        SuuntoNativeEvent.decoStopBroken,
      );
      expect(
        SuuntoNativeEvent.of(
          event(
            ProfileEventType.decoViolation,
            value: ((0x1D << 8) | 2).toDouble(),
          ),
        ),
        SuuntoNativeEvent.ceilingBroken,
      );
    });

    test('labels a low-ppO2 alarm an older import stored as high ppO2', () {
      // Before #1523 the cloud import typed "PO2 Low" as ppO2High; the code
      // it stored alongside still says which alarm the watch raised.
      final code = ((0x18 << 8) | 1).toDouble();
      expect(
        SuuntoNativeEvent.of(event(ProfileEventType.ppO2High, value: code)),
        SuuntoNativeEvent.lowPpo2Alarm,
      );
      expect(
        SuuntoNativeEvent.of(event(ProfileEventType.ppO2Low, value: code)),
        SuuntoNativeEvent.lowPpo2Alarm,
      );
    });

    test('ignores a code whose type does not match the event', () {
      // Another computer's value that happens to equal a Suunto code is not
      // read as one unless the event type agrees with it.
      expect(
        SuuntoNativeEvent.of(
          event(
            ProfileEventType.gasSwitch,
            value: ((0x18 << 8) | 5).toDouble(),
          ),
        ),
        isNull,
      );
    });

    test('ignores an event from another or an unknown computer', () {
      // Every computer's events are stored as imported, so only the
      // computer's manufacturer says the value is a Suunto code.
      final code = ((0x18 << 8) | 5).toDouble();
      for (final manufacturer in ['Shearwater', null]) {
        expect(
          SuuntoNativeEvent.of(
            event(
              ProfileEventType.ascentRateWarning,
              value: code,
              manufacturer: manufacturer,
            ),
          ),
          isNull,
          reason: '$manufacturer',
        );
      }
    });

    test('matches the manufacturer regardless of case', () {
      expect(
        SuuntoNativeEvent.of(
          event(
            ProfileEventType.ascentRateWarning,
            value: ((0x18 << 8) | 5).toDouble(),
            manufacturer: ' SUUNTO ',
          ),
        ),
        SuuntoNativeEvent.ascentRateAlarm,
      );
    });

    test('ignores computed and user events', () {
      final code = ((0x18 << 8) | 5).toDouble();
      for (final source in [EventSource.computed, EventSource.user]) {
        expect(
          SuuntoNativeEvent.of(
            event(
              ProfileEventType.ascentRateWarning,
              value: code,
              source: source,
            ),
          ),
          isNull,
          reason: source.name,
        );
      }
    });

    test('ignores a missing or fractional value', () {
      expect(
        SuuntoNativeEvent.of(event(ProfileEventType.ascentRateWarning)),
        isNull,
      );
      expect(
        SuuntoNativeEvent.of(
          event(ProfileEventType.ascentRateWarning, value: 6149.5),
        ),
        isNull,
      );
    });
  });
}
