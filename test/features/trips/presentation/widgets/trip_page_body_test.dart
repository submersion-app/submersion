import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/presentation/widgets/trip_page_body.dart';

/// A page kept alive in its TabBarView, as the trip page keeps its tabs
/// while unlocked.
class _Kept extends StatefulWidget {
  const _Kept({required this.label});

  final String label;

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      key: Key(widget.label),
      children: [
        for (var i = 0; i < 60; i++)
          SizedBox(height: 40, child: Text('${widget.label} $i')),
      ],
    );
  }
}

void main() {
  Future<void> pumpBody(WidgetTester tester, {required bool headerOpen}) =>
      tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              body: TripPageBody(
                above: const [],
                header: const SizedBox(height: 300, child: Text('header')),
                below: const Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'one'),
                        Tab(text: 'two'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _Kept(label: 'one'),
                          _Kept(label: 'two'),
                        ],
                      ),
                    ),
                  ],
                ),
                headerOpen: headerOpen,
              ),
            ),
          ),
        ),
      );

  ScrollPosition list(WidgetTester tester, String label) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(Key(label), skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
        ),
      )
      .position;

  testWidgets('with the editor closed, a drag on one tab leaves the other '
      'kept tab where it was', (tester) async {
    await pumpBody(tester, headerOpen: false);
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('one 0'), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(list(tester, 'one').pixels, greaterThan(0));
    expect(list(tester, 'two').pixels, 0);
  });

  testWidgets('opening and closing the editor over a scrolled kept tab '
      'builds without error', (tester) async {
    await pumpBody(tester, headerOpen: false);
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('one 0'), const Offset(0, -200));
    await tester.pumpAndSettle();

    await pumpBody(tester, headerOpen: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('header'), findsOneWidget);

    await pumpBody(tester, headerOpen: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
