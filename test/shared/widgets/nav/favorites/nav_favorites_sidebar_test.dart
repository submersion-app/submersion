import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_favorites_section.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_rail_label.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_rail_tile.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_star_button.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

const _prefsKey = 'nav_favorite_ids';

/// Every destination that can be starred (all but Home and `more`).
final List<String> _allMovableIds = movableNavIds;

Future<Widget> _buildTestApp({
  String initialLocation = '/dashboard',
  List<String>? favorites,
  TargetPlatform? platform,
}) async {
  SharedPreferences.setMockInitialValues({_prefsKey: ?favorites});
  final prefs = await SharedPreferences.getInstance();

  GoRoute page(String path, String label) =>
      GoRoute(path: path, builder: (context, state) => Text('$label page'));

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          page('/dashboard', 'Dashboard'),
          page('/dives', 'Dives'),
          page('/sites', 'Sites'),
          page('/trips', 'Trips'),
          page('/settings', 'Settings'),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateServiceProvider.overrideWith((ref) async => null),
      updateStatusProvider.overrideWith((ref) => _StubUpdateStatusNotifier()),
      downloadNotifierProvider.overrideWith((ref) => _StubDownloadNotifier()),
      settingsProvider.overrideWith(
        (ref) => _StubSettingsNotifier(const AppSettings()),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: platform == null ? null : ThemeData(platform: platform),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  _StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  _StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The star toggle rendered inside the rail label for [label].
Finder _starFor(String label, IconData icon) => find.descendant(
  of: find.widgetWithText(NavRailLabel, label),
  matching: find.byIcon(icon),
);

Finder _favoriteTile(String id) => find.byKey(ValueKey('navFavorite:$id'));

/// Whether the outline star in the rail label for [label] is drawn dimmed.
bool _starDimmed(WidgetTester tester, String label) => tester
    .widget<NavStarButton>(
      find.descendant(
        of: find.widgetWithText(NavRailLabel, label),
        matching: find.byType(NavStarButton),
      ),
    )
    .dim;

/// The desktop drag handle inside the favorite tile for [id].
Finder _dragHandleFor(String id) => find.descendant(
  of: _favoriteTile(id),
  matching: find.byIcon(Icons.drag_handle),
);

/// The filled star inside the favorite tile for [id].
Finder _unstarFor(String id) =>
    find.descendant(of: _favoriteTile(id), matching: find.byIcon(Icons.star));

/// Whether the favorite tile for [id] is drawn in its selected state.
bool _favoriteSelected(WidgetTester tester, String id) => tester
    .widget<NavRailTile>(
      find.descendant(
        of: _favoriteTile(id),
        matching: find.byType(NavRailTile),
      ),
    )
    .selected;

/// Rail label ids, in order, for the destinations still hosted by the rail.
List<String> _railLabels(WidgetTester tester) {
  final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
  return rail.destinations
      .map((d) => (d.label as NavRailLabel).text)
      .toList(growable: false);
}

/// Moves [gesture] from [from] to [to] in 8px increments, pumping a frame
/// after each so reorderable-list gap tracking sees continuous motion.
Future<void> _dragInSteps(
  WidgetTester tester,
  TestGesture gesture, {
  required Offset from,
  required Offset to,
}) async {
  const step = 8.0;
  final distance = (to - from).distance;
  final steps = (distance / step).ceil();
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump();
  }
}

Future<List<String>?> _stored() async =>
    (await SharedPreferences.getInstance()).getStringList(_prefsKey);

void main() {
  group('sidebar Favorites section (extended rail)', () {
    testWidgets('renders the Favorites header directly under Home', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavFavoritesSection), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);

      final homeBottom = tester.getBottomLeft(find.text('Home')).dy;
      final headerTop = tester.getTopLeft(find.text('Favorites')).dy;
      final divesTop = tester
          .getTopLeft(find.widgetWithText(NavRailLabel, 'Dives'))
          .dy;
      expect(headerTop, greaterThanOrEqualTo(homeBottom));
      expect(headerTop, lessThan(divesTop));
    });

    testWidgets('shows a muted hint while there are no favorites', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Star an item to add it here'), findsOneWidget);
      expect(find.byKey(const ValueKey('navFavoritesList')), findsNothing);
    });

    testWidgets('Home and Favorites themselves have no star toggle', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(NavRailLabel, 'Home'), findsNothing);
      expect(find.widgetWithText(NavRailLabel, 'Favorites'), findsNothing);
      expect(_starFor('Dives', Icons.star_border), findsOneWidget);
    });

    testWidgets('starring moves the entry out of the rail into Favorites', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(_railLabels(tester), contains('Sites'));

      await tester.tap(_starFor('Sites', Icons.star_border));
      await tester.pumpAndSettle();

      // Exactly one "Sites" anywhere in the sidebar, and it is the favorite.
      expect(_favoriteTile('sites'), findsOneWidget);
      expect(find.text('Sites'), findsOneWidget);
      expect(_railLabels(tester), isNot(contains('Sites')));
      expect(find.widgetWithText(NavRailLabel, 'Sites'), findsNothing);
      expect(_unstarFor('sites'), findsOneWidget);
      expect(find.text('Star an item to add it here'), findsNothing);
      expect(await _stored(), ['sites']);
    });

    testWidgets('un-starring moves the entry back to its original position', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp(favorites: ['sites']));
      await tester.pumpAndSettle();

      expect(_favoriteTile('sites'), findsOneWidget);
      expect(_railLabels(tester), isNot(contains('Sites')));

      await tester.tap(_unstarFor('sites'));
      await tester.pumpAndSettle();

      expect(_favoriteTile('sites'), findsNothing);
      expect(find.text('Sites'), findsOneWidget);
      final labels = _railLabels(tester);
      expect(labels.indexOf('Sites'), labels.indexOf('Dives') + 1);
      expect(labels.indexOf('Trips'), labels.indexOf('Sites') + 1);
      expect(find.text('Star an item to add it here'), findsOneWidget);
      expect(await _stored(), isEmpty);
    });

    testWidgets('the current route is highlighted on the favorite tile', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(
        await _buildTestApp(
          initialLocation: '/sites',
          favorites: ['sites', 'trips'],
        ),
      );
      await tester.pumpAndSettle();

      expect(_favoriteSelected(tester, 'sites'), isTrue);
      expect(_favoriteSelected(tester, 'trips'), isFalse);
      // The rail no longer hosts Sites, so it has nothing to highlight.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, isNull);

      // Navigating to a rail destination moves the highlight back.
      await tester.tap(find.text('Dives'));
      await tester.pumpAndSettle();
      expect(_favoriteSelected(tester, 'sites'), isFalse);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );
    });

    testWidgets('hides the rail divider when every destination is a favorite', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp(favorites: _allMovableIds));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, isEmpty);
      expect(find.byType(NavRailLabel), findsNothing);
      expect(
        find.byKey(const ValueKey('navFavoritesEndDivider')),
        findsNothing,
      );
      for (final id in _allMovableIds) {
        expect(_favoriteTile(id), findsOneWidget);
      }
    });

    testWidgets('long-pressing a rail destination stars it', (tester) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.flight_outlined));
      await tester.pumpAndSettle();

      expect(_favoriteTile('trips'), findsOneWidget);
      expect(_railLabels(tester), isNot(contains('Trips')));
      expect(await _stored(), ['trips']);
    });

    testWidgets('renders stored favorites in order and skips stale ids', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(
        await _buildTestApp(favorites: ['trips', 'ghost', 'dives']),
      );
      await tester.pumpAndSettle();

      expect(_favoriteTile('trips'), findsOneWidget);
      expect(_favoriteTile('dives'), findsOneWidget);
      expect(_favoriteTile('ghost'), findsNothing);
      expect(
        tester.getTopLeft(_favoriteTile('trips')).dy,
        lessThan(tester.getTopLeft(_favoriteTile('dives')).dy),
      );
    });

    testWidgets('tapping a favorite navigates to its route', (tester) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp(favorites: ['settings']));
      await tester.pumpAndSettle();

      await tester.tap(_favoriteTile('settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings page'), findsOneWidget);
    });

    testWidgets('the Home tile navigates to the dashboard', (tester) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp(initialLocation: '/dives'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard page'), findsOneWidget);
    });

    testWidgets('long-press drag reorders favorites and persists', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(
        await _buildTestApp(favorites: ['dives', 'sites', 'trips']),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(_favoriteTile('dives'));
      final end = tester.getCenter(_favoriteTile('trips'));

      // Long-press to lift, then drag in small steps like a real pointer:
      // the list advances its gap incrementally as neighbours' midpoints
      // pass through the dragged proxy, so one big jump would stall halfway.
      final gesture = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + kPressTimeout);
      await _dragInSteps(tester, gesture, from: from, to: end);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(await _stored(), ['sites', 'trips', 'dives']);
      expect(
        tester.getTopLeft(_favoriteTile('trips')).dy,
        lessThan(tester.getTopLeft(_favoriteTile('dives')).dy),
      );
    });

    testWidgets('hovering a rail label brightens its star', (tester) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1300, 800));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      expect(_starDimmed(tester, 'Dives'), isTrue);

      await mouse.moveTo(
        tester.getCenter(find.widgetWithText(NavRailLabel, 'Dives')),
      );
      await tester.pumpAndSettle();
      expect(_starDimmed(tester, 'Dives'), isFalse);
      // Only the hovered row lights up.
      expect(_starDimmed(tester, 'Sites'), isTrue);

      await mouse.moveTo(const Offset(1300, 800));
      await tester.pumpAndSettle();
      expect(_starDimmed(tester, 'Dives'), isTrue);
    });
  });

  group('sidebar Favorites section (desktop extended rail)', () {
    testWidgets('shows a drag handle on each favorite instead of long-press', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(
        await _buildTestApp(
          favorites: ['dives', 'sites'],
          platform: TargetPlatform.macOS,
        ),
      );
      await tester.pumpAndSettle();

      expect(_dragHandleFor('dives'), findsOneWidget);
      expect(_dragHandleFor('sites'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
      // The handle sits after the un-star button in the same row.
      expect(
        tester.getCenter(_dragHandleFor('dives')).dx,
        greaterThan(tester.getCenter(_unstarFor('dives')).dx),
      );
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(
                of: _dragHandleFor('dives'),
                matching: find.byType(Tooltip),
              ),
            )
            .message,
        'Drag to reorder',
      );
    });

    testWidgets('dragging the handle reorders favorites and persists', (
      tester,
    ) async {
      _useViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(
        await _buildTestApp(
          favorites: ['dives', 'sites', 'trips'],
          platform: TargetPlatform.macOS,
        ),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(_dragHandleFor('dives'));
      final end = Offset(from.dx, tester.getCenter(_favoriteTile('trips')).dy);

      // The handle lifts immediately: no long-press needed on desktop.
      final gesture = await tester.startGesture(from);
      await tester.pump();
      await _dragInSteps(tester, gesture, from: from, to: end);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(await _stored(), ['sites', 'trips', 'dives']);
      expect(
        tester.getTopLeft(_favoriteTile('trips')).dy,
        lessThan(tester.getTopLeft(_favoriteTile('dives')).dy),
      );
    });

    testWidgets('the collapsed desktop rail falls back to long-press drag', (
      tester,
    ) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(
        await _buildTestApp(
          favorites: ['dives', 'sites'],
          platform: TargetPlatform.macOS,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(
        find.byType(ReorderableDelayedDragStartListener),
        findsNWidgets(2),
      );
    });
  });

  group('sidebar Favorites section (collapsed rail)', () {
    testWidgets('shows favorite icons in order without a text header', (
      tester,
    ) async {
      // Wide enough for the rail, too narrow for the extended labels.
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(
        await _buildTestApp(favorites: ['trips', 'sites']),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Star an item to add it here'), findsNothing);
      expect(_favoriteTile('trips'), findsOneWidget);
      expect(_favoriteTile('sites'), findsOneWidget);
      expect(
        tester.getTopLeft(_favoriteTile('trips')).dy,
        lessThan(tester.getTopLeft(_favoriteTile('sites')).dy),
      );
      // Moved, not copied: the rail proper no longer shows Trips.
      expect(find.byIcon(Icons.flight_outlined), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .destinations
            .length,
        13,
      );
    });

    testWidgets('renders nothing extra while empty', (tester) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('navFavoritesList')), findsNothing);
      expect(find.text('Star an item to add it here'), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('long-pressing a collapsed rail icon stars it', (tester) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.location_on_outlined));
      await tester.pumpAndSettle();

      expect(_favoriteTile('sites'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(await _stored(), ['sites']);
    });

    testWidgets('right-clicking the selected collapsed rail icon stars it', (
      tester,
    ) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(await _buildTestApp(initialLocation: '/dives'));
      await tester.pumpAndSettle();

      // The current destination renders its filled icon; the star affordance
      // has to work on that variant too.
      expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
      await tester.tap(
        find.byIcon(Icons.scuba_diving),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(_favoriteTile('dives'), findsOneWidget);
      expect(_favoriteSelected(tester, 'dives'), isTrue);
      expect(await _stored(), ['dives']);
    });

    testWidgets('right-clicking a collapsed favorite un-stars it', (
      tester,
    ) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(await _buildTestApp(favorites: ['sites']));
      await tester.pumpAndSettle();

      await tester.tap(_favoriteTile('sites'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(_favoriteTile('sites'), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(await _stored(), isEmpty);
    });

    testWidgets('tapping a collapsed favorite navigates', (tester) async {
      _useViewport(tester, const Size(1000, 900));
      await tester.pumpWidget(await _buildTestApp(favorites: ['trips']));
      await tester.pumpAndSettle();

      await tester.tap(_favoriteTile('trips'));
      await tester.pumpAndSettle();

      expect(find.text('Trips page'), findsOneWidget);
    });
  });
}
