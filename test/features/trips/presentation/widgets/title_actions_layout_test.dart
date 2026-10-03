import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/presentation/widgets/title_actions_layout.dart';

/// The trip Gear card's header layout (issue #2794).
void main() {
  const title = Key('title');
  const actions = Key('actions');

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TitleActionsLayout(
              title: const SizedBox(key: title, width: 100, height: 20),
              actions: const SizedBox(key: actions, width: 150, height: 40),
            ),
          ),
        ),
      ),
    );
  }

  RenderTitleActionsLayout renderOf(WidgetTester tester) =>
      tester.renderObject(find.byType(TitleActionsLayout));

  testWidgets(
    'one line when both fit: title at the start, actions at the end',
    (tester) async {
      await pump(tester, width: 300);
      expect(
        tester.getRect(find.byKey(title)),
        const Rect.fromLTWH(0, 10, 100, 20),
      );
      expect(
        tester.getRect(find.byKey(actions)),
        const Rect.fromLTWH(150, 0, 150, 40),
      );
      expect(
        tester.getSize(find.byType(TitleActionsLayout)),
        const Size(300, 40),
      );
    },
  );

  testWidgets('exactly the natural width still fits on one line', (
    tester,
  ) async {
    await pump(tester, width: 250);
    expect(
      tester.getSize(find.byType(TitleActionsLayout)),
      const Size(250, 40),
    );
  });

  testWidgets(
    'actions drop under the title, at the end, when they do not fit',
    (tester) async {
      await pump(tester, width: 249);
      expect(
        tester.getRect(find.byKey(title)),
        const Rect.fromLTWH(0, 0, 100, 20),
      );
      expect(
        tester.getRect(find.byKey(actions)),
        const Rect.fromLTWH(99, 20, 150, 40),
      );
      expect(
        tester.getSize(find.byType(TitleActionsLayout)),
        const Size(249, 60),
      );
    },
  );

  testWidgets('right to left mirrors both arrangements', (tester) async {
    await pump(tester, width: 300, direction: TextDirection.rtl);
    expect(tester.getRect(find.byKey(title)).left, 200);
    expect(tester.getRect(find.byKey(actions)).left, 0);

    await pump(tester, width: 200, direction: TextDirection.rtl);
    expect(tester.getRect(find.byKey(title)).left, 100);
    expect(
      tester.getRect(find.byKey(actions)),
      const Rect.fromLTWH(0, 20, 150, 40),
    );
  });

  testWidgets('switching the text direction lays it out again', (tester) async {
    await pump(tester, width: 300);
    final render = renderOf(tester);
    expect(tester.getRect(find.byKey(title)).left, 0);

    await pump(tester, width: 300, direction: TextDirection.rtl);
    expect(renderOf(tester), same(render));
    expect(tester.getRect(find.byKey(title)).left, 200);
    expect(tester.getRect(find.byKey(actions)).left, 0);
  });

  testWidgets('dry layout agrees with layout', (tester) async {
    await pump(tester, width: 300);
    final render = renderOf(tester);
    expect(
      render.getDryLayout(const BoxConstraints(maxWidth: 300)),
      const Size(300, 40),
    );
    expect(
      render.getDryLayout(const BoxConstraints(maxWidth: 200)),
      const Size(200, 60),
    );
  });

  testWidgets('intrinsic sizes follow the arrangement', (tester) async {
    await pump(tester, width: 300);
    final render = renderOf(tester);
    expect(render.getMinIntrinsicWidth(double.infinity), 150);
    expect(render.getMaxIntrinsicWidth(double.infinity), 250);
    expect(render.getMaxIntrinsicHeight(300), 40);
    expect(render.getMaxIntrinsicHeight(200), 60);
    expect(render.getMinIntrinsicHeight(200), 60);
  });

  testWidgets('an unbounded width lays both on one line', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: UnconstrainedBox(
            child: TitleActionsLayout(
              title: const SizedBox(key: title, width: 100, height: 20),
              actions: const SizedBox(key: actions, width: 150, height: 40),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TitleActionsLayout)),
      const Size(250, 40),
    );
  });

  testWidgets('taps reach the actions on either line', (tester) async {
    var taps = 0;
    for (final width in [300.0, 200.0]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TitleActionsLayout(
                title: const SizedBox(width: 100, height: 20),
                actions: GestureDetector(
                  key: actions,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 150, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(actions));
    }
    expect(taps, 2);
  });
}
