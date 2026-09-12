import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

List<NavTrackPoint> _points() => const [
  NavTrackPoint(
    timestamp: 1700000000,
    north: 0,
    east: 0,
    depth: 5,
    distance: 0,
    speed: 0.3,
  ),
  NavTrackPoint(
    timestamp: 1700000600,
    north: 40,
    east: 0,
    depth: 5,
    distance: 40,
    speed: 0.3,
  ),
];

Dive _dive(String id, DateTime entry, {DiveSite? site}) => Dive(
  id: id,
  dateTime: entry,
  entryTime: entry,
  site: site,
  tanks: const [],
  profile: const [],
  gear: looseGear(const []),
  notes: '',
  photoIds: const [],
  sightings: const [],
  weights: const [],
  tags: const [],
);

NavTrackImportPreview _preview({
  List<Dive> candidateDives = const [],
  String? duplicateOfRouteId,
  List<NavTrackPoint>? points,
}) {
  final p = points ?? _points();
  return NavTrackImportPreview(
    parsed: ParsedNavTrack(points: p),
    stats: NavTrackStats.of(p),
    segmentation: NavTrackSegmenter.classify(p),
    candidateDives: candidateDives,
    duplicateOfRouteId: duplicateOfRouteId,
    sourceRef: '005.DAT.csv',
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required NavTrackImportPreview preview,
  NavTrackImportService? service,
  List<EquipmentItem>? equipment,
}) async {
  // A host locale the app actually translates into, so the English finders
  // below pass only because the MaterialApp pins `en`. Drop the pin and
  // every test in this file that asserts on English strings ("No site
  // chosen", "No equipment", the import errors) would fail on a non-English
  // host locale, which is the point.
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        if (service != null)
          navTrackImportServiceProvider.overrideWithValue(service),
        if (equipment != null)
          activeEquipmentProvider.overrideWith((ref) async => equipment),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NavTrackImportReviewPage(
          bytes: Uint8List(0),
          fileName: '005.DAT.csv',
          preview: preview,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Like [_pump], but with a real `GoRouter` so a successful save's
/// `context.go('/nav-routes/$id')` has somewhere to land.
Future<void> _pumpWithRouter(
  WidgetTester tester, {
  required NavTrackImportPreview preview,
  NavTrackImportService? service,
  List<EquipmentItem>? equipment,
  NavTrackRepository? repository,
}) async {
  final base = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: '/review',
    routes: [
      GoRoute(
        path: '/review',
        builder: (context, state) => NavTrackImportReviewPage(
          bytes: Uint8List(0),
          fileName: '005.DAT.csv',
          preview: preview,
        ),
      ),
      GoRoute(
        path: '/nav-routes/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('ROUTE_DETAIL_PAGE')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        if (service != null)
          navTrackImportServiceProvider.overrideWithValue(service),
        if (equipment != null)
          activeEquipmentProvider.overrideWith((ref) async => equipment),
        if (repository != null)
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
}

/// Records the parameters `commit` was called with, so a test can assert on
/// them without touching a real database.
class _RecordingImportService implements NavTrackImportService {
  String? lastEquipmentId;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async => throw UnimplementedError();

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
  }) async {
    lastEquipmentId = equipmentId;
    return 'new-route-id';
  }
}

/// Records whether/how often `delete` was called, without touching a real
/// database -- the base class's other methods are never exercised by the
/// tests that use this fake.
class _RecordingRepository extends NavTrackRepository {
  int deleteCallCount = 0;
  final List<String> deletedIds = [];

  @override
  Future<void> delete(String routeId) async {
    deleteCallCount++;
    deletedIds.add(routeId);
  }
}

/// A `commit` that always fails, to prove a duplicate is not deleted ahead
/// of a commit that never lands.
class _ThrowingImportService implements NavTrackImportService {
  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async => throw UnimplementedError();

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
  }) async {
    throw StateError('commit failed');
  }
}

