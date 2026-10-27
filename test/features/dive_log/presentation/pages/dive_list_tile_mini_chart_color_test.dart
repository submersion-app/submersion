import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed) {
    state = CardViewConfig.defaultDetailed();
  }
}

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 18),
  DiveProfilePoint(timestamp: 1800, depth: 0),
];

void main() {
  Future<Color?> miniChartColor(
    WidgetTester tester, {
    double? colorValue,
    bool checked = false,
    Brightness brightness = Brightness.light,
    ProfileMetricColorOverrides profileMetricColors =
        ProfileMetricColorOverrides.none,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              AppSettings(
                cardColorAttribute: CardColorAttribute.depth,
                profileMetricColors: profileMetricColors,
              ),
            ),
          ),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
          batchProfileCacheProvider.overrideWith((ref) => {'d1': _profile}),
        ],
        child: Theme(
          data: AppThemeRegistry.resolveTheme(
            AppThemeRegistry.findById('submersion'),
            brightness,
          ),
          child: DiveListTile(
            diveId: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2024, 6, 1),
            siteName: 'Blue Hole',
            colorValue: colorValue,
            minValueInList: 0,
            maxValueInList: 10,
            isChecked: checked,
            isSelectionMode: checked,
            summary: DiveSummary(
              id: 'd1',
              diveNumber: 7,
              dateTime: DateTime(2024, 6, 1),
              siteName: 'Blue Hole',
              maxDepth: 18.0,
              sortTimestamp: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<DiveProfileMiniChart>(find.byType(DiveProfileMiniChart))
        .color;
  }

  group('DiveListTile mini chart colour', () {
    testWidgets('draws in the full chart depth colour on a plain card', (
      tester,
    ) async {
      expect(await miniChartColor(tester), AppColors.chartDepth);
    });

    testWidgets('falls back to the card accent on a mid-tint card', (
      tester,
    ) async {
      // Halfway along the Ocean gradient, where the depth blue disappears;
      // the card is dark, so its accent is the light cyan.
      expect(await miniChartColor(tester, colorValue: 5), Colors.cyan.shade200);
    });

    testWidgets('keeps the depth colour on a selected dark-mode card', (
      tester,
    ) async {
      // The selected fill is translucent primaryContainer; judged as the
      // opaque colour it reads too close to the blue, but over the surface
      // it is what the diver sees, and the blue stays clear.
      expect(
        await miniChartColor(
          tester,
          checked: true,
          brightness: Brightness.dark,
        ),
        AppColors.chartDepth,
      );
    });

    testWidgets('follows the depth colour the diver chose', (tester) async {
      const chosen = Color(0xFF6A1B9A);
      expect(
        await miniChartColor(
          tester,
          profileMetricColors: ProfileMetricColorOverrides.fromArgb({
            ProfileMetric.depth: chosen.toARGB32(),
          }),
        ),
        chosen,
      );
    });

    testWidgets('keeps the depth colour on a plain dark-mode card', (
      tester,
    ) async {
      expect(
        await miniChartColor(tester, brightness: Brightness.dark),
        AppColors.chartDepth,
      );
    });
  });
}
