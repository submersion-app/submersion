import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/services/scrubber_margin_service.dart';

/// Pure arithmetic over the four inputs. Nothing here says when the
/// scrubber "will" run out; it states expected use and the margin after.
void main() {
  const ccr = EquipmentItem(
    id: 'r1',
    name: 'CCR',
    type: EquipmentType.rebreather,
  );

  ScrubberMarginInputs inputs({
    double? rated = 300,
    double consumed = 90,
    int? divesOverride,
    int diveDays = 5,
    List<double> divesPerDay = const [2, 3, 2],
    int? runtimeOverride,
    List<double> scrubber = const [40, 50],
    List<double> runtime = const [60, 70, 80],
  }) => ScrubberMarginInputs(
    item: ccr,
    ratedMinutes: rated,
    consumedMinutes: consumed,
    expectedDivesOverride: divesOverride,
    itineraryDiveDays: diveDays,
    divesPerDiveDayHistory: divesPerDay,
    runtimeMinutesOverride: runtimeOverride,
    scrubberMinutesHistory: scrubber,
    rebreatherRuntimeMinutesHistory: runtime,
  );

  test('overrides win and carry n 0', () {
    final m = computeScrubberMargin(
      inputs(divesOverride: 12, runtimeOverride: 70),
    );
    expect(m.expectedDives, 12);
    expect(m.expectedDivesN, 0);
    expect(m.divesFromOverride, isTrue);
    expect(m.minutesFromOverride, isTrue);
    expect(m.minutesPerDive, 70);
    expect(m.minutesPerDiveN, 0);
    expect(m.expectedUse, 840);
    expect(m.remainingBefore, 210);
    expect(m.marginAfter, -630);
    expect(m.caution, isTrue);
  });

  test('a zero or negative override is ignored, as the trip form does', () {
    // The trip form saves a non-positive entry as unset; a stale or synced
    // row could still carry one, and it must not zero the expected use or
    // claim it was set on this trip.
    for (final bad in const [0, -3]) {
      final m = computeScrubberMargin(
        inputs(divesOverride: bad, runtimeOverride: bad),
      );
      final estimate = computeScrubberMargin(inputs());
      expect(m.expectedDives, estimate.expectedDives, reason: 'dives $bad');
      expect(m.expectedDivesN, estimate.expectedDivesN);
      expect(m.divesFromOverride, isFalse);
      expect(m.minutesPerDive, estimate.minutesPerDive, reason: 'min $bad');
      expect(m.minutesPerDiveN, estimate.minutesPerDiveN);
      expect(m.minutesFromOverride, isFalse);
    }
  });

  test('estimates use the medians with their n', () {
    final m = computeScrubberMargin(inputs());
    // 5 dive days times the median of 2, 3, 2 = 10 dives.
    expect(m.expectedDives, 10);
    expect(m.expectedDivesN, 3);
    // Median of 40 and 50.
    expect(m.minutesPerDive, 45);
    expect(m.minutesPerDiveN, 2);
    expect(m.expectedUse, 450);
    expect(m.marginAfter, -240);
  });

  test('a fractional median rounds the dive count up', () {
    final m = computeScrubberMargin(inputs(divesPerDay: [1, 2], diveDays: 3));
    // Median 1.5 times 3 days = 4.5, rounded up.
    expect(m.expectedDives, 5);
  });

  test('empty history defaults to 2 dives per day and runtime fallback', () {
    final m = computeScrubberMargin(
      inputs(
        divesPerDay: const [],
        scrubber: const [],
        runtime: const [60, 80],
      ),
    );
    expect(m.expectedDives, 10);
    expect(m.expectedDivesN, 0);
    expect(m.minutesPerDive, 70);
    expect(m.minutesPerDiveN, 2);
  });

  test('no history at all gives zero minutes per dive', () {
    final m = computeScrubberMargin(
      inputs(scrubber: const [], runtime: const []),
    );
    expect(m.minutesPerDive, 0);
    expect(m.expectedUse, 0);
  });

  test('consumed beyond rated floors the remaining at zero', () {
    final m = computeScrubberMargin(inputs(consumed: 400));
    expect(m.remainingBefore, 0);
    expect(m.caution, isTrue);
  });

  test('caution follows the 20 percent line', () {
    // Remaining 210, use 6 dives at 20 min = 120: margin 90 is 30 percent.
    final fine = computeScrubberMargin(
      inputs(divesOverride: 6, runtimeOverride: 20),
    );
    expect(fine.marginAfter, 90);
    expect(fine.caution, isFalse);
    // 8 dives at 20 = 160: margin 50 is under 60 (20 percent of 300).
    final tight = computeScrubberMargin(
      inputs(divesOverride: 8, runtimeOverride: 20),
    );
    expect(tight.marginAfter, 50);
    expect(tight.caution, isTrue);
  });

  test('no rating gives no margin and no caution', () {
    final m = computeScrubberMargin(inputs(rated: null));
    expect(m.ratedMinutes, isNull);
    expect(m.marginAfter, isNull);
    expect(m.caution, isFalse);
    expect(m.expectedUse, 450);
  });

  test('a default with no history is not an override', () {
    // n is 0 either way, so the flags are what tell the card whether the
    // diver set this figure or the app fell back to a default.
    final m = computeScrubberMargin(
      inputs(divesPerDay: const [], scrubber: const [], runtime: const []),
    );
    expect(m.expectedDivesN, 0);
    expect(m.divesFromOverride, isFalse);
    expect(m.minutesPerDiveN, 0);
    expect(m.minutesFromOverride, isFalse);
  });
}
