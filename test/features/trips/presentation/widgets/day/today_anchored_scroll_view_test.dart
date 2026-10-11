import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_anchored_scroll_view.dart';

const _todayKey = ValueKey('today');

List<Widget> _slivers() => [
  SliverList.builder(
    itemCount: 10,
    itemBuilder: (_, i) => SizedBox(height: 100, child: Text('Earlier $i')),
  ),
  const SliverToBoxAdapter(
    key: _todayKey,
    child: SizedBox(height: 100, child: Text('Today')),
  ),
];

Future<void> _pump(WidgetTester tester, {Key? center}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: TodayAnchoredScrollView(center: center, slivers: _slivers()),
      ),
    ),
  ),
);

void main() {
  testWidgets('with little after today, the window ends at today', (
    tester,
  ) async {
    await _pump(tester, center: _todayKey);
    await tester.pump();
    final today = tester.getRect(find.text('Today'));
    expect(today.bottom, closeTo(600, 1));
  });

  testWidgets('an anchor that arrives later gets the same fill', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, center: _todayKey);
    await tester.pump();
    expect(tester.getRect(find.text('Today')).bottom, closeTo(600, 1));
  });
}
