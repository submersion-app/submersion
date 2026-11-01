import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 600, depth: 30),
  DiveProfilePoint(timestamp: 2400, depth: 30),
  DiveProfilePoint(timestamp: 3000, depth: 0),
];

const _back = DiveTank(id: 'back', gasMix: GasMix(o2: 21), order: 0);
const _deco = DiveTank(id: 'deco', gasMix: GasMix(o2: 50), order: 1);

final _pressures = {
  for (final id in ['back', 'deco'])
    id: [
      for (var t = 0; t <= 3000; t += 60)
        TankPressurePoint(tankId: id, timestamp: t, pressure: 200 - t / 60),
    ],
};

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sheet {
  int? result;
  var closed = false;
}

Future<_Sheet> _open(
  WidgetTester tester, {
  int initialSeconds = 900,
  List<DiveProfilePoint> profile = _profile,
  bool imperial = false,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final sheet = _Sheet();
  final units = UnitFormatter(
    AppSettings(depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _SettingsNotifier(const AppSettings()),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                sheet.result = await showGasSwitchTimeSheet(
                  context,
                  profile: profile,
                  initialSeconds: initialSeconds,
                  units: units,
                  tanks: const [_back, _deco],
                  tankId: 'deco',
                  tankPressures: _pressures,
                );
                sheet.closed = true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return sheet;
}

void main() {
  group('canPickOnProfile', () {
    test('needs two samples over some span of time', () {
      expect(canPickOnProfile(_profile), isTrue);
      expect(canPickOnProfile(const []), isFalse);
      expect(
        canPickOnProfile(const [DiveProfilePoint(timestamp: 60, depth: 10)]),
        isFalse,
      );
      expect(
        canPickOnProfile(const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 0, depth: 10),
        ]),
        isFalse,
      );
    });
  });

  group('the sheet', () {
    testWidgets('opens at the row\'s time with its depth', (tester) async {
      await _open(tester);

      expect(find.text('Set switch time'), findsOneWidget);
      expect(find.text('15:00 at 30.0m'), findsOneWidget);
    });

    testWidgets('hosts the dive profile chart with depth and pressure only', (
      tester,
    ) async {
      await _open(tester);

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.depthAndPressureOnly, isTrue);
      expect(chart.emphasizedTankId, 'deco');
      expect(chart.tankPressures, _pressures);
      expect(chart.highlightedTimestamp, 900);
    });

    testWidgets('tapping the chart moves the time', (tester) async {
      await _open(tester);

      await tester.tapAt(tester.getCenter(find.byType(LineChart).first));
      await tester.pumpAndSettle();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      // The nearest sample of a sparse profile.
      expect(chart.highlightedTimestamp, anyOf(600, 2400));
    });

    testWidgets('the slider moves the same time', (tester) async {
      await _open(tester);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(120);
      await tester.pump();

      expect(find.text('2:00 at 6.0m'), findsOneWidget);
    });

    testWidgets('the slider lines up with the chart\'s plot', (tester) async {
      await _open(tester);

      final sheetChart = tester.getRect(find.byType(DiveProfileChart));
      final padding = tester
          .widget<Slider>(find.byType(Slider))
          .padding!
          .resolve(TextDirection.ltr);

      expect(padding.left, DiveProfileChart.plotLeftInset(sheetChart.width));
      expect(
        padding.right,
        DiveProfileChart.plotRightInset(sheetChart.width, hasRightAxis: true),
      );
    });

    testWidgets('Set time returns the chosen seconds', (tester) async {
      final sheet = await _open(tester);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(120.4);
      await tester.pump();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();

      expect(sheet.closed, isTrue);
      expect(sheet.result, 120);
    });

    testWidgets('Cancel returns nothing', (tester) async {
      final sheet = await _open(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sheet.closed, isTrue);
      expect(sheet.result, isNull);
    });

    testWidgets('a time past the profile opens at its end', (tester) async {
      await _open(tester, initialSeconds: 5000);

      expect(find.text('50:00 at 0.0m'), findsOneWidget);
    });

    testWidgets('a time before the first sample shows no depth', (
      tester,
    ) async {
      await _open(
        tester,
        initialSeconds: 5,
        profile: const [
          DiveProfilePoint(timestamp: 10, depth: 1),
          DiveProfilePoint(timestamp: 20, depth: 2),
        ],
      );

      expect(find.text('0:05 at --'), findsOneWidget);
    });

    testWidgets('a profile with no depth still opens', (tester) async {
      await _open(
        tester,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 3000, depth: 0),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('15:00 at 0.0m'), findsOneWidget);
    });

    testWidgets('the slider runs left to right in a right-to-left language', (
      tester,
    ) async {
      await _open(tester, locale: const Locale('he'));

      expect(
        Directionality.of(tester.element(find.byType(Slider))),
        TextDirection.ltr,
      );
    });

    testWidgets('reads depth in the diver\'s unit', (tester) async {
      await _open(tester, imperial: true);

      expect(find.text('15:00 at 98.4ft'), findsOneWidget);
    });
  });
}
