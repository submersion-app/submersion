import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map_axes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4503: the heat map names its rows and its timeline.
void main() {
  Widget host(Widget child, {double width = 300, double height = 160}) =>
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );

  group('TissueHeatMapCompartmentAxis', () {
    testWidgets('places 1, 8 and 16 on their rows', (tester) async {
      await tester.pumpWidget(
        host(
          const TissueHeatMapCompartmentAxis(compartmentCount: 16),
          height: 320,
        ),
      );

      // Each row is 20 px tall, taller than a label, so each label sits on
      // its row's centre.
      expect(tester.getCenter(find.text('1')).dy, closeTo(10, 1));
      expect(tester.getCenter(find.text('8')).dy, closeTo(150, 1));
      expect(tester.getCenter(find.text('16')).dy, closeTo(310, 1));
    });

    testWidgets('lays out inside an IntrinsicHeight, as the detail page '
        'pairs cards', (tester) async {
      await tester.pumpWidget(
        host(
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TissueHeatMapCompartmentAxis(compartmentCount: 16),
                SizedBox(width: 100, height: 72),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('16'), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('keeps every label inside a 72 px axis at ${scale}x text, '
          'clear of the legend above', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: host(
              const TissueHeatMapCompartmentAxis(compartmentCount: 16),
              width: TissueHeatMapCompartmentAxis.width,
              height: 72,
            ),
          ),
        );

        final axis = tester.getRect(find.byType(TissueHeatMapCompartmentAxis));
        for (final label in ['1', '8', '16']) {
          final rect = tester.getRect(find.text(label));
          expect(
            rect.top,
            greaterThanOrEqualTo(axis.top - 0.01),
            reason: label,
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(axis.bottom + 0.01),
            reason: label,
          );
          expect(
            rect.left,
            greaterThanOrEqualTo(axis.left - 0.01),
            reason: label,
          );
        }
        // And clear of each other.
        final one = tester.getRect(find.text('1'));
        final eight = tester.getRect(find.text('8'));
        final sixteen = tester.getRect(find.text('16'));
        expect(one.bottom, lessThanOrEqualTo(eight.top));
        expect(eight.bottom, lessThanOrEqualTo(sixteen.top));
      });
    }

    testWidgets('labels nothing for a model with no compartments', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const TissueHeatMapCompartmentAxis(compartmentCount: 0)),
      );

      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('names only the first row of a one-compartment model', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const TissueHeatMapCompartmentAxis(compartmentCount: 1)),
      );

      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TissueHeatMapTimeAxis', () {
    final timestamps = [for (var t = 0; t <= 1920; t += 60) t];

    testWidgets('reads start, middle and end in minutes', (tester) async {
      await tester.pumpWidget(
        host(TissueHeatMapTimeAxis(timestamps: timestamps), height: 20),
      );

      final start = tester.getRect(find.text('0 min'));
      final middle = tester.getRect(find.text('16 min'));
      final end = tester.getRect(find.text('32 min'));
      expect(start.left, closeTo(0, 1));
      expect(middle.center.dx, closeTo(150, 1));
      expect(end.right, closeTo(300, 1));
    });

    testWidgets('reads the profile chart\'s own clock, before zero too', (
      tester,
    ) async {
      // A secondary computer switched on three minutes before the merged
      // dive's zero point: the chart and the cursor time read -3:00.
      await tester.pumpWidget(
        host(
          const TissueHeatMapTimeAxis(timestamps: [-180, 1500, 3120]),
          height: 20,
        ),
      );

      expect(find.text('-3 min'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('52 min'), findsOneWidget);
    });

    testWidgets('drops part minutes the way the cursor time does', (
      tester,
    ) async {
      // 52:40 reads "52 min", as hovering it reads "at 52:40".
      await tester.pumpWidget(
        host(
          const TissueHeatMapTimeAxis(timestamps: [0, 90, 3160]),
          height: 20,
        ),
      );

      expect(find.text('1 min'), findsOneWidget);
      expect(find.text('52 min'), findsOneWidget);
    });

    testWidgets('keeps its three labels apart at large text', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: host(
            const TissueHeatMapTimeAxis(timestamps: [-180, 3720, 7500]),
            height: 60,
          ),
        ),
      );

      final start = tester.getRect(find.text('-3 min'));
      final middle = tester.getRect(find.text('62 min'));
      final end = tester.getRect(find.text('125 min'));
      expect(start.left, greaterThanOrEqualTo(-0.01));
      expect(start.right, lessThanOrEqualTo(middle.left));
      expect(middle.right, lessThanOrEqualTo(end.left));
      expect(end.right, lessThanOrEqualTo(300.01));
    });

    for (final (name, stamps, expected) in [
      ('a two-sample profile', [0, 60], ['0 min', '1 min']),
      ('a dive under a minute', [0, 20, 40], ['0 min']),
      ('a two-minute dive', [0, 60, 90], ['0 min', '1 min']),
    ]) {
      testWidgets('names each time once on $name', (tester) async {
        await tester.pumpWidget(
          host(TissueHeatMapTimeAxis(timestamps: stamps), height: 20),
        );

        final shown = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .toList();
        expect(shown, expected);
      });
    }

    test('keeps a time before zero negative, under a minute too', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      // The minute a sample falls in: -0:30 is in minute -1, 52:40 in 52.
      expect(TissueHeatMapTimeAxis.timeLabel(l10n, -30), '-1 min');
      expect(TissueHeatMapTimeAxis.timeLabel(l10n, -170), '-3 min');
      expect(TissueHeatMapTimeAxis.timeLabel(l10n, 0), '0 min');
      expect(TissueHeatMapTimeAxis.timeLabel(l10n, 3160), '52 min');
    });

    test('fits only a timeline with one time per sample', () {
      expect(TissueHeatMapTimeAxis.fits(null, 3), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0, 10], 3), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0], 1), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0, 10, 20], 3), isTrue);
    });
  });

  group('tissueHeatMapSemantics', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names the time span the strip covers', () {
      expect(
        tissueHeatMapSemantics(
          l10n,
          compartmentCount: 16,
          timestamps: const [0, 960, 1920],
        ),
        'Heat map of compartments 1 to 16, fast at the top and slow at the '
        'bottom, from 0 min to 32 min of the dive',
      );
    });

    test('says no span when the dive starts and ends in the same minute', () {
      expect(
        tissueHeatMapSemantics(
          l10n,
          compartmentCount: 16,
          timestamps: const [0, 25, 50],
        ),
        'Heat map of compartments 1 to 16, fast at the top and slow at the '
        'bottom',
      );
    });
  });
}
