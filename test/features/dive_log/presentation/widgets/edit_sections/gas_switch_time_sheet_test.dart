import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 600, depth: 30),
  DiveProfilePoint(timestamp: 2400, depth: 30),
  DiveProfilePoint(timestamp: 3000, depth: 0),
];

const _chart = ValueKey('gas-switch-time-chart');
const _cursor = ValueKey('gas-switch-time-cursor');

class _Sheet {
  int? result;
  var closed = false;
}

Future<_Sheet> _open(
  WidgetTester tester, {
  int initialSeconds = 900,
  List<DiveProfilePoint> profile = _profile,
  bool imperial = false,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final sheet = _Sheet();
  final units = UnitFormatter(
    AppSettings(depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
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
                otherSwitchTimes: const [2520],
                breathStarts: const [890],
              );
              sheet.closed = true;
            },
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

    testWidgets('tapping the chart moves the time and the cursor', (
      tester,
    ) async {
      await _open(tester);

      final chart = find.byKey(_chart);
      await tester.tapAt(tester.getCenter(chart));
      await tester.pump();

      expect(find.text('25:00 at 30.0m'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(_cursor)).dx,
        closeTo(tester.getCenter(chart).dx, 1),
      );
    });

    testWidgets('the cursor line runs the height of the chart', (tester) async {
      await _open(tester);

      expect(
        tester
            .getSize(find.byKey(const ValueKey('gas-switch-time-line')))
            .height,
        tester.getSize(find.byKey(_chart)).height,
      );
    });

    testWidgets('a horizontal drag follows the finger', (tester) async {
      await _open(tester);

      final chart = find.byKey(_chart);
      final width = tester.getSize(chart).width;
      await tester.timedDrag(
        chart,
        Offset(width / 4, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();

      expect(find.text('37:30 at 30.0m'), findsOneWidget);
    });

    testWidgets('a vertical drag over the chart leaves the time alone', (
      tester,
    ) async {
      await _open(tester);

      await tester.timedDrag(
        find.byKey(_chart),
        const Offset(0, 40),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('15:00 at 30.0m'), findsOneWidget);
    });

    testWidgets('the slider moves the same time', (tester) async {
      await _open(tester);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(120);
      await tester.pump();

      expect(find.text('2:00 at 6.0m'), findsOneWidget);
    });

    testWidgets('the slider lines up with the chart', (tester) async {
      await _open(tester);

      final chart = tester.getRect(find.byKey(_chart));
      final slider = tester.getRect(find.byType(Slider));

      expect(slider.left, chart.left);
      expect(slider.right, chart.right);
      expect(tester.widget<Slider>(find.byType(Slider)).padding?.horizontal, 0);
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

    testWidgets('reads depth in the diver\'s unit', (tester) async {
      await _open(tester, imperial: true);

      expect(find.text('15:00 at 98.4ft'), findsOneWidget);
    });
  });
}
