import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

void main() {
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
