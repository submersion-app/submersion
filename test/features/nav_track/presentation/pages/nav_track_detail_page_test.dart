import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_3d_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/world_map_expectations.dart';

/// Records calls instead of touching a real database, mirroring the
/// alignment page test's `_RecordingNavTrackRepository`.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? renamedId;
  String? newName;
  String? unlinkedId;
  String? deletedId;
  String? linkedRouteId;
  String? linkedDiveId;
  NavTrackLinkMode? linkMode;
  String? setSiteRouteId;
  String? setSiteId;
  GeoPoint? setSiteAnchor;
  bool? setSiteClearAnchor;
  String? setEquipmentRouteId;
  String? setEquipmentId;
  String? setEquipmentDeviceName;

  @override
  Future<void> rename(String routeId, String? name) async {
    renamedId = routeId;
    newName = name;
  }

  @override
  Future<void> setEquipment(
    String routeId, {
    String? equipmentId,
    String? deviceName,
  }) async {
    setEquipmentRouteId = routeId;
    setEquipmentId = equipmentId;
    setEquipmentDeviceName = deviceName;
  }

  @override
  Future<void> setSite(
    String routeId,
    String? siteId, {
    GeoPoint? anchor,
    bool clearAnchor = false,
  }) async {
    setSiteRouteId = routeId;
    setSiteId = siteId;
    setSiteAnchor = anchor;
    setSiteClearAnchor = clearAnchor;
  }

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    linkedRouteId = routeId;
    linkedDiveId = diveId;
    this.linkMode = linkMode;
    return true;
  }

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async {
    unlinkedId = routeId;
  }

  @override
  Future<void> delete(String routeId) async {
    deletedId = routeId;
  }
}

NavTrack _route({
  String? diveId,
  String? equipmentId,
  String? siteId,
  double? anchorLatitude,
  double? anchorLongitude,
  NavTrackEndMode endMode = NavTrackEndMode.none,
}) => NavTrack(
  id: 'r1',
  diveId: diveId,
  equipmentId: equipmentId,
  siteId: siteId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 0,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  endMode: endMode,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  required NavTrack route,
  Dive? linkedDive,
  EquipmentItem? equipment,
  DiveSite? site,
  GoRouter? router,
  List<Dive>? allDives,
  List<DiveSite>? allSites,
  Locale? locale,
  _RecordingNavTrackRepository? repository,
  MockSettingsNotifier? settingsNotifier,
}) async {
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  final effectiveRepository = repository ?? _RecordingNavTrackRepository();
  final effectiveOverrides = [
    ...overrides,
    navTrackByIdProvider(route.id).overrideWith((ref) async => route),
    navTrackRepositoryProvider.overrideWithValue(effectiveRepository),
    if (linkedDive != null)
      diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
    if (equipment != null)
      equipmentItemProvider(
        equipment.id,
      ).overrideWith((ref) async => equipment),
    if (site != null) siteProvider(site.id).overrideWith((ref) async => site),
    if (allDives != null) divesProvider.overrideWith((ref) async => allDives),
    if (allSites != null) sitesProvider.overrideWith((ref) async => allSites),
  ];
  if (router != null) {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  } else {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: route.id),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return effectiveRepository;
}

