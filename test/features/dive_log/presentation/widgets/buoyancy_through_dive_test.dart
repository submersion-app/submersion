import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_through_dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'buoyancy_outcome_fixture.dart';

// The fixture's rig: 5 kg of body, 6 kg of lead.
TwinSample _s(int t, double depth, double suit, double tanks) => TwinSample(
  timestamp: t,
  depthM: depth,
  suitKg: suit,
  tanksKg: tanks,
  netKg: suit + tanks + 5.0 - 6.0,
);

final _dive = [
  _s(0, 0, 3.9, -2.0),
  _s(60, 2, 3.6, -1.9),
  _s(120, 18, 1.5, -1.6),
  _s(180, 5, 3.0, -1.0),
];

const _stop = TwinAnchor(
  kind: TwinAnchorKind.detectedStop,
  timestamp: 180,
  depthM: 5,
);

const _tank = TwinTankInput(
  id: 't1',
  label: 'tank',
  volumeL: 12.0,
  workingPressureBar: 200.0,
);

BuoyancyTwinOutcome _outcome({
  double verdictNet = 1.8,
  List<TwinSample>? samples,
  TwinAnchor anchor = _stop,
  TwinSuitKind suitKind = TwinSuitKind.wetsuit,
  List<TwinTankInput> tanks = const [_tank],
}) => buoyancyOutcome(
  verdictNet: verdictNet,
  samples: samples ?? _dive,
  anchor: anchor,
  suitKind: suitKind,
  tanks: tanks,
);

