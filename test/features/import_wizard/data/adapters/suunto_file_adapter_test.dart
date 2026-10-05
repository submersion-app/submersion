import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_file_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_file_step.dart';

import 'suunto_cloud_adapter_test.mocks.dart';

class _RecordingRouteWriter implements SuuntoRouteWriter {
  final attached = <String>[];

  @override
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async {
    attached.add(diveId);
    return null;
  }

  @override
  Future<String?> attachIfMissing(
    String diveId,
    SuuntoParsedDive parsed,
  ) async => null;
}

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late _RecordingRouteWriter recorder;
  late SuuntoFileAdapter adapter;

  final parsed = SuuntoParsedDive(
    dive: DownloadedDive(
      startTime: DateTime.utc(2026, 4, 19, 13, 44),
      durationSeconds: 1800,
      maxDepth: 14,
      profile: const [],
    ),
    deviceName: 'Suunto Nautic S',
    serialNumber: 'NS-1',
  );

  setUp(() {
    mockImportService = MockDiveImportService();
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    recorder = _RecordingRouteWriter();
    adapter = SuuntoFileAdapter(
      importService: mockImportService,
      computerRepository: mockComputerRepo,
      diveRepository: mockDiveRepo,
      consolidationService: MockDiveConsolidationService(),
      diverId: 'diver-1',
      routeWriter: recorder,
    );

    when(
      mockComputerRepo.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => null);
    when(mockComputerRepo.createComputer(any)).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as DiveComputer,
    );
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

  test('describes itself as the Suunto JSON file source', () {
    expect(adapter.sourceType, ImportSourceType.suuntoFile);
    expect(adapter.displayName, 'Suunto JSON');
    expect(adapter.defaultTagName, startsWith('Suunto Import '));
  });

  test('acquires dives through a single file step', () {
    final steps = adapter.acquisitionSteps;

    expect(steps, hasLength(1));
    expect(steps.single.canAdvance, same(suuntoFileDivesReadyProvider));
  });

  test('bundles the read dives under its own source type', () async {
    adapter.setParsedDives([parsed]);

    final bundle = await adapter.buildBundle();

    expect(bundle.source.type, ImportSourceType.suuntoFile);
    expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
  });

  test('imports a new dive and attaches its route', () async {
    adapter.setParsedDives([parsed]);
    final bundle = await adapter.buildBundle();

    final result = await adapter.performImport(bundle, {
      ImportEntityType.dives: {0},
    }, {});

    expect(result.importedDiveIds, ['new-dive-id']);
    expect(recorder.attached, ['new-dive-id']);
  });

  test('loads only the dives from the file step results', () async {
    final file = SuuntoJsonFile(name: 'a.json', bytes: Uint8List(0));
    adapter.setReadResults([
      SuuntoFileReadResult.dive(file, parsed),
      SuuntoFileReadResult.rejected(file, SuuntoFileRejection.notJson),
    ]);

    final bundle = await adapter.buildBundle();

    expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
  });

  testWidgets('hands the last results back to a rebuilt file step', (
    tester,
  ) async {
    final file = SuuntoJsonFile(name: 'a.json', bytes: Uint8List(0));
    final results = [SuuntoFileReadResult.dive(file, parsed)];
    adapter.setReadResults(results);

    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final step = adapter.acquisitionSteps.single.builder(context);

    expect((step as SuuntoFileStep).previousResults, results);
  });

  test('resetState forgets the read files and their dives', () async {
    final file = SuuntoJsonFile(name: 'a.json', bytes: Uint8List(0));
    adapter.setReadResults([SuuntoFileReadResult.dive(file, parsed)]);

    adapter.resetState();

    final bundle = await adapter.buildBundle();
    expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
  });
}
