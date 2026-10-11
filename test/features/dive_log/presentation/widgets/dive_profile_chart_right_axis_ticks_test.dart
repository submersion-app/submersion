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
              width: 400,
              height: 300,
              child: DiveProfileChart(profile: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = tester.widget<LineChart>(find.byType(LineChart).first).data;
    final right = data.titlesData.rightTitles.sideTitles;
    expect(right.showTitles, isTrue);

    // Walk the depth grid the way fl_chart does and collect each label.
    const interval = 2.0;
    final labels = <String>[];
    for (var v = data.minY; v <= data.maxY + 1e-9; v += interval) {
      final widget = right.getTitlesWidget(
        v,
        TitleMeta(
          min: data.minY,
          max: data.maxY,
          parentAxisSize: 300,
          axisPosition: 0,
          appliedInterval: interval,
          sideTitles: right,
          formattedValue: '$v',
          axisSide: AxisSide.right,
          rotationQuarterTurns: 0,
        ),
      );
      // Out-of-band and near-boundary ticks come back as an empty box.
      if (widget is SideTitleWidget) {
        labels.add((widget.child as Text).data!);
      }
    }

    expect(labels.length, greaterThan(3));
    expect(labels.toSet().length, labels.length, reason: '$labels');
  });
}
