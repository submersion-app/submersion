import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
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

    testWidgets('no pairing when the two are reordered apart', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = _diveWithConditions('reordered');
      // Put another visible section between details and environment.
      final settings = AppSettings(
        diveDetailSections: [
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.details,
            visible: true,
          ),
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.notes,
            visible: true,
          ),
          const DiveDetailSectionConfig(
            id: DiveDetailSectionId.environment,
            visible: true,
          ),
          ...DiveDetailSectionId.values
              .where(
                (id) =>
                    id != DiveDetailSectionId.details &&
                    id != DiveDetailSectionId.notes &&
                    id != DiveDetailSectionId.environment,
              )
              .map((id) => DiveDetailSectionConfig(id: id, visible: false)),
        ],
      );

      await tester.pumpWidget(
        _buildTestWidget(
          dive: dive,
          settings: settings,
          extraOverrides: _renderOverrides(dive.id, prefs),
        ),
      );
      await tester.pumpAndSettle();

      // Adjacency broken => full-width, no pairing (both cards still present).
      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Environment'), findsOneWidget);
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
}
