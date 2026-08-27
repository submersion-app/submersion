import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<BuildContext> _pump(
  WidgetTester tester, {
  required List<int> selected,
  required ValueChanged<List<int>> onChanged,
  Locale locale = const Locale('en'),
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return WeekdayFilterSelector(
              selectedWeekdays: selected,
              onChanged: onChanged,
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return capturedContext;
}

void main() {
  testWidgets('renders all seven weekdays as chips', (tester) async {
    await _pump(tester, selected: const [], onChanged: (_) {});

    expect(find.byType(FilterChip), findsNWidgets(7));
  });

  testWidgets('orders chips starting from the locale week start', (
    tester,
  ) async {
    final context = await _pump(tester, selected: const [], onChanged: (_) {});

    final materialLocalizations = MaterialLocalizations.of(context);
    final firstWeekday = materialLocalizations.firstDayOfWeekIndex == 0
        ? 7
        : materialLocalizations.firstDayOfWeekIndex;
    final expectedFirstLabel = weekdayAbbreviation(context, firstWeekday);

    final firstChip = tester.widget<FilterChip>(find.byType(FilterChip).first);
    final labelText = (firstChip.label as Text).data;

    expect(labelText, expectedFirstLabel);
  });

  testWidgets('a Monday-first locale starts the row on Monday', (tester) async {
    // The default `en` (en_US) locale is Sunday-first, so it only ever
    // exercises one branch of the week-start conversion. German is
    // Monday-first, which is the other branch.
    final context = await _pump(
      tester,
      selected: const [],
      onChanged: (_) {},
      locale: const Locale('de'),
    );

    // Guards the premise of this test rather than the widget: if the bundled
    // German data ever changed its week start, the assertion below would pass
    // for the wrong reason.
    expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 1);

    final firstChip = tester.widget<FilterChip>(find.byType(FilterChip).first);
    expect(
      (firstChip.label as Text).data,
      weekdayAbbreviation(context, DateTime.monday),
    );
  });

  testWidgets('marks selected weekdays as selected chips', (tester) async {
    await _pump(tester, selected: const [1], onChanged: (_) {});

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    final selectedCount = chips.where((c) => c.selected).length;

    expect(selectedCount, 1);
  });

  testWidgets('tapping an unselected chip adds its weekday', (tester) async {
    List<int>? result;
    await _pump(
      tester,
      selected: const [],
      onChanged: (weekdays) => result = weekdays,
    );

    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();

    expect(result, hasLength(1));
  });

  testWidgets('tapping a selected chip removes its weekday', (tester) async {
    List<int>? result;
    await _pump(
      tester,
      selected: const [1, 2, 3, 4, 5, 6, 7],
      onChanged: (weekdays) => result = weekdays,
    );

    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();

    expect(result, hasLength(6));
  });
}
