import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _diveId = 'd1';

Dive _dive() => Dive(
  id: _diveId,
  dateTime: DateTime(2026, 1, 1, 10),
  maxDepth: 20,
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 20),
  ),
);

/// The overlay the planner hands over: named after the plan, as saved.
final _planOverlay = ChartSourceOverlay(
  sourceId: 'plan:p1',
  name: '41.0m - Nov 5',
  color: Colors.purple,
  tintByMetric: false,
  computerId: null,
  points: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 18),
  ),
);

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

List<Override> _pageOverrides({ChartSourceOverlay? plan}) {
  final dive = _dive();
  // Settings come from getBaseOverrides.
  return [
    diveProvider(dive.id).overrideWith((ref) async => dive),
    profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
    sourceProfileAnalysisProvider((
      diveId: dive.id,
      sourceId: null,
    )).overrideWith((ref) async => null),
    gasSwitchesProvider(
      dive.id,
    ).overrideWith((ref) async => <GasSwitchWithTank>[]),
    tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
    plannedProfileOverlayProvider(dive.id).overrideWith((ref) async => plan),
  ];
}

DiveProfileChart _chart(WidgetTester tester) =>
    tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DiveProfileChart)));

/// The planned profile of a dive with a linked plan (#4215): drawn full
/// screen as well as on the card, named "Plan" in the legend, and switched
/// from the chart options' Overlays section.
void main() {
  group('legend state', () {
    test('showPlannedProfile defaults on and toggles', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(profileLegendProvider, (_, _) {});
      addTearDown(sub.close);

      expect(container.read(profileLegendProvider).showPlannedProfile, isTrue);
      container.read(profileLegendProvider.notifier).togglePlannedProfile();
      expect(container.read(profileLegendProvider).showPlannedProfile, isFalse);
    });

    test('copyWith and equality carry showPlannedProfile', () {
      const a = ProfileLegendState();
      final b = a.copyWith(showPlannedProfile: false);
      expect(b.showPlannedProfile, isFalse);
      expect(b, isNot(equals(a)));
      expect(b.hashCode, isNot(equals(a.hashCode)));
      expect(b.copyWith(showPlannedProfile: true), equals(a));
    });
  });

  group('chart options', () {
    Widget dialog({required bool hasPlannedProfile}) => _app(
      [settingsProvider.overrideWith((ref) => _StubSettingsNotifier())],
      Scaffold(
        body: ChartOptionsDialog(
          config: ProfileLegendConfig(
            hasTemperatureData: true,
            hasPlannedProfile: hasPlannedProfile,
          ),
          anchorOffset: const Offset(300, 0),
          anchorSize: const Size(40, 40),
        ),
      ),
    );

    testWidgets('the Overlays section switches the plan', (tester) async {
      await tester.pumpWidget(dialog(hasPlannedProfile: true));
      // Overlays opens expanded, so its rows are on screen at once.
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartOptionsDialog)),
      );
      expect(container.read(profileLegendProvider).showPlannedProfile, isTrue);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(container.read(profileLegendProvider).showPlannedProfile, isFalse);
    });

    testWidgets('a dive with no linked plan has no Plan row', (tester) async {
      await tester.pumpWidget(dialog(hasPlannedProfile: false));
      // Overlays opens expanded, so its rows are on screen at once.
      await tester.pumpAndSettle();
      expect(find.text('Plan'), findsNothing);
    });

    testWidgets('a plan alone still opens the Overlays section', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          [settingsProvider.overrideWith((ref) => _StubSettingsNotifier())],
          const Scaffold(
            body: ChartOptionsDialog(
              config: ProfileLegendConfig(hasPlannedProfile: true),
              anchorOffset: Offset(300, 0),
              anchorSize: Size(40, 40),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Overlays'), findsOneWidget);
    });
  });

  // Both surfaces that draw a dive's profile, run through one body so the
  // card and full screen cannot drift apart again.
  final surfaces = <String, Widget Function()>{
    'the card': () => Scaffold(
      body: SizedBox(
        width: 800,
        height: 500,
        child: DiveProfileChartHost(dive: _dive()),
      ),
    ),
    'full screen': () => const FullscreenProfilePage(diveId: _diveId),
  };

  for (final MapEntry(key: surface, value: home) in surfaces.entries) {
    group(surface, () {
      Future<void> pump(WidgetTester tester, {ChartSourceOverlay? plan}) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final base = await getBaseOverrides();
        await tester.pumpWidget(
          _app([...base, ..._pageOverrides(plan: plan)], home()),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('draws the plan, named Plan', (tester) async {
        await pump(tester, plan: _planOverlay);

        final chart = _chart(tester);
        expect(chart.hasPlannedProfile, isTrue);
        final plan = chart.overlays!.singleWhere(
          (o) => o.sourceId == 'plan:p1',
        );
        expect(plan.name, 'Plan');
        expect(plan.points, _planOverlay.points);
        expect(plan.color, _planOverlay.color);
        expect(plan.tintByMetric, isFalse);
        // The legend entry the diver reads, not the plan's own name.
        expect(find.text('Depth · Plan'), findsOneWidget);
        expect(find.textContaining(_planOverlay.name), findsNothing);
      });

      testWidgets('switched off, hides the plan but keeps its switch', (
        tester,
      ) async {
        await pump(tester, plan: _planOverlay);
        _container(
          tester,
        ).read(profileLegendProvider.notifier).togglePlannedProfile();
        await tester.pump();

        final chart = _chart(tester);
        expect(chart.overlays, isNull);
        expect(chart.hasPlannedProfile, isTrue);
      });

      testWidgets('a dive with no linked plan offers no switch', (
        tester,
      ) async {
        await pump(tester);

        final chart = _chart(tester);
        expect(chart.overlays, isNull);
        expect(chart.hasPlannedProfile, isFalse);
      });
    });
  }
}
