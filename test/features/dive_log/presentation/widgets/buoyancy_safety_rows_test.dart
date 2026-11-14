import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_safety_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'buoyancy_outcome_fixture.dart';

Future<void> _pump(
  WidgetTester tester,
  TwinOutputs outputs, {
  double? wing,
  double width = 800,
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuoyancySafetyRows(
          outputs: outputs,
          units: UnitFormatter(settings),
          wingLiftCapacityKg: wing,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _rowIcon(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Icon));

IconData _icon(WidgetTester tester, String key) =>
    tester.widget<Icon>(_rowIcon(key)).icon!;

void main() {
  group('peak lift', () {
    testWidgets('passes when it is within the wing', (tester) async {
      await _pump(
        tester,
        buoyancyOutcome(peakLiftDemandKg: 3.0).outputs,
        wing: 13.6,
      );
      expect(find.text('Peak lift needed'), findsOneWidget);
      expect(find.text('3.0 kg'), findsOneWidget);
      expect(find.text("within your wing's 13.6 kg"), findsOneWidget);
      expect(_icon(tester, 'safety-peak-lift'), Icons.check_circle_outline);
    });

    testWidgets('warns when it exceeds the wing', (tester) async {
      await _pump(
        tester,
        buoyancyOutcome(peakLiftDemandKg: 15.0).outputs,
        wing: 13.6,
      );
      expect(find.text("exceeds your wing's 13.6 kg"), findsOneWidget);
      expect(_icon(tester, 'safety-peak-lift'), Icons.warning_amber_rounded);
    });

    testWidgets('is neutral with no wing lift recorded', (tester) async {
      await _pump(tester, buoyancyOutcome(peakLiftDemandKg: 3.0).outputs);
      expect(find.text('3.0 kg'), findsOneWidget);
      expect(find.textContaining('your wing'), findsNothing);
      expect(_icon(tester, 'safety-peak-lift'), Icons.info_outline);
    });

    testWidgets('a non-positive wing lift counts as not recorded', (
      tester,
    ) async {
      await _pump(
        tester,
        buoyancyOutcome(peakLiftDemandKg: 3.0).outputs,
        wing: 0,
      );
      expect(find.textContaining('your wing'), findsNothing);
      expect(_icon(tester, 'safety-peak-lift'), Icons.info_outline);
    });
  });

  group('ditchable weight', () {
    testWidgets('passes when droppable lead covers it', (tester) async {
      await _pump(
        tester,
        buoyancyOutcome(minDitchableKg: 2.0, droppableLeadKg: 4.0).outputs,
      );
      expect(find.text('Min ditchable weight'), findsOneWidget);
      expect(find.text('2.0 kg'), findsOneWidget);
      expect(find.text('you can ditch 4.0 kg'), findsOneWidget);
      expect(_icon(tester, 'safety-ditchable'), Icons.check_circle_outline);
    });

    testWidgets('warns when it does not', (tester) async {
      await _pump(
        tester,
        buoyancyOutcome(minDitchableKg: 6.0, droppableLeadKg: 2.0).outputs,
      );
      expect(find.text('you can ditch only 2.0 kg'), findsOneWidget);
      expect(_icon(tester, 'safety-ditchable'), Icons.warning_amber_rounded);
    });
  });

  group('drysuit gas', () {
    testWidgets('is shown when there is any', (tester) async {
      await _pump(tester, buoyancyOutcome(drysuitGasLiters: 12).outputs);
      expect(find.text('Drysuit gas added'), findsOneWidget);
      expect(find.text('12 L'), findsOneWidget);
    });

    testWidgets('is absent for a wetsuit dive', (tester) async {
      await _pump(tester, buoyancyOutcome().outputs);
      expect(find.text('Drysuit gas added'), findsNothing);
    });
  });

  testWidgets('an imperial diver reads lb', (tester) async {
    await _pump(
      tester,
      buoyancyOutcome(peakLiftDemandKg: 3.0).outputs,
      wing: 13.6,
      settings: const AppSettings(weightUnit: WeightUnit.pounds),
    );
    expect(find.text('6.6 lbs'), findsOneWidget);
    expect(find.text("within your wing's 30.0 lbs"), findsOneWidget);
  });

  testWidgets('a narrow card does not overflow', (tester) async {
    await _pump(
      tester,
      buoyancyOutcome(
        peakLiftDemandKg: 15.0,
        minDitchableKg: 6.0,
        droppableLeadKg: 2.0,
        drysuitGasLiters: 12,
      ).outputs,
      wing: 13.6,
      width: 300,
    );
    expect(tester.takeException(), isNull);
  });
}
