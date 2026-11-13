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
        host(const TissueHeatMapCompartmentAxis(compartmentCount: 16)),
      );

      // Each row is 10 px tall; a label sits on its row's centre.
      expect(tester.getCenter(find.text('1')).dy, closeTo(5, 1));
      expect(tester.getCenter(find.text('8')).dy, closeTo(75, 1));
      expect(tester.getCenter(find.text('16')).dy, closeTo(155, 1));
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

    testWidgets('counts from the first sample, not from zero', (tester) async {
      await tester.pumpWidget(
        host(
          TissueHeatMapTimeAxis(timestamps: const [30, 90, 150]),
          height: 20,
        ),
      );

      expect(find.text('0 min'), findsOneWidget);
      expect(find.text('1 min'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
    });

    test('fits only a timeline with one time per sample', () {
      expect(TissueHeatMapTimeAxis.fits(null, 3), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0, 10], 3), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0], 1), isFalse);
      expect(TissueHeatMapTimeAxis.fits(const [0, 10, 20], 3), isTrue);
    });
  });
}
