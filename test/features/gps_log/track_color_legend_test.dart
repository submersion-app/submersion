import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_color_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required TrackColorMode mode,
  ({double min, double max})? range,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackColorLegend(mode: mode, speedRangeMps: range),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing in uniform mode', (tester) async {
    await _pump(tester, mode: TrackColorMode.uniform);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Slower'), findsNothing);
  });

  testWidgets('speed mode labels both ends with formatted speeds', (
    tester,
  ) async {
    await _pump(
      tester,
      mode: TrackColorMode.speed,
      range: (min: 0.0, max: 10.0),
    );
    // 0 m/s and 10 m/s under the default metric setting.
    expect(find.text('0.0 km/h'), findsOneWidget);
    expect(find.text('36.0 km/h'), findsOneWidget);
  });

  testWidgets('elapsed mode labels start and end', (tester) async {
    await _pump(tester, mode: TrackColorMode.elapsed);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
  });

  testWidgets('speed mode with no range falls back to generic labels', (
    tester,
  ) async {
    await _pump(tester, mode: TrackColorMode.speed);
    expect(find.text('Slower'), findsOneWidget);
    expect(find.text('Faster'), findsOneWidget);
  });

  testWidgets('renders one swatch per bucket', (tester) async {
    await _pump(tester, mode: TrackColorMode.elapsed);
    // Scoped to the ramp: the enclosing Card contributes a ColoredBox too.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('track-legend-ramp')),
        matching: find.byType(ColoredBox),
      ),
      findsNWidgets(kTrackColorBuckets),
    );
  });

  testWidgets('does not overflow when speed labels are wide', (tester) async {
    // Regression: the label row was constrained to the swatch strip's fixed
    // width, so a formatted speed pair clipped with a RenderFlex overflow.
    await _pump(
      tester,
      mode: TrackColorMode.speed,
      range: (min: 0.0, max: 42.0),
    );
    expect(tester.takeException(), isNull);
  });
}
