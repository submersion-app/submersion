import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The chart publishes where its plot sits and what it spans, so the pinned
/// strip can start its condense exactly on the chart's depth line (#4423).
void main() {
  final profile = [
    for (var t = 0; t <= 1800; t += 30)
      DiveProfilePoint(
        timestamp: t,
        depth: t < 120 ? t / 4 : (t > 1680 ? (1800 - t) / 4 : 30),
      ),
  ];

  Future<List<ProfilePlotFrame>> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    final frames = <ProfilePlotFrame>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                onPlotFrame: frames.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return frames;
  }

  testWidgets('reports the visible time and depth ranges', (tester) async {
    final frames = await pump(tester);
    expect(frames, isNotEmpty);
    final frame = frames.last;
    expect(frame.minSeconds, lessThanOrEqualTo(0));
    expect(frame.maxSeconds, greaterThanOrEqualTo(1800));
    expect(frame.minDepthMeters, 0);
    expect(frame.maxDepthMeters, inInclusiveRange(30, 40));
  });

  testWidgets('its key marks a box over the plot, inside the chart', (
    tester,
  ) async {
    final frame = (await pump(tester)).last;
    final plot = frame.plotKey.currentContext!.findRenderObject()! as RenderBox;
    final plotRect = plot.localToGlobal(Offset.zero) & plot.size;
    final chartRect = tester.getRect(find.byType(DiveProfileChart));
    expect(chartRect.contains(plotRect.topLeft), isTrue);
    expect(
      chartRect.contains(plotRect.bottomRight - const Offset(1, 1)),
      isTrue,
    );
    expect(plotRect.width, greaterThan(chartRect.width / 2));
    expect(plotRect.height, greaterThan(chartRect.height / 3));
  });

  testWidgets('reports depth in meters whatever the diver\'s unit', (
    tester,
  ) async {
    final frame = (await pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    )).last;
    expect(frame.maxDepthMeters, inInclusiveRange(30, 40));
  });

  testWidgets('does not report again while nothing changes', (tester) async {
    final frames = await pump(tester);
    final count = frames.length;
    await tester.pump(const Duration(milliseconds: 300));
    expect(frames.length, count);
  });
}
