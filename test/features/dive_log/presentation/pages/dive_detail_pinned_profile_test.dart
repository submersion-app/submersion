import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A 46-minute, 277-point dive, so the page is tall enough to scroll the
/// profile card away.
List<DiveProfilePoint> _profile(double maxDepth) => [
  for (var t = 0; t <= 46 * 60; t += 10)
    DiveProfilePoint(
      timestamp: t,
      depth: t < 150 ? t / 150 * maxDepth : (t > 2640 ? 0 : maxDepth - 3),
    ),
];

Dive _dive(String id, double maxDepth) =>
    createTestDiveWithBottomTime(id: id).copyWith(profile: _profile(maxDepth));

List<Override> _diveOverrides(Dive dive) => [
  diveProvider(dive.id).overrideWith((ref) async => dive),
  diveDataSourcesProvider(
    dive.id,
  ).overrideWith((ref) async => <DiveDataSource>[]),
  sourceProfilesProvider(
    dive.id,
  ).overrideWith((ref) async => <String, SourceProfile>{}),
  gasSwitchesProvider(
    dive.id,
  ).overrideWith((ref) async => <GasSwitchWithTank>[]),
  tankPressuresProvider(
    dive.id,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
  sourceProfileAnalysisProvider((diveId: dive.id, sourceId: null)).overrideWith(
    (ref) async => ProfileAnalysisService().analyze(
      diveId: dive.id,
      depths: [for (final p in dive.profile) p.depth],
      timestamps: [for (final p in dive.profile) p.timestamp],
    ),
  ),
];

void main() {
  final diveA = _dive('dive-a', 30);
  final diveB = _dive('dive-b', 18);

  Future<void> pumpPage(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    ValueNotifier<String>? diveId,
    MockSettingsNotifier? notifier,
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(
      settingsNotifier: notifier ?? MockSettingsNotifier(settings),
    );
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      original?.call(d);
    };
    final id = diveId ?? ValueNotifier(diveA.id);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          ..._diveOverrides(diveA),
          ..._diveOverrides(diveB),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: id,
              builder: (context, value, _) =>
                  DiveDetailPage(diveId: value, embedded: true),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> scrollPastProfile(WidgetTester tester) async {
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
  }

  // Scrolling the card's top past the page's pins a live copy of the whole
  // card that squashes: its chart keeps its axes and lines as it shortens.
  testWidgets('the card pins and its chart squashes as it scrolls away', (
    tester,
  ) async {
    await pumpPage(tester);
    // The card in the page reports nothing: only the pinned copy does.
    final inPage = tester.widget<DiveProfileChartHost>(
      find.byType(DiveProfileChartHost),
    );
    expect(inPage.onPlotFrame, isNull);
    final cardTop = tester.getTopLeft(find.byType(DiveDetailProfileSection)).dy;
    final viewportTop = tester.getTopLeft(find.byType(Scrollable).first).dy;
    final restHeight = tester.getSize(find.byType(DiveProfileChart)).height;

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(cardTop - viewportTop + 80);
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }

    final copy = find.byWidgetPredicate(
      (w) => w is DiveDetailProfileSection && w.fillHeight,
    );
    expect(copy, findsOneWidget);
    final squashed = tester.getSize(
      find.descendant(of: copy, matching: find.byType(DiveProfileChart)),
    );
    expect(squashed.height, closeTo(restHeight - 80, 1));
    expect(
      tester
          .widget<DiveProfileChartHost>(
            find.descendant(
              of: copy,
              matching: find.byType(DiveProfileChartHost),
            ),
          )
          .onPlotFrame,
      isNotNull,
    );
  });

  testWidgets('no strip while the profile card is on screen', (tester) async {
    await pumpPage(tester);
    expect(find.byType(PinnedProfileOverlay), findsOneWidget);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('the strip appears after scrolling past the profile', (
    tester,
  ) async {
    await pumpPage(tester);
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsOneWidget);
  });

  bool overlayEnabled(WidgetTester tester) => tester
      .widget<PinnedProfileOverlay>(find.byType(PinnedProfileOverlay))
      .enabled;

  testWidgets('no strip with the setting off', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(pinProfileOnScroll: false),
    );
    expect(overlayEnabled(tester), isFalse);
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('no strip in the list layout', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(diveDetailLayout: DiveDetailLayout.list),
    );
    expect(overlayEnabled(tester), isFalse);
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  // The page keeps its place when the strip is turned on or off: the scroll
  // view is not rebuilt under a different parent (review M3).
  testWidgets('turning the setting off keeps the scroll position', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await pumpPage(tester, notifier: notifier);
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(300);
    await tester.pump();

    await notifier.setPinProfileOnScroll(false);
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      300,
    );
  });

  testWidgets('no strip when the profile section is hidden', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(
        diveDetailSections: [
          for (final s in DiveDetailSectionConfig.defaultSections)
            s.id == DiveDetailSectionId.profile
                ? s.copyWith(visible: false)
                : s,
        ],
      ),
    );
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets(
    'switching dives in the pane rebuilds the strip for the new dive',
    (tester) async {
      final id = ValueNotifier(diveA.id);
      await pumpPage(tester, diveId: id);
      await scrollPastProfile(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      container.read(profileTrackingIndexProvider(diveA.id).notifier).state =
          40;
      await tester.pump();

      id.value = diveB.id;
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await scrollPastProfile(tester);

      final strip = tester.widget<PinnedProfileStrip>(
        find.byType(PinnedProfileStrip),
      );
      expect(strip.dive.id, diveB.id);
      expect(container.read(profileTrackingIndexProvider(diveB.id)), isNull);
    },
  );
}
