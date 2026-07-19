@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'chart_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget harness(PlanCanvasSeries series, {required Brightness brightness}) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        planCanvasSeriesProvider.overrideWith((ref) => series),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 800, height: 500, child: PlanProfileChart()),
          ),
        ),
      ),
    );
  }

  group('plan chart goldens', () {
    testWidgets('deco plan, dark', (tester) async {
      await tester.pumpWidget(
        harness(decoSeries(), brightness: Brightness.dark),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_deco_dark.png'),
      );
    });

    testWidgets('deco plan, light', (tester) async {
      await tester.pumpWidget(
        harness(decoSeries(), brightness: Brightness.light),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_deco_light.png'),
      );
    });

    testWidgets('ndl plan, dark', (tester) async {
      await tester.pumpWidget(
        harness(ndlSeries(), brightness: Brightness.dark),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_ndl_dark.png'),
      );
    });

    testWidgets('dense trimix schedule, dark', (tester) async {
      await tester.pumpWidget(
        harness(denseDecoSeries(), brightness: Brightness.dark),
      );
      await expectLater(
        find.byType(PlanProfileChart),
        matchesGoldenFile('goldens/plan_chart_dense_dark.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
