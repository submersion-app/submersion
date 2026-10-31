import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3805: a touch on a bar or slice shows its number first, and
/// View dives opens it, so reading a chart never leaves the page.
void main() {
  Future<void> pump(WidgetTester tester, Widget chart) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: chart)),
      ),
    );
    await tester.pumpAndSettle();
  }

  const week = [
    (label: 'Mon', count: 1),
    (label: 'Tue', count: 300),
    (label: 'Wed', count: 0),
  ];

  Offset columnTop(WidgetTester tester, int index, int bars) {
    final chart = tester.getRect(find.byType(BarChart));
    const leftAxis = 44.0;
    final column = (chart.width - leftAxis) / bars;
    return Offset(
      chart.left + leftAxis + column * (index + 0.5),
      chart.top + 12,
    );
  }

  group('bars', () {
    testWidgets('a tap marks a bar and shows its number and View dives', (
      tester,
    ) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));

      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();

      expect(find.text('Tue · 300 dives'), findsOneWidget);
      expect(find.text('View dives'), findsOneWidget);
    });

    testWidgets('a tap on the empty space above a short bar marks it', (
      tester,
    ) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));

      await tester.tapAt(columnTop(tester, 0, 3));
      await tester.pumpAndSettle();

      expect(find.text('Mon · 1 dive'), findsOneWidget);
    });

    testWidgets('tapping the marked bar clears it', (tester) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));

      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();
      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tue'), findsOneWidget);
      expect(find.text('View dives'), findsNothing);
    });

    testWidgets('tapping another bar moves the mark', (tester) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));

      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();
      await tester.tapAt(columnTop(tester, 0, 3));
      await tester.pumpAndSettle();

      expect(find.text('Mon · 1 dive'), findsOneWidget);
      expect(find.text('Tue · 300 dives'), findsNothing);
    });

    testWidgets('View dives opens the marked bar', (tester) async {
      int? opened;
      await pump(
        tester,
        CategoryBarChart(data: week, onOpenBar: (i) async => opened = i),
      );

      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View dives'));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('a bar with no dives shows its number and no View dives', (
      tester,
    ) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));

      await tester.tapAt(columnTop(tester, 2, 3));
      await tester.pumpAndSettle();

      expect(find.text('Wed · 0 dives'), findsOneWidget);
      expect(find.text('View dives'), findsNothing);
    });

    testWidgets('new data clears the mark', (tester) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));
      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();

      await pump(
        tester,
        CategoryBarChart(
          data: const [
            (label: 'Mon', count: 2),
            (label: 'Tue', count: 300),
            (label: 'Wed', count: 0),
          ],
          onOpenBar: (_) async {},
        ),
      );

      expect(find.text('View dives'), findsNothing);
    });

    testWidgets('data shorter than the marked index clears the mark', (
      tester,
    ) async {
      await pump(tester, CategoryBarChart(data: week, onOpenBar: (_) async {}));
      await tester.tapAt(columnTop(tester, 2, 3));
      await tester.pumpAndSettle();

      await pump(
        tester,
        CategoryBarChart(
          data: const [(label: 'Mon', count: 2)],
          onOpenBar: (_) async {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('with no callback a tap shows no strip', (tester) async {
      await pump(tester, const CategoryBarChart(data: week));

      await tester.tapAt(columnTop(tester, 1, 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('a screen reader can open a non-zero bar', (tester) async {
      int? opened;
      await pump(
        tester,
        CategoryBarChart(data: week, onOpenBar: (i) async => opened = i),
      );

      final actions = tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.customSemanticsActions != null,
            ),
          )
          .properties
          .customSemanticsActions!;

      expect(actions.keys.map((a) => a.label), [
        'View dives: Mon',
        'View dives: Tue',
      ]);
      actions.values.last();
      expect(opened, 1);
    });
  });

  group('pie', () {
    final segments = [
      DistributionSegment(label: 'Salt', count: 60, percentage: 60),
      DistributionSegment(label: 'Fresh', count: 40, percentage: 40),
    ];

    Offset sliceAt(WidgetTester tester) {
      final pie = tester.getRect(find.byType(PieChart));
      // Sections start at three o'clock, so this lands in the first one.
      return pie.center + const Offset(50, 30);
    }

    testWidgets('a tap on a slice marks it and View dives opens it', (
      tester,
    ) async {
      int? opened;
      await pump(
        tester,
        DistributionPieChart(
          data: segments,
          onOpenSegment: (i) async => opened = i,
        ),
      );

      await tester.tapAt(sliceAt(tester));
      await tester.pumpAndSettle();

      expect(find.text('Salt · 60 dives'), findsOneWidget);
      expect(opened, isNull);

      await tester.tap(find.text('View dives'));
      await tester.pumpAndSettle();

      expect(opened, 0);
    });

    testWidgets('a legend row opens in one tap and has a chevron', (
      tester,
    ) async {
      int? opened;
      await pump(
        tester,
        DistributionPieChart(
          data: segments,
          onOpenSegment: (i) async => opened = i,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      await tester.tap(find.text('Fresh'));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('with no callback a legend row has no chevron', (tester) async {
      await pump(tester, DistributionPieChart(data: segments));

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });
}
