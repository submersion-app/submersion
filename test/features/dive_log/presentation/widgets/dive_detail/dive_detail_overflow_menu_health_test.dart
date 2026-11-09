import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/data/services/dive_health_metrics_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_health_metrics_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

class _Metrics extends Fake implements DiveHealthMetricsService {}

/// "Add heart rate from Apple Health" on a dive's menu (issue #637): for an
/// older dive of the diver the Health switch belongs to, where Health is.
void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    String? metricsDiver = 'a',
    bool health = true,
  }) async {
    final dive = createTestDiveWithBottomTime().copyWith(diverId: 'a');
    SharedPreferences.setMockInitialValues({
      SettingsKeys.healthMetricsDiver: ?metricsDiver,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          diveHealthMetricsServiceProvider.overrideWithValue(
            health ? _Metrics() : null,
          ),
          healthSettingsProvider.overrideWith(
            (ref) =>
                HealthSettingsNotifier(prefs, diverExists: (_) async => true),
          ),
          diveHasRawDataProvider(dive.id).overrideWith((ref) async => false),
          diveHasImportedFileProvider(
            dive.id,
          ).overrideWith((ref) async => false),
          preDiveSessionForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => null),
          mirrorCandidatesProvider(dive.id).overrideWith((ref) async => []),
        ],
        child: DiveDetailOverflowMenu(
          dive: dive,
          embedded: false,
          menuKey: GlobalKey(),
          displayOptions: MenuController(),
          onSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  const label = 'Add heart rate from Apple Health';

  testWidgets('offered on the bound diver\'s dive', (tester) async {
    await pumpMenu(tester);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('not offered while the switch is off', (tester) async {
    await pumpMenu(tester, metricsDiver: null);
    expect(find.text(label), findsNothing);
  });

  testWidgets('not offered on another diver\'s dive', (tester) async {
    await pumpMenu(tester, metricsDiver: 'b');
    expect(find.text(label), findsNothing);
  });

  testWidgets('not offered where Health is not', (tester) async {
    await pumpMenu(tester, health: false);
    expect(find.text(label), findsNothing);
  });
}
