import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_selection.dart';

/// The readout's three states (issue #4569): idle, hovering a level, and a
/// level pinned by a click or a tap. While pinned, hovering changes nothing.
void main() {
  const a = VerticalProbe(direction: VerticalLeg.descent, meters: 100);
  const b = VerticalProbe(direction: VerticalLeg.ascent, meters: 200);
  const idle = VerticalIdle();

  test('hovering a level from idle shows it', () {
    final s = hoverSelection(idle, a);
    expect(s, isA<VerticalHovering>());
    expect(s.probe, same(a));
  });

  test('hovering off the bars returns to idle', () {
    expect(hoverSelection(hoverSelection(idle, a), null), isA<VerticalIdle>());
  });

  test('leaving the scale returns to idle', () {
    expect(exitSelection(hoverSelection(idle, a)), isA<VerticalIdle>());
  });

  test('a tap on a level pins it', () {
    final s = tapSelection(idle, a);
    expect(s, isA<VerticalPinned>());
    expect(s.probe, same(a));
  });

  test('while pinned, hover and exit change nothing', () {
    final pinned = tapSelection(idle, a);
    expect(hoverSelection(pinned, b), same(pinned));
    expect(hoverSelection(pinned, null), same(pinned));
    expect(exitSelection(pinned), same(pinned));
  });

  test('a tap on another level moves the pin', () {
    final s = tapSelection(tapSelection(idle, a), b);
    expect(s, isA<VerticalPinned>());
    expect(s.probe, same(b));
  });

  test('a tap away from the bars unpins', () {
    expect(tapSelection(tapSelection(idle, a), null), isA<VerticalIdle>());
  });

  test('idle carries no probe', () {
    expect(idle.probe, isNull);
  });
}
