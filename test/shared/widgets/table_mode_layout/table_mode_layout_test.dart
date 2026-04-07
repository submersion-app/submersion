import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

// ---------------------------------------------------------------------------
// Helper: build a test app without GoRouter (for non-detail-pane tests).
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required Widget child,
  double width = 1200,
  List<dynamic>? overrides,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
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
    overrides: overrides?.cast() ?? [],
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
  List<Widget>? appBarActions,
  bool isMapViewActive = false,
  VoidCallback? onMapViewToggle,
  Widget? floatingActionButton,
  bool showProfilePanel = false,
  VoidCallback? onProfileToggled,
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
    appBarActions: appBarActions,
    isMapViewActive: isMapViewActive,
    onMapViewToggle: onMapViewToggle,
    floatingActionButton: floatingActionButton,
    showProfilePanel: showProfilePanel,
    onProfileToggled: onProfileToggled,
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
      testWidgets('appears when profilePanelContent is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            child: _buildLayout(
              profilePanelContent: const SizedBox(
                height: 100,
                child: Text('Profile Panel'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('profile_toggle')), findsOneWidget);
      });

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
      testWidgets(
        'toggling details ON calls onProfileToggled when profile was active',
        (tester) async {
          // Start with details OFF and profile ON. Tapping details should call
          // onProfileToggled so the caller can turn off the profile provider.
          // GoRouter is required because tapping details switches to MasterDetailScaffold.
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

          // Tap the details toggle
          await tester.tap(find.byKey(const ValueKey('details_toggle')));
          await tester.pumpAndSettle();

          // Details ON (via provider), and onProfileToggled was called to signal
          // the caller to turn off the profile panel
          expect(container.read(tableDetailsPaneProvider('dives')), isTrue);
          expect(profileToggleCalled, isTrue);
        },
      );

      testWidgets('toggling profile ON disables details via provider', (
        tester,
      ) async {
        // Start with details ON and profile OFF. Tapping profile toggle should
        // call onProfileToggled AND turn off tableDetailsPaneProvider directly.
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

        // The profile toggle should be visible inside the MasterDetailScaffold
        // master pane
        await tester.tap(find.byKey(const ValueKey('profile_toggle')));
        await tester.pumpAndSettle();

        // onProfileToggled called, and details turned OFF by widget directly
        expect(profileToggleCalled, isTrue);
        expect(container.read(tableDetailsPaneProvider('dives')), isFalse);
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
  });
}
