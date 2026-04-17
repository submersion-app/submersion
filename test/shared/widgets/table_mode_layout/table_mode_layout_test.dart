import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setShowDetailsPaneForSection(
    String sectionKey,
    bool value,
  ) async {}

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helper: build a test app without GoRouter (for non-detail-pane tests).
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required Widget child,
  double width = 1200,
  List<dynamic>? overrides,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
      ...?overrides?.cast(),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: child,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Helper: build a test app WITH GoRouter (needed when details pane is ON
// because MasterDetailScaffold reads GoRouterState.of(context)).
// ---------------------------------------------------------------------------

Widget _buildRoutedTestWidget({
  required Widget child,
  double width = 1200,
  List<dynamic>? overrides,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: child,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
      ...?overrides?.cast(),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Helper: minimal TableModeLayout with only required params.
// ---------------------------------------------------------------------------

Widget _buildLayout({
  String sectionKey = 'dives',
  String appBarTitle = 'Dives',
  Widget? mapContent,
  Widget? profilePanelContent,
  Widget? columnSettingsAction,
  List<Widget>? appBarActions,
  bool isMapViewActive = false,
  VoidCallback? onMapViewToggle,
  Widget? floatingActionButton,
  bool showProfilePanel = false,
  VoidCallback? onProfileToggled,
  bool isSelectionMode = false,
  PreferredSizeWidget? selectionAppBar,
}) {
  return TableModeLayout(
    sectionKey: sectionKey,
    appBarTitle: appBarTitle,
    tableContent: const Text('Table Content'),
    detailBuilder: (_, id) => Text('Detail $id'),
    summaryBuilder: (_) => const Text('Summary'),
    onEntitySelected: (_) {},
    mapContent: mapContent,
    profilePanelContent: profilePanelContent,
    columnSettingsAction: columnSettingsAction,
    appBarActions: appBarActions,
    isMapViewActive: isMapViewActive,
    onMapViewToggle: onMapViewToggle,
    floatingActionButton: floatingActionButton,
    showProfilePanel: showProfilePanel,
    onProfileToggled: onProfileToggled,
    isSelectionMode: isSelectionMode,
    selectionAppBar: selectionAppBar,
  );
}

void main() {
  group('TableModeLayout', () {
    // ------------------------------------------------------------------
    // Default state
    // ------------------------------------------------------------------
    group('default state', () {
      testWidgets('renders full-width table with no detail pane and no map', (
        tester,
      ) async {
        await tester.pumpWidget(_buildTestWidget(child: _buildLayout()));
        await tester.pumpAndSettle();

        expect(find.text('Table Content'), findsOneWidget);
        // No detail pane content visible
        expect(find.text('Summary'), findsNothing);
        expect(find.text('Dives'), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Details toggle
    // ------------------------------------------------------------------
    group('details toggle', () {
      testWidgets('appears on desktop (>= 1100px)', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(width: 1200, child: _buildLayout()),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('details_toggle')), findsOneWidget);
      });

      testWidgets('hidden on mobile (< 1100px)', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(width: 800, child: _buildLayout()),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('details_toggle')), findsNothing);
      });

      testWidgets('toggling details ON switches to MasterDetailScaffold', (
        tester,
      ) async {
        // Needs GoRouter because MasterDetailScaffold reads GoRouterState
        await tester.pumpWidget(
          _buildRoutedTestWidget(
            width: 1200,
            overrides: [
              tableDetailsPaneProvider('dives').overrideWith((_) => true),
            ],
            child: _buildLayout(),
          ),
        );
        await tester.pumpAndSettle();

        // MasterDetailScaffold renders the summary in the detail pane
        expect(find.text('Summary'), findsOneWidget);
        expect(find.text('Table Content'), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Profile toggle
    // ------------------------------------------------------------------
    group('profile toggle', () {
      testWidgets(
        'appears when profilePanelContent and onProfileToggled are provided',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              child: _buildLayout(
                profilePanelContent: const SizedBox(
                  height: 100,
                  child: Text('Profile Panel'),
                ),
                onProfileToggled: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('profile_toggle')), findsOneWidget);
        },
      );

      testWidgets('hidden when profilePanelContent is null', (tester) async {
        await tester.pumpWidget(_buildTestWidget(child: _buildLayout()));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('profile_toggle')), findsNothing);
      });

      testWidgets('profile panel is visible when showProfilePanel is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              showProfilePanel: true,
              profilePanelContent: const SizedBox(
                height: 100,
                child: Text('Profile Panel'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile Panel'), findsOneWidget);
      });

      testWidgets('profile panel hidden when showProfilePanel is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              showProfilePanel: false,
              profilePanelContent: const SizedBox(
                height: 100,
                child: Text('Profile Panel'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile Panel'), findsNothing);
      });
    });

    // ------------------------------------------------------------------
    // Map toggle
    // ------------------------------------------------------------------
    group('map toggle', () {
      testWidgets('appears when mapContent is provided', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              mapContent: Container(
                color: Colors.blue,
                child: const Text('Map'),
              ),
              onMapViewToggle: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('map_toggle')), findsOneWidget);
      });

      testWidgets(
        'appears when onMapViewToggle is provided without mapContent',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(child: _buildLayout(onMapViewToggle: () {})),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('map_toggle')), findsOneWidget);
        },
      );

      testWidgets('hidden when no map support', (tester) async {
        await tester.pumpWidget(_buildTestWidget(child: _buildLayout()));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('map_toggle')), findsNothing);
      });

      testWidgets('map content visible when isMapViewActive true', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              mapContent: Container(
                color: Colors.blue,
                child: const Text('Map'),
              ),
              isMapViewActive: true,
              onMapViewToggle: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Map'), findsOneWidget);
        expect(find.text('Table Content'), findsOneWidget);
      });

      testWidgets('calls onMapViewToggle when tapped', (tester) async {
        var toggled = false;
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              mapContent: Container(
                color: Colors.blue,
                child: const Text('Map'),
              ),
              onMapViewToggle: () => toggled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('map_toggle')));
        expect(toggled, isTrue);
      });
    });

    // ------------------------------------------------------------------
    // App bar actions
    // ------------------------------------------------------------------
    group('appBarActions', () {
      testWidgets('additional actions appear in app bar', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              appBarActions: [
                IconButton(
                  key: const ValueKey('column_settings'),
                  icon: const Icon(Icons.view_column),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('column_settings')), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Mutual exclusion
    // ------------------------------------------------------------------
    group('mutual exclusion', () {
      testWidgets('toggling details ON does not turn off profile', (
        tester,
      ) async {
        var profileToggleCalled = false;

        final router = GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (context, state) => MediaQuery(
                data: const MediaQueryData(size: Size(1200, 800)),
                child: _buildLayout(
                  showProfilePanel: true,
                  onProfileToggled: () => profileToggleCalled = true,
                  profilePanelContent: const SizedBox(
                    height: 100,
                    child: Text('Profile Panel'),
                  ),
                ),
              ),
            ),
          ],
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
              tableDetailsPaneProvider('dives').overrideWith((_) => false),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp.router(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('details_toggle')));
        await tester.pumpAndSettle();

        // Details ON, profile NOT toggled off
        expect(container.read(tableDetailsPaneProvider('dives')), isTrue);
        expect(profileToggleCalled, isFalse);
      });

      testWidgets('toggling profile ON does not turn off details', (
        tester,
      ) async {
        var profileToggleCalled = false;

        final router = GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (context, state) => MediaQuery(
                data: const MediaQueryData(size: Size(1200, 800)),
                child: _buildLayout(
                  showProfilePanel: false,
                  onProfileToggled: () => profileToggleCalled = true,
                  profilePanelContent: const SizedBox(
                    height: 100,
                    child: Text('Profile Panel'),
                  ),
                ),
              ),
            ),
          ],
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tableDetailsPaneProvider('dives').overrideWith((_) => true),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp.router(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('profile_toggle')));
        await tester.pumpAndSettle();

        // Profile toggled, details stays ON
        expect(profileToggleCalled, isTrue);
        expect(container.read(tableDetailsPaneProvider('dives')), isTrue);
      });
    });

    // ------------------------------------------------------------------
    // Floating action button
    // ------------------------------------------------------------------
    group('floating action button', () {
      testWidgets('renders FAB when provided', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Toggle button styling
    // ------------------------------------------------------------------
    group('toggle button styling', () {
      testWidgets('active details toggle uses primary color', (tester) async {
        // Details is ON but not yet rendered into MasterDetailScaffold --
        // we just need to check the icon color. Use the routed helper.
        await tester.pumpWidget(
          _buildRoutedTestWidget(
            width: 1200,
            overrides: [
              tableDetailsPaneProvider('dives').overrideWith((_) => true),
            ],
            child: _buildLayout(),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.descendant(
          of: find.byKey(const ValueKey('details_toggle')),
          matching: find.byType(Icon),
        );
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        final context = tester.element(find.byType(TableModeLayout));
        final primaryColor = Theme.of(context).colorScheme.primary;
        expect(icon.color, equals(primaryColor));
      });

      testWidgets('inactive details toggle uses default color', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            width: 1200,
            overrides: [
              tableDetailsPaneProvider('dives').overrideWith((_) => false),
            ],
            child: _buildLayout(),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.descendant(
          of: find.byKey(const ValueKey('details_toggle')),
          matching: find.byType(Icon),
        );
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, isNull);
      });

      testWidgets('active map toggle uses primary color', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              mapContent: Container(
                color: Colors.blue,
                child: const Text('Map'),
              ),
              isMapViewActive: true,
              onMapViewToggle: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.descendant(
          of: find.byKey(const ValueKey('map_toggle')),
          matching: find.byType(Icon),
        );
        expect(iconFinder, findsOneWidget);

        final icon = tester.widget<Icon>(iconFinder);
        final context = tester.element(find.byType(TableModeLayout));
        final primaryColor = Theme.of(context).colorScheme.primary;
        expect(icon.color, equals(primaryColor));
      });
    });

    // ------------------------------------------------------------------
    // Selection mode app bar
    // ------------------------------------------------------------------
    group('selection mode app bar', () {
      testWidgets(
        'shows selection app bar in full-width mode when isSelectionMode is true',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              child: _buildLayout(
                isSelectionMode: true,
                selectionAppBar: AppBar(title: const Text('2 selected')),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('2 selected'), findsOneWidget);
          // The default app bar title should not be shown
          expect(find.text('Dives'), findsNothing);
        },
      );

      testWidgets(
        'shows selection app bar in detail pane mode when isSelectionMode is true',
        (tester) async {
          await tester.pumpWidget(
            _buildRoutedTestWidget(
              width: 1200,
              overrides: [
                tableDetailsPaneProvider('dives').overrideWith((_) => true),
              ],
              child: _buildLayout(
                isSelectionMode: true,
                selectionAppBar: AppBar(title: const Text('3 selected')),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('3 selected'), findsOneWidget);
          // The default app bar title should not be shown
          expect(find.text('Dives'), findsNothing);
        },
      );
    });

    // ------------------------------------------------------------------
    // Details pane with map active
    // ------------------------------------------------------------------
    group('details pane with map', () {
      testWidgets(
        'map content is visible when details pane and map are both active',
        (tester) async {
          await tester.pumpWidget(
            _buildRoutedTestWidget(
              width: 1200,
              overrides: [
                tableDetailsPaneProvider('dives').overrideWith((_) => true),
              ],
              child: _buildLayout(
                mapContent: Container(
                  color: Colors.blue,
                  child: const Text('Map'),
                ),
                isMapViewActive: true,
                onMapViewToggle: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Map, table, and summary (detail pane) should all be visible
          expect(find.text('Map'), findsOneWidget);
          expect(find.text('Table Content'), findsOneWidget);
          expect(find.text('Summary'), findsOneWidget);
        },
      );

      testWidgets(
        'profile panel is visible when details pane and profile are both active',
        (tester) async {
          await tester.pumpWidget(
            _buildRoutedTestWidget(
              width: 1200,
              overrides: [
                tableDetailsPaneProvider('dives').overrideWith((_) => true),
              ],
              child: _buildLayout(
                profilePanelContent: const SizedBox(
                  height: 100,
                  child: Text('Profile Panel'),
                ),
                showProfilePanel: true,
                onProfileToggled: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Profile, table, and summary should all be visible
          expect(find.text('Profile Panel'), findsOneWidget);
          expect(find.text('Table Content'), findsOneWidget);
          expect(find.text('Summary'), findsOneWidget);
        },
      );
    });

    // ------------------------------------------------------------------
    // Profile panel in _buildBody
    // ------------------------------------------------------------------
    group('profile panel in body', () {
      testWidgets(
        'profile panel content appears above table in full-width mode',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              child: _buildLayout(
                profilePanelContent: const SizedBox(
                  height: 100,
                  child: Text('Profile Panel'),
                ),
                showProfilePanel: true,
                onProfileToggled: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Both profile panel and table should be visible
          expect(find.text('Profile Panel'), findsOneWidget);
          expect(find.text('Table Content'), findsOneWidget);

          // Profile panel should appear above the table (Column layout)
          final profileOffset = tester.getTopLeft(find.text('Profile Panel'));
          final tableOffset = tester.getTopLeft(find.text('Table Content'));
          expect(profileOffset.dy, lessThan(tableOffset.dy));
        },
      );

      testWidgets(
        'profile panel and map active together shows profile above table with map beside',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              child: _buildLayout(
                profilePanelContent: const SizedBox(
                  height: 100,
                  child: Text('Profile Panel'),
                ),
                showProfilePanel: true,
                onProfileToggled: () {},
                mapContent: Container(
                  color: Colors.blue,
                  child: const Text('Map'),
                ),
                isMapViewActive: true,
                onMapViewToggle: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // All three should be visible
          expect(find.text('Profile Panel'), findsOneWidget);
          expect(find.text('Table Content'), findsOneWidget);
          expect(find.text('Map'), findsOneWidget);

          // Profile panel should be above the table
          final profileOffset = tester.getTopLeft(find.text('Profile Panel'));
          final tableOffset = tester.getTopLeft(find.text('Table Content'));
          expect(profileOffset.dy, lessThan(tableOffset.dy));
        },
      );
    });

    // ------------------------------------------------------------------
    // Mobile map: full-page
    // ------------------------------------------------------------------
    group('mobile map layout', () {
      testWidgets('shows full-page map on mobile when map is active', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            width: 500, // mobile width
            child: _buildLayout(
              mapContent: Container(
                color: Colors.blue,
                child: const Text('Map'),
              ),
              isMapViewActive: true,
              onMapViewToggle: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Map should be visible
        expect(find.text('Map'), findsOneWidget);
        // Table should NOT be visible on mobile when map is full-page
        expect(find.text('Table Content'), findsNothing);
      });
    });

    // ------------------------------------------------------------------
    // Column settings action
    // ------------------------------------------------------------------
    group('column settings action', () {
      testWidgets('renders columnSettingsAction in app bar', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              columnSettingsAction: IconButton(
                key: const ValueKey('col_settings'),
                icon: const Icon(Icons.view_column),
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('col_settings')), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Vertical divider between toggle actions and appBarActions
    // ------------------------------------------------------------------
    group('vertical divider', () {
      testWidgets(
        'renders VerticalDivider when both toggle actions and appBarActions exist',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              child: _buildLayout(
                mapContent: Container(
                  color: Colors.blue,
                  child: const Text('Map'),
                ),
                onMapViewToggle: () {},
                appBarActions: [
                  IconButton(
                    key: const ValueKey('search'),
                    icon: const Icon(Icons.search),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Both the map toggle and the search action exist, so a
          // VerticalDivider should be rendered between them
          expect(find.byType(VerticalDivider), findsOneWidget);
        },
      );

      testWidgets('no VerticalDivider when only appBarActions and no toggles', (
        tester,
      ) async {
        // No map/profile/details toggles, just appBarActions
        await tester.pumpWidget(
          _buildTestWidget(
            width: 500, // mobile, no details toggle
            child: _buildLayout(
              appBarActions: [
                IconButton(
                  key: const ValueKey('search'),
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No toggle buttons, so no divider should appear
        expect(find.byType(VerticalDivider), findsNothing);
      });
    });

    // ------------------------------------------------------------------
    // Different sections
    // ------------------------------------------------------------------
    group('different section keys', () {
      testWidgets('works with sites section key', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(sectionKey: 'sites', appBarTitle: 'Dive Sites'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dive Sites'), findsOneWidget);
        expect(find.text('Table Content'), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------
    // Profile panel only (no map)
    // ------------------------------------------------------------------
    group('profile only without map', () {
      testWidgets('shows profile column layout without map', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              profilePanelContent: const SizedBox(
                height: 100,
                child: Text('Profile Panel'),
              ),
              showProfilePanel: true,
              onProfileToggled: () {},
              // No map
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile Panel'), findsOneWidget);
        expect(find.text('Table Content'), findsOneWidget);
        // No map - profile is in Column above table
      });
    });

    // ------------------------------------------------------------------
    // Profile toggle callback
    // ------------------------------------------------------------------
    group('profile toggle callback', () {
      testWidgets('calls onProfileToggled when tapped', (tester) async {
        var toggled = false;
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              profilePanelContent: const SizedBox(
                height: 100,
                child: Text('Profile Panel'),
              ),
              onProfileToggled: () => toggled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('profile_toggle')));
        expect(toggled, isTrue);
      });
    });
  });
}
