import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _profile = List.generate(
  61,
  (i) => DiveProfilePoint(
    timestamp: i * 10,
    depth: 10.0 + i % 5,
    temperature: 20.0 + i % 3,
  ),
);

/// A 10 m flat profile, so the ambient pressure over any range is 2 bar.
final _flatProfile = List.generate(
  61,
  (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
);

/// 200 -> 100 bar over the 600 s dive, sampled every 30 s. The panel's
/// default range (the middle half, 150 s to 450 s) sees 175 -> 125 bar.
final _backGasPressures = {
  'bg': [
    for (var t = 0; t <= 600; t += 30)
      TankPressurePoint(tankId: 'bg', timestamp: t, pressure: 200 - t / 6),
  ],
};

Future<void> _pumpPanel(
  WidgetTester tester, {
  required double width,
  int? maxColumns,
  List<DiveProfilePoint>? profile,
  List<DiveTank> tanks = const [],
  Map<String, List<TankPressurePoint>> tankPressures = const {},
  GasConsumptionDisplay display = GasConsumptionDisplay.both,
  bool isRebreather = false,
  int duration = 600,
  (int, int)? range,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      // The chart's own source. The primary-source union differs from it
      // only on a multi-computer dive; leaving it empty proves the panel
      // reads the pressures drawn beside its depth stats.
      activeSourceTankPressuresProvider.overrideWith(
        (ref, id) async => tankPressures,
      ),
      tankPressuresProvider.overrideWith((ref, id) async => const {}),
      gasModelProvider.overrideWithValue(GasModel.ideal),
      gasConsumptionDisplayProvider.overrideWithValue(display),
    ],
  );
  addTearDown(container.dispose);
  final selection = container.read(rangeSelectionProvider('d1').notifier)
    ..initialize(duration)
    ..enableRangeMode();
  if (range != null) selection.setRange(range.$1, range.$2);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: maxColumns == null
              ? RangeStatsPanel(
                  diveId: 'd1',
                  profile: profile ?? _profile,
                  units: const UnitFormatter(AppSettings()),
                  tanks: tanks,
                  isRebreather: isRebreather,
                )
              : RangeStatsPanel(
                  diveId: 'd1',
                  profile: profile ?? _profile,
                  units: const UnitFormatter(AppSettings()),
                  tanks: tanks,
                  isRebreather: isRebreather,
                  maxColumns: maxColumns,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the fifth stat (Avg Depth) shares a row with the first (Elapsed).
bool _fifthStatOnFirstRow(WidgetTester tester) =>
    tester.getTopLeft(find.text('Avg Depth')).dy ==
    tester.getTopLeft(find.text('Elapsed')).dy;

void main() {
  testWidgets('keeps four columns by default, however wide it is', (
    tester,
  ) async {
    await _pumpPanel(tester, width: 1400);

    expect(_fifthStatOnFirstRow(tester), isFalse);
  });

  testWidgets('a higher maxColumns spreads the stats across a wide strip', (
    tester,
  ) async {
    await _pumpPanel(tester, width: 1400, maxColumns: 8);

    expect(_fifthStatOnFirstRow(tester), isTrue);
    // The eighth stat still fits the first row; the ninth wraps, because
    // the column count stops at maxColumns however wide the strip is.
    final firstRow = tester.getTopLeft(find.text('Elapsed')).dy;
    expect(tester.getTopLeft(find.text('Max Ascent')).dy, firstRow);
    expect(tester.getTopLeft(find.text('Min Temp')).dy, greaterThan(firstRow));
  });

  testWidgets('never drops below four columns on a narrow screen', (
    tester,
  ) async {
    // Too narrow for a fifth 120px stat. (Not phone-narrow: the test font
    // draws every glyph as a wide box and would overflow the header.)
    await _pumpPanel(tester, width: 500, maxColumns: 8);

    expect(_fifthStatOnFirstRow(tester), isFalse);
    expect(
      tester.getTopLeft(find.text('Max Depth')).dy,
      tester.getTopLeft(find.text('Elapsed')).dy,
    );
  });

  group('the selected interval (#3890)', () {
    /// The stat chip under [label], as the diver reads it.
    String valueOf(WidgetTester tester, String label) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(Column),
      );
      final texts = tester.widgetList<Text>(
        find.descendant(of: chip.first, matching: find.byType(Text)),
      );
      return texts.last.data!;
    }

    /// Flat at 10 m, sampled every 30 s for two minutes.
    final flatEvery30s = [
      for (var t = 0; t <= 120; t += 30)
        DiveProfilePoint(timestamp: t, depth: 10),
    ];

    testWidgets('Elapsed is the whole selection', (tester) async {
      await _pumpPanel(
        tester,
        width: 1400,
        profile: flatEvery30s,
        duration: 120,
        range: (15, 105),
      );

      expect(valueOf(tester, 'Elapsed'), '01:30');
    });

    testWidgets('a selection between two samples is not a surface interval', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        width: 1400,
        profile: flatEvery30s,
        duration: 120,
        range: (15, 25),
      );

      expect(valueOf(tester, 'Elapsed'), '00:10');
      expect(valueOf(tester, 'Min Depth'), '10.0m');
      expect(valueOf(tester, 'Max Depth'), '10.0m');
      expect(valueOf(tester, 'Avg Depth'), '10.0m');
    });

    testWidgets('a selection between two samples shows SAC at its depth', (
      tester,
    ) async {
      // No sample inside the range, so the depth comes from the plotted
      // line: 10 bar/min of the series at 2 bar ambient.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: flatEvery30s,
        duration: 120,
        range: (35, 55),
        tanks: const [DiveTank(id: 'bg', volume: 12, role: TankRole.backGas)],
        tankPressures: _backGasPressures,
      );

      expect(find.text('5.0 bar/min'), findsOneWidget);
    });

    testWidgets('a value that cannot be derived is shown as unavailable', (
      tester,
    ) async {
      // Trimmed: the plotted line starts at 5:00, after the selection ends.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: const [
          DiveProfilePoint(timestamp: 300, depth: 10),
          DiveProfilePoint(timestamp: 360, depth: 12),
          DiveProfilePoint(timestamp: 420, depth: 12),
        ],
        duration: 420,
        range: (100, 200),
        tanks: const [DiveTank(id: 'bg', volume: 12, role: TankRole.backGas)],
        tankPressures: _backGasPressures,
      );

      expect(valueOf(tester, 'Elapsed'), '01:40');
      for (final label in const [
        'Depth Delta',
        'Min Depth',
        'Max Depth',
        'Avg Depth',
        'Avg Vert Speed',
        'Max Descent',
        'Max Ascent',
      ]) {
        expect(valueOf(tester, label), '--', reason: label);
      }
      // SAC divides by the depth, so it has none to divide by.
      expect(find.text('SAC'), findsNothing);
      expect(find.text('RMV'), findsNothing);
    });
  });

  group('gas consumption (#2928)', () {
    const backGas = DiveTank(id: 'bg', volume: 12, role: TankRole.backGas);

    Future<void> pumpGas(
      WidgetTester tester, {
      List<DiveTank> tanks = const [backGas],
      Map<String, List<TankPressurePoint>>? tankPressures,
      GasConsumptionDisplay display = GasConsumptionDisplay.both,
      bool isRebreather = false,
    }) => _pumpPanel(
      tester,
      width: 1400,
      profile: _flatProfile,
      tanks: tanks,
      tankPressures: tankPressures ?? _backGasPressures,
      display: display,
      isRebreather: isRebreather,
    );

    testWidgets('shows SAC and RMV over the selected range', (tester) async {
      await pumpGas(tester);

      // 50 bar over 5 min at 2 bar ambient: 5 bar/min, 60 L/min of 12 L.
      expect(find.text('SAC'), findsOneWidget);
      expect(find.text('5.0 bar/min'), findsOneWidget);
      expect(find.text('RMV'), findsOneWidget);
      expect(find.text('60.0 L/min'), findsOneWidget);
    });

    testWidgets('a range holding a single profile sample still shows SAC', (
      tester,
    ) async {
      // Samples every 5 min: the 150 s to 450 s range holds only t=300.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: [
          for (var t = 0; t <= 600; t += 300)
            DiveProfilePoint(timestamp: t, depth: 10),
        ],
        tanks: const [backGas],
        tankPressures: _backGasPressures,
      );

      expect(find.text('5.0 bar/min'), findsOneWidget);
      expect(find.text('60.0 L/min'), findsOneWidget);
    });

    testWidgets('averages depth over time, for SAC and RMV too (#3891)', (
      tester,
    ) async {
      // The default range, 150 s to 450 s: 60 s at 10 m, a 60 s ramp to
      // 30 m, 180 s at 30 m. A sample average would say 20 m.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: const [
          DiveProfilePoint(timestamp: 150, depth: 10),
          DiveProfilePoint(timestamp: 210, depth: 10),
          DiveProfilePoint(timestamp: 270, depth: 30),
          DiveProfilePoint(timestamp: 450, depth: 30),
        ],
        tanks: const [backGas],
        tankPressures: _backGasPressures,
      );

      // (60 * 10 + 60 * 20 + 180 * 30) / 300 is 24 m, so 3.4 bar ambient:
      // 50 bar over 5 min is 2.9 bar/min, 35.3 L/min of 12 L.
      expect(find.text('24.0m'), findsOneWidget);
      expect(find.text('2.9 bar/min'), findsOneWidget);
      expect(find.text('35.3 L/min'), findsOneWidget);
    });

    testWidgets('interpolates depth at the range edges (#3891)', (
      tester,
    ) async {
      // The 150 s to 450 s range holds only t=400, at 30 m, but starts on the
      // ramp at 13.3 m.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 10),
          DiveProfilePoint(timestamp: 100, depth: 10),
          DiveProfilePoint(timestamp: 400, depth: 30),
          DiveProfilePoint(timestamp: 600, depth: 30),
        ],
      );

      expect(find.text('23.1m'), findsOneWidget);
      expect(find.text('13.3m'), findsOneWidget);
      expect(find.text('30.0m'), findsOneWidget);
    });

    testWidgets('a range between two samples still has depth and SAC (#3891)', (
      tester,
    ) async {
      // The 150 s to 450 s range holds no sample: 15 m to 25 m on the ramp.
      await _pumpPanel(
        tester,
        width: 1400,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 10),
          DiveProfilePoint(timestamp: 600, depth: 30),
        ],
        tanks: const [backGas],
        tankPressures: _backGasPressures,
      );

      expect(find.text('15.0m'), findsOneWidget);
      expect(find.text('25.0m'), findsOneWidget);
      expect(find.text('20.0m'), findsOneWidget);
      // 50 bar over 5 min at 3 bar ambient: 3.3 bar/min, 40.0 L/min of 12 L.
      expect(find.text('3.3 bar/min'), findsOneWidget);
      expect(find.text('40.0 L/min'), findsOneWidget);
    });

    group('depth over the pressure coverage (#3973)', () {
      // 30 m, up to 10 m over the fifth minute, then 10 m to 10:00.
      const profile = [
        DiveProfilePoint(timestamp: 0, depth: 30),
        DiveProfilePoint(timestamp: 240, depth: 30),
        DiveProfilePoint(timestamp: 300, depth: 10),
        DiveProfilePoint(timestamp: 600, depth: 10),
      ];

      Future<void> pumpRange(
        WidgetTester tester, {
        required (int, int) range,
        required Map<String, List<TankPressurePoint>> tankPressures,
        List<DiveProfilePoint> profile = profile,
      }) => _pumpPanel(
        tester,
        width: 1400,
        profile: profile,
        tanks: const [backGas],
        tankPressures: tankPressures,
        range: range,
      );

      // 200 -> 150 bar across the 10 m stretch alone: 50 bar over 5 min at
      // 2 bar ambient is 5 bar/min, 60 L/min of 12 L.
      const lateStart = {
        'bg': [
          TankPressurePoint(tankId: 'bg', timestamp: 300, pressure: 200),
          TankPressurePoint(tankId: 'bg', timestamp: 600, pressure: 150),
        ],
      };

      testWidgets('a selection of the covered stretch alone', (tester) async {
        await pumpRange(tester, range: (300, 600), tankPressures: lateStart);

        expect(find.text('5.0 bar/min'), findsOneWidget);
        expect(find.text('60.0 L/min'), findsOneWidget);
      });

      testWidgets('a transmitter that starts late keeps the same rate', (
        tester,
      ) async {
        await pumpRange(tester, range: (0, 600), tankPressures: lateStart);

        expect(find.text('5.0 bar/min'), findsOneWidget);
        expect(find.text('60.0 L/min'), findsOneWidget);
        // Avg Depth still describes the whole selection.
        expect(find.text('19.0m'), findsOneWidget);
      });

      testWidgets('a transmitter that stops early keeps the same rate', (
        tester,
      ) async {
        // 200 -> 120 bar over the 30 m stretch alone: 80 bar over 4 min at
        // 4 bar ambient is 5 bar/min, 60 L/min of 12 L.
        await pumpRange(
          tester,
          range: (0, 600),
          tankPressures: const {
            'bg': [
              TankPressurePoint(tankId: 'bg', timestamp: 0, pressure: 200),
              TankPressurePoint(tankId: 'bg', timestamp: 240, pressure: 120),
            ],
          },
        );

        expect(find.text('5.0 bar/min'), findsOneWidget);
        expect(find.text('60.0 L/min'), findsOneWidget);
      });

      testWidgets('shows neither when the plotted line misses the coverage', (
        tester,
      ) async {
        // The selection has a depth, but only where nothing read pressure.
        await pumpRange(
          tester,
          range: (0, 600),
          tankPressures: lateStart,
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 30),
            DiveProfilePoint(timestamp: 240, depth: 30),
          ],
        );

        expect(find.text('30.0m'), findsWidgets);
        expect(find.text('SAC'), findsNothing);
        expect(find.text('RMV'), findsNothing);
      });
    });

    testWidgets('follows a SAC-only display preference', (tester) async {
      await pumpGas(tester, display: GasConsumptionDisplay.sac);

      expect(find.text('SAC'), findsOneWidget);
      expect(find.text('RMV'), findsNothing);
    });

    testWidgets('follows an RMV-only display preference', (tester) async {
      await pumpGas(tester, display: GasConsumptionDisplay.rmv);

      expect(find.text('SAC'), findsNothing);
      expect(find.text('RMV'), findsOneWidget);
    });

    testWidgets('RMV-only falls back to SAC when no cylinder has a volume', (
      tester,
    ) async {
      await pumpGas(
        tester,
        tanks: const [DiveTank(id: 'bg')],
        display: GasConsumptionDisplay.rmv,
      );

      expect(find.text('SAC'), findsOneWidget);
      expect(find.text('5.0 bar/min'), findsOneWidget);
      expect(find.text('RMV'), findsNothing);
    });

    testWidgets('shows neither without a transmitter series', (tester) async {
      await pumpGas(
        tester,
        tanks: const [
          DiveTank(id: 'bg', volume: 12, startPressure: 200, endPressure: 50),
        ],
        tankPressures: const {},
      );

      expect(find.text('SAC'), findsNothing);
      expect(find.text('RMV'), findsNothing);
    });

    const ccrTanks = [
      DiveTank(id: 'dil', volume: 3, role: TankRole.diluent),
      DiveTank(
        id: 'o2',
        volume: 3,
        role: TankRole.oxygenSupply,
        gasMix: GasMix(o2: 100),
        order: 1,
      ),
    ];
    final ccrPressures = {
      'dil': _backGasPressures['bg']!,
      'o2': [
        for (var t = 0; t <= 600; t += 30)
          TankPressurePoint(tankId: 'o2', timestamp: t, pressure: 200 - t / 12),
      ],
    };

    testWidgets('a rebreather shows neither SAC nor RMV (#3673)', (
      tester,
    ) async {
      await pumpGas(
        tester,
        tanks: ccrTanks,
        tankPressures: ccrPressures,
        isRebreather: true,
      );

      // The diluent and oxygen drops are not a breathing rate.
      expect(find.text('SAC'), findsNothing);
      expect(find.text('RMV'), findsNothing);
    });

    testWidgets('open circuit adds every breathed cylinder to SAC', (
      tester,
    ) async {
      await pumpGas(
        tester,
        tanks: ccrTanks,
        tankPressures: ccrPressures,
        display: GasConsumptionDisplay.sac,
      );

      // The oxygen cylinder's 25 bar, of the same size, joins the 50.
      expect(find.text('7.5 bar/min'), findsOneWidget);
    });
  });
}
