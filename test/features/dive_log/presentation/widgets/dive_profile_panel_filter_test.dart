import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// The table-mode profile panel previews the highlighted dive. The highlight
// outlives a filter change, so the panel must not preview a dive the active
// filter has taken out of the list the table shows.

const _houseReef = DiveSite(id: 'site-house', name: 'House Reef');
const _farWall = DiveSite(id: 'site-far', name: 'Far Wall');

Dive _dive(String id, int number, DiveSite site) {
  return Dive(
    id: id,
    diveNumber: number,
    dateTime: DateTime(2026, 3, number, 10),
    maxDepth: 20.0,
    runtime: const Duration(minutes: 40),
    site: site,
    tanks: const [],
    profile: List.generate(
      10,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i < 5 ? i * 4.0 : (9 - i) * 4.0,
      ),
    ),
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
}

final _houseDive = _dive('dive-house', 1, _houseReef);
final _farDive = _dive('dive-far', 2, _farWall);

/// The unfiltered dive source. Everything downstream of it (the filter, the
/// sort, the table's list) is the real provider chain.
class _StubDiveListNotifier extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _StubDiveListNotifier(List<Dive> dives) : super(AsyncValue.data(dives));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<Override> _perDiveOverrides(Dive dive) => [
  diveProvider(dive.id).overrideWith((ref) => Future.value(dive)),
  diveDataSourcesProvider(
    dive.id,
  ).overrideWith((ref) => Future.value(<DiveDataSource>[])),
  sourceProfilesProvider(
    dive.id,
  ).overrideWith((ref) => Future.value(<String, SourceProfile>{})),
  profileAnalysisProvider(dive.id).overrideWith((ref) => Future.value(null)),
  gasSwitchesProvider(dive.id).overrideWith((ref) => Future.value([])),
  tankPressuresProvider(dive.id).overrideWith((ref) => Future.value({})),
];

Future<ProviderContainer> _pumpPanel(
  WidgetTester tester, {
  required String highlightedId,
}) async {
  await tester.pumpWidget(
    testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveListNotifierProvider.overrideWith(
          (ref) => _StubDiveListNotifier([_houseDive, _farDive]),
        ),
        highlightedDiveIdProvider.overrideWith((ref) => highlightedId),
        ..._perDiveOverrides(_houseDive),
        ..._perDiveOverrides(_farDive),
      ],
      child: const SizedBox(height: 350, width: 600, child: DiveProfilePanel()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(DiveProfilePanel)),
  );
}

void main() {
  group('DiveProfilePanel and the active dive filter', () {
    testWidgets('stops previewing a highlighted dive the filter excludes', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, highlightedId: 'dive-far');
      expect(find.text('Far Wall'), findsOneWidget);

      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        siteId: 'site-house',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Far Wall'), findsNothing);
      expect(find.text('Select a dive to view its profile'), findsOneWidget);
    });

    // A filter the highlighted dive satisfies (a tag chip tapped in the
    // master-detail pane, say) must not cost the diver their place.
    testWidgets('keeps previewing a highlighted dive the filter still lists', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, highlightedId: 'dive-far');

      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        siteId: 'site-far',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Far Wall'), findsOneWidget);
    });

    // The highlight itself is left alone, only ignored while filtered out, so
    // relaxing the filter brings the preview back.
    testWidgets('previews the dive again once the filter lists it again', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, highlightedId: 'dive-far');
      final filter = container.read(diveFilterProvider.notifier);

      filter.state = const DiveFilterState(siteId: 'site-house');
      await tester.pump();
      await tester.pump();
      expect(find.text('Far Wall'), findsNothing);

      filter.state = const DiveFilterState();
      await tester.pump();
      await tester.pump();

      expect(find.text('Far Wall'), findsOneWidget);
      expect(container.read(highlightedDiveIdProvider), 'dive-far');
    });
  });
}
