import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_anchored_scroll_view.dart';

const _todayKey = ValueKey('today');

List<Widget> _slivers({double todayHeight = 100}) => [
  SliverList.builder(
    itemCount: 10,
    itemBuilder: (_, i) => SizedBox(height: 100, child: Text('Earlier $i')),
  ),
  SliverToBoxAdapter(
    key: _todayKey,
    child: SizedBox(height: todayHeight, child: const Text('Today')),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  Key? center,
  double todayHeight = 100,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: TodayAnchoredScrollView(
          center: center,
          slivers: _slivers(todayHeight: todayHeight),
        ),
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

  testWidgets('content after today that shrinks later is filled again', (
    tester,
  ) async {
    await _pump(tester, center: _todayKey, todayHeight: 100);
    await tester.pump();
    // The day's card loses its late-loading extras: less follows today.
    await _pump(tester, center: _todayKey, todayHeight: 40);
    await tester.pump();
    expect(tester.getRect(find.text('Today')).bottom, closeTo(600, 1));
  });
}
