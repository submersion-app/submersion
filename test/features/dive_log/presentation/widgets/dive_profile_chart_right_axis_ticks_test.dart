import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Issue #3055: the right axis labels the depth grid's ticks with the
  // metric's value there. A 3 C temperature range across a 20 m dive used
  // to print 31, 31, 31, 30, 30 ... at whole degrees.
  testWidgets('right-axis temperature ticks carry distinct labels', (
    tester,
  ) async {
    final profile = List.generate(
      41,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i <= 20 ? i * 1.0 : (40 - i) * 1.0,
        temperature: 29.0 + (i % 3),
      ),
    );
    // A desktop-sized chart, as in the issue's screenshots: tall enough that
    // fl_chart lays out ticks finer than a whole degree apart.
    tester.view.physicalSize = const Size(1800, 1000);
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
              width: 1700,
              height: 900,
              child: DiveProfileChart(profile: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The labels fl_chart actually laid out on the right axis, at the tick
    // interval it chose itself (the right axis sets none).
    final labels = [
      for (final title in tester.widgetList<SideTitleWidget>(
        find.byType(SideTitleWidget),
      ))
        if (title.meta.axisSide == AxisSide.right) (title.child as Text).data!,
    ];

    expect(labels.length, greaterThan(3));
    expect(labels.toSet().length, labels.length, reason: '$labels');
  });
}
