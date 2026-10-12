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
  container.read(rangeSelectionProvider('d1').notifier)
    ..initialize(600)
    ..enableRangeMode();

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

    testWidgets('a rebreather reads SAC from the diluent alone', (
      tester,
    ) async {
      await pumpGas(
        tester,
        tanks: ccrTanks,
        tankPressures: ccrPressures,
        display: GasConsumptionDisplay.sac,
        isRebreather: true,
      );

      // Diluent alone: 50 bar over 5 min at 2 bar ambient.
      expect(find.text('5.0 bar/min'), findsOneWidget);
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
