import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/tab_pinned_app_bar.dart';

/// A [TabPinnedAppBar] for page [index] under a 400px-wide page, with the
/// controller's animation standing at [value].
Future<void> _pump(
  WidgetTester tester, {
  required int index,
  required double value,
  TextDirection direction = TextDirection.ltr,
}) async {
  final animation = AlwaysStoppedAnimation<double>(value);
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          // Pushed along as a sliding page would be, so the bar has to undo it.
          child: Transform.translate(
            offset: Offset(
              (direction == TextDirection.ltr ? 400 : -400) * (index - value),
              0,
            ),
            child: TabPinnedAppBar(
              animation: animation,
              index: index,
              child: const PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: SizedBox(key: ValueKey('bar'), height: 56),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _barLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('bar'))).dx;

bool _barShown(WidgetTester tester) => tester
    .widget<Visibility>(
      find.ancestor(
        of: find.byKey(const ValueKey('bar')),
        matching: find.byType(Visibility),
      ),
    )
    .visible;

void main() {
  testWidgets('undoes its page\'s slide, so the bar stays put', (tester) async {
    await _pump(tester, index: 1, value: 0.7);

    expect(_barLeft(tester), closeTo(0, 0.001));
  });

  testWidgets('right to left, the pages slide the other way', (tester) async {
    await _pump(tester, index: 1, value: 0.7, direction: TextDirection.rtl);

    expect(_barLeft(tester), closeTo(0, 0.001));
  });

  testWidgets('shows only while its page is the nearer one', (tester) async {
    await _pump(tester, index: 1, value: 0.4);
    expect(_barShown(tester), isFalse);

    await _pump(tester, index: 1, value: 0.6);
    expect(_barShown(tester), isTrue);
  });

  test('keeps the size of the bar it holds', () {
    const bar = PreferredSize(
      preferredSize: Size.fromHeight(98),
      child: SizedBox(),
    );
    const pinned = TabPinnedAppBar(
      animation: AlwaysStoppedAnimation<double>(0),
      index: 0,
      child: bar,
    );

    expect(pinned.preferredSize, bar.preferredSize);
  });
}
