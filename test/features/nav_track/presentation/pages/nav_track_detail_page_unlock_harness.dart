import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_edit_save_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_file_actions.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pushed_page_launcher.dart';
import '../../../../helpers/test_app.dart';

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

final candidateDive = Dive(
  id: 'dive-9',
  diveNumber: 9,
  dateTime: DateTime(2026, 8, 22, 9),
  entryTime: DateTime(2026, 8, 22, 9),
);

List<NavTrackPoint> _samples(int count) => [
  for (var i = 0; i < count; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: i * 5.0,
      depth: 5.0 + i,
      distance: i * 11.0,
    ),
];

/// The route the page shows, as stored: linked to dive-1, at site-1, its
/// anchor on that site's pin, recorded with ten samples.
NavTrack navRoute({String? diveId = 'dive-1'}) => NavTrack(
  id: 'r1',
  diveId: diveId,
  siteId: 'site-1',
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  name: 'Morning',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 10,
  anchorLatitude: 47.1,
  anchorLongitude: 8.3,
  points: _samples(10),
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

/// Counts every write the page makes straight to the repository.
class CountingNavTrackRepository extends NavTrackRepository {
  final writes = <String>[];

  /// Set to make a delete fail, as a locked database would.
  bool deleteFails = false;

  @override
  Future<void> rename(String routeId, String? name) async =>
      writes.add('rename');

  @override
  Future<void> setSite(
    String routeId,
    String? siteId, {
    GeoPoint? anchor,
    bool clearAnchor = false,
  }) async => writes.add('setSite');

  @override
  Future<void> setEquipment(
    String routeId, {
    String? equipmentId,
    String? deviceName,
  }) async => writes.add('setEquipment');

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    writes.add('link');
    return true;
  }

  @override
  Future<bool> relink(
    String routeId, {
    required String fromDiveId,
    required String toDiveId,
    required NavTrackLinkMode linkMode,
  }) async {
    writes.add('relink');
    return true;
  }

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async =>
      writes.add('unlink');

  @override
  Future<void> updateCorrection(
    String routeId,
    NavTrackCorrection correction,
  ) async => writes.add('updateCorrection');

  @override
  Future<void> delete(String routeId) async {
    if (deleteFails) throw StateError('the database is locked');
    writes.add('delete');
  }
}

/// Records each save the page asks for and stores its result where the
/// page reads the route from.
class FakeNavTrackSave extends NavTrackEditSaveService {
  FakeNavTrackSave(this.stored) : super(NavTrackRepository());

  final StateController<NavTrack?> stored;
  final calls = <({NavTrack after, Set<String> cards})>[];

  @override
  Future<({NavTrack before, NavTrack after})?> save({
    required String routeId,
    required NavTrack Function(NavTrack stored) apply,
    required Iterable<String> changedCardIds,
    ({GeoPoint? anchor})? anchorFromSite,
  }) async {
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    stored.state = after;
    return (before: before, after: after);
  }
}

/// Reads the same recording again from a file, and on update stores it
/// with twelve samples, as a console's longer export would.
class FakeNavTrackImport implements NavTrackImportService {
  FakeNavTrackImport(this.stored);

  final StateController<NavTrack?> stored;
  final updates = <String>[];

  @override
  ParsedNavTrack parseFile(Uint8List bytes) =>
      ParsedNavTrack(points: _samples(12));

  @override
  Future<bool> updateFromFile({
    required String routeId,
    required ParsedNavTrack parsed,
    required Uint8List sourceFile,
    String? sourceRef,
  }) async {
    updates.add(routeId);
    final route = stored.state!;
    stored.state = NavTrack(
      id: route.id,
      diveId: route.diveId,
      linkMode: route.linkMode,
      siteId: route.siteId,
      source: route.source,
      sourceRef: sourceRef,
      name: route.name,
      startTime: route.startTime,
      endTime: route.endTime,
      pointCount: parsed.points.length,
      anchorLatitude: route.anchorLatitude,
      anchorLongitude: route.anchorLongitude,
      points: parsed.points,
      createdAt: route.createdAt,
      updatedAt: route.updatedAt,
    );
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NavTrackPageHarness {
  NavTrackPageHarness(this.save, this.repository, this.stored, this.import);

  final FakeNavTrackSave save;
  final CountingNavTrackRepository repository;
  final StateController<NavTrack?> stored;
  final FakeNavTrackImport import;
}

final _storedProvider = StateProvider<NavTrack?>((ref) => null);

/// Pumps the underwater track page, tall enough to show every card.
Future<NavTrackPageHarness> pumpNavTrackPage(
  WidgetTester tester, {
  NavTrack? route,
  Brightness? brightness,
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final repository = CountingNavTrackRepository();
  final initial = route ?? navRoute();
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => initial),
        navTrackByIdProvider(
          initial.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        navTrackRepositoryProvider.overrideWithValue(repository),
        navTrackEditSaveServiceProvider.overrideWith(
          (ref) => FakeNavTrackSave(ref.watch(_storedProvider.notifier)),
        ),
        siteProvider(oldSite.id).overrideWith((ref) async => oldSite),
        siteProvider(newSite.id).overrideWith((ref) async => newSite),
        sitesProvider.overrideWith((ref) async => [oldSite, newSite]),
        divesProvider.overrideWith((ref) async => [candidateDive]),
        diveProvider(
          candidateDive.id,
        ).overrideWith((ref) async => candidateDive),
        bathymetryGridProvider.overrideWith((ref, cell) async => null),
        navTrackImportServiceProvider.overrideWith(
          (ref) => FakeNavTrackImport(ref.watch(_storedProvider.notifier)),
        ),
      ],
      child: PushedPageLauncher(
        theme: brightness,
        page: NavTrackDetailPage(
          trackId: initial.id,
          fileActions: NavTrackFileActions(
            // The route's own file read again: same name, same recording.
            pickFile: () async =>
                (bytes: Uint8List.fromList([1, 2, 3]), name: 'r1.csv'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(NavTrackDetailPage)),
  );
  return NavTrackPageHarness(
    container.read(navTrackEditSaveServiceProvider) as FakeNavTrackSave,
    repository,
    container.read(_storedProvider.notifier),
    container.read(navTrackImportServiceProvider) as FakeNavTrackImport,
  );
}
