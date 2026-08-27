import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';

void main() {
  group('ReefHealth.fromJson', () {
    test('round-trips a full record', () {
      final original = ReefHealth(
        sst: 30.56,
        sstAnomaly: 1.15,
        hotspot: 1.47,
        degreeHeatingWeeks: 17.17,
        alertLevel: BleachingAlertLevel.alertLevel4,
        observedAt: DateTime.utc(2023, 9, 19, 12),
      );
      expect(ReefHealth.fromJson(original.toJson()), original);
    });

    test('absent alert level stays null', () {
      final health = ReefHealth.fromJson({
        'observedAt': '2026-07-23T12:00:00.000Z',
      });
      expect(health.alertLevel, isNull);
    });

    // A cached row written by a different build, or corrupted on disk, must
    // not read back as the safest-looking state. Rendering "No thermal
    // stress" over a reef whose real condition is unknown is the one failure
    // mode this entity has to avoid.
    test('unrecognised alert level reads as null, not noStress', () {
      final health = ReefHealth.fromJson({
        'alertLevel': 'someRenamedValue',
        'observedAt': '2026-07-23T12:00:00.000Z',
      });
      expect(health.alertLevel, isNull);
      expect(health.alertLevel, isNot(BleachingAlertLevel.noStress));
    });

    test('observedAt is normalized to UTC', () {
      final health = ReefHealth.fromJson({
        'observedAt': '2026-07-23T12:00:00.000Z',
      });
      expect(health.observedAt.isUtc, isTrue);
      expect(health.observedAt, DateTime.utc(2026, 7, 23, 12));
    });
  });
}
