import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_lights_scroller.dart';

/// [count] pills 100 wide in a scroller [width] wide.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int count = 6,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(
          width: width,
          height: 44,
          child: HomeLightsScroller(
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(width: 100, height: 44, child: Text('$i')),
            ],
          ),
        ),
      ),
    ),
  );
  // The scroll metrics arrive after the first layout.
  await tester.pump();
}

HomeLightsScrollerState _state(WidgetTester tester) =>
    tester.state<HomeLightsScrollerState>(find.byType(HomeLightsScroller));

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(HomeLightsScroller),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

final _mask = find.descendant(
  of: find.byType(HomeLightsScroller),
  matching: find.byType(ShaderMask),
);

void main() {
  testWidgets('no fade when every light fits', (tester) async {
    await _pump(tester, width: 800, count: 3);
    expect(_state(tester).fadesStart, isFalse);
    expect(_state(tester).fadesEnd, isFalse);
    expect(_mask, findsNothing);
  });

  testWidgets('no fade when every light fits but a trailing gap would not', (
    tester,
  ) async {
    // Three 100-wide lights and the two gaps between them take 312: the
    // row is 3 short of a gap after the last light, which must not count.
    await _pump(tester, width: 315, count: 3);
    expect(_state(tester).fadesEnd, isFalse);
    expect(_mask, findsNothing);
  });

  for (final direction in TextDirection.values) {
    testWidgets('the edge with lights past it fades (${direction.name})', (
      tester,
    ) async {
      await _pump(tester, width: 300, direction: direction);
      // At rest: only the end has lights past it.
      expect(_state(tester).fadesStart, isFalse);
      expect(_state(tester).fadesEnd, isTrue);
      expect(_mask, findsOneWidget);

      // Part way along: both ends do.
      _position(tester).jumpTo(100);
      await tester.pump();
      expect(_state(tester).fadesStart, isTrue);
      expect(_state(tester).fadesEnd, isTrue);

      // At the end: only the start.
      final position = _position(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(_state(tester).fadesStart, isTrue);
      expect(_state(tester).fadesEnd, isFalse);
    });
  }

  testWidgets('the fade follows a width change', (tester) async {
    await _pump(tester, width: 300);
    expect(_state(tester).fadesEnd, isTrue);
    await _pump(tester, width: 900);
    expect(_state(tester).fadesEnd, isFalse);
    expect(_mask, findsNothing);
  });

  testWidgets('the scroll view survives the mask going in and out', (
    tester,
  ) async {
    await _pump(tester, width: 900);
    final scrollable = find.descendant(
      of: find.byType(HomeLightsScroller),
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable);
    await _pump(tester, width: 300);
    expect(_mask, findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable), same(before));
    await _pump(tester, width: 900);
    expect(_mask, findsNothing);
    expect(tester.state<ScrollableState>(scrollable), same(before));
  });
}
