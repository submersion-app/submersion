import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../widgets/buoyancy_outcome_fixture.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that doesn't access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppSettings _settingsWithVisibleSections(List<DiveDetailSectionId> visible) {
  final sections = DiveDetailSectionId.values
      .map(
        (id) => DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
      )
      .toList();
  return AppSettings(diveDetailSections: sections);
}

Widget _buildTestWidget({
  required Dive dive,
  required AppSettings settings,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(
        dive.id,
      ).overrideWith((ref) async => <DiveDataSource>[]),
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier(settings)),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailPage(diveId: dive.id),
    ),
  );
}

List<Override> _renderOverrides(
  String diveId,
  SharedPreferences prefs, {
  List<BuddyWithRole> buddies = const [],
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  buddiesForDiveProvider(diveId).overrideWith((ref) async => buddies),
  diveSightingsProvider(diveId).overrideWith((ref) async => <Sighting>[]),
  buddySignaturesForDiveProvider(
    diveId,
  ).overrideWith((ref) async => <Signature>[]),
  surfaceIntervalProvider(diveId).overrideWith((ref) async => null),
  tankPressuresProvider(
    diveId,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
];

/// Finds the ResponsiveSectionPair whose subtree contains [label].
Finder _pairContaining(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(ResponsiveSectionPair),
);

/// Top-left of the card holding [label].
///
/// Compares cards rather than titles where a header carries a button that
/// sets its title lower than its neighbour's, as Buoyancy's does.
Offset _cardTopLeft(WidgetTester tester, String label) => tester.getTopLeft(
  find.ancestor(of: find.text(label), matching: find.byType(Card)).first,
);

/// A dive with environment data so the Environment (Conditions) card renders.
Dive _diveWithConditions(String id) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 15, 10, 0),
  airTemp: 24.0,
  waterTemp: 20.0,
  currentStrength: CurrentStrength.moderate,
);

/// A dive with entry/exit fixes so the Surface GPS card renders.
Dive _diveWithGps(String id) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 15, 10, 0),
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
);

/// A dive with a cylinder and a weight so both of those cards render.
Dive _diveWithGasAndWeights(String id) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 15, 10, 0),
  tanks: const [
    DiveTank(
      id: 't1',
      name: 'AL80',
      volume: 11.1,
      workingPressure: 207,
      startPressure: 200,
      endPressure: 50,
    ),
  ],
  weights: [
    DiveWeight(id: 'w1', diveId: id, weightType: WeightType.belt, amountKg: 6),
  ],
);

/// A dive with a cylinder and a short profile, so the Cylinders card renders
/// and Gas consumption by segment has a profile to segment.
Dive _diveWithGasAndProfile(String id) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 15, 10, 0),
  tanks: const [
    DiveTank(
      id: 't1',
      name: 'AL80',
      volume: 11.1,
      workingPressure: 207,
      startPressure: 200,
      endPressure: 50,
    ),
  ],
  profile: List.generate(
    6,
    (i) => DiveProfilePoint(
      timestamp: i * 60,
      depth: i < 3 ? i * 8.0 : (5 - i) * 8.0,
    ),
  ),
);

const _sacTitle = 'Gas consumption by segment';
const _buoyancyTitle = 'BUOYANCY';

/// One time-interval SAC segment, so the Gas consumption card has a row.
final _sacAnalysis = ProfileAnalysis.empty().copyWith(
  sacSegments: const [
    SacSegment(
      startTimestamp: 0,
      endTimestamp: 300,
      avgDepth: 18.0,
      minDepth: 0.0,
      maxDepth: 24.0,
      sacRate: 0.8,
      gasConsumed: 4.0,
      segmentationType: SacSegmentationType.timeInterval,
    ),
  ],
);

