import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/profile_zoom_mode.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The chart options' Zoom choice (issue #5069): one row with three values
/// in place of the "Keep overlays in view" checkbox.
Widget _dialog() => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChartOptionsDialog(
        config: ProfileLegendConfig(),
        anchorOffset: Offset.zero,
        anchorSize: Size(40, 40),
      ),
    ),
  ),
);

Future<ProviderContainer> _openDisplay(WidgetTester tester) async {
  await tester.pumpWidget(_dialog());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Display'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ChartOptionsDialog)),
  );
}

void main() {
  testWidgets('Display shows Zoom with the session value', (tester) async {
    await _openDisplay(tester);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Both axes, magnify overlays'), findsOneWidget);
  });

  testWidgets('picking Time only sets the session zoom mode', (tester) async {
    final container = await _openDisplay(tester);

    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time only').last);
    await tester.pumpAndSettle();

    expect(
      container.read(profileLegendProvider).zoomMode,
      ProfileZoomMode.timeOnly,
    );
    expect(find.text('Time only'), findsOneWidget);
  });

  testWidgets('picking keep overlays in view sets the viewport flag', (
    tester,
  ) async {
    final container = await _openDisplay(tester);

    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Both axes, keep overlays in view').last);
    await tester.pumpAndSettle();

    expect(container.read(profileLegendProvider).metricsFollowViewport, isTrue);
  });

  testWidgets('the Keep overlays in view checkbox is gone', (tester) async {
    await _openDisplay(tester);
    expect(find.text('Keep overlays in view'), findsNothing);
  });

  // A config built without the chart's live axis (as here) still gives the
  // Right axis row a value: None.
  testWidgets('the Right axis row reads None without a live axis value', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChartOptionsDialog(
              config: ProfileLegendConfig(
                rightAxisChoices: [
                  (
                    metric: ProfileRightAxisMetric.temperature,
                    color: Color(0xFF5C6BC0),
                  ),
                ],
              ),
              anchorOffset: Offset.zero,
              anchorSize: Size(40, 40),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('chart-options-right-axis'));
    expect(
      find.descendant(of: row, matching: find.text('None')),
      findsOneWidget,
    );
  });
}