void main() {
  testWidgets('tapping the 3D-preview button opens NavTrack3dPage', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    await tester.tap(find.byKey(const ValueKey('nav-track-open-3d-preview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NavTrack3dPage), findsOneWidget);
  });

  testWidgets('shows "No dive linked" for an unlinked route', (tester) async {
    await _pump(tester, route: _route());

    expect(find.byKey(const ValueKey('nav-track-no-dive')), findsOneWidget);
    expect(find.text('No dive linked'), findsOneWidget);
    expect(find.text('Choose dive'), findsOneWidget);
  });

  group('on a narrow phone in German (#2692)', () {
    // A ListTile measures its trailing widget against the full tile width
    // first, so a translated action button there ("Tauchgang wählen",
    // "Tauchplatz wählen") starved the card's label down to one fragment per
    // line. The action belongs below the label instead.
    Future<void> pumpNarrow(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, route: _route(), locale: const Locale('de'));
    }

    void expectReadableAboveAction(
      WidgetTester tester, {
      required String label,
      required Finder action,
    }) {
      final labelRect = tester.getRect(find.text(label));
      final actionRect = tester.getRect(action);
      expect(
        labelRect.width,
        greaterThan(150),
        reason:
            '"$label" collapsed to ${labelRect.width}px wide on a 360px '
            'screen; the action button is starving the ListTile text column.',
      );
      expect(actionRect.top, greaterThanOrEqualTo(labelRect.bottom));
    }

    testWidgets('the "no dive linked" card keeps its label readable', (
      tester,
    ) async {
      await pumpNarrow(tester);

      expectReadableAboveAction(
        tester,
        label: 'Kein Tauchgang verknüpft',
        action: find.widgetWithText(TextButton, 'Tauchgang wählen'),
      );
    });

    testWidgets('the site card keeps its label readable', (tester) async {
      await pumpNarrow(tester);

      expectReadableAboveAction(
        tester,
        label: 'Kein Tauchplatz',
        action: find.byKey(const ValueKey('nav-track-change-site')),
      );
    });
  });

  testWidgets('shows the linked dive for a linked route', (tester) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 412,
      dateTime: DateTime(2026, 8, 22, 10, 8),
    );
    await _pump(
      tester,
      route: _route(diveId: 'dive-1'),
      linkedDive: dive,
    );

    expect(find.byKey(const ValueKey('nav-track-linked-dive')), findsOneWidget);
    expect(find.textContaining('#412'), findsOneWidget);
  });

  testWidgets('a linked dive without a number is labelled by its id, not as a '
      'numbered dive (matching the routes list chip)', (tester) async {
    final dive = Dive(id: 'dive-1', dateTime: DateTime(2026, 8, 22, 10, 8));
    await _pump(
      tester,
      route: _route(diveId: 'dive-1'),
      linkedDive: dive,
    );

    expect(find.text('Dive dive-1'), findsOneWidget);
    expect(find.text('Dive #dive-1'), findsNothing);
  });

  testWidgets('tapping "Choose dive" and picking one links the route to it', (
    tester,
  ) async {
    final candidate = Dive(
      id: 'dive-9',
      diveNumber: 9,
      dateTime: DateTime(2026, 8, 22, 9),
      entryTime: DateTime(2026, 8, 22, 9),
    );
    final repository = await _pump(
      tester,
      route: _route(),
      allDives: [candidate],
    );

    await tester.tap(find.text('Choose dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#9'));
    await tester.pumpAndSettle();

    expect(repository.linkedRouteId, 'r1');
    expect(repository.linkedDiveId, 'dive-9');
    expect(repository.linkMode, NavTrackLinkMode.manual);
  });

  testWidgets(
    '"Choose dive" pre-selects the sole time-overlapping dive (#2394)',
    (tester) async {
      // Entry time equals the route's own startTime (1755856800000ms), so
      // this is the sole dive NavTrackMatcher.candidatesFor overlaps --
      // no fake match service needed, the pre-selection is computed
      // directly from the dives already fetched for the sheet.
      final candidate = Dive(
        id: 'dive-9',
        diveNumber: 9,
        dateTime: DateTime.fromMillisecondsSinceEpoch(1755856800000),
        entryTime: DateTime.fromMillisecondsSinceEpoch(1755856800000),
      );
      await _pump(tester, route: _route(), allDives: [candidate]);

      await tester.tap(find.text('Choose dive'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('nav-track-dive-choice-dive-9')),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('shows the no-correction sentence when nothing was aligned', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    expect(find.text('No correction applied yet.'), findsOneWidget);
  });

  group('the equipment row', () {
    testWidgets('shows the linked equipment name and "Change device" when '
        'equipmentId is set', (tester) async {
      const scooter = EquipmentItem(
        id: 'eq1',
        name: 'Test Scooter',
        type: EquipmentType.dpv,
      );
      await _pump(
        tester,
        route: _route(equipmentId: 'eq1'),
        equipment: scooter,
      );

      expect(
        find.byKey(const ValueKey('nav-track-equipment-row')),
        findsOneWidget,
      );
      expect(find.text('Test Scooter'), findsOneWidget);
      expect(find.text('Change device'), findsOneWidget);
    });

    testWidgets(
      'shows a "no device" placeholder and "Choose device" when unset',
      (tester) async {
        await _pump(tester, route: _route());

        expect(find.text('No device'), findsOneWidget);
        expect(find.text('Choose device'), findsOneWidget);
      },
    );

    testWidgets(
      'no "Change device" entry left in the overflow menu (moved to its '
      'own row)',
      (tester) async {
        await _pump(tester, route: _route());

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Change device'), findsNothing);
      },
    );
  });

  testWidgets(
    'the inline map preview renders a TileLayer with the app\'s tile URL '
    '(item 3)',
    (tester) async {
      await _pump(
        tester,
        route: _route(anchorLatitude: 47.1, anchorLongitude: 8.3),
      );

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavTrackDetailPage)),
      );
      expect(tileLayer.urlTemplate, container.read(mapTileUrlProvider));
    },
  );

  testWidgets(
    'the inline map fits its camera to the whole route, not a fixed zoom '
    'on the anchor alone (a long route was cut off at the map edge)',
    (tester) async {
      final route = _route(anchorLatitude: 47.1, anchorLongitude: 8.3).copyWith(
        points: [
          for (var i = 0; i < 5; i++)
            NavTrackPoint(
              timestamp: 1755856800 + i,
              // A route spread far wider than a fixed zoom 15 would show,
              // in metres east of the anchor.
              north: 0,
              east: i * 2000.0,
              depth: 5,
            ),
        ],
      );
      await _pump(tester, route: route);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCameraFit, isNotNull);
    },
  );

  testWidgets('a route crossing the antimeridian still fits without crashing '
      '(Copilot review on PR #3637: a raw LatLngBounds.fromPoints asserts '
      'east <= 180 and cannot express a wrapped route)', (tester) async {
    // Anchor just west of the dateline; an 11 km east offset pushes the
    // second point past 180 deg, where it wraps to a negative longitude.
    final route = _route(anchorLatitude: 0, anchorLongitude: 179.95).copyWith(
      points: [
        for (final east in [0.0, 11000.0])
          NavTrackPoint(
            timestamp: 1755856800 + east.toInt(),
            north: 0,
            east: east,
            depth: 5,
          ),
      ],
    );
    await _pump(tester, route: route);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    // The wrap means no legal LatLngBounds exists, so TrackCamera falls
    // back to its centre+zoom framing instead of initialCameraFit.
    expect(map.options.initialCameraFit, isNull);
    expect(
      map.options.initialCenter.longitude,
      inInclusiveRange(-180.0, 180.0),
    );
  });

  testWidgets(
    'falls back to the anchor-centered fixed zoom when there is nothing '
    'to fit a camera to',
    (tester) async {
      await _pump(
        tester,
        route: _route(anchorLatitude: 47.1, anchorLongitude: 8.3),
      );

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCameraFit, isNull);
      expect(map.options.initialCenter, const LatLng(47.1, 8.3));
    },
  );

  testWidgets(
    'the inline map re-frames when the anchor moves, since initialCameraFit '
    'only applies once (Change site can move the anchor to a new pin)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var current = _route(anchorLatitude: 47.1, anchorLongitude: 8.3);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider('r1').overrideWith((ref) async => current),
            navTrackRepositoryProvider.overrideWithValue(
              _RecordingNavTrackRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NavTrackDetailPage(trackId: 'r1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(controller.camera.center.latitude, closeTo(47.1, 0.01));

      current = _route(anchorLatitude: 10.0, anchorLongitude: 20.0);
      ProviderScope.containerOf(
        tester.element(find.byType(NavTrackDetailPage)),
      ).invalidate(navTrackByIdProvider('r1'));
      await tester.pumpAndSettle();

      expect(controller.camera.center.latitude, closeTo(10.0, 0.01));
      expect(controller.camera.center.longitude, closeTo(20.0, 0.01));
    },
  );

  testWidgets(
    'the inline map can rotate, so it carries a compass that resets it to '
    'north (#3386)',
    (tester) async {
      // The new equipment row (#3635) pushed the map further down the
      // ListView, past the default 800x600 test surface -- ensureVisible
      // alone left the compass button's hit-test point just outside the
      // viewport (off by a few dozen px), so this gives the page the room
      // the earlier, shorter content didn't need.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        route: _route(anchorLatitude: 47.1, anchorLongitude: 8.3),
      );

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController;
      expect(controller, isNotNull, reason: 'the compass steers the map');
      expect(
        tester
            .widget<MapCompassButton>(find.byType(MapCompassButton))
            .controller,
        same(controller),
      );

      controller!.rotate(45);
      await tester.pump();
      await tester.tap(find.byType(MapCompassButton));
      await tester.pumpAndSettle();

      expect(controller.camera.rotation % 360, closeTo(0, 0.01));
    },
  );

  group('speed stats respect the depth-unit setting', () {
    NavTrack routeWithSpeed(double metersPerSecond) =>
        _route(anchorLatitude: 47.1, anchorLongitude: 8.3).copyWith(
          points: [
            NavTrackPoint(
              timestamp: 1755856800,
              north: 0,
              east: 0,
              depth: 0,
              speed: metersPerSecond,
            ),
            NavTrackPoint(
              timestamp: 1755856801,
              north: 1,
              east: 0,
              depth: 0,
              speed: metersPerSecond,
            ),
          ],
        );

    testWidgets('metric (default): m/min', (tester) async {
      await _pump(tester, route: routeWithSpeed(2));

      // 2 m/s = 120 m/min.
      expect(find.textContaining('120.0 m/min'), findsWidgets);
    });

    testWidgets('imperial: ft/min, not m/min', (tester) async {
      final settings = MockSettingsNotifier();
      await settings.setDepthUnit(DepthUnit.feet);
      await _pump(tester, route: routeWithSpeed(2), settingsNotifier: settings);

      // 120 m/min x 3.28084 ft/m.
      expect(find.textContaining('393.7 ft/min'), findsWidgets);
      expect(find.textContaining('m/min'), findsNothing);
    });
  });

  group('the battery row', () {
    testWidgets(
      'skips a leading 0.00V sample (sensor not settled yet) when picking '
      'the start reading (018.DAT.csv: row 1 reads 0, row 2 reads the real '
      '3.9)',
      (tester) async {
        final route = _route(anchorLatitude: 47.1, anchorLongitude: 8.3)
            .copyWith(
              points: const [
                NavTrackPoint(
                  timestamp: 1755856800,
                  north: 0,
                  east: 0,
                  depth: 0,
                  batteryVolts: 0,
                ),
                NavTrackPoint(
                  timestamp: 1755856801,
                  north: 0,
                  east: 0,
                  depth: 0,
                  batteryVolts: 3.9,
                ),
                NavTrackPoint(
                  timestamp: 1755857000,
                  north: 0,
                  east: 0,
                  depth: 0,
                  batteryVolts: 3.78,
                ),
              ],
            );
        await _pump(tester, route: route);

        expect(find.text('Battery: 3.90 V -> 3.78 V'), findsOneWidget);
        expect(find.textContaining('0.00 V'), findsNothing);
      },
    );

    testWidgets('no battery row when every sample is 0V or null', (
      tester,
    ) async {
      final route = _route(anchorLatitude: 47.1, anchorLongitude: 8.3).copyWith(
        points: const [
          NavTrackPoint(timestamp: 1755856800, north: 0, east: 0, depth: 0),
          NavTrackPoint(
            timestamp: 1755856801,
            north: 0,
            east: 0,
            depth: 0,
            batteryVolts: 0,
          ),
        ],
      );
      await _pump(tester, route: route);

      expect(find.textContaining('Battery:'), findsNothing);
    });
  });

  group('the site row (item 4)', () {
    testWidgets(
      'shows a "no site" placeholder and "Choose site" when unset, and no '
      'longer offers "Change site" from the overflow menu',
      (tester) async {
        await _pump(tester, route: _route());

        expect(
          find.byKey(const ValueKey('nav-track-site-row')),
          findsOneWidget,
        );
        expect(find.text('No site'), findsOneWidget);
        expect(find.text('Choose site'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Change site'), findsNothing);
      },
    );

    testWidgets('shows the site name and "Change site" when a site is set', (
      tester,
    ) async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      await _pump(
        tester,
        route: _route(siteId: 'site-1'),
        site: site,
      );

      expect(find.byKey(const ValueKey('nav-track-site-row')), findsOneWidget);
      expect(find.text('Test Site'), findsOneWidget);
      expect(find.text('Change site'), findsOneWidget);
    });

    testWidgets('tapping the action opens the site picker', (tester) async {
      await _pump(tester, route: _route());

      await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
      await tester.pumpAndSettle();

      expect(find.byType(SitePickerSheet), findsOneWidget);
    });

    testWidgets('picking an existing site in the picker assigns it to the '
        'route', (tester) async {
      const oldSite = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      const newSite = DiveSite(
        id: 'site-2',
        name: 'Other Site',
        location: GeoPoint(47.2, 8.4),
      );
      final repository = await _pump(
        tester,
        route: _route(siteId: 'site-1'),
        site: oldSite,
        allSites: [oldSite, newSite],
      );

      await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(newSite.name));
      await tester.pumpAndSettle();

      expect(repository.setSiteRouteId, 'r1');
      expect(repository.setSiteId, 'site-2');
      expect(repository.setSiteAnchor, const GeoPoint(47.2, 8.4));
    });

    testWidgets(
      'creating a new site in the picker pushes /sites/new and assigns the '
      'saved site to the route',
      (tester) async {
        final route = _route();
        const newSite = DiveSite(
          id: 'site-new',
          name: 'Brand New Site',
          location: GeoPoint(47.5, 8.6),
        );
        final router = GoRouter(
          initialLocation: '/tracks/underwater/${route.id}',
          routes: [
            GoRoute(
              path: '/tracks/underwater/:id',
              builder: (context, state) =>
                  NavTrackDetailPage(trackId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/sites/new',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(newSite.id),
                  child: const Text('save new site'),
                ),
              ),
            ),
          ],
        );
        final repository = await _pump(
          tester,
          route: route,
          router: router,
          site: newSite,
          allSites: const [],
        );

        await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Dive Site'));
        await tester.pumpAndSettle();

        expect(find.text('save new site'), findsOneWidget);
        await tester.tap(find.text('save new site'));
        await tester.pumpAndSettle();

        expect(repository.setSiteRouteId, 'r1');
        expect(repository.setSiteId, 'site-new');
        expect(repository.setSiteAnchor, const GeoPoint(47.5, 8.6));
      },
    );

    testWidgets(
      'creating a new site seeds the form with the route anchor and keeps a '
      'hand-placed anchor',
      (tester) async {
        final route = _route(anchorLatitude: 47.3, anchorLongitude: 8.5);
        const newSite = DiveSite(
          id: 'site-new',
          name: 'Brand New Site',
          location: GeoPoint(47.3, 8.5),
        );
        Object? seededLocation;
        final router = GoRouter(
          initialLocation: '/tracks/underwater/${route.id}',
          routes: [
            GoRoute(
              path: '/tracks/underwater/:id',
              builder: (context, state) =>
                  NavTrackDetailPage(trackId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/sites/new',
              builder: (context, state) {
                seededLocation = state.extra;
                return Scaffold(
                  body: TextButton(
                    onPressed: () => context.pop(newSite.id),
                    child: const Text('save new site'),
                  ),
                );
              },
            ),
          ],
        );
        final repository = await _pump(
          tester,
          route: route,
          router: router,
          site: newSite,
          allSites: const [],
        );

        await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Dive Site'));
        await tester.pumpAndSettle();

        expect(
          seededLocation,
          const NewSiteSeed(location: GeoPoint(47.3, 8.5)),
        );
        await tester.tap(find.text('save new site'));
        await tester.pumpAndSettle();

        // The anchor was placed by hand (no old site), so the site change
        // must not rewrite it.
        expect(repository.setSiteId, 'site-new');
        expect(repository.setSiteAnchor, isNull);
        expect(repository.setSiteClearAnchor, isFalse);
      },
    );
  });

  testWidgets('shows a loading indicator while the route resolves', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final completer = Completer<NavTrack?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the load-error message when the provider errors', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider(
            'r1',
          ).overrideWith((ref) async => Future<NavTrack?>.error('boom')),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this track.'), findsOneWidget);
  });

  testWidgets('shows "Route not found" when the route no longer exists', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track not found.'), findsOneWidget);
  });

  testWidgets('shows the "set start point" placeholder when unanchored', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    expect(
      find.text('Set the start point to see this on a map.'),
      findsOneWidget,
    );
    expect(find.byType(FlutterMap), findsNothing);
  });

  group('correction status text per end mode', () {
    testWidgets('none', (tester) async {
      await _pump(tester, route: _route());
      expect(find.text('No correction applied yet.'), findsOneWidget);
    });

    testWidgets('sameAsStart', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.sameAsStart));
      expect(find.text('End set to same as start.'), findsOneWidget);
    });

    testWidgets('point', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.point));
      expect(find.text('End point set on the map.'), findsOneWidget);
    });

    testWidgets('gpsFix', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.gpsFix));
      expect(
        find.text('End set from the recording\'s GPS fix.'),
        findsOneWidget,
      );
    });
  });

  group('overflow menu actions', () {
    testWidgets('rename saves the trimmed new name through the repository', (
      tester,
    ) async {
      final repository = await _pump(tester, route: _route());

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Morning dive  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.renamedId, 'r1');
      expect(repository.newName, 'Morning dive');
    });

    testWidgets(
      'change device opens the picker and persists the chosen equipment',
      (tester) async {
        const scooter = EquipmentItem(
          id: 'eq1',
          name: 'Test Scooter',
          type: EquipmentType.dpv,
        );
        final overrides = await getBaseOverrides();
        final repository = _RecordingNavTrackRepository();
        final route = _route();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              navTrackByIdProvider(route.id).overrideWith((ref) async => route),
              navTrackRepositoryProvider.overrideWithValue(repository),
              activeEquipmentProvider.overrideWith((ref) async => [scooter]),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: NavTrackDetailPage(trackId: route.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('nav-track-change-device')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Scooter'));
        await tester.pumpAndSettle();

        expect(repository.setEquipmentRouteId, 'r1');
        expect(repository.setEquipmentId, 'eq1');
        expect(repository.setEquipmentDeviceName, 'Test Scooter');
      },
    );

    testWidgets('change device, choosing "no equipment", clears both fields', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final repository = _RecordingNavTrackRepository();
      final route = _route(equipmentId: 'eq1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
            navTrackRepositoryProvider.overrideWithValue(repository),
            activeEquipmentProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NavTrackDetailPage(trackId: route.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-track-change-device')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-track-equipment-none')));
      await tester.pumpAndSettle();

      expect(repository.setEquipmentRouteId, 'r1');
      expect(repository.setEquipmentId, isNull);
      expect(repository.setEquipmentDeviceName, isNull);
    });

    testWidgets('the unlink item only appears for a linked route, and calls '
        'unlink', (tester) async {
      final unlinkedRepository = await _pump(
        tester,
        route: _route(diveId: 'dive-1'),
        linkedDive: Dive(
          id: 'dive-1',
          diveNumber: 5,
          dateTime: DateTime(2026, 8, 22),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Unlink'), findsOneWidget);
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(unlinkedRepository.unlinkedId, 'r1');
    });

    testWidgets('no unlink item for an unlinked route', (tester) async {
      await _pump(tester, route: _route());

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Unlink'), findsNothing);
    });

    testWidgets('delete asks for confirmation, then deletes and pops', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final repository = _RecordingNavTrackRepository();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/tracks/underwater/${route.id}'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
            navTrackRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete track?'), findsOneWidget);
      // Two "Delete" texts now exist: the dialog title's button and the
      // menu item underneath; tap the dialog's action explicitly.
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, 'r1');
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('toolbar navigation', () {
    testWidgets('the align button pushes the alignment route', (tester) async {
      final overrides = await getBaseOverrides();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/tracks/underwater/${route.id}',
        routes: [
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/align',
            builder: (context, state) =>
                const Scaffold(body: Text('ALIGN_PAGE')),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/3d',
            builder: (context, state) =>
                const Scaffold(body: Text('SEASCAPE_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-track-align')));
      await tester.pumpAndSettle();
      expect(find.text('ALIGN_PAGE'), findsOneWidget);
    });

    testWidgets('the 3D button pushes the seascape route', (tester) async {
      final overrides = await getBaseOverrides();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/tracks/underwater/${route.id}',
        routes: [
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/3d',
            builder: (context, state) =>
                const Scaffold(body: Text('SEASCAPE_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('nav-track-open-3d')),
          matching: find.byIcon(Icons.terrain),
        ),
        findsOneWidget,
        reason:
            'should match the icon dive_detail_page.dart uses for its '
            '"3D-Unterwasserwelt" button, not the AR-cube icon',
      );

      await tester.tap(find.byKey(const ValueKey('nav-track-open-3d')));
      await tester.pumpAndSettle();
      expect(find.text('SEASCAPE_PAGE'), findsOneWidget);
    });
  });

  group('navTrackAnchorShouldFollowSiteChange (item 5)', () {
    test('the anchor follows the new site when it was never set', () {
      expect(
        navTrackAnchorShouldFollowSiteChange(null, const GeoPoint(47.1, 8.3)),
        isTrue,
      );
    });

    test('the anchor follows the new site when it still equals the old '
        'site\'s pin (the diver never moved the start point)', () {
      const oldSiteLocation = GeoPoint(47.1, 8.3);
      expect(
        navTrackAnchorShouldFollowSiteChange(oldSiteLocation, oldSiteLocation),
        isTrue,
      );
    });

    test('the anchor stays when the diver already moved it away from the old '
        'site\'s pin', () {
      const oldSiteLocation = GeoPoint(47.1, 8.3);
      const movedAnchor = GeoPoint(47.2, 8.4);
      expect(
        navTrackAnchorShouldFollowSiteChange(movedAnchor, oldSiteLocation),
        isFalse,
      );
    });
  });

  group('navTrackAnchorChangeForSite', () {
    const oldPin = GeoPoint(47.1, 8.3);
    const newPin = GeoPoint(47.2, 8.4);

    test('moves an anchor that followed the old pin to the new pin', () {
      expect(navTrackAnchorChangeForSite(oldPin, oldPin, newPin), (
        write: true,
        anchor: newPin,
      ));
    });

    test('clears an anchor that followed the old pin when the new site has '
        'no pin, rather than leaving the route at the old site', () {
      expect(navTrackAnchorChangeForSite(oldPin, oldPin, null), (
        write: true,
        anchor: null,
      ));
    });

    test('leaves a hand-placed anchor alone', () {
      expect(
        navTrackAnchorChangeForSite(const GeoPoint(50, 10), oldPin, newPin),
        (write: false, anchor: null),
      );
    });
  });

  testWidgets(
    'a track with no name or source file is titled Underwater track',
    (tester) async {
      await _pump(
        tester,
        route: NavTrack(
          id: 'r1',
          source: NavTrackSource.seacraftEnc,
          startTime: 1755856800000,
          endTime: 1755860400000,
          pointCount: 0,
          createdAt: DateTime(2026, 8, 22),
          updatedAt: DateTime(2026, 8, 22),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Underwater track'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the inline map zooms and scrolls like the other maps '
      '(#3664)', (tester) async {
    await _pump(
      tester,
      route: _route(anchorLatitude: 47.1, anchorLongitude: 8.3),
    );
    expectZoomsAndScrollsLikeOtherMaps(tester);
  });
}