Future<void> _pump(
  WidgetTester tester,
  BuoyancyTwinOutcome outcome, {
  int? cursorSeconds,
  ValueChanged<int?>? onCursorSeconds,
  AppSettings settings = const AppSettings(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BuoyancyThroughDive(
            outcome: outcome,
            units: UnitFormatter(settings),
            cursorSeconds: cursorSeconds,
            onCursorSeconds: onCursorSeconds,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BuoyancyChart _chart(WidgetTester tester) =>
    tester.widget<BuoyancyChart>(find.byType(BuoyancyChart));

void main() {
  group('readout at rest', () {
    testWidgets('is the verdict net at the final stop', (tester) async {
      await _pump(tester, _outcome());
      expect(find.text('1.8 kg buoyant'), findsOneWidget);
      expect(find.text('at your final stop, about 5m'), findsOneWidget);
    });

    testWidgets('a negative net reads heavy', (tester) async {
      await _pump(tester, _outcome(verdictNet: -1.2));
      expect(find.text('1.2 kg heavy'), findsOneWidget);
    });

    testWidgets('within half a kilo reads close to neutral', (tester) async {
      await _pump(tester, _outcome(verdictNet: -0.3));
      expect(find.text('Close to neutral'), findsOneWidget);
      expect(find.textContaining('heavy'), findsNothing);
    });

    testWidgets('a dive with no profile reads the convention', (tester) async {
      await _pump(
        tester,
        _outcome(
          samples: const [],
          anchor: const TwinAnchor(
            kind: TwinAnchorKind.convention,
            timestamp: -1,
            depthM: 5,
          ),
        ),
      );
      expect(
        find.text('estimated at the 5m safety-stop convention'),
        findsOneWidget,
      );
    });
  });

  group('following a cursor', () {
    testWidgets('the readout and the bar show that sample', (tester) async {
      await _pump(
        tester,
        _outcome(),
        cursorSeconds: 120,
        onCursorSeconds: (_) {},
      );
      // suit 1.5 + tanks -1.6 + body 5 - lead 6
      expect(find.text('1.1 kg heavy'), findsOneWidget);
      expect(find.text('at 18m, 2:00'), findsOneWidget);
      expect(find.byTooltip('Suit 1.5 kg'), findsOneWidget);
      expect(find.byTooltip('Cylinders 1.6 kg'), findsOneWidget);
    });

    testWidgets('the cursor snaps to the nearest plottable sample', (
      tester,
    ) async {
      final samples = [
        _dive[0],
        const TwinSample(
          timestamp: 60,
          depthM: 2,
          suitKg: 3.6,
          tanksKg: -1.9,
          netKg: double.nan,
        ),
        _dive[2],
        _dive[3],
      ];
      // 70 s is nearest the dropped 60 s sample; of the plotted ones, 120 s.
      await _pump(
        tester,
        _outcome(samples: samples),
        cursorSeconds: 70,
        onCursorSeconds: (_) {},
      );
      expect(find.text('at 18m, 2:00'), findsOneWidget);
    });

    testWidgets('without a host callback a chart touch moves the readout', (
      tester,
    ) async {
      await _pump(tester, _outcome());
      _chart(tester).onCursorSeconds!(120);
      await tester.pump();
      expect(find.text('at 18m, 2:00'), findsOneWidget);
      expect(_chart(tester).cursorSeconds, 120);

      _chart(tester).onCursorSeconds!(null);
      await tester.pump();
      expect(find.text('at your final stop, about 5m'), findsOneWidget);
    });

    testWidgets('with a host callback touches go to the host', (tester) async {
      final reported = <int?>[];
      await _pump(tester, _outcome(), onCursorSeconds: reported.add);
      _chart(tester).onCursorSeconds!(120);
      await tester.pump();
      expect(reported, [120]);
      // The host did not move the cursor, so the readout stays at rest.
      expect(find.text('at your final stop, about 5m'), findsOneWidget);
    });
  });

  group('chart', () {
    testWidgets('marks start, deepest and final stop, resting on the stop', (
      tester,
    ) async {
      await _pump(tester, _outcome());
      final chart = _chart(tester);
      expect(chart.markers.map((m) => m.label), [
        'Start',
        'Deepest',
        'Final stop',
      ]);
      expect(chart.markers.map((m) => m.seconds), [60, 120, 180]);
      expect(chart.markers.map((m) => m.optional), [false, true, false]);
      expect(chart.restSeconds, 180);
    });

    testWidgets('fewer than two samples: no chart, readout and bar remain', (
      tester,
    ) async {
      await _pump(tester, _outcome(samples: [_dive[3]]));
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('1.8 kg buoyant'), findsOneWidget);
      expect(find.byType(BuoyancyBalanceBar), findsOneWidget);
    });
  });

  group('cause notes', () {
    testWidgets('name the suit squeeze and the gas breathed', (tester) async {
      await _pump(tester, _outcome());
      // Suit: 3.6 at the start of the dive, 1.5 at 18 m.
      expect(
        find.text('Suit squeeze cost 2.1 kg of lift at 18m'),
        findsOneWidget,
      );
      // Tanks: -2.0 at the first sample, -1.0 at the last.
      expect(
        find.text('Gas breathed left the tanks 1.0 kg lighter'),
        findsOneWidget,
      );
    });

    testWidgets('no suit note for a drysuit', (tester) async {
      await _pump(tester, _outcome(suitKind: TwinSuitKind.drysuit));
      expect(find.textContaining('Suit squeeze'), findsNothing);
      expect(find.textContaining('Gas breathed'), findsOneWidget);
    });

    testWidgets('no gas note without tanks', (tester) async {
      await _pump(tester, _outcome(tanks: const []));
      expect(find.textContaining('Gas breathed'), findsNothing);
    });
  });

  testWidgets('an imperial diver reads lb and ft throughout', (tester) async {
    await _pump(
      tester,
      _outcome(),
      settings: const AppSettings(
        weightUnit: WeightUnit.pounds,
        depthUnit: DepthUnit.feet,
      ),
    );
    expect(find.text('4.0 lbs buoyant'), findsOneWidget);
    expect(find.text('at your final stop, about 16ft'), findsOneWidget);
    expect(
      find.text('Suit squeeze cost 4.6 lbs of lift at 59ft'),
      findsOneWidget,
    );
    expect(
      find.text('Gas breathed left the tanks 2.2 lbs lighter'),
      findsOneWidget,
    );
    expect(find.textContaining(' kg'), findsNothing);
  });

  testWidgets('a narrow card does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      _outcome(),
      cursorSeconds: 120,
      onCursorSeconds: (_) {},
    );
    expect(tester.takeException(), isNull);
  });
}
