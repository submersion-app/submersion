import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  test('scroll and slot map onto each other over the loaded rows', () {
    expect(
      slotPositionForScroll(
        pixels: 0,
        maxScrollExtent: 900,
        loadedSlotCount: 10,
      ).round(),
      0,
    );
    expect(
      slotPositionForScroll(
        pixels: 900,
        maxScrollExtent: 900,
        loadedSlotCount: 10,
      ).round(),
      9,
    );
    expect(
      slotPositionForScroll(
        pixels: 450,
        maxScrollExtent: 900,
        loadedSlotCount: 11,
      ).round(),
      5,
    );
    expect(
      scrollForSlot(slot: 5, maxScrollExtent: 900, loadedSlotCount: 11),
      450,
    );
    expect(
      scrollForSlot(slot: 40, maxScrollExtent: 900, loadedSlotCount: 11),
      900,
    );
    expect(
      slotPositionForScroll(
        pixels: 10,
        maxScrollExtent: 0,
        loadedSlotCount: 11,
      ).round(),
      0,
    );
  });

  test('track position and slot map onto each other over all slots', () {
    expect(
      slotPositionForTrack(dy: 0, trackExtent: 500, slotCount: 101).round(),
      0,
    );
    expect(
      slotPositionForTrack(dy: 250, trackExtent: 500, slotCount: 101).round(),
      50,
    );
    expect(
      slotPositionForTrack(dy: 900, trackExtent: 500, slotCount: 101).round(),
      100,
    );
    expect(
      slotPositionForTrack(dy: -20, trackExtent: 500, slotCount: 101).round(),
      0,
    );
    expect(trackForSlot(slot: 50, trackExtent: 500, slotCount: 101), 250);
    expect(trackForSlot(slot: 0, trackExtent: 500, slotCount: 1), 0);
  });

  test('positions between slots are fractional, so motion is continuous', () {
    expect(
      slotPositionForScroll(
        pixels: 450,
        maxScrollExtent: 900,
        loadedSlotCount: 11,
      ),
      5,
    );
    expect(
      slotPositionForScroll(
        pixels: 45,
        maxScrollExtent: 900,
        loadedSlotCount: 11,
      ),
      closeTo(0.5, 1e-9),
    );
    expect(
      slotPositionForScroll(
        pixels: 10,
        maxScrollExtent: 0,
        loadedSlotCount: 11,
      ),
      0,
    );
    expect(
      slotPositionForTrack(dy: 126, trackExtent: 500, slotCount: 101),
      closeTo(25.2, 1e-9),
    );
    expect(
      slotPositionForTrack(dy: 900, trackExtent: 500, slotCount: 101),
      100,
    );
    expect(
      trackForSlot(slot: 25.2, trackExtent: 500, slotCount: 101),
      closeTo(126, 1e-9),
    );
    expect(
      scrollForSlot(slot: 0.5, maxScrollExtent: 900, loadedSlotCount: 11),
      closeTo(45, 1e-9),
    );
  });

  test('wanted only past three viewports of estimated content', () {
    // 10 loaded rows fill 1.5 viewports; 30 slots in all estimate 4.5.
    expect(
      scrubberWanted(
        slotCount: 30,
        loadedSlotCount: 10,
        maxScrollExtent: 300,
        viewportDimension: 600,
      ),
      isTrue,
    );
    expect(
      scrubberWanted(
        slotCount: 10,
        loadedSlotCount: 10,
        maxScrollExtent: 300,
        viewportDimension: 600,
      ),
      isFalse,
    );
    expect(
      scrubberWanted(
        slotCount: 0,
        loadedSlotCount: 0,
        maxScrollExtent: 0,
        viewportDimension: 600,
      ),
      isFalse,
    );
  });

  test('thinning keeps markers at least minSpacing apart', () {
    const markers = [
      ScrubberMarker(slot: 0, label: 'a'),
      ScrubberMarker(slot: 1, label: 'b'),
      ScrubberMarker(slot: 10, label: 'c'),
      ScrubberMarker(slot: 11, label: 'd'),
      ScrubberMarker(slot: 100, label: 'e'),
    ];
    final kept = thinMarkers(
      markers,
      slotCount: 101,
      trackExtent: 500,
      minSpacing: 28,
    );
    expect(kept.map((m) => m.label), ['a', 'c', 'e']);
  });
}
