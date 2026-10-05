import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_route.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import 'suunto_cloud_adapter_test.mocks.dart';

/// Records which dive each route was attached to, so every write path in
/// the shared Suunto import core can be checked without a database.
class _RecordingRouteWriter implements SuuntoRouteWriter {
  _RecordingRouteWriter({this.result = 'route-id'});

  final String? result;
  final attached = <(String, SuuntoParsedDive)>[];
  final backfilled = <(String, SuuntoParsedDive)>[];

  @override
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async {
    attached.add((diveId, parsed));
    return result;
  }

  @override
  Future<String?> attachIfMissing(
    String diveId,
    SuuntoParsedDive parsed,
  ) async {
    backfilled.add((diveId, parsed));
    return result;
  }
}

SuuntoParsedDive _parsedWithRoute() => SuuntoParsedDive(
  dive: DownloadedDive(
    startTime: DateTime.utc(2026, 3, 15, 10, 32),
    durationSeconds: 30 * 60,
    maxDepth: 18.5,
    profile: const [],
  ),
  deviceName: 'Suunto Nautic S',
  serialNumber: 'SN-1',
  route: const SuuntoDiveRoute(
    points: [
      NavTrackPoint(timestamp: 1773570720, north: 0, east: 0, depth: 1),
      NavTrackPoint(timestamp: 1773570721, north: 1, east: 1, depth: 2),
    ],
    originLatitude: 47.3,
    originLongitude: -2.9,
  ),
);

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late _RecordingRouteWriter recorder;
  late SuuntoCloudAdapter adapter;
  late SuuntoParsedDive parsed;

  const diverId = 'diver-1';

  SuuntoCloudAdapter buildAdapter(SuuntoRouteWriter writer) =>
      SuuntoCloudAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        consolidationService: mockConsolidationService,
        diverId: diverId,
        routeWriter: writer,
      );

  setUp(() {
    mockImportService = MockDiveImportService();
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    mockConsolidationService = MockDiveConsolidationService();
    recorder = _RecordingRouteWriter();
    adapter = buildAdapter(recorder);
    parsed = _parsedWithRoute();

    when(
      mockDiveRepo.getSourceKeysByDiveId(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => {});
    when(
      mockComputerRepo.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => null);
    when(mockComputerRepo.createComputer(any)).thenAnswer((invocation) async {
      final computer = invocation.positionalArguments.first as DiveComputer;
      return DiveComputer(
        id: 'computer-${computer.serialNumber ?? computer.name}',
        name: computer.name,
        diverId: diverId,
        manufacturer: 'Suunto',
        model: computer.name,
        serialNumber: computer.serialNumber,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    });
    when(
      mockImportService.importSingleDiveAsNew(
        any,
        computerId: anyNamed('computerId'),
        diverId: anyNamed('diverId'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
      ),
    ).thenAnswer((_) async => 'new-dive-id');
  });

  Future<ImportBundle> plainBundle(SuuntoCloudAdapter a) async {
    a.setParsedDives([parsed]);
    return a.buildBundle();
  }

  Future<ImportBundle> bundleWithMatch() async {
    final bundle = await plainBundle(adapter);
    return ImportBundle(
      source: bundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: bundle.groups[ImportEntityType.dives]!.items,
          duplicateIndices: const {0},
          matchResults: {
            0: const DiveMatchResult(
              diveId: 'existing-dive',
              score: 0.9,
              timeDifferenceMs: 0,
            ),
          },
        ),
      },
    );
  }

  Future<void> importWith(ImportBundle bundle, DuplicateAction? action) =>
      adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          if (action != null) ImportEntityType.dives: {0: action},
        },
      );

  test('a new dive gets its route', () async {
    await importWith(await plainBundle(adapter), null);

    expect(recorder.attached, [('new-dive-id', parsed)]);
  });

  test(
    'a skipped duplicate backfills a missing route on the matched dive',
    () async {
      await importWith(await bundleWithMatch(), DuplicateAction.skip);

      expect(recorder.attached, isEmpty);
      expect(recorder.backfilled, [('existing-dive', parsed)]);
    },
  );

  test('a skip chosen for an unselected duplicate backfills too', () async {
    final bundle = await bundleWithMatch();
    await adapter.performImport(
      bundle,
      {ImportEntityType.dives: <int>{}},
      {
        ImportEntityType.dives: {0: DuplicateAction.skip},
      },
    );

    expect(recorder.backfilled, [('existing-dive', parsed)]);
  });

  test('a cancelled import backfills nothing', () async {
    final bundle = await bundleWithMatch();
    final token = ImportCancellationToken()..cancel();
    await adapter.performImport(
      bundle,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.skip},
      },
      cancelToken: token,
    );

    expect(recorder.backfilled, isEmpty);
  });

  test('replace source attaches the route to the matched dive', () async {
    await importWith(await bundleWithMatch(), DuplicateAction.replaceSource);

    expect(recorder.attached, [('existing-dive', parsed)]);
  });

  test('a folded consolidation attaches the route to the target', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'other-computer');

    await importWith(await bundleWithMatch(), DuplicateAction.consolidate);

    expect(recorder.attached, [('existing-dive', parsed)]);
  });

  test('a dive kept standalone gets the route on itself', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'other-computer');
    when(
      mockConsolidationService.apply(
        targetDiveId: anyNamed('targetDiveId'),
        secondaryDiveIds: anyNamed('secondaryDiveIds'),
      ),
    ).thenThrow(const UnreadableSeriesException(['series-1']));

    await importWith(await bundleWithMatch(), DuplicateAction.consolidate);

    expect(recorder.attached, [('new-dive-id', parsed)]);
  });

  test('a same-computer consolidation backfills a missing route', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'computer-SN-1');

    await importWith(await bundleWithMatch(), DuplicateAction.consolidate);

    expect(recorder.attached, isEmpty);
    expect(recorder.backfilled, [('existing-dive', parsed)]);
  });

  test('a route that could not be written leaves the counts alone', () async {
    final failing = buildAdapter(_RecordingRouteWriter(result: null));
    final bundle = await plainBundle(failing);

    final result = await failing.performImport(bundle, {
      ImportEntityType.dives: {0},
    }, {});

    expect(result.importedCounts[ImportEntityType.dives], 1);
    expect(result.importedDiveIds, ['new-dive-id']);
  });
}
