import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom_shortcuts.dart';

void main() {
  late List<String> fired;

  Widget harness({required bool useMetaModifier}) {
    return MaterialApp(
      home: CallbackShortcuts(
        bindings: displayZoomShortcuts(
          onZoomIn: () => fired.add('in'),
          onZoomOut: () => fired.add('out'),
          onReset: () => fired.add('reset'),
          useMetaModifier: useMetaModifier,
        ),
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    );
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  setUp(() => fired = []);

  testWidgets('control shortcuts fire on non-Apple platforms', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.equal,
    );
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.minus,
    );
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.digit0,
    );

    expect(fired, ['in', 'out', 'reset']);
  });

  testWidgets('numpad plus and minus are also bound', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.numpadAdd,
    );
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.numpadSubtract,
    );

    expect(fired, ['in', 'out']);
  });

  testWidgets('meta shortcuts fire on Apple platforms', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: true));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.equal);

    expect(fired, ['in']);
  });

  testWidgets('the wrong modifier does not fire', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.equal);

    expect(fired, isEmpty);
  });
}
