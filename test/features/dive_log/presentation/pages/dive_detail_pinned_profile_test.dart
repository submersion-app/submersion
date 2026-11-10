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
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart';
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
  gasSwitchesProvider(dive.id).overrideWith((ref) async => <GasSwitchWithTank>[]),
  tankPressuresProvider(
    dive.id,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
  sourceProfileAnalysisProvider((
    diveId: dive.id,
    sourceId: null,
  )).overrideWith(
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
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
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
        overrides: [...base, ..._diveOverrides(diveA), ..._diveOverrides(diveB)],
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

  testWidgets('no overlay with the setting off', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(pinProfileOnScroll: false),
    );
    expect(find.byType(PinnedProfileOverlay), findsNothing);
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('no overlay in the list layout', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(diveDetailLayout: DiveDetailLayout.list),
    );
    expect(find.byType(PinnedProfileOverlay), findsNothing);
  });

  testWidgets('no strip when the profile section is hidden', (tester) async {
    await pumpPage(
      tester,
      settings: AppSettings(
        diveDetailSections: [
          for (final s in DiveDetailSectionConfig.defaultSections)
            s.id == DiveDetailSectionId.profile ? s.copyWith(visible: false) : s,
        ],
      ),
    );
    await scrollPastProfile(tester);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('switching dives in the pane rebuilds the strip for the new dive', (
    tester,
  ) async {
    final id = ValueNotifier(diveA.id);
    await pumpPage(tester, diveId: id);
    await scrollPastProfile(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
    container.read(profileTrackingIndexProvider(diveA.id).notifier).state = 40;
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
  });
}
