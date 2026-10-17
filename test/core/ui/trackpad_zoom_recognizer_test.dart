import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

void main() {
  Future<({List<double> zooms, List<double> pans})> pumpRecognizer(
    WidgetTester tester,
  ) async {
    final pans = <double>[];
    final zooms = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TrackpadZoomGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  TrackpadZoomGestureRecognizer
                >(TrackpadZoomGestureRecognizer.new, (r) {
                  r.onPan = (_, dx) => pans.add(dx);
                  r.onZoom = (_, delta) => zooms.add(delta);
                }),
          },
          child: const SizedBox(width: 400, height: 300),
        ),
      ),
    );
    return (zooms: zooms, pans: pans);
  }

  // Windows reports a touchpad pinch through DirectManipulation, whose content
  // transform zooms about the fingers: scaling by s about a point c also
  // translates the content by c * (1 - s). Flutter passes that translation on
  // as the gesture's pan, so a pinch arrives with a large pan alongside it.
  Offset windowsPinchPan(Offset centroid, double scale) =>
      centroid * (1 - scale);

  testWidgets('a Windows pinch-out zooms in despite its induced pan', (
    tester,
  ) async {
    final (:zooms, :pans) = await pumpRecognizer(tester);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    const centroid = Offset(600, 400);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    for (final scale in [1.1, 1.25, 1.5]) {
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          at,
          pan: windowsPinchPan(centroid, scale),
          scale: scale,
        ),
      );
    }
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(zooms, everyElement(greaterThan(0)));
    expect(
      zooms.fold(0.0, (a, b) => a + b),
      closeTo(math.log(1.5) / math.ln2, 1e-9),
    );
    // The induced sideways movement is not a swipe either.
    expect(pans, isEmpty);
  });

  testWidgets('a Windows pinch-in zooms out despite its induced pan', (
    tester,
  ) async {
    final (:zooms, pans: _) = await pumpRecognizer(tester);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    const centroid = Offset(600, 400);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    for (final scale in [0.9, 0.75, 0.5]) {
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          at,
          pan: windowsPinchPan(centroid, scale),
          scale: scale,
        ),
      );
    }
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(zooms, everyElement(lessThan(0)));
    expect(zooms.fold(0.0, (a, b) => a + b), closeTo(-1.0, 1e-9));
  });

  testWidgets('a two-finger vertical scroll still zooms', (tester) async {
    final (:zooms, pans: _) = await pumpRecognizer(tester);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, 100)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(zooms, [closeTo(1.0, 1e-9)]);
  });

  testWidgets('a scroll that turns into a pinch stops scrolling', (
    tester,
  ) async {
    final (:zooms, pans: _) = await pumpRecognizer(tester);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, 50)),
    );
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, -150), scale: 2),
    );
    // Back to scale 1.0 with more pan: still the same pinch gesture.
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, 250)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(zooms, [
      closeTo(0.5, 1e-9),
      closeTo(1.0, 1e-9),
      closeTo(-1.0, 1e-9),
    ]);
  });

  testWidgets('a pinch gesture does not carry into the next scroll', (
    tester,
  ) async {
    final (:zooms, pans: _) = await pumpRecognizer(tester);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, -200), scale: 1.5),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    zooms.clear();

    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(0, 100)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(zooms, [closeTo(1.0, 1e-9)]);
  });

  testWidgets('a sideways two-finger swipe reports a horizontal pan', (
    tester,
  ) async {
    final pans = <double>[];
    final zooms = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TrackpadZoomGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  TrackpadZoomGestureRecognizer
                >(TrackpadZoomGestureRecognizer.new, (r) {
                  r.onPan = (_, dx) => pans.add(dx);
                  r.onZoom = (_, delta) => zooms.add(delta);
                }),
          },
          child: const SizedBox(width: 400, height: 300),
        ),
      ),
    );

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 150);
    await tester.sendEventToBinding(pointer.panZoomStart(at));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(at, pan: const Offset(-30, 0)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());

    expect(pans, [-30]);
    // No vertical movement, so no zoom.
    expect(zooms.every((z) => z == 0), isTrue);
  });
}
