import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSiteTableConfigNotifier
    extends EntityTableConfigNotifier<SiteField> {
  _TestSiteTableConfigNotifier(EntityTableViewConfig<SiteField> config)
    : super(
        defaultConfig: config,
        fieldFromName: SiteFieldAdapter.instance.fieldFromName,
      );
}

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<SiteField>(
  columns: [
    EntityTableColumnConfig(field: SiteField.siteName, isPinned: true),
    EntityTableColumnConfig(field: SiteField.country),
    EntityTableColumnConfig(field: SiteField.maxDepth),
    EntityTableColumnConfig(field: SiteField.diveCount),
    EntityTableColumnConfig(field: SiteField.waterType),
  ],
);

SiteWithDiveCount _makeSite({
  required String id,
  required String name,
  String? country,
  double? maxDepth,
  int diveCount = 0,
}) {
  return SiteWithDiveCount(
    site: DiveSite(id: id, name: name, country: country, maxDepth: maxDepth),
    diveCount: diveCount,
  );
}

Future<List<Override>> _buildOverrides({
  required List<SiteWithDiveCount> sites,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    sortedSitesWithCountsProvider.overrideWithValue(AsyncValue.data(sites)),
    siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
    siteListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    siteTableConfigProvider.overrideWith(
      (ref) => _TestSiteTableConfigNotifier(_testConfig),
    ),
  ];
}

void main() {
  group('SiteListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final sites = [
        _makeSite(
          id: 's1',
          name: 'Blue Hole',
          country: 'Belize',
          maxDepth: 40.0,
          diveCount: 5,
        ),
        _makeSite(
          id: 's2',
          name: 'Coral Garden',
          country: 'Egypt',
          maxDepth: 18.0,
          diveCount: 12,
        ),
      ];

      final overrides = await _buildOverrides(sites: sites);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from the config (shortLabel values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('Max D'), findsOneWidget);
      expect(find.text('Dives'), findsOneWidget);
    });

    testWidgets('renders rows for each site', (tester) async {
      final sites = [
        _makeSite(id: 's1', name: 'Blue Hole', diveCount: 5),
        _makeSite(id: 's2', name: 'Coral Garden', diveCount: 12),
        _makeSite(id: 's3', name: 'Shark Point', diveCount: 3),
      ];

      final overrides = await _buildOverrides(sites: sites);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Each site name should appear
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Coral Garden'), findsOneWidget);
      expect(find.text('Shark Point'), findsOneWidget);
    });

    testWidgets('shows empty state when no sites', (tester) async {
      final overrides = await _buildOverrides(sites: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Should show the empty state icon
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Column settings icon should be in the app bar
      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Manta Point', country: 'Indonesia')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Should still render the site name in the table
      expect(find.text('Manta Point'), findsOneWidget);
    });

    testWidgets('renders with site data including country', (tester) async {
      final sites = [
        _makeSite(
          id: 's1',
          name: 'USS Liberty',
          country: 'Indonesia',
          maxDepth: 30.0,
          diveCount: 8,
        ),
      ];

      final overrides = await _buildOverrides(sites: sites);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('USS Liberty'), findsOneWidget);
      expect(find.text('Indonesia'), findsOneWidget);
    });

    testWidgets('table app bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('table app bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('table app bar has map button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('table app bar has more options popup', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Test Site')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Manta Point')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Manta Point')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('compact bar has popup menu', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Manta Point')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('compact bar has map button', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Manta Point')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.map), findsOneWidget);
    });
  });
}
