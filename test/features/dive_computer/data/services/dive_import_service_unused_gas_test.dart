import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import 'dive_import_service_test.mocks.dart';

/// Issue #3668: with the diver's switch on, a rebreather download writes no
/// cylinder for an open-circuit gas no transmitter read and the diver never
/// breathed. The bailout transmitter claim still sees every gas first.
void main() {
  late MockDiveComputerRepository repo;
  late MockDiveRepository diveRepo;

  final computer = DiveComputer(
    id: 'comp-1',
    name: 'Petrel 3',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repo = MockDiveComputerRepository();
    diveRepo = MockDiveRepository();
    when(
      diveRepo.getSourceKeysByDiveId(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => {});
    when(
      diveRepo.getDiveNumberForDate(any, diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => 1);
    when(
      repo.findMatchingDiveWithScore(
        profileStartTime: anyNamed('profileStartTime'),
        toleranceMinutes: anyNamed('toleranceMinutes'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      repo.clearSourceAndProfiles(
        diveId: anyNamed('diveId'),
        computerId: anyNamed('computerId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      repo.importProfile(
        computerId: anyNamed('computerId'),
        profileStartTime: anyNamed('profileStartTime'),
        points: anyNamed('points'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        avgDepth: anyNamed('avgDepth'),
        isPrimary: anyNamed('isPrimary'),
        diverId: anyNamed('diverId'),
        tanks: anyNamed('tanks'),
        decoAlgorithm: anyNamed('decoAlgorithm'),
        diveMode: anyNamed('diveMode'),
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        computerTissue: anyNamed('computerTissue'),
        events: anyNamed('events'),
        gasSwitches: anyNamed('gasSwitches'),
        diveNumber: anyNamed('diveNumber'),
        forceNew: anyNamed('forceNew'),
        rawData: anyNamed('rawData'),
        rawFingerprint: anyNamed('rawFingerprint'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
        descriptorModel: anyNamed('descriptorModel'),
        libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        addMissingTanks: anyNamed('addMissingTanks'),
      ),
    ).thenAnswer((_) async => 'dive-id');
  });

  List<TankData> writtenTanks() =>
      verify(
            repo.importProfile(
              computerId: anyNamed('computerId'),
              profileStartTime: anyNamed('profileStartTime'),
              points: anyNamed('points'),
              durationSeconds: anyNamed('durationSeconds'),
              maxDepth: anyNamed('maxDepth'),
              avgDepth: anyNamed('avgDepth'),
              isPrimary: anyNamed('isPrimary'),
              diverId: anyNamed('diverId'),
              tanks: captureAnyNamed('tanks'),
              decoAlgorithm: anyNamed('decoAlgorithm'),
              diveMode: anyNamed('diveMode'),
              gfLow: anyNamed('gfLow'),
              gfHigh: anyNamed('gfHigh'),
              decoConservatism: anyNamed('decoConservatism'),
              computerTissue: anyNamed('computerTissue'),
              events: anyNamed('events'),
              gasSwitches: anyNamed('gasSwitches'),
              diveNumber: anyNamed('diveNumber'),
              forceNew: anyNamed('forceNew'),
              rawData: anyNamed('rawData'),
              rawFingerprint: anyNamed('rawFingerprint'),
              descriptorVendor: anyNamed('descriptorVendor'),
              descriptorProduct: anyNamed('descriptorProduct'),
              descriptorModel: anyNamed('descriptorModel'),
              libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
              addMissingTanks: anyNamed('addMissingTanks'),
            ),
          ).captured.single
          as List<TankData>;

  /// The reporter's dive as the resolver hands it over: two transmitters and
  /// two pressureless gases it marked unused.
  DownloadedDive reporterDive({List<DownloadedTank> extra = const []}) =>
      DownloadedDive(
        fingerprint: 'fp-ccr',
        startTime: DateTime(2026, 10, 20, 9, 0),
        durationSeconds: 3000,
        maxDepth: 30.0,
        diveMode: DiveMode.ccr,
        profile: const [],
        events: const [],
        tanks: [
          const DownloadedTank(
            index: 0,
            o2Percent: 21.0,
            startPressure: 190.0,
            endPressure: 157.0,
            role: 'diluent',
            transmitterSerial: '818',
          ),
          const DownloadedTank(
            index: 1,
            o2Percent: 100.0,
            startPressure: 207.0,
            endPressure: 146.0,
            role: 'oxygenSupply',
            transmitterSerial: '154648',
            mixRecorded: false,
          ),
          ...extra,
          const DownloadedTank(
            index: 3,
            o2Percent: 100.0,
            role: 'deco',
            unusedOcGas: true,
          ),
          const DownloadedTank(
            index: 4,
            o2Percent: 21.0,
            role: 'bailout',
            unusedOcGas: true,
          ),
        ],
      );

  DiveImportService serviceWith(Future<bool> Function(String?)? omit) =>
      DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: omit,
      );

  test('switch on: a new dive gets only the transmitter cylinders', () async {
    await serviceWith(
      (_) async => true,
    ).importDives(dives: [reporterDive()], computer: computer);

    expect(writtenTanks().map((t) => t.index), [0, 1]);
  });

  test('switch off: a new dive gets all four', () async {
    await serviceWith(
      (_) async => false,
    ).importDives(dives: [reporterDive()], computer: computer);

    expect(writtenTanks().map((t) => t.index), [0, 1, 3, 4]);
  });

  test('no loader: a new dive gets all four', () async {
    await serviceWith(
      null,
    ).importDives(dives: [reporterDive()], computer: computer);

    expect(writtenTanks(), hasLength(4));
  });

  test('a loader that throws imports everything', () async {
    await serviceWith(
      (_) async => throw StateError('settings unreadable'),
    ).importDives(dives: [reporterDive()], computer: computer);

    expect(writtenTanks(), hasLength(4));
  });

  test('the switch is read for the diver the dive is filed under', () async {
    final asked = <String?>[];
    await serviceWith((diverId) async {
      asked.add(diverId);
      return true;
    }).importSingleDiveAsNew(
      reporterDive(),
      computerId: computer.id,
      diverId: 'owner-2',
    );

    expect(asked, ['owner-2']);
    expect(writtenTanks().map((t) => t.index), [0, 1]);
  });

  test(
    'a registered bailout transmitter still takes the unused Air gas',
    () async {
      final service = DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: (_) async => true,
        transmitterMatcherForImports: (_) async =>
            TransmitterMatcher.fromEntries([
              Transmitter(
                id: 'e1',
                transmitterSerial: '555',
                label: 'Bailout',
                role: TankRole.bailout,
                createdAt: DateTime.utc(2026, 9, 1),
                updatedAt: DateTime.utc(2026, 9, 1),
              ),
            ]),
      );

      await service.importDives(
        dives: [
          reporterDive(
            extra: const [
              DownloadedTank(
                index: 2,
                o2Percent: 21.0,
                startPressure: 200.0,
                endPressure: 200.0,
                role: 'backGas',
                transmitterSerial: '555',
                mixRecorded: false,
              ),
            ],
          ),
        ],
        computer: computer,
      );

      final tanks = writtenTanks();
      expect(tanks.map((t) => t.index), [0, 1, 2]);
      final bailout = tanks.firstWhere((t) => t.index == 2);
      expect(bailout.role, 'bailout');
      expect(bailout.o2Percent, 21.0);
      expect(bailout.mixRecorded, isTrue, reason: 'claimed the Air gas');
    },
  );

  test(
    'a batch re-download in replace mode passes no unused gas when on',
    () async {
      when(
        repo.findMatchingDiveWithScore(
          profileStartTime: anyNamed('profileStartTime'),
          toleranceMinutes: anyNamed('toleranceMinutes'),
          durationSeconds: anyNamed('durationSeconds'),
          maxDepth: anyNamed('maxDepth'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => const DiveMatchResult(
          diveId: 'existing',
          score: 0.95,
          timeDifferenceMs: 0,
        ),
      );

      final result = await serviceWith((_) async => true).importDives(
        dives: [reporterDive()],
        computer: computer,
        mode: ImportMode.replaceSource,
      );

      expect(result.updated, 1);
      expect(writtenTanks().map((t) => t.index), [0, 1]);
    },
  );

  test(
    're-downloading into an existing dive passes no unused gas when on',
    () async {
      final conflict = ImportConflict(
        downloaded: reporterDive(),
        existingDiveId: 'existing',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
        ),
      );

      await serviceWith((_) async => true).resolveConflict(
        conflict,
        ConflictResolution.replaceSource,
        computer.id,
      );

      expect(writtenTanks().map((t) => t.index), [0, 1]);
    },
  );

  test(
    'a re-download lets a registered bailout transmitter take the Air first',
    () async {
      final service = DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: (_) async => true,
        transmitterMatcherForImports: (_) async =>
            TransmitterMatcher.fromEntries([
              Transmitter(
                id: 'e1',
                transmitterSerial: '555',
                label: 'Bailout',
                role: TankRole.bailout,
                createdAt: DateTime.utc(2026, 9, 1),
                updatedAt: DateTime.utc(2026, 9, 1),
              ),
            ]),
      );
      final conflict = ImportConflict(
        downloaded: reporterDive(
          extra: const [
            DownloadedTank(
              index: 2,
              o2Percent: 21.0,
              startPressure: 200.0,
              endPressure: 200.0,
              role: 'backGas',
              transmitterSerial: '555',
              mixRecorded: false,
            ),
          ],
        ),
        existingDiveId: 'existing',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
        ),
      );

      await service.resolveConflict(
        conflict,
        ConflictResolution.replaceSource,
        computer.id,
      );

      final tanks = writtenTanks();
      expect(tanks.map((t) => t.index), [0, 1, 2]);
      final bailout = tanks.firstWhere((t) => t.index == 2);
      expect(bailout.o2Percent, 21.0);
      expect(bailout.mixRecorded, isTrue, reason: 'claimed the Air gas');
    },
  );

  group('re-download with a registered bailout transmitter', () {
    TransmitterMatcher bailoutEntry() => TransmitterMatcher.fromEntries([
      Transmitter(
        id: 'e1',
        transmitterSerial: '555',
        label: 'Bailout',
        role: TankRole.bailout,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    const bailoutTransmitter = DownloadedTank(
      index: 2,
      o2Percent: 21.0,
      startPressure: 200.0,
      endPressure: 200.0,
      role: 'backGas',
      transmitterSerial: '555',
      mixRecorded: false,
    );

    ImportConflict conflictFor(DownloadedDive dive) => ImportConflict(
      downloaded: dive,
      existingDiveId: 'existing',
      duplicateResult: const DuplicateResult(
        matchingDiveId: 'existing',
        confidence: DuplicateConfidence.exact,
        score: 0.95,
      ),
    );

    test('with nothing unused, the switch changes nothing', () async {
      // The diver bailed out onto the Air, so no gas is unused.
      final dive = DownloadedDive(
        fingerprint: 'fp-bailed',
        startTime: DateTime(2026, 10, 20, 9, 0),
        durationSeconds: 3000,
        maxDepth: 30.0,
        diveMode: DiveMode.ccr,
        profile: const [],
        events: const [],
        tanks: const [
          DownloadedTank(
            index: 0,
            o2Percent: 21.0,
            role: 'diluent',
            transmitterSerial: '818',
          ),
          bailoutTransmitter,
          DownloadedTank(index: 4, o2Percent: 21.0, role: 'bailout'),
        ],
      );
      final service = DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: (_) async => true,
        transmitterMatcherForImports: (_) async => bailoutEntry(),
      );

      await service.resolveConflict(
        conflictFor(dive),
        ConflictResolution.replaceSource,
        computer.id,
      );

      final tanks = writtenTanks();
      expect(tanks.map((t) => t.index), [0, 2, 4]);
      expect(tanks.firstWhere((t) => t.index == 2).mixRecorded, isFalse);
    });

    test('with the switch off, the registry is never read', () async {
      var reads = 0;
      final service = DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: (_) async => false,
        transmitterMatcherForImports: (_) async {
          reads++;
          return bailoutEntry();
        },
      );

      await service.resolveConflict(
        conflictFor(reporterDive()),
        ConflictResolution.replaceSource,
        computer.id,
      );

      expect(reads, 0);
    });

    test('a batch re-download hands the registry to the claim', () async {
      when(
        repo.findMatchingDiveWithScore(
          profileStartTime: anyNamed('profileStartTime'),
          toleranceMinutes: anyNamed('toleranceMinutes'),
          durationSeconds: anyNamed('durationSeconds'),
          maxDepth: anyNamed('maxDepth'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => const DiveMatchResult(
          diveId: 'existing',
          score: 0.95,
          timeDifferenceMs: 0,
        ),
      );
      final service = DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        omitUnusedOcGasesForImports: (_) async => true,
        transmitterMatcherForImports: (_) async => bailoutEntry(),
      );

      await service.importDives(
        dives: [
          reporterDive(extra: const [bailoutTransmitter]),
        ],
        computer: computer,
        mode: ImportMode.replaceSource,
      );

      final tanks = writtenTanks();
      expect(tanks.map((t) => t.index), [0, 1, 2]);
      expect(tanks.firstWhere((t) => t.index == 2).o2Percent, 21.0);
      expect(tanks.firstWhere((t) => t.index == 2).mixRecorded, isTrue);
    });
  });

  test(
    're-downloading into an existing dive keeps every gas when off',
    () async {
      final conflict = ImportConflict(
        downloaded: reporterDive(),
        existingDiveId: 'existing',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
        ),
      );

      await serviceWith((_) async => false).resolveConflict(
        conflict,
        ConflictResolution.replaceSource,
        computer.id,
      );

      expect(writtenTanks(), hasLength(4));
    },
  );
}
