import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_date_group.dart';

import 'group_test_host.dart';

void main() {
  Future<GroupHarness> pump(WidgetTester tester, [DiveFilterState? f]) =>
      pumpGroup(
        tester,
        (d, on) => RefineDateGroup(draft: d, onChanged: on),
        initial: f ?? const DiveFilterState(),
      );

  testWidgets('presets write their range; All time clears', (tester) async {
    final h = await pump(tester);
    final now = DateTime.now();
    await tester.tap(find.text('This year'));
    await tester.pump();
    expect(h.draft.startDate, DateTime(now.year, 1, 1));
    expect(h.draft.endDate, DateTime(now.year, now.month, now.day));
    await tester.tap(find.text('Last year'));
    await tester.pump();
    expect(h.draft.startDate, DateTime(now.year - 1, 1, 1));
    expect(h.draft.endDate, DateTime(now.year - 1, 12, 31));
    await tester.tap(find.text('Last 5 years'));
    await tester.pump();
    expect(h.draft.startDate, DateTime(now.year - 5, now.month, now.day));
    await tester.tap(find.text('All time'));
    await tester.pump();
    expect(h.draft.startDate, isNull);
    expect(h.draft.endDate, isNull);
  });

  testWidgets('Clear dates clears both bounds', (tester) async {
    final h = await pump(
      tester,
      DiveFilterState(startDate: DateTime(2024), endDate: DateTime(2025)),
    );
    await tester.tap(find.text('Clear dates'));
    await tester.pump();
    expect(h.draft.startDate, isNull);
    expect(h.draft.endDate, isNull);
  });

  testWidgets('the pickers write the range', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.text('Start Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(h.draft.startDate, isNotNull);
    expect(h.draft.endDate, isNotNull);
  });

  testWidgets('weekdays toggle and clear', (tester) async {
    final h = await pump(tester, const DiveFilterState(weekdays: [6]));
    await tester.tap(find.text('Clear weekdays'));
    await tester.pump();
    expect(h.draft.weekdays, isEmpty);
  });

  test('declares its fields and counts its axes', () {
    expect(RefineDateGroup.fields, {'startDate', 'endDate', 'weekdays'});
    expect(RefineDateGroup.activeCount(const DiveFilterState()), 0);
    expect(
      RefineDateGroup.activeCount(
        DiveFilterState(startDate: DateTime(2025), weekdays: const [1]),
      ),
      2,
    );
  });

  testWidgets('a weekday chip adds its day', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.text('Sat'));
    await tester.pump();
    expect(h.draft.weekdays, [6]);
  });
}