void main() {
  testWidgets('shows the source file name and segment summary', (tester) async {
    await _pump(tester, preview: _preview());
    expect(find.text('005.DAT.csv'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nav-track-segment-summary')),
      findsOneWidget,
    );
  });

  testWidgets('pre-selects the unique overlapping dive', (tester) async {
    final dive = _dive('d1', DateTime.utc(2025, 1, 15, 16, 16, 7));
    await _pump(tester, preview: _preview(candidateDives: [dive]));

    final radio = tester.widget<RadioListTile<String?>>(
      find.byKey(const ValueKey('nav-track-link-d1')),
    );
    expect(radio.value, 'd1');

    final group = tester.widget<RadioGroup<String?>>(
      find.byType(RadioGroup<String?>),
    );
    expect(group.groupValue, 'd1');
  });

  testWidgets(
    'pre-fills the site from the pre-selected dive\'s own hydrated site, '
    'with no further action from the diver',
    (tester) async {
      const site = DiveSite(id: 'site-1', name: 'Lake Zurich');
      final dive = _dive(
        'd1',
        DateTime.utc(2025, 1, 15, 16, 16, 7),
        site: site,
      );
      await _pump(tester, preview: _preview(candidateDives: [dive]));

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Lake Zurich'), findsOneWidget);
    },
  );

  testWidgets(
    'clears a pre-filled site when switching to a dive with no site',
    (tester) async {
      const site = DiveSite(id: 'site-1', name: 'Lake Zurich');
      final withSite = _dive(
        'd1',
        DateTime.utc(2025, 1, 15, 16, 16, 7),
        site: site,
      );
      final withoutSite = _dive('d2', DateTime.utc(2025, 1, 15, 16, 20, 0));
      await _pump(
        tester,
        preview: _preview(candidateDives: [withSite, withoutSite]),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('nav-track-link-d1')),
      );
      await tester.tap(find.byKey(const ValueKey('nav-track-link-d1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lake Zurich'));
      expect(find.text('Lake Zurich'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('nav-track-link-d2')),
      );
      await tester.tap(find.byKey(const ValueKey('nav-track-link-d2')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('nav-track-site-picker')),
      );

      expect(find.text('Lake Zurich'), findsNothing);
      expect(find.text('No site chosen'), findsOneWidget);
    },
  );

  testWidgets('leaves the route unlinked when several dives overlap', (
    tester,
  ) async {
    final d1 = _dive('d1', DateTime.utc(2025, 1, 15, 16, 16, 7));
    final d2 = _dive('d2', DateTime.utc(2025, 1, 15, 16, 20, 0));
    await _pump(tester, preview: _preview(candidateDives: [d1, d2]));

    final group = tester.widget<RadioGroup<String?>>(
      find.byType(RadioGroup<String?>),
    );
    expect(group.groupValue, isNull);
    expect(
      find.byKey(const ValueKey('nav-track-link-unlinked')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-track-link-d1')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-track-link-d2')), findsOneWidget);
  });

  testWidgets('shows no warnings for a normal, fresh import', (tester) async {
    await _pump(tester, preview: _preview());
    expect(
      find.byKey(const ValueKey('nav-track-warning-no-movement')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('nav-track-warning-duplicate')),
      findsNothing,
    );
  });

  testWidgets('warns when no movement was recorded', (tester) async {
    const still = [
      NavTrackPoint(timestamp: 1700000000, north: 0, east: 0, depth: 30),
      NavTrackPoint(timestamp: 1700000600, north: 0, east: 0, depth: 30),
    ];
    await _pump(tester, preview: _preview(points: still));
    expect(
      find.byKey(const ValueKey('nav-track-warning-no-movement')),
      findsOneWidget,
    );
  });

  testWidgets('warns about a duplicate and offers replace', (tester) async {
    await _pump(
      tester,
      preview: _preview(duplicateOfRouteId: 'existing-route'),
    );
    expect(
      find.byKey(const ValueKey('nav-track-warning-duplicate')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('shows a site picker entry point defaulting to no site chosen', (
    tester,
  ) async {
    await _pump(tester, preview: _preview());
    // The equipment section added above the site section pushes it (and
    // everything below) out of the default test viewport's cache extent,
    // so it is not built until scrolled into view -- same as a real user
    // would need to scroll a phone screen this long.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-track-site-picker')), findsOneWidget);
    expect(find.text('No site chosen'), findsOneWidget);
  });

  testWidgets(
    'shows an equipment picker entry point defaulting to no equipment '
    'chosen',
    (tester) async {
      await _pump(tester, preview: _preview(), equipment: const []);
      expect(
        find.byKey(const ValueKey('nav-track-equipment-picker')),
        findsOneWidget,
      );
      expect(find.text('No equipment'), findsOneWidget);
    },
  );

  testWidgets('picking equipment and saving persists the chosen equipmentId', (
    tester,
  ) async {
    const scooter = EquipmentItem(
      id: 'eq1',
      name: 'Test Scooter',
      type: EquipmentType.dpv,
    );
    final service = _RecordingImportService();
    await _pumpWithRouter(
      tester,
      preview: _preview(),
      service: service,
      equipment: const [scooter],
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-equipment-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Scooter'));
    await tester.pumpAndSettle();

    expect(find.text('Test Scooter'), findsOneWidget);

    // Scroll the save button into the test viewport (see the "site picker"
    // test above for why).
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
    await tester.pumpAndSettle();

    expect(service.lastEquipmentId, 'eq1');
  });

  testWidgets('saving without picking equipment commits a null equipmentId', (
    tester,
  ) async {
    final service = _RecordingImportService();
    await _pumpWithRouter(
      tester,
      preview: _preview(),
      service: service,
      equipment: const [],
    );

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
    await tester.pumpAndSettle();

    expect(service.lastEquipmentId, isNull);
  });

  testWidgets(
    'does not delete the duplicate route when replacing it and commit fails '
    '(a failed commit must leave the original route in place)',
    (tester) async {
      final repository = _RecordingRepository();
      final service = _ThrowingImportService();
      await _pumpWithRouter(
        tester,
        preview: _preview(duplicateOfRouteId: 'existing-route'),
        service: service,
        repository: repository,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
      await tester.pumpAndSettle();

      expect(repository.deleteCallCount, 0);
      // The page stays put (no navigation to a route that was never
      // created) and surfaces the failure instead.
      expect(find.text('ROUTE_DETAIL_PAGE'), findsNothing);
    },
  );

  testWidgets('deletes the duplicate route only after a successful commit', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    final service = _RecordingImportService();
    await _pumpWithRouter(
      tester,
      preview: _preview(duplicateOfRouteId: 'existing-route'),
      service: service,
      repository: repository,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
    await tester.pumpAndSettle();

    expect(repository.deleteCallCount, 1);
    expect(repository.deletedIds, ['existing-route']);
  });

  testWidgets('shows a parse-error message when the preview future rejects', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final failingService = _FailingImportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          navTrackImportServiceProvider.overrideWithValue(failingService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackImportReviewPage(
            bytes: Uint8List(0),
            fileName: 'bad.csv',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not be read as a Seacraft ENC'),
      findsOneWidget,
    );
  });

  testWidgets('shows a generic import-error message for a non-parse failure', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final throwingService = _GenericFailingImportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          navTrackImportServiceProvider.overrideWithValue(throwingService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackImportReviewPage(
            bytes: Uint8List(0),
            fileName: 'bad.csv',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This file could not be imported:'),
      findsOneWidget,
    );
  });

  testWidgets(
    'choosing "no equipment" after picking one clears the selection',
    (tester) async {
      const scooter = EquipmentItem(
        id: 'eq1',
        name: 'Test Scooter',
        type: EquipmentType.dpv,
      );
      final service = _RecordingImportService();
      await _pumpWithRouter(
        tester,
        preview: _preview(),
        service: service,
        equipment: const [scooter],
      );

      await tester.tap(
        find.byKey(const ValueKey('nav-track-equipment-picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Scooter'));
      await tester.pumpAndSettle();
      expect(find.text('Test Scooter'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('nav-track-equipment-picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No equipment'));
      await tester.pumpAndSettle();

      expect(find.text('Test Scooter'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
      await tester.pumpAndSettle();

      expect(service.lastEquipmentId, isNull);
    },
  );
}

class _FailingImportService implements NavTrackImportService {
  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    throw const NavTrackParseException(
      'bad file',
      reason: NavTrackParseReason.unreadable,
    );
  }

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
  }) async => throw UnimplementedError();
}

/// A `prepare` that fails with a plain exception rather than
/// [NavTrackParseException], to exercise the page's generic import-error
/// branch (as opposed to the localized parse-reason text).
class _GenericFailingImportService implements NavTrackImportService {
  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    throw StateError('disk full');
  }

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
  }) async => throw UnimplementedError();
}
