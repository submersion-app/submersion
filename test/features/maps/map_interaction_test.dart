import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';

void main() {
  group('mapInteractionOptions', () {
    test('touch enables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: true, allowRotation: false);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isTrue);
      expect(InteractiveFlag.hasPinchMove(o.flags), isTrue);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isTrue);
    });

    test('non-touch disables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: false, allowRotation: true);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isFalse);
      expect(InteractiveFlag.hasPinchMove(o.flags), isFalse);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isFalse);
    });

    test('rotate gesture only for touch with rotation allowed', () {
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: true).flags,
        ),
        isTrue,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: false).flags,
        ),
        isFalse,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: false, allowRotation: true).flags,
        ),
        isFalse,
      );
    });

    test('gesture race enabled only when rotating by touch', () {
      expect(
        mapInteractionOptions(
          isTouch: true,
          allowRotation: true,
        ).enableMultiFingerGestureRace,
        isTrue,
      );
      expect(
        mapInteractionOptions(
          isTouch: false,
          allowRotation: true,
        ).enableMultiFingerGestureRace,
        isFalse,
      );
    });

    test('rotation threshold widened to 30 degrees', () {
      expect(
        mapInteractionOptions(
          isTouch: true,
          allowRotation: true,
        ).rotationThreshold,
        30.0,
      );
    });

    test('scroll-wheel zoom and drag always enabled', () {
      for (final isTouch in [true, false]) {
        for (final allowRotation in [true, false]) {
          final o = mapInteractionOptions(
            isTouch: isTouch,
            allowRotation: allowRotation,
          );
          expect(InteractiveFlag.hasScrollWheelZoom(o.flags), isTrue);
          expect(InteractiveFlag.hasDrag(o.flags), isTrue);
        }
      }
    });
  });
}
