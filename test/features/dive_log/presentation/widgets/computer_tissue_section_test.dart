import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/presentation/widgets/computer_tissue_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget buildSection({
  ComputerTissueSnapshot? snapshot,
  double? calculatedGf99Percent,
  double? calculatedSurfaceGfPercent,
  double? calculatedCnsPercent,
  PressureUnit pressureUnit = PressureUnit.bar,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => MockSettingsNotifier(AppSettings(pressureUnit: pressureUnit)),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ComputerTissueSection(
            snapshot: snapshot,
            calculatedGf99Percent: calculatedGf99Percent,
            calculatedSurfaceGfPercent: calculatedSurfaceGfPercent,
            calculatedCnsPercent: calculatedCnsPercent,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing without a snapshot', (tester) async {
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(find.text('Dive computer'), findsNothing);
    expect(find.byType(ComputerTissueLoadBar), findsNothing);
  });

  testWidgets('renders a bar per compartment for loadPercent', (tester) async {
    const snapshot = ComputerTissueSnapshot(
      algorithm: 'RGBM',
      end: ComputerTissueState(loadPercent: [40.0, 65.5, 100.0]),
    );
    await tester.pumpWidget(buildSection(snapshot: snapshot));
    await tester.pumpAndSettle();

    expect(find.text('Dive computer'), findsOneWidget);
    expect(find.text('RGBM'), findsOneWidget);
    expect(find.text('3 RGBM compartments'), findsOneWidget);
    expect(find.byType(ComputerTissueLoadBar), findsNWidgets(3));
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('66%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('renders tensions in bar when that is the active unit', (
    tester,
  ) async {
    const snapshot = ComputerTissueSnapshot(
      end: ComputerTissueState(n2Bar: [1.25, 0.9], heBar: [0.1, 0.0]),
    );
    await tester.pumpWidget(buildSection(snapshot: snapshot));
    await tester.pumpAndSettle();

    expect(find.text('2 compartments'), findsOneWidget);
    expect(find.text('1.25 bar'), findsOneWidget);
    expect(find.text('0.90 bar'), findsOneWidget);
    expect(find.text('0.10 bar'), findsOneWidget);
    expect(find.text('0.00 bar'), findsOneWidget);
    expect(find.byType(ComputerTissueLoadBar), findsNothing);
  });

  testWidgets('renders tensions in psi when that is the active unit', (
    tester,
  ) async {
    const snapshot = ComputerTissueSnapshot(
      end: ComputerTissueState(n2Bar: [1.0]),
    );
    await tester.pumpWidget(
      buildSection(snapshot: snapshot, pressureUnit: PressureUnit.psi),
    );
    await tester.pumpAndSettle();

    // 1 bar is 14.5 psi.
    expect(find.text('14.5 psi'), findsOneWidget);
    expect(find.textContaining('bar'), findsNothing);
  });

  testWidgets('renders the start/end aggregate table with calculated lines', (
    tester,
  ) async {
    const snapshot = ComputerTissueSnapshot(
      start: ComputerTissueState(n2LoadPercent: 12, gf99Percent: 0),
      end: ComputerTissueState(
        n2LoadPercent: 58,
        gf99Percent: 45,
        surfaceGfPercent: 72,
        cnsPercent: 8,
        otu: 21.4,
        rgbmNitrogen: 0.95,
        rgbmHelium: 1.02,
      ),
    );
    await tester.pumpWidget(
      buildSection(
        snapshot: snapshot,
        calculatedGf99Percent: 41.2,
        calculatedSurfaceGfPercent: 69.7,
        calculatedCnsPercent: 7.4,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.text('N₂ load'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);
    expect(find.text('GF99'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('SurfGF'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('CNS'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('OTU'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    // Missing start values are shown as a dash, not omitted.
    expect(find.text('--'), findsNWidgets(3));
    // Calculated values sit under the computer's as a secondary line.
    expect(find.text('calculated 41%'), findsOneWidget);
    expect(find.text('calculated 70%'), findsOneWidget);
    expect(find.text('calculated 7%'), findsOneWidget);
    expect(find.text('RGBM N₂ factor'), findsOneWidget);
    expect(find.text('0.95'), findsOneWidget);
    expect(find.text('RGBM He factor'), findsOneWidget);
    expect(find.text('1.02'), findsOneWidget);
  });

  testWidgets('omits the calculated line when there is nothing to compare', (
    tester,
  ) async {
    const snapshot = ComputerTissueSnapshot(
      end: ComputerTissueState(gf99Percent: 45),
    );
    await tester.pumpWidget(buildSection(snapshot: snapshot));
    await tester.pumpAndSettle();

    expect(find.text('45%'), findsOneWidget);
    expect(find.textContaining('calculated'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
  });
}
