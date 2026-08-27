import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:submersion/l10n/arb/app_localizations.dart';
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

      // Verify column headers from the config (displayName values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Dive Count'), findsOneWidget);
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

    testWidgets(
      'compact bar omits map button in table mode (managed by layout)',
      (tester) async {
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

        // Map toggle is managed by TableModeLayout, not the compact bar
        expect(find.byIcon(Icons.map), findsNothing);
      },
    );

    testWidgets('tapping a row sets highlighted site id', (tester) async {
      final sites = [
        _makeSite(id: 's1', name: 'Blue Hole'),
        _makeSite(id: 's2', name: 'Coral Garden'),
      ];

      final overrides = await _buildOverrides(sites: sites);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(body: SiteListContent(showAppBar: true));
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on a site row
      await tester.tap(find.text('Blue Hole'));
      // Pump past the DoubleTapGestureRecognizer's 300ms timeout
      await tester.pump(const Duration(milliseconds: 350));

      // The tap should have set the highlighted site ID
      expect(container.read(highlightedSiteIdProvider), 's1');
    });

    testWidgets('double-tapping a row navigates to site detail', (
      tester,
    ) async {
      final sites = [_makeSite(id: 's1', name: 'Blue Hole')];

      final overrides = await _buildOverrides(sites: sites);

      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/sites',
        routes: [
          GoRoute(
            path: '/sites',
            builder: (context, state) =>
                const Scaffold(body: SiteListContent(showAppBar: true)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  pushedPath = state.uri.toString();
                  return const Scaffold(body: SizedBox());
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Double-tap on a site row
      await tester.tap(find.text('Blue Hole'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Blue Hole'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/sites/s1');
    });

    // Table mode owns no app bar -- TableModeLayout does, and it cannot reach
    // this content's SelectionController -- so before the Select bar existed
    // here, long-press was the only touch route into multi-select. Removing
    // long-press without this would have left table mode with no way in at
    // all on a touch device.
    testWidgets('offers Select while closed and swaps it for the '
        'contextual bar on entry', (tester) async {
      final overrides = await _buildOverrides(
        sites: [_makeSite(id: 's1', name: 'Blue Hole')],
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      final selectButton = find.byKey(const ValueKey('enter_selection'));
      final exitButton = find.byKey(const ValueKey('selection_exit'));

      expect(selectButton, findsOneWidget);
      expect(exitButton, findsNothing);

      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      // One bar at a time, in the same slot: the Select affordance yields to
      // the contextual bar rather than stacking above it.
      expect(exitButton, findsOneWidget);
      expect(selectButton, findsNothing);
      expect(find.text('0 selected'), findsOneWidget);
    });

    // Table mode used to ignore both modifiers, so the only way into a
    // multi-row selection was long-press then tap. These drive the real
    // gesture sequence: a plain tap highlights the row, then a modified tap
    // on a later row builds the selection from it.
    group('modifier clicks', () {
      // Cmd on macOS, Control elsewhere -- mirrors
      // SelectableListScope.isModifierPressed so this passes on the macOS dev
      // machine and the Linux CI runner alike.
      final modifierKey = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      Future<void> pumpFourSites(WidgetTester tester) async {
        final overrides = await _buildOverrides(
          sites: [
            _makeSite(id: 's1', name: 'Blue Hole'),
            _makeSite(id: 's2', name: 'Coral Garden'),
            _makeSite(id: 's3', name: 'Shark Point'),
            _makeSite(id: 's4', name: 'Turtle Bay'),
          ],
        );
        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: true),
          ),
        );
        await tester.pumpAndSettle();

        // Plain tap highlights the row without checking it. Settle past the
        // double-tap window so the next tap is not read as a double-tap.
        await tester.tap(find.text('Blue Hole'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      // Table rows carry an onDoubleTap, so onTap only resolves once the
      // double-tap timer expires. The modifier has to stay held across that
      // wait, because the handler reads the keyboard when the tap fires.
      Future<void> tapRowWithKey(
        WidgetTester tester,
        String rowText,
        LogicalKeyboardKey key,
      ) async {
        await tester.sendKeyDownEvent(key);
        await tester.tap(find.text(rowText));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.sendKeyUpEvent(key);
        await tester.pumpAndSettle();
      }

      testWidgets('shift-tap selects the span from the highlighted row', (
        tester,
      ) async {
        await pumpFourSites(tester);

        await tapRowWithKey(
          tester,
          'Shark Point',
          LogicalKeyboardKey.shiftLeft,
        );

        expect(find.text('3 selected'), findsOneWidget);
      });

      testWidgets('modifier-tap checks the highlighted row too', (
        tester,
      ) async {
        await pumpFourSites(tester);

        await tapRowWithKey(tester, 'Shark Point', modifierKey);

        expect(find.text('2 selected'), findsOneWidget);
      });
    });

    // Table mode used to return before the SelectableListScope wrapper, so it
    // had no keyboard handling at all: the only way out of selection mode was
    // the bar's close button.
    group('keyboard handling', () {
      final selectAllKey = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      Future<void> pumpThreeSitesInSelection(WidgetTester tester) async {
        final overrides = await _buildOverrides(
          sites: [
            _makeSite(id: 's1', name: 'Blue Hole'),
            _makeSite(id: 's2', name: 'Coral Garden'),
            _makeSite(id: 's3', name: 'Shark Point'),
          ],
        );
        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('enter_selection')));
        await tester.pumpAndSettle();

        // Table rows carry an onDoubleTap, so the tap only resolves once the
        // double-tap timer expires.
        await tester.tap(find.text('Blue Hole'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
      }

      testWidgets('Escape exits selection mode', (tester) async {
        await pumpThreeSitesInSelection(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsNothing);
      });

      testWidgets('Ctrl/Cmd-A checks every visible row', (tester) async {
        await pumpThreeSitesInSelection(tester);

        await tester.sendKeyDownEvent(selectAllKey);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(selectAllKey);
        await tester.pumpAndSettle();

        expect(find.text('3 selected'), findsOneWidget);
      });
    });
  });
}
