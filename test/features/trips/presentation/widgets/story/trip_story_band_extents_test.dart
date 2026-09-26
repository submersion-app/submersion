import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';

void main() {
  test('unscaled text gets the floor extents', () {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);

    expect(extents.docked, TripStoryBandExtents.dockedFloor);
    expect(extents.expanded, TripStoryBandExtents.expandedFloor);
  });

  test('large text grows the docked band', () {
    final extents = TripStoryBandExtents.forScaler(
      const TextScaler.linear(3.0),
    );

    expect(extents.docked, greaterThan(TripStoryBandExtents.dockedFloor));
    // The expanded floor still dominates here: 119.88 + 100 is under 260.
    expect(extents.expanded, TripStoryBandExtents.expandedFloor);
  });

  test('once the docked band outgrows the floor, expanded tracks it', () {
    // At 5x the panel needs 191.8, so docked + headroom finally clears 260.
    final extents = TripStoryBandExtents.forScaler(
      const TextScaler.linear(5.0),
    );

    expect(extents.expanded, greaterThan(TripStoryBandExtents.expandedFloor));
    expect(
      extents.expanded,
      extents.docked + TripStoryBandExtents.expandedHeadroom,
    );
  });

  test('the expanded band always clears the docked one', () {
    for (final scale in [1.0, 1.5, 2.0, 3.0, 4.0]) {
      final extents = TripStoryBandExtents.forScaler(TextScaler.linear(scale));

      expect(
        extents.expanded,
        greaterThanOrEqualTo(
          extents.docked + TripStoryBandExtents.expandedHeadroom - 0.01,
        ),
        reason: 'scale $scale left no room to morph',
      );
    }
  });
}