/// Drives the Gas consumption card from [analysis]; null = no segments.
///
/// Time-interval segmentation reads the segments straight off the analysis,
/// so no phase or gas-switch provider is in play.
List<Override> _sacOverrides(Dive dive, ProfileAnalysis? analysis) => [
  profileAnalysisProvider(dive.id).overrideWith((ref) async => analysis),
  ..._sacSupportOverrides(dive),
];

/// Everything the Gas consumption card reads besides the analysis itself.
List<Override> _sacSupportOverrides(Dive dive) => [
  selectedSegmentationProvider.overrideWith(
    (ref) => SacSegmentationType.timeInterval,
  ),
  gasSwitchesProvider(
    dive.id,
  ).overrideWith((ref) async => <GasSwitchWithTank>[]),
  sourceProfilesProvider(
    dive.id,
  ).overrideWith((ref) async => <String, SourceProfile>{}),
];

/// Overrides the buoyancy model for [dive]; [outcome] null = unmodelable.
Override _buoyancyOverride(Dive dive, BuoyancyTwinOutcome? outcome) =>
    buoyancyTwinProvider(dive.id).overrideWith((ref) async => outcome);

TideRecord _tideRecord(String diveId) => TideRecord(
  id: 'tide-1',
  diveId: diveId,
  heightMeters: 1.6,
  tideState: TideState.rising,
  rateOfChange: 0.4,
  highTideHeight: 2.4,
  highTideTime: DateTime.utc(2026, 3, 15, 14),
  lowTideHeight: 0.4,
  lowTideTime: DateTime.utc(2026, 3, 15, 8),
  createdAt: DateTime.utc(2026, 3, 15, 12),
);

/// Overrides the healed tide record for [dive]; [record] null = no tide data.
Override _tideOverride(Dive dive, TideRecord? record) =>
    healedTideRecordProvider((
      diveId: dive.id,
      location: dive.site?.location,
      entryTime: dive.effectiveEntryTime,
    )).overrideWith((ref) async => record);

/// Section config listing [order] as the visible sections, in that order.
AppSettings _settingsWithOrder(List<DiveDetailSectionId> order) {
  return AppSettings(
    diveDetailSections: [
      for (final id in order) DiveDetailSectionConfig(id: id, visible: true),
      for (final id in DiveDetailSectionId.values)
        if (!order.contains(id))
          DiveDetailSectionConfig(id: id, visible: false),
    ],
  );
}

