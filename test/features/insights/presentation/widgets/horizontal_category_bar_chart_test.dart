import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The horizontal bar chart (issue #1765).
Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

void main() {
  testWidgets('one row per category with bars proportional to the largest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const HorizontalCategoryBarChart(
          data: [(label: 'Wreck', count: 10), (label: 'Lake', count: 5)],
        ),
      ),
    );

    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Lake'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    final factors = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.widthFactor)
        .toList();
    expect(factors, [1.0, 0.5]);
  });

  testWidgets('rows keep the order they are given', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HorizontalCategoryBarChart(
          data: [(label: 'A', count: 1), (label: 'B', count: 3)],
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('A')).dy,
      lessThan(tester.getTopLeft(find.text('B')).dy),
    );
  });

  // Issue #3048: the Gas page now uses this chart, so a right-to-left
  // locale must fill each bar from the label's side, not the left edge.
  testWidgets('bars grow from the start edge in right-to-left text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: HorizontalCategoryBarChart(
            data: [(label: 'A', count: 4), (label: 'B', count: 1)],
          ),
        ),
      ),
    );

    final track = find.byType(FractionallySizedBox).last;
    final fill = find.descendant(of: track, matching: find.byType(Container));
    expect(
      tester.getTopRight(fill).dx,
      moreOrLessEquals(tester.getTopRight(track).dx),
    );
  });

  testWidgets('empty data shows the shared empty state', (tester) async {
    await tester.pumpWidget(_wrap(const HorizontalCategoryBarChart(data: [])));

    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
