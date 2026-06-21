import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

  group('MapResetNorthButton', () {
    Widget harness(MapController controller) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: FlutterMap(
            mapController: controller,
            options: const MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 3,
            ),
            children: const [MapResetNorthButton()],
          ),
        ),
      ),
    );

    testWidgets('hidden at north, shown when rotated, resets on tap', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(harness(controller));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      controller.rotate(45);
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(controller.camera.rotation.abs() < 0.01, isTrue);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('shouldShowResetNorth', () {
    test('hidden at or near north', () {
      expect(shouldShowResetNorth(0), isFalse);
      expect(shouldShowResetNorth(0.3), isFalse);
      expect(shouldShowResetNorth(359.8), isFalse);
      expect(shouldShowResetNorth(360), isFalse);
    });

    test('shown when meaningfully rotated', () {
      expect(shouldShowResetNorth(15), isTrue);
      expect(shouldShowResetNorth(90), isTrue);
      expect(shouldShowResetNorth(200), isTrue);
      expect(shouldShowResetNorth(-15), isTrue);
    });
  });
}