final _buddy = BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  role: DiveRole.builtInBuddy(),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Details + Conditions pairing', () {
    testWidgets('pairs side by side on a wide pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithConditions('pair-wide');
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.details,
        DiveDetailSectionId.environment,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Both cards live inside one ResponsiveSectionPair.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Details'), findsOneWidget);
      expect(_pairContaining('Environment'), findsOneWidget);

      // Side by side: Details header is left of the Environment header, at
      // roughly the same vertical position.
      final detailsPos = tester.getTopLeft(find.text('Details'));
      final envPos = tester.getTopLeft(find.text('Environment'));
      expect(detailsPos.dx, lessThan(envPos.dx));
      expect((detailsPos.dy - envPos.dy).abs(), lessThan(4));
    });

    testWidgets('stacks (not side-by-side) on a narrow pane', (tester) async {
      // 700px pane => ~668px content width, below the pair's 700px threshold,
      // but wide enough to avoid the header stat-row overflow.
      await tester.binding.setSurfaceSize(const Size(700, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithConditions('pair-narrow');
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.details,
        DiveDetailSectionId.environment,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Still wrapped in a ResponsiveSectionPair, but stacked: Environment sits
      // below Details.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final detailsY = tester.getTopLeft(find.text('Details')).dy;
      final envY = tester.getTopLeft(find.text('Environment')).dy;
      expect(detailsY, lessThan(envY));
    });

    testWidgets('no pairing when Conditions data is absent', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Empty dive => _hasEnvironmentData is false, Environment renders nothing.
      final dive = Dive(id: 'no-cond', dateTime: DateTime(2026, 3, 15, 10, 0));
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.details,
        DiveDetailSectionId.environment,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Details renders full-width; no pair widget, no Environment card.
      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Environment'), findsNothing);
    });

    testWidgets('still pairs when another section sits between them', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithConditions('reordered');
      // Put another visible section between details and environment.
      final settings = _settingsWithOrder([
        DiveDetailSectionId.details,
        DiveDetailSectionId.notes,
        DiveDetailSectionId.environment,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Pairing looks ahead past Notes, so the pair still forms at Details'
      // slot and Notes drops below it.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Details'), findsOneWidget);
      expect(_pairContaining('Environment'), findsOneWidget);

      final detailsY = tester.getTopLeft(find.text('Details')).dy;
      final envY = tester.getTopLeft(find.text('Environment')).dy;
      final notesY = tester.getTopLeft(find.text('Notes')).dy;
      expect((detailsY - envY).abs(), lessThan(4));
      expect(notesY, greaterThan(detailsY));
    });

    testWidgets('sits at the same height whichever half is ordered first', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Gaps are placed between sections, never owned by one of them, so the
      // pair's position depends only on its slot -- not on whether the diver
      // put Details or Environment first, and not on which half the pair
      // table calls the left one.
      final dive = _diveWithConditions('gap-slot');

      Future<double> pairTop(List<DiveDetailSectionId> order) async {
        // Tear the tree down first: pumping a second ProviderScope over the
        // live one keeps the existing SettingsNotifier, so the new section
        // order would never reach the page.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _buildTestWidget(
            dive: dive,
            settings: _settingsWithOrder(order),
            extraOverrides: _renderOverrides(dive.id, prefs),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ResponsiveSectionPair), findsOneWidget);
        // Details stays on the left either way.
        expect(
          tester.getTopLeft(find.text('Details')).dx,
          lessThan(tester.getTopLeft(find.text('Environment')).dx),
        );
        return tester.getTopLeft(find.byType(ResponsiveSectionPair)).dy;
      }

      final detailsFirst = await pairTop([
        DiveDetailSectionId.details,
        DiveDetailSectionId.environment,
      ]);
      final environmentFirst = await pairTop([
        DiveDetailSectionId.environment,
        DiveDetailSectionId.details,
      ]);

      expect(environmentFirst, detailsFirst);
    });
  });

  group('Buddies + Signatures pairing', () {
    testWidgets('pairs side by side when the dive has buddies (wide pane)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'buddies-wide',
        dateTime: DateTime(2026, 3, 15, 10, 0),
      );
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs, buddies: [_buddy]),
        ),
      );
      await tester.pumpAndSettle();

      // Buddies + Signatures are inside one pair. "Alice" appears in both the
      // Buddies card and the Signatures card, so match one-or-more.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Alice'), findsWidgets);
    });

    testWidgets('no pairing for a solo dive (no buddies, no course)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(id: 'solo', dateTime: DateTime(2026, 3, 15, 10, 0));
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Signatures self-erases, Buddies renders full-width: no pair.
      expect(find.byType(ResponsiveSectionPair), findsNothing);
    });
  });

  group('Surface GPS + Tide pairing', () {
    testWidgets('pairs side by side on a wide pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGps('gps-tide-wide');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.tide,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _tideOverride(dive, _tideRecord(dive.id)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SurfaceGpsSection),
          matching: find.byType(ResponsiveSectionPair),
        ),
        findsOneWidget,
      );
      expect(_pairContaining('Tide'), findsOneWidget);

      // Surface GPS sits to the left of Tide, at the same vertical offset.
      final gpsPos = tester.getTopLeft(find.text('Surface GPS'));
      final tidePos = tester.getTopLeft(find.text('Tide'));
      expect(gpsPos.dx, lessThan(tidePos.dx));
      expect((gpsPos.dy - tidePos.dy).abs(), lessThan(4));
    });

    testWidgets('pairs across an intervening Water Conditions section', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGps('gps-tide-gap');
      // The pre-existing default order, which every upgrading user has saved.
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tide,
        DiveDetailSectionId.reefHealth,
        DiveDetailSectionId.surfaceGps,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _tideOverride(dive, _tideRecord(dive.id)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Surface GPS stays on the left even though Tide comes first in the
      // saved order.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final gpsPos = tester.getTopLeft(find.text('Surface GPS'));
      final tidePos = tester.getTopLeft(find.text('Tide'));
      expect(gpsPos.dx, lessThan(tidePos.dx));
      expect((gpsPos.dy - tidePos.dy).abs(), lessThan(4));
    });

    testWidgets('stacks on a narrow pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGps('gps-tide-narrow');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.tide,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _tideOverride(dive, _tideRecord(dive.id)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final gpsY = tester.getTopLeft(find.text('Surface GPS')).dy;
      final tideY = tester.getTopLeft(find.text('Tide')).dy;
      expect(gpsY, lessThan(tideY));
    });

    testWidgets('no pairing when the dive has no tide data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGps('gps-no-tide');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.tide,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _tideOverride(dive, null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.byType(SurfaceGpsSection), findsOneWidget);
      expect(find.text('Tide'), findsNothing);
    });

    testWidgets('no pairing when the dive has no GPS fixes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(id: 'no-gps', dateTime: DateTime(2026, 3, 15, 10, 0));
      final settings = _settingsWithOrder([
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.tide,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _tideOverride(dive, _tideRecord(dive.id)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.byType(SurfaceGpsSection), findsNothing);
      expect(find.text('Tide'), findsOneWidget);
    });
  });

  group('Cylinders + Gas consumption pairing', () {
    testWidgets('pairs side by side on a wide pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-wide');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacOverrides(dive, _sacAnalysis),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Cylinders'), findsOneWidget);
      expect(_pairContaining(_sacTitle), findsOneWidget);

      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final sacPos = tester.getTopLeft(find.text(_sacTitle));
      expect(cylPos.dx, lessThan(sacPos.dx));
      expect((cylPos.dy - sacPos.dy).abs(), lessThan(4));
    });

    testWidgets('fits side by side at the 700px threshold', (tester) async {
      // 732px pane => 700px content width, the narrowest the row renders at.
      await tester.binding.setSurfaceSize(const Size(732, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-threshold');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacOverrides(dive, _sacAnalysis),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final sacPos = tester.getTopLeft(find.text(_sacTitle));
      expect(cylPos.dx, lessThan(sacPos.dx));
      expect((cylPos.dy - sacPos.dy).abs(), lessThan(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes Gas consumption\'s slot in a saved order', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-saved');
      // The pre-existing default order: Gas consumption near the top,
      // Cylinders below Details.
      final settings = _settingsWithOrder([
        DiveDetailSectionId.sacSegments,
        DiveDetailSectionId.details,
        DiveDetailSectionId.tanks,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacOverrides(dive, _sacAnalysis),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Cylinders stays on the left, and the row sits above Details.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final sacPos = tester.getTopLeft(find.text(_sacTitle));
      expect(cylPos.dx, lessThan(sacPos.dx));
      expect((cylPos.dy - sacPos.dy).abs(), lessThan(4));
      expect(cylPos.dy, lessThan(tester.getTopLeft(find.text('Details')).dy));
    });

    testWidgets('stacks Cylinders directly above it on a narrow pane', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(700, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-narrow');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacOverrides(dive, _sacAnalysis),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final cylY = tester.getTopLeft(find.text('Cylinders')).dy;
      final sacY = tester.getTopLeft(find.text(_sacTitle)).dy;
      expect(cylY, lessThan(sacY));
    });

    testWidgets('keeps the row when the analysis briefly goes null', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-transient');
      // Starts good, then settles to null the way a mid-sync empty-profile
      // read does. The card keeps its last good segments, so the pair must
      // too, or the row would split while the card stayed.
      final analysis = StateProvider<ProfileAnalysis?>((ref) => _sacAnalysis);
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacSupportOverrides(dive),
            profileAnalysisProvider(
              dive.id,
            ).overrideWith((ref) async => ref.watch(analysis)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      ).read(analysis.notifier).state = null;
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final sacPos = tester.getTopLeft(find.text(_sacTitle));
      expect(cylPos.dx, lessThan(sacPos.dx));
      expect((cylPos.dy - sacPos.dy).abs(), lessThan(4));
    });

    testWidgets('an analysis reload does not rebuild the page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-sac-reload');
      final analysis = StateProvider<ProfileAnalysis?>((ref) => _sacAnalysis);
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacSupportOverrides(dive),
            profileAnalysisProvider(
              dive.id,
            ).overrideWith((ref) async => ref.watch(analysis)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      // The pair gate is the page's only read of the analysis. A reload
      // passes through loading; if the gate read that as "no segments" the
      // whole page would rebuild twice into the same layout.
      var pageRebuilds = 0;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is DiveDetailPage) pageRebuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);

      ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      ).read(analysis.notifier).state = _sacAnalysis.copyWith(
        sacSegments: [..._sacAnalysis.sacSegments!],
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(pageRebuilds, 0);
    });

    testWidgets('no pairing when the dive has no SAC segments', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndProfile('gas-no-sac');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.sacSegments,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            ..._sacOverrides(dive, null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Cylinders'), findsOneWidget);
      expect(find.text(_sacTitle), findsNothing);
    });
  });

  group('Weights + Buoyancy pairing', () {
    testWidgets('pairs side by side on a wide pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('weights-buoyancy-wide');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Weight'), findsOneWidget);
      expect(_pairContaining(_buoyancyTitle), findsOneWidget);

      final weightPos = _cardTopLeft(tester, 'Weight');
      final buoyancyPos = _cardTopLeft(tester, _buoyancyTitle);
      expect(weightPos.dx, lessThan(buoyancyPos.dx));
      expect((weightPos.dy - buoyancyPos.dy).abs(), lessThan(4));
    });

    testWidgets('fits side by side at the 700px threshold', (tester) async {
      await tester.binding.setSurfaceSize(const Size(732, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('weights-buoyancy-threshold');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final weightPos = _cardTopLeft(tester, 'Weight');
      final buoyancyPos = _cardTopLeft(tester, _buoyancyTitle);
      expect(weightPos.dx, lessThan(buoyancyPos.dx));
      expect((weightPos.dy - buoyancyPos.dy).abs(), lessThan(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps Weights on the left when Buoyancy is ordered first', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('weights-buoyancy-reversed');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.buoyancy,
        DiveDetailSectionId.weights,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final weightPos = _cardTopLeft(tester, 'Weight');
      final buoyancyPos = _cardTopLeft(tester, _buoyancyTitle);
      expect(weightPos.dx, lessThan(buoyancyPos.dx));
      expect((weightPos.dy - buoyancyPos.dy).abs(), lessThan(4));
    });

    testWidgets('stacks Weights directly above Buoyancy on a narrow pane', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(700, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('weights-buoyancy-narrow');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final weightY = tester.getTopLeft(find.text('Weight')).dy;
      final buoyancyY = tester.getTopLeft(find.text(_buoyancyTitle)).dy;
      expect(weightY, lessThan(buoyancyY));
    });

    testWidgets('no pairing when the buoyancy model has no result', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('weights-no-buoyancy');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text(_buoyancyTitle), findsNothing);
    });

    testWidgets('no pairing when the dive carries no weights', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights(
        'buoyancy-only',
      ).copyWith(weights: const []);
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._renderOverrides(dive.id, prefs),
            _buoyancyOverride(dive, buoyancyOutcome()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.text(_buoyancyTitle), findsOneWidget);
    });
  });
}
