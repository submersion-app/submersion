import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

void main() {
  for (final zoom in const [0.7, 0.8, 1.0, 1.3, 1.4]) {
    testWidgets('forwards taps through the transform at zoom $zoom', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DisplayZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(taps, 1, reason: 'tap must register at zoom $zoom');
    });
  }
}
