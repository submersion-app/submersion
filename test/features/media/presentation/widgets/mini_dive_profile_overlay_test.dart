import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

LineChartBarData _depthBar(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first;

void main() {
  const settings = AppSettings();

  testWidgets('empty profile renders nothing', (tester) async {
    await tester.pumpWidget(
      _host(
        const MiniDiveProfileOverlay(
          profile: [],
          photoElapsedSeconds: 0,
          settings: settings,
        ),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('a profile starting after t=0 descends from the surface', (
    tester,
  ) async {
    // Subsurface/DC-XML sampling: first sample at 10s, so the sparkline must
    // reach the left edge rather than starting one interval in (issue #684).
    final profile = [
      for (var i = 1; i <= 8; i++)
        DiveProfilePoint(timestamp: i * 10, depth: i * 2.0),
    ];
    await tester.pumpWidget(
      _host(
        MiniDiveProfileOverlay(
          profile: profile,
          photoElapsedSeconds: 30,
          photoDepthMeters: 6.0,
          settings: settings,
        ),
      ),
    );

    final bar = _depthBar(tester);
    expect(bar.spots.first, const FlSpot(0, 0));
    // Additive: every real sample is still drawn after the lead-in.
    expect(bar.spots.length, profile.length + 1);
    expect(bar.spots[1].x, 10);
  });

  testWidgets('a profile already starting at t=0 gains no lead-in', (
    tester,
  ) async {
    final profile = [
      for (var i = 0; i < 8; i++)
        DiveProfilePoint(timestamp: i * 10, depth: i.toDouble()),
    ];
    await tester.pumpWidget(
      _host(
        MiniDiveProfileOverlay(
          profile: profile,
          photoElapsedSeconds: 20,
          settings: settings,
        ),
      ),
    );

    final bar = _depthBar(tester);
    expect(bar.spots.length, profile.length);
    expect(bar.spots.first.x, 0);
  });

  testWidgets('a trimmed profile keeps its gap', (tester) async {
    // First sample far past one interval: no fabricated descent.
    final profile = [
      for (var i = 0; i < 8; i++)
        DiveProfilePoint(timestamp: 600 + i * 10, depth: 20.0 + i),
    ];
    await tester.pumpWidget(
      _host(
        MiniDiveProfileOverlay(
          profile: profile,
          photoElapsedSeconds: 620,
          settings: settings,
        ),
      ),
    );

    final bar = _depthBar(tester);
    expect(bar.spots.length, profile.length);
    expect(bar.spots.first.x, 600);
  });
}
