import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_section_fold.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);

  @override
  Future<void> setDiveDetailSectionExpanded(
    DiveDetailSectionId id,
    bool expanded,
  ) async {
    state = state.copyWith(
      diveDetailSections: [
        for (final section in state.diveDetailSections)
          section.id == id ? section.copyWith(expanded: expanded) : section,
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sections that return early with empty dive data (no extra providers needed).
const _earlyReturnSections = [
  DiveDetailSectionId.decoStatus,
  DiveDetailSectionId.sacSegments,
  DiveDetailSectionId.environment,
  DiveDetailSectionId.altitude,
  DiveDetailSectionId.weights,
  DiveDetailSectionId.tanks,
  DiveDetailSectionId.equipment,
  DiveDetailSectionId.tags,
  DiveDetailSectionId.customFields,
];

/// Sections whose builders only need context + dive (no Riverpod providers).
const _simpleRenderSections = [DiveDetailSectionId.notes];

/// Build settings with only specified sections visible.
AppSettings _settingsWithVisibleSections(
  List<DiveDetailSectionId> visible, {
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  List<DiveDetailSectionId> expanded = const [],
}) {
  final sections = DiveDetailSectionId.values
      .map(
        (id) => DiveDetailSectionConfig(
          id: id,
          visible: visible.contains(id),
          expanded: expanded.contains(id),
        ),
      )
      .toList();
  return AppSettings(diveDetailSections: sections, diveDetailLayout: layout);
}

/// Build a minimal ProviderScope + MaterialApp for DiveDetailPage.
Widget _buildTestWidget({
  required Dive dive,
  required AppSettings settings,
  List<Override> extraOverrides = const [],
  bool embedded = false,
  _MockSettingsNotifier? notifier,
}) {
  return ProviderScope(
    overrides: [
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(
        dive.id,
      ).overrideWith((ref) async => <DiveDataSource>[]),
      settingsProvider.overrideWith(
        (ref) => notifier ?? _MockSettingsNotifier(settings),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailPage(diveId: dive.id, embedded: embedded),
    ),
  );
}

/// Provider overrides needed for sections that always render their widgets.
List<Override> _alwaysRenderOverrides(
  String diveId,
  SharedPreferences prefs,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  buddiesForDiveProvider(diveId).overrideWith((ref) async => <BuddyWithRole>[]),
  diveSightingsProvider(diveId).overrideWith((ref) async => <Sighting>[]),
  buddySignaturesForDiveProvider(
    diveId,
  ).overrideWith((ref) async => <Signature>[]),
  surfaceIntervalProvider(diveId).overrideWith((ref) async => null),
  tankPressuresProvider(
    diveId,
  ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
];

/// A minimal dive with all collections empty (triggers early-return branches).
final _emptyDive = Dive(
  id: 'test-dive-1',
  dateTime: DateTime(2026, 3, 15, 10, 0),
);

/// A dive with tags and notes (triggers widget-building branches).
final _diveWithContent = Dive(
  id: 'test-dive-2',
  dateTime: DateTime(2026, 3, 15, 10, 0),
  notes: 'Great dive, saw a lot of fish.',
  tags: [
    Tag(
      id: 'tag-1',
      name: 'Night Dive',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ],
  customFields: [
    const DiveCustomField(id: 'cf-1', key: 'Instructor', value: 'Jane'),
  ],
);

/// A dive with rich data to exercise non-early-return builder paths.
final _richDive = Dive(
  id: 'test-dive-3',
  dateTime: DateTime(2026, 3, 15, 10, 0),
  altitude: 1500.0,
  airTemp: 22.0,
  waterTemp: 18.0,
  weightAmount: 5.0,
  weightType: WeightType.integrated,
  weights: [
    const DiveWeight(
      id: 'w-1',
      diveId: 'test-dive-3',
      weightType: WeightType.belt,
      amountKg: 4.0,
    ),
  ],
  tanks: [
    const DiveTank(
      id: 'tank-1',
      volume: 11.1,
      startPressure: 200.0,
      endPressure: 50.0,
    ),
  ],
  equipment: [
    const EquipmentItem(
      id: 'eq-1',
      name: 'BCD',
      type: EquipmentType.bcd,
      status: EquipmentStatus.active,
    ),
  ],
);

/// A dive with a depth/time profile, so the chart section has something to
/// draw.
final _diveWithProfile = Dive(
  id: 'test-dive-4',
  dateTime: DateTime(2026, 3, 15, 10, 0),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DiveDetailPage section config rendering', () {
    testWidgets('renders with all sections invisible (only fixed header)', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections([]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _emptyDive, settings: settings),
      );
      await tester.pumpAndSettle();

      // Page renders — header is always shown (dive number, date)
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders early-return sections with empty dive data', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections(_earlyReturnSections);

      await tester.pumpWidget(
        _buildTestWidget(dive: _emptyDive, settings: settings),
      );
      await tester.pumpAndSettle();

      // Page renders without errors — all sections return [] due to empty data
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders notes section with dive content', (tester) async {
      final settings = _settingsWithVisibleSections(_simpleRenderSections);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Notes section rendered with dive notes text
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
    });

    testWidgets('renders tags section when dive has tags', (tester) async {
      final settings = _settingsWithVisibleSections([DiveDetailSectionId.tags]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Tags section rendered with tag name
      expect(find.text('Night Dive'), findsOneWidget);
    });

    testWidgets('renders custom fields section when dive has custom fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.customFields,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Custom fields section rendered (key has trailing colon)
      expect(find.text('Instructor:'), findsOneWidget);
      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets('hidden sections do not render their content', (tester) async {
      // Only notes is visible; tags and customFields are invisible
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Notes renders
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
      // Tags and custom fields do NOT render
      expect(find.text('Night Dive'), findsNothing);
      expect(find.text('Instructor:'), findsNothing);
    });

    testWidgets('sections render in config order', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Put notes before tags (reversed from default)
      final settings = AppSettings(
        diveDetailSections: [
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.notes,
            visible: true,
          ),
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.tags,
            visible: true,
          ),
          // All others invisible
          ...DiveDetailSectionId.values
              .where(
                (id) =>
                    id != DiveDetailSectionId.notes &&
                    id != DiveDetailSectionId.tags,
              )
              .map((id) => DiveDetailSectionConfig(id: id, visible: false)),
        ],
      );

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Both sections render
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
      expect(find.text('Night Dive'), findsOneWidget);
    });

    testWidgets('early-return sections plus content sections together', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        ..._earlyReturnSections,
        ..._simpleRenderSections,
        DiveDetailSectionId.tags,
        DiveDetailSectionId.customFields,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // Content sections render
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
      expect(find.text('Night Dive'), findsOneWidget);
      expect(find.text('Instructor:'), findsOneWidget);
    });

    testWidgets('renders dataSources section with empty data sources', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.dataSources,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _emptyDive, settings: settings),
      );
      await tester.pumpAndSettle();

      // Page renders with data sources section (empty state)
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders buddies and sightings sections with empty data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.sightings,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _emptyDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_emptyDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Page renders without errors
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders signatures section without course', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.signatures,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _emptyDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_emptyDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Page renders — no instructor signature since courseId is null
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders details section with surface interval provider', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _emptyDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_emptyDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Details section renders
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders all sections together with empty dive data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // All sections visible — exercises every builder closure
      final settings = _settingsWithVisibleSections(
        DiveDetailSectionId.values.toList(),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _emptyDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_emptyDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Page fully renders with all sections
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders altitude section when dive has altitude data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.altitude,
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders environment section when dive has env data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.environment,
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders weights section when dive has weights', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.weights,
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders tanks section when dive has tanks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders equipment section when dive has equipment', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.equipment,
        DiveDetailSectionId.details,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('renders all data-bearing sections with rich dive', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 10000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections(
        DiveDetailSectionId.values.toList(),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _richDive,
          settings: settings,
          extraOverrides: _alwaysRenderOverrides(_richDive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // All builder closures are exercised with data present
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('buddies section shows the Me row with the localized role '
        'when diverRoleId is set', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'test-dive-role',
        dateTime: DateTime(2026, 3, 15, 10, 0),
        diverRoleId: DiveRole.rearGuardId,
      );
      final buddy = Buddy(
        id: 'b1',
        name: 'Alice',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final rearGuard = DiveRole(
        id: DiveRole.rearGuardId,
        name: 'Rear Guard',
        isBuiltIn: true,
        sortOrder: 6,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            buddiesForDiveProvider(dive.id).overrideWith(
              (ref) async => [
                BuddyWithRole(buddy: buddy, role: DiveRole.builtInBuddy()),
              ],
            ),
            diveSightingsProvider(
              dive.id,
            ).overrideWith((ref) async => <Sighting>[]),
            buddySignaturesForDiveProvider(
              dive.id,
            ).overrideWith((ref) async => <Signature>[]),
            surfaceIntervalProvider(dive.id).overrideWith((ref) async => null),
            tankPressuresProvider(
              dive.id,
            ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
            allDiveRolesProvider.overrideWith((ref) async => [rearGuard]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Me row above the buddy row, with the localized role name.
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Rear Guard'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      final meY = tester.getCenter(find.text('Me')).dy;
      final aliceY = tester.getCenter(find.text('Alice')).dy;
      expect(meY, lessThan(aliceY));
    });

    testWidgets('buddies section shows the Me row even with no buddies, '
        'and an unknown role id falls back to the raw slug', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'test-dive-role-2',
        dateTime: DateTime(2026, 3, 15, 10, 0),
        diverRoleId: 'mysterySlug',
      );
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: [
            ..._alwaysRenderOverrides(dive.id, prefs),
            allDiveRolesProvider.overrideWith((ref) async => <DiveRole>[]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
      expect(find.text('mysterySlug'), findsOneWidget);
    });
  });

  group('DiveDetailPage dive number badge', () {
    /// A dive whose 5-digit number previously wrapped mid-word (#744 / #801).
    final bigNumberDive = Dive(
      id: 'test-dive-big-number',
      dateTime: DateTime(2026, 3, 15, 10, 0),
      diveNumber: 28466,
    );

    /// Overrides for the embedded header's nav buttons, which derive
    /// prev/next from the ordered dive id list.
    List<Override> embeddedOverrides() => [
      orderedDiveIdsProvider.overrideWith((ref) async => <String>[]),
    ];

    /// Number of distinct rendered lines for the badge [text] rendered by
    /// the paragraph matched by [finder].
    int lineCountOf(WidgetTester tester, Finder finder, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      return boxes.map((box) => box.top).toSet().length;
    }

    testWidgets('embedded mode shows the dive number in the pinned header '
        'and the hero card, each on a single line', (tester) async {
      final settings = _settingsWithVisibleSections([]);

      await tester.pumpWidget(
        _buildTestWidget(
          dive: bigNumberDive,
          settings: settings,
          extraOverrides: embeddedOverrides(),
          embedded: true,
        ),
      );
      await tester.pumpAndSettle();

      // Embedded header badge plus the hero card badge.
      final badges = find.text('#28466');
      expect(badges, findsNWidgets(2));
      expect(lineCountOf(tester, badges.at(0), '#28466'), 1);
      expect(lineCountOf(tester, badges.at(1), '#28466'), 1);
    });

    testWidgets('standalone page shows the dive number exactly once, '
        'on a single line', (tester) async {
      final settings = _settingsWithVisibleSections([]);

      await tester.pumpWidget(
        _buildTestWidget(dive: bigNumberDive, settings: settings),
      );
      await tester.pumpAndSettle();

      // Hero card badge only — there is no embedded header here.
      final badge = find.text('#28466');
      expect(badge, findsOneWidget);
      expect(lineCountOf(tester, badge, '#28466'), 1);
    });
  });

  group('DiveDetailPage layouts', () {
    testWidgets('the detailed layout shows section content unfolded', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsNothing);
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
    });

    testWidgets('the list layout folds every visible section away', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
        DiveDetailSectionId.tags,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsNWidgets(2));
      // Folded: the header row names the section, the content is not built.
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Great dive, saw a lot of fish.'), findsNothing);
      expect(find.text('Night Dive'), findsNothing);
    });

    testWidgets('tapping a folded header unfolds just that section', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
        DiveDetailSectionId.tags,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
      // The other section stays folded.
      expect(find.text('Night Dive'), findsNothing);
    });

    testWidgets('tapping an unfolded header folds it back', (tester) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      // The fold's own chevron, not the title: once unfolded, the Notes card
      // underneath carries a "Notes" heading of its own.
      final chevron = find.descendant(
        of: find.byType(DiveSectionFold),
        matching: find.byIcon(Icons.expand_more),
      );

      await tester.tap(chevron);
      await tester.pumpAndSettle();
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);

      await tester.tap(chevron);
      await tester.pumpAndSettle();
      expect(find.text('Great dive, saw a lot of fish.'), findsNothing);
    });

    testWidgets('a hidden section gets no fold in the list layout', (
      tester,
    ) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsOneWidget);
      expect(find.text('Tags'), findsNothing);
    });

    testWidgets('a section with nothing to show gets no fold', (tester) async {
      // The empty dive has no tags, so the Tags builder returns nothing --
      // a fold here would open onto a blank.
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.tags,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _emptyDive, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsNothing);
    });
  });

  // The chart used to render unconditionally, above the configurable
  // sections. It is a section now, so it answers to the same visibility
  // switch as the rest.
  group('the dive profile chart as a section', () {
    testWidgets('renders when the profile section is visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.profile,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithProfile, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('is gone when the diver switches it off', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithProfile, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsNothing);
      // The header is still fixed, so the page is not blank.
      expect(find.text('#-'), findsOneWidget);
    });

    testWidgets('folds away in the list layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.profile,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithProfile, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsOneWidget);
      expect(find.byType(DiveProfileChart), findsNothing);

      await tester.tap(find.text('Dive Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('a dive with no samples gets no chart section', (tester) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.profile,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _emptyDive, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsNothing);
    });
  });

  // Deco Status and Tissue Loading were one section. They are two now, and
  // pair back into the two-column block they used to render as.
  group('the deco/tissue split', () {
    testWidgets('both halves visible renders without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.decoStatus,
        DiveDetailSectionId.tissueLoading,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithProfile, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one half alone renders without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.decoStatus,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithProfile, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('#-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gauge dive is offered neither half', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gauge = Dive(
        id: 'gauge-dive',
        dateTime: DateTime(2026, 3, 15, 10, 0),
        diveMode: DiveMode.gauge,
        profile: List.generate(
          61,
          (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
        ),
      );
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.decoStatus,
        DiveDetailSectionId.tissueLoading,
        DiveDetailSectionId.profile,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: gauge, settings: settings),
      );
      await tester.pumpAndSettle();

      // Only the profile chart folds in -- depth over time is what a gauge
      // records, the deco math is not.
      expect(find.byType(DiveSectionFold), findsOneWidget);
      expect(find.text('Dive Profile'), findsOneWidget);
    });
  });

  group('DiveDetailPage list layout fold persistence', () {
    testWidgets('a section left unfolded opens without a tap', (tester) async {
      final settings = _settingsWithVisibleSections(
        [DiveDetailSectionId.notes, DiveDetailSectionId.tags],
        layout: DiveDetailLayout.list,
        expanded: [DiveDetailSectionId.notes],
      );

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsNWidgets(2));
      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
      // The section the diver never opened stays folded.
      expect(find.text('Night Dive'), findsNothing);
    });

    testWidgets('unfolding a section records it in settings', (tester) async {
      final notifier = _MockSettingsNotifier(
        _settingsWithVisibleSections([
          DiveDetailSectionId.notes,
        ], layout: DiveDetailLayout.list),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _diveWithContent,
          settings: notifier.state,
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      final unfolded = notifier.state.diveDetailSections
          .where((section) => section.expanded)
          .map((section) => section.id)
          .toList();
      expect(unfolded, [DiveDetailSectionId.notes]);
    });

    testWidgets('folding a section clears it in settings', (tester) async {
      final notifier = _MockSettingsNotifier(
        _settingsWithVisibleSections(
          [DiveDetailSectionId.notes],
          layout: DiveDetailLayout.list,
          expanded: [DiveDetailSectionId.notes],
        ),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _diveWithContent,
          settings: notifier.state,
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      // The fold's own chevron, not the title: while unfolded, the Notes
      // card underneath carries a "Notes" heading of its own.
      await tester.tap(
        find.descendant(
          of: find.byType(DiveSectionFold),
          matching: find.byIcon(Icons.expand_more),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        notifier.state.diveDetailSections.every((section) => !section.expanded),
        isTrue,
      );
    });

    // Leaving the dive and coming back used to re-fold everything, because
    // the open set lived in the page's own State.
    testWidgets('an unfolded section is still open on a fresh page', (
      tester,
    ) async {
      final notifier = _MockSettingsNotifier(
        _settingsWithVisibleSections([
          DiveDetailSectionId.notes,
        ], layout: DiveDetailLayout.list),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: _diveWithContent,
          settings: notifier.state,
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // Read what was stored before the scope disposes the notifier, then
      // build a fresh page over it the way reopening the dive would.
      final saved = notifier.state;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: saved),
      );
      await tester.pumpAndSettle();

      expect(find.text('Great dive, saw a lot of fish.'), findsOneWidget);
    });
  });

  group('DiveDetailPage list layout rows', () {
    // Reordering lives in the display-options menu, so the rows stay a single
    // tap target each.
    testWidgets('the folded rows carry no drag handles', (tester) async {
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
        DiveDetailSectionId.tags,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSectionFold), findsNWidgets(2));
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });
  });

  group('DiveDetailPage section spacing', () {
    Finder cardAround(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(Card)).first;

    // One gap, placed once: a section that also spaced itself used to sit
    // twice as far from its neighbour as the sections that did not.
    testWidgets('detailed sections sit exactly one section gap apart', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.tags,
        DiveDetailSectionId.notes,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      final tags = cardAround('Night Dive');
      final notes = cardAround('Great dive, saw a lot of fish.');
      expect(
        tester.getTopLeft(notes).dy - tester.getBottomLeft(tags).dy,
        DiveDetailLayout.detailed.sectionGap,
      );
    });

    testWidgets('list rows sit flush against each other', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.tags,
        DiveDetailSectionId.notes,
      ], layout: DiveDetailLayout.list);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      final folds = find.byType(DiveSectionFold);
      expect(
        tester.getTopLeft(folds.at(1)).dy,
        tester.getBottomLeft(folds.at(0)).dy,
      );
    });
  });

  group('DiveDetailPage app bar actions', () {
    // MediaQuery follows the view, not the test surface, so the window width
    // the app bar reads has to be set on the view itself.
    void setWindowWidth(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Finder favoriteInBar() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.favorite_border),
    );

    // Six action icons leave a phone-width app bar no room for its title, so
    // the favorite toggle moves into the overflow menu there.
    testWidgets('on a phone-width window, favorite lives in the overflow', (
      tester,
    ) async {
      setWindowWidth(tester, 560);
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(favoriteInBar(), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Add to favorites'), findsOneWidget);
    });

    testWidgets('on a wide window, favorite stays in the bar', (tester) async {
      setWindowWidth(tester, 900);
      final settings = _settingsWithVisibleSections([
        DiveDetailSectionId.notes,
      ]);

      await tester.pumpWidget(
        _buildTestWidget(dive: _diveWithContent, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(favoriteInBar(), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Add to favorites'), findsNothing);
    });
  });
}
