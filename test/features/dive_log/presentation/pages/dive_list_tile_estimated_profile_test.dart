import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/estimated_profile_chart.dart';
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
  Future<void> pumpTile(
    WidgetTester tester, {
    Duration? runtime = const Duration(minutes: 40),
    Duration? bottomTime = const Duration(minutes: 36),
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(const AppSettings()),
          ),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: DiveListTile(
          diveId: 'd1',
          diveNumber: 7,
          dateTime: DateTime(2024, 6, 1),
          siteName: 'Blue Hole',
          summary: DiveSummary(
            id: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2024, 6, 1),
            siteName: 'Blue Hole',
            maxDepth: 18.0,
            runtime: runtime,
            bottomTime: bottomTime,
            sortTimestamp: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cacheProfile(
    WidgetTester tester,
    List<DiveProfilePoint> profile,
  ) async {
    ProviderScope.containerOf(
      tester.element(find.byType(DiveListTile)),
    ).read(batchProfileCacheProvider.notifier).state = {
      'd1': profile,
    };
    await tester.pump();
  }

  group('DiveListTile estimated sparkline (#4112)', () {
    testWidgets('a dive known to have no samples gets a faded estimate', (
      tester,
    ) async {
      await pumpTile(tester);
      await cacheProfile(tester, const []);

      final mini = tester.widget<EstimatedProfileMiniChart>(
        find.byType(EstimatedProfileMiniChart),
      );
      expect(
        mini.profile,
        EstimatedProfile.estimate(
          maxDepth: 18,
          runtime: const Duration(minutes: 40),
          bottomTime: const Duration(minutes: 36),
        ),
      );
      expect(find.byType(DiveProfileMiniChart), findsNothing);
    });

    testWidgets('no estimate while the samples are still loading', (
      tester,
    ) async {
      await pumpTile(tester);

      expect(find.byType(EstimatedProfileMiniChart), findsNothing);
      expect(find.byType(DiveProfileMiniChart), findsNothing);
    });

    testWidgets('a recorded profile draws the real sparkline only', (
      tester,
    ) async {
      await pumpTile(tester);
      await cacheProfile(tester, _profile);

      expect(find.byType(DiveProfileMiniChart), findsOneWidget);
      expect(find.byType(EstimatedProfileMiniChart), findsNothing);
    });

    testWidgets('no estimate without a time to draw it over', (tester) async {
      await pumpTile(tester, runtime: null, bottomTime: null);
      await cacheProfile(tester, const []);

      expect(find.byType(EstimatedProfileMiniChart), findsNothing);
    });
  });
}
