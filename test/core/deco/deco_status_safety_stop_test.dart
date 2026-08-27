import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';

/// A minimal DecoStatus for exercising the safetyStopSeconds field. The
/// tissue-loading getters are covered elsewhere; here we only care about the
/// value being carried through the constructor default, copyWith, and equality.
DecoStatus buildStatus({int? safetyStopSeconds}) {
  return DecoStatus(
    compartments: const [],
    ndlSeconds: 999 * 60,
    ceilingMeters: 0,
    ttsSeconds: 0,
    safetyStopSeconds: safetyStopSeconds ?? 0,
    gfLow: 0.3,
    gfHigh: 0.7,
    decoStops: const [],
    currentDepthMeters: 0,
    ambientPressureBar: 1.0,
  );
}

void main() {
  group('DecoStatus.safetyStopSeconds', () {
    test('defaults to 0 when omitted from the constructor', () {
      const status = DecoStatus(
        compartments: [],
        ndlSeconds: 0,
        ceilingMeters: 0,
        ttsSeconds: 0,
        gfLow: 0.3,
        gfHigh: 0.7,
        decoStops: [],
        currentDepthMeters: 0,
        ambientPressureBar: 1.0,
      );
      expect(status.safetyStopSeconds, 0);
    });

    test('copyWith overrides the value when provided', () {
      final status = buildStatus(safetyStopSeconds: 180);
      final updated = status.copyWith(safetyStopSeconds: 60);
      expect(updated.safetyStopSeconds, 60);
    });

    test('copyWith preserves the value when not provided', () {
      final status = buildStatus(safetyStopSeconds: 120);
      final copy = status.copyWith(ttsSeconds: 999);
      expect(copy.safetyStopSeconds, 120);
      expect(copy.ttsSeconds, 999);
    });

    test('participates in equality (props)', () {
      final a = buildStatus(safetyStopSeconds: 180);
      final b = buildStatus(safetyStopSeconds: 180);
      final c = buildStatus(safetyStopSeconds: 90);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
