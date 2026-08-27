import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/tissue_recovery_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: TissueRecoveryChart()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

/// The vertical marker lines fl_chart was handed on the last build.
List<VerticalLine> _markers(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.extraLinesData.verticalLines;
}

Future<void> _setPlan(
  WidgetTester tester,
  ProviderContainer container, {
  required double firstDepth,
  required int firstTime,
  required double secondDepth,
  required int secondTime,
}) async {
  container.read(siFirstDiveDepthProvider.notifier).state = firstDepth;
  container.read(siFirstDiveTimeProvider.notifier).state = firstTime;
  container.read(siSecondDiveDepthProvider.notifier).state = secondDepth;
  container.read(siSecondDiveTimeProvider.notifier).state = secondTime;
  await tester.pumpAndSettle();
}

void main() {
  // The chart always draws a "now" line at the current interval; the minimum
  // interval marker is the one under test, so count the extras beyond that.
  group('tissue recovery chart minimum interval marker', () {
    testWidgets('marks the minimum when there is one to mark', (tester) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 30,
      );

      final minutes = container.read(siMinimumIntervalProvider).minutes!;
      expect(minutes, inInclusiveRange(1, 240));

      final markerXs = _markers(tester).map((line) => line.x).toList();
      expect(
        markerXs,
        contains(minutes.toDouble()),
        reason: 'the recommended wait should be drawn on the recovery curve',
      );
    });

    testWidgets('draws no minimum marker when the plan is impossible', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );
      expect(
        container.read(siMinimumIntervalProvider).outcome,
        SiIntervalOutcome.impossible,
      );

      // Only the "now" line survives: there is no wait to point at.
      expect(_markers(tester), hasLength(1));
    });

    testWidgets('draws no minimum marker when the wait runs past the chart', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 55.0,
        firstTime: 120,
        secondDepth: 12.0,
        secondTime: 100,
      );
      expect(
        container.read(siMinimumIntervalProvider).outcome,
        SiIntervalOutcome.beyondHorizon,
      );

      expect(_markers(tester), hasLength(1));
    });

    testWidgets('draws no minimum marker when no wait is needed', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 20,
        secondDepth: 9.0,
        secondTime: 10,
      );
      expect(container.read(siMinimumIntervalProvider).minutes, 0);

      // A zero minute wait would sit on the chart's own axis, which reads as
      // noise rather than as advice.
      expect(_markers(tester), hasLength(1));
    });
  });
}
