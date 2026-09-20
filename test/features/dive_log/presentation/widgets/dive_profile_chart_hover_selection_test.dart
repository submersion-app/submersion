import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mouse-hover selection on the profile chart. fl_chart's touch callback and
/// the chart's own pointer-hover fallback both see every hover, but only one
/// may report it; the t=0 surface lead-in must read as time 0; and the right
/// edge of the plot must reach the last sample.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _chartWidth = 1750.0;

/// A 53-minute dive sampled every 2 s from t=2, so the chart draws a surface
/// lead-in vertex at t=0 before the first real sample.
final _profile = List.generate(
  1590,
  (i) => DiveProfilePoint(
    timestamp: 2 + i * 2,
    depth: i == 0 ? 0.73 : 12 + (i % 7) * 0.3,
  ),
);

Future<void> _pumpChart(
  WidgetTester tester, {
  required List<int?> points,
  required List<int?> times,
}) async {
  tester.view.physicalSize = const Size(1800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: _chartWidth,
            height: 800,
            child: DiveProfileChart(
              profile: _profile,
              onPointSelected: points.add,
              onTimeSelected: times.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(LineChart).first);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: rect.centerLeft + const Offset(-5, 0));
  addTearDown(mouse.removePointer);
  return mouse;
}

void main() {
  testWidgets('each hover move over the plot reports one sample', (
    tester,
  ) async {
    final points = <int?>[];
    final times = <int?>[];
    await _pumpChart(tester, points: points, times: times);
    final rect = tester.getRect(find.byType(LineChart).first);
    final mouse = await _mouse(tester);
    // Enter the plot first: fl_chart reports its enter event as well.
    await mouse.moveTo(Offset(rect.left + 60, rect.center.dy));
    await tester.pump();

    for (var x = rect.left + 60.5; x < rect.right - 5; x += 7.25) {
      points.clear();
      await mouse.moveTo(Offset(x, rect.center.dy));
      await tester.pump();
      expect(
        points,
        hasLength(1),
        reason:
            'hover at x=$x: fl_chart owns the selection over the plot, so '
            'the pointer-hover fallback must not report as well',
      );
    }
  });

  testWidgets('hovering the surface lead-in selects time 0', (tester) async {
    final points = <int?>[];
    final times = <int?>[];
    await _pumpChart(tester, points: points, times: times);
    final rect = tester.getRect(find.byType(LineChart).first);
    final mouse = await _mouse(tester);

    // Well into the plot first, so a stale selection cannot pass the test.
    await mouse.moveTo(rect.center);
    await tester.pump();
    expect(times.whereType<int>().last, greaterThan(0));

    // Left of the plot (the depth axis gutter), then its very first pixel.
    for (final x in [rect.left + 2, rect.left + 49]) {
      await mouse.moveTo(Offset(x, rect.center.dy));
      await tester.pump();
      expect(times.last, 0, reason: 'hover at x=$x');
    }
  });

  testWidgets('hovering at the right edge selects the last sample', (
    tester,
  ) async {
    final points = <int?>[];
    final times = <int?>[];
    await _pumpChart(tester, points: points, times: times);
    final rect = tester.getRect(find.byType(LineChart).first);
    final mouse = await _mouse(tester);

    await mouse.moveTo(rect.center);
    await tester.pump();

    for (final x in [rect.right - 1, rect.right - 0.1]) {
      await mouse.moveTo(Offset(x, rect.center.dy));
      await tester.pump();
      expect(times.last, _profile.last.timestamp, reason: 'hover at x=$x');
      expect(points.last, _profile.length - 1, reason: 'hover at x=$x');
    }
  });
}
