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

  // Issue #3421: shares of a whole draw against the whole, so a bar's
  // length matches its printed percentage.
  testWidgets('a scale draws bars against it instead of the largest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const HorizontalCategoryBarChart(
          data: [(label: 'Stage', count: 2)],
          scaleTo: 200,
        ),
      ),
    );

    final factor = tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor;
    expect(factor, 0.01);
  });

  testWidgets('a count above the scale draws a full bar, not past it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const HorizontalCategoryBarChart(
          data: [(label: 'Stage', count: 12)],
          scaleTo: 10,
        ),
      ),
    );

    final factor = tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor;
    expect(factor, 1.0);
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

  group('tappable rows (#3804)', () {
    const rows = [(label: 'Sidemount', count: 6), (label: 'Other', count: 4)];

    testWidgets('a chart with no callback has no tap targets', (tester) async {
      await tester.pumpWidget(
        _wrap(const HorizontalCategoryBarChart(data: rows)),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a row reports its index, wherever it is tapped', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _wrap(HorizontalCategoryBarChart(data: rows, onRowTap: tapped.add)),
      );

      final second = tester.getRect(find.byType(InkWell).last);
      await tester.tapAt(second.centerRight - const Offset(4, 0));
      await tester.tapAt(second.centerLeft + const Offset(4, 0));
      await tester.tap(find.text('Sidemount'));

      expect(tapped, [1, 1, 0]);
    });

    testWidgets('a row meets the minimum touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(HorizontalCategoryBarChart(data: rows, onRowTap: (_) {})),
      );

      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    });

    testWidgets('a row is a button carrying its label and count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HorizontalCategoryBarChart(
            data: rows,
            formatCount: (n) => '$n dives',
            countWidth: 72,
            onRowTap: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(InkWell).first),
        matchesSemantics(
          label: 'Sidemount, 6 dives',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('in Arabic at double text size a row fits and takes the tap', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery.withClampedTextScaling(
              minScaleFactor: 2,
              maxScaleFactor: 2,
              child: SizedBox(
                width: 300,
                child: HorizontalCategoryBarChart(
                  data: const [(label: 'أسطوانة خلفية مفردة', count: 131)],
                  formatCount: (n) => '$n · ٦٢٪',
                  countWidth: 72,
                  onRowTap: tapped.add,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(InkWell));
      await tester.tapAt(row.centerLeft + const Offset(4, 0));
      await tester.tapAt(row.centerRight - const Offset(4, 0));
      expect(tapped, [0, 0]);
    });
  });
}
