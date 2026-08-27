import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_depth_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(SeascapeDepthLegend legend) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: legend),
);

void main() {
  testWidgets('shows the ramp ends in display units', (tester) async {
    await tester.pumpWidget(
      host(
        const SeascapeDepthLegend(
          maxDepthMeters: 40,
          hasLand: false,
          appearance: SeascapeAppearance(),
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
        ),
      ),
    );
    expect(find.text('0 m'), findsOneWidget);
    expect(find.text('40 m'), findsOneWidget);
    expect(find.text('Land'), findsNothing);
  });

  testWidgets('clamped custom range shows a plus cap', (tester) async {
    await tester.pumpWidget(
      host(
        const SeascapeDepthLegend(
          maxDepthMeters: 80,
          hasLand: true,
          appearance: SeascapeAppearance(rampMaxDepthMeters: 20),
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
        ),
      ),
    );
    expect(find.text('20+ m'), findsOneWidget);
    expect(find.text('Land'), findsOneWidget);
  });

  testWidgets('banded mode renders 10 discrete swatches', (tester) async {
    await tester.pumpWidget(
      host(
        const SeascapeDepthLegend(
          maxDepthMeters: 40,
          hasLand: false,
          appearance: SeascapeAppearance(rampBanded: true),
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('seascapeLegendBandedBar')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('seascapeLegendBandedBar')),
        matching: find.byType(ColoredBox),
      ),
      findsNWidgets(10),
    );
  });

  testWidgets('feet diver reads feet', (tester) async {
    await tester.pumpWidget(
      host(
        const SeascapeDepthLegend(
          maxDepthMeters: 30.48,
          hasLand: false,
          appearance: SeascapeAppearance(),
          displayUnitInMeters: 0.3048,
          depthSymbol: 'ft',
        ),
      ),
    );
    expect(find.text('100 ft'), findsOneWidget);
  });
}
