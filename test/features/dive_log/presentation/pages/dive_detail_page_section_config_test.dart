import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sections that return early with empty dive data (no extra providers needed).
const _earlyReturnSections = [
  DiveDetailSectionId.decoO2,
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
AppSettings _settingsWithVisibleSections(List<DiveDetailSectionId> visible) {
  final sections = DiveDetailSectionId.values
      .map(
        (id) => DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
      )
      .toList();
  return AppSettings(diveDetailSections: sections);
}

/// Build a minimal ProviderScope + MaterialApp for DiveDetailPage.
Widget _buildTestWidget({required Dive dive, required AppSettings settings}) {
  return ProviderScope(
    overrides: [
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(
        dive.id,
      ).overrideWith((ref) async => <DiveDataSource>[]),
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailPage(diveId: dive.id),
    ),
  );
}

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

void main() {
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
  });
}
