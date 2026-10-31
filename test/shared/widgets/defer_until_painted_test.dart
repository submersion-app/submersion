import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/defer_until_painted.dart';

const _placeholderKey = Key('placeholder');
const _contentKey = Key('content');

// A getter, not a const: a rebuild of the page has to reach the state.
// ignore: prefer_const_constructors
Widget get _deferred => DeferUntilPainted(
  placeholder: const SizedBox(key: _placeholderKey, height: 100),
  child: const SizedBox(key: _contentKey, height: 100),
);

/// A 600px-tall page with [above] pixels of content over the deferred widget,
/// which is the last thing in a lazy list.
Widget _page({required double above, ScrollController? controller}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 600)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverList.list(
                children: [
                  SizedBox(height: above),
                  _deferred,
                  const SizedBox(height: 2000),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('paints the placeholder first, then swaps in the child', (
    tester,
  ) async {
    await tester.pumpWidget(_page(above: 0));

    expect(find.byKey(_placeholderKey), findsOneWidget);
    expect(find.byKey(_contentKey), findsNothing);

    await tester.pump();

    expect(find.byKey(_placeholderKey), findsNothing);
    expect(find.byKey(_contentKey), findsOneWidget);
  });

  testWidgets('a widget in the cache band waits until it is scrolled in', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    // 600px down is exactly the fold: laid out for the cache band, not painted.
    await tester.pumpWidget(_page(above: 600, controller: scroll));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_placeholderKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(_contentKey, skipOffstage: false), findsNothing);

    scroll.jumpTo(50);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_contentKey), findsOneWidget);
  });

  testWidgets('moving into view without any scrolling also reveals it', (
    tester,
  ) async {
    await tester.pumpWidget(_page(above: 600));
    await tester.pump();

    // Content above shrank, or the window grew: no scroll notification fires,
    // so a scroll listener would leave the placeholder up.
    await tester.pumpWidget(_page(above: 100));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_contentKey), findsOneWidget);
  });

  testWidgets('stays swapped across a rebuild', (tester) async {
    await tester.pumpWidget(_page(above: 0));
    await tester.pump();

    final element = tester.element(find.byKey(_contentKey));
    await tester.pumpWidget(_page(above: 0));
    await tester.pump();

    expect(tester.element(find.byKey(_contentKey)), same(element));
    expect(find.byKey(_placeholderKey), findsNothing);
  });
}
