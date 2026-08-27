import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart' show Override;

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _loc = GeoPoint(12.15, -68.3);

class _Host extends StatefulWidget {
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;
  const _Host({this.selectedSiteId, this.selectedSiteLocation});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  SiteScapeMode mode = SiteScapeMode.map2d;

  @override
  Widget build(BuildContext context) {
    return SiteScapeView(
      mode: mode,
      onModeChanged: (m) => setState(() => mode = m),
      selectedSiteId: widget.selectedSiteId,
      selectedSiteLocation: widget.selectedSiteLocation,
      mapController: null,
      // Real hosts seat the toggle inside their own 2D stack, so it goes
      // offstage with the map in 3D and the terrain pane's injected copy
      // is the only one on screen. Mirror that, or the two would collide
      // on the same widget keys.
      mapBuilder: (_) => Stack(
        children: [
          const ColoredBox(color: Colors.green, child: Text('MAP_STACK')),
          SiteScapeModeToggle(
            mode: mode,
            onModeChanged: (m) => setState(() => mode = m),
            selectedSiteId: widget.selectedSiteId,
            selectedSiteLocation: widget.selectedSiteLocation,
          ),
        ],
      ),
    );
  }
}

Widget _app(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      // The pane resolves via its own provider; park it on no-data so the
      // pane renders a terminal message without touching the network.
      siteSeascapeProvider.overrideWith(
        (ref, id) async => const SiteSeascapeNoData(),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('known-absent grid keeps the map and disables 3D', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(selectedSiteId: 'site-1', selectedSiteLocation: _loc),
        overrides: [
          bathymetryGridProvider.overrideWith((ref, key) async => null),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('MAP_STACK'), findsOneWidget);
    expect(find.byType(SiteTerrainPane), findsNothing);
    // Known-absent grid: the 3D button is disabled.
    final disabled = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape3dButton')),
    );
    expect(disabled.onPressed, isNull);
  });

  testWidgets('with a grid the toggle enters 3D and Offstage hides the map', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(selectedSiteId: 'site-1', selectedSiteLocation: _loc),
        overrides: [
          // A never-completing fetch: the grid stays LOADING, so the 3D
          // button stays enabled (only a known-absent grid disables it).
          bathymetryGridProvider.overrideWith(
            (ref, key) => Completer<BathymetryGrid?>().future,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final b3 = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape3dButton')),
    );
    expect(
      b3.onPressed,
      isNotNull,
      reason: 'a still-loading grid must keep 3D enabled',
    );
    await tester.tap(find.byKey(const ValueKey('siteScape3dButton')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SiteTerrainPane), findsOneWidget);
    // Nearest Offstage ancestor is the view's own (Navigator adds more
    // further up the tree); default finders skip offstage subtrees, so
    // both finders must opt out of that.
    final offstage = tester.widget<Offstage>(
      find
          .ancestor(
            of: find.text('MAP_STACK', skipOffstage: false),
            matching: find.byType(Offstage, skipOffstage: false),
          )
          .first,
    );
    expect(offstage.offstage, isTrue);
    await tester.tap(find.byKey(const ValueKey('siteScape2dButton')));
    await tester.pump();
    expect(find.byType(SiteTerrainPane), findsNothing);
  });

  testWidgets('in 3D the toggle is docked inside the terrain pane, so it '
      'shares a card with the pane actions instead of floating alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(selectedSiteId: 'site-1', selectedSiteLocation: _loc),
        overrides: [
          bathymetryGridProvider.overrideWith(
            (ref, key) => Completer<BathymetryGrid?>().future,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('siteScape3dButton')));
    await tester.pump();
    await tester.pump();

    // The host's own copy went offstage with the 2D stack, so the only
    // toggle on screen is the one the pane docked.
    expect(
      find.descendant(
        of: find.byType(SiteTerrainPane),
        matching: find.byKey(const ValueKey('siteScape2dButton')),
      ),
      findsOneWidget,
    );
    // Even on a site whose seascape came back empty, the way back to 2D is
    // still docked: entering 3D must never be a dead end.
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
    final back = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape2dButton')),
    );
    expect(back.onPressed, isNotNull);
  });

  testWidgets('no selection disables 3D', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape3dButton')),
    );
    expect(button.onPressed, isNull);
  });
}
