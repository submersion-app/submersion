import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/scene_clock.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';
import 'package:submersion/shared/widgets/summary/summary_scene_pane.dart';

class _RecordingPainter extends CustomPainter {
  _RecordingPainter(this.seconds, this.brightness);

  final double seconds;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_RecordingPainter old) => true;
}

void main() {
  final calls = <(double, Brightness)>[];

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool disableAnimations = false,
    Widget child = const Text('facts'),
  }) {
    calls.clear();
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: SummaryScenePane(
            ink: Colors.white,
            painterBuilder: (seconds, b) {
              calls.add((seconds, b));
              return _RecordingPainter(seconds, b);
            },
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('the painter is excluded from semantics and the facts are not', (
    tester,
  ) async {
    await pump(tester);

    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is _RecordingPainter,
    );
    expect(
      find.ancestor(of: paint, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.text('facts'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsNothing,
    );
  });

  testWidgets('the painter receives the clock and the ambient brightness', (
    tester,
  ) async {
    await pump(tester, brightness: Brightness.dark, disableAnimations: true);

    expect(calls.last, (SceneClock.stillSeconds, Brightness.dark));
  });

  testWidgets('SceneInk.of inside the pane returns the ink colour', (
    tester,
  ) async {
    late Color ink;
    await pump(
      tester,
      child: Builder(
        builder: (context) {
          ink = SceneInk.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(ink, Colors.white);
  });
}
