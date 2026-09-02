import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(ExpansionTile), matching: matching);

Future<void> _pumpLegend(
  WidgetTester tester, {
  required ProfileLegendConfig config,
  double width = 1200,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DiveProfileLegend(
            config: config,
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers a GTR toggle only when the dive has GTR data', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      config: const ProfileLegendConfig(hasTtsData: true),
    );
    expect(find.text('GTR'), findsNothing);

    await _pumpLegend(
      tester,
      config: const ProfileLegendConfig(hasTtsData: true, hasGtrData: true),
    );
    expect(find.text('GTR'), findsOneWidget);
  });

  testWidgets('the options dialog gives GTR a computer/calculated selector', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      width: 300,
      config: const ProfileLegendConfig(hasTtsData: true, hasGtrData: true),
    );
    await _openDialog(tester);

    expect(_inDialog(find.text('GTR')), findsOneWidget);
    // TTS and GTR: both are source-capable.
    expect(find.byType(SegmentedButton<MetricDataSource>), findsNWidgets(2));
  });
}
