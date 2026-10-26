import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_gear_linker.dart';

import 'dive_computer_adapter_test.mocks.dart';

class _RecordingRegistrar extends TransmitterAutoRegistrar {
  _RecordingRegistrar() : super(nameFor: (s) => 'Transmitter $s');
  final calls = <(List<String>, String?)>[];

  @override
  Future<Set<String>> registerNewSerials(
    Iterable<String> serials, {
    required String? diverId,
  }) async {
    calls.add((serials.toList(), diverId));
    return serials.toSet();
  }
}

class _RecordingLinker extends TransmitterGearLinker {
  final calls = <(Set<String>, String?)>[];

  @override
  Future<void> linkSerials(
    Iterable<String> serials, {
    required String? diverId,
  }) async {
    calls.add((serials.toSet(), diverId));
  }
}

class _Registry extends TransmitterRepository {
  _Registry(this.needingSetup);
  final Set<String> needingSetup;

  @override
  Future<Set<String>> serialsNeedingSetup(String? diverId) async =>
      needingSetup;
}

/// A download creates the Transmitter item for each new serial, puts every
/// transmitter on its dives, and nudges about each one not set up (#3676).
void main() {
  const diverId = 'diver-1';
  late MockDiveImportService importService;
  late MockDiveComputerRepository computerRepo;
  late MockDiveRepository diveRepo;
  late _RecordingRegistrar registrar;
  late _RecordingLinker linker;
  late DiveComputerAdapter adapter;

  final computer = DiveComputer(
    id: 'comp-1',
    diverId: diverId,
    name: 'Teric',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  DownloadedDive dive(String fp, String serial, int day) => DownloadedDive(
    startTime: DateTime(2026, 3, day, 10),
    durationSeconds: 3000,
    maxDepth: 20,
    fingerprint: fp,
    profile: const [],
    tanks: [DownloadedTank(index: 0, o2Percent: 21, transmitterSerial: serial)],
  );

  setUp(() {
    importService = MockDiveImportService();
    computerRepo = MockDiveComputerRepository();
    diveRepo = MockDiveRepository();
    registrar = _RecordingRegistrar();
    linker = _RecordingLinker();
    adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: computerRepo,
      diveRepository: diveRepo,
      consolidationService: MockDiveConsolidationService(),
      diverId: diverId,
      knownComputer: computer,
      transmitterRegistrar: registrar,
      transmitterGearLinker: linker,
      transmitterRepository: _Registry({'777'}),
    );
    when(
      diveRepo.getSourceKeysByDiveId(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => {});
  });

  test('a download with a new serial creates its item, links it and raises '
      'the notice', () async {
    final dives = [
      dive('a', '999', 1),
      dive('b', '777', 2),
      dive('c', '555', 3),
    ];
    adapter.setDownloadedDives(dives);
    final bundle = await adapter.buildBundle();
    when(importService.unmatchedTransmitterSerials).thenReturn(['999']);
    for (final (i, d) in dives.indexed) {
      when(
        importService.importSingleDiveAsNew(
          d,
          computerId: computer.id,
          diverId: diverId,
        ),
      ).thenAnswer((_) async => 'new-$i');
    }

    final result = await adapter.performImport(bundle, {
      ImportEntityType.dives: {0, 1, 2},
    }, const {});

    // Every serial the download wrote, planned-dive fills included; the
    // registrar skips the ones it already knows (review).
    expect(registrar.calls.single.$1.toSet(), {'999', '777', '555'});
    expect(registrar.calls.single.$2, diverId);
    expect(linker.calls.single.$1, {'999', '777', '555'});
    expect(linker.calls.single.$2, diverId);
    final byKind = {for (final n in result.notices) n.kind: n.count};
    // 999 is new and 777 has no cylinder; 555 is set up.
    expect(byKind[ImportNoticeKind.unknownTransmitter], 2);
  });

  test('a download of set-up serials raises no notice', () async {
    final dives = [dive('a', '555', 1)];
    adapter.setDownloadedDives(dives);
    final bundle = await adapter.buildBundle();
    when(importService.unmatchedTransmitterSerials).thenReturn(const []);
    when(
      importService.importSingleDiveAsNew(
        dives.single,
        computerId: computer.id,
        diverId: diverId,
      ),
    ).thenAnswer((_) async => 'new-0');

    final result = await adapter.performImport(bundle, {
      ImportEntityType.dives: {0},
    }, const {});

    expect(
      result.notices.where(
        (n) => n.kind == ImportNoticeKind.unknownTransmitter,
      ),
      isEmpty,
    );
    expect(registrar.calls.single.$1, ['555']);
  });
}
