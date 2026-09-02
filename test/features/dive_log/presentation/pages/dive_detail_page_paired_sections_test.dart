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
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
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

    testWidgets('takes the leading gap of the slot it occupies', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Details is the one section that emits no leading gap of its own;
      // Environment emits the usual 24. A pair renders at the slot of
      // whichever half the diver ordered first, so that is the gap it must
      // inherit -- not whichever half the pair table calls the left one.
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

      expect(environmentFirst - detailsFirst, 24);
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

  group('Cylinders + Weights pairing', () {
    testWidgets('pairs side by side on a wide pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('gas-weights-wide');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(_pairContaining('Cylinders'), findsOneWidget);
      expect(_pairContaining('Weight'), findsOneWidget);

      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final weightPos = tester.getTopLeft(find.text('Weight'));
      expect(cylPos.dx, lessThan(weightPos.dx));
      expect((cylPos.dy - weightPos.dy).abs(), lessThan(4));
    });

    testWidgets('pairs across an intervening Buoyancy section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('gas-weights-gap');
      // The pre-existing default order, which every upgrading user has saved.
      final settings = _settingsWithOrder([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.buoyancy,
        DiveDetailSectionId.tanks,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Cylinders stays on the left even though Weights comes first in the
      // saved order.
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final cylPos = tester.getTopLeft(find.text('Cylinders'));
      final weightPos = tester.getTopLeft(find.text('Weight'));
      expect(cylPos.dx, lessThan(weightPos.dx));
      expect((cylPos.dy - weightPos.dy).abs(), lessThan(4));
    });

    testWidgets('stacks on a narrow pane', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights('gas-weights-narrow');
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      final cylY = tester.getTopLeft(find.text('Cylinders')).dy;
      final weightY = tester.getTopLeft(find.text('Weight')).dy;
      expect(cylY, lessThan(weightY));
    });

    testWidgets('no pairing when the dive carries no weights', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'gas-only',
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
      );
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Cylinders'), findsOneWidget);
      expect(find.text('Weight'), findsNothing);
    });

    testWidgets('no pairing on a gauge dive, where Cylinders is hidden', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithGasAndWeights(
        'gauge-dive',
      ).copyWith(diveMode: DiveMode.gauge);
      final settings = _settingsWithOrder([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Cylinders'), findsNothing);
      expect(find.text('Weight'), findsOneWidget);
    });
  });
}
