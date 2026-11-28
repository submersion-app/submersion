import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import 'dive_import_service_test.mocks.dart';

/// Issue #5000: a cylinder whose source reports no end pressure gets one
/// derived from its series by the repository, which reads it at surfacing
/// only when the diver's "Tank pressure at surfacing" switch is on. The
/// import service hands that switch over, read for the diver the dive is
/// filed under.
void main() {
  late MockDiveComputerRepository repo;
  late MockDiveRepository diveRepo;

  final computer = DiveComputer(
    id: 'comp-1',
    name: 'Suunto Nautic',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final dive = DownloadedDive(
    fingerprint: 'fp-nautic',
    startTime: DateTime(2026, 11, 20, 10, 0),
    durationSeconds: 2520,
    maxDepth: 18.0,
    profile: const [],
    tanks: const [DownloadedTank(index: 0, o2Percent: 33.0)],
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
        diveMode: anyNamed('diveMode'),
        events: anyNamed('events'),
        gasSwitches: anyNamed('gasSwitches'),
        diveNumber: anyNamed('diveNumber'),
        forceNew: anyNamed('forceNew'),
        addMissingTanks: anyNamed('addMissingTanks'),
        targetDiveId: anyNamed('targetDiveId'),
        trimTankPressureAtSurfacing: anyNamed('trimTankPressureAtSurfacing'),
      ),
    ).thenAnswer((_) async => 'dive-id');
  });

  /// The switch value each importProfile call received, in call order.
  List<bool> handedOver() => verify(
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
      diveMode: anyNamed('diveMode'),
      events: anyNamed('events'),
      gasSwitches: anyNamed('gasSwitches'),
      diveNumber: anyNamed('diveNumber'),
      forceNew: anyNamed('forceNew'),
      addMissingTanks: anyNamed('addMissingTanks'),
      targetDiveId: anyNamed('targetDiveId'),
      trimTankPressureAtSurfacing: captureAnyNamed(
        'trimTankPressureAtSurfacing',
      ),
    ),
  ).captured.cast<bool>();

  DiveImportService serviceWith(Future<bool> Function(String?)? loader) =>
      DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        trimTankPressureAtSurfacingForImports: loader,
      );

  test('a download hands the switch to the repository', () async {
    await serviceWith(
      (_) async => false,
    ).importDives(dives: [dive], computer: computer);

    expect(handedOver(), [false]);
  });

  test('no loader reads at surfacing, the setting default', () async {
    await serviceWith(null).importDives(dives: [dive], computer: computer);

    expect(handedOver(), [true]);
  });

  test('a loader that throws reads at surfacing', () async {
    await serviceWith(
      (_) async => throw StateError('settings unreadable'),
    ).importDives(dives: [dive], computer: computer);

    expect(handedOver(), [true]);
  });

  test('the switch is read for the diver the dive is filed under', () async {
    final asked = <String?>[];
    await serviceWith((diverId) async {
      asked.add(diverId);
      return false;
    }).importSingleDiveAsNew(dive, computerId: computer.id, diverId: 'owner-2');

    expect(asked, ['owner-2']);
    expect(handedOver(), [false]);
  });

  test('replacing a source hands the switch over too', () async {
    final conflict = ImportConflict(
      downloaded: dive,
      existingDiveId: 'existing-dive-1',
      duplicateResult: const DuplicateResult(
        matchingDiveId: 'existing-dive-1',
        confidence: DuplicateConfidence.exact,
        score: 0.95,
      ),
    );

    await serviceWith(
      (_) async => false,
    ).resolveConflict(conflict, ConflictResolution.replaceSource, computer.id);

    expect(handedOver(), [false]);
  });

  test('filling a planned dive hands the switch over too', () async {
    await serviceWith((_) async => false).attachToPlannedDive(
      dive,
      'dive-id',
      computer.id,
      settled: (
        gfLow: null,
        gfHigh: null,
        decoAlgorithm: null,
        decoConservatism: null,
        computerTissue: null,
      ),
    );

    expect(handedOver(), [false]);
  });

  // A live download is parsed with the active diver's switch before the
  // diver it is filed under is known, so the import re-reads a reported end
  // pressure with that diver's switch (issue #5000, review of PR #5087).
  group('a reported end pressure follows the owning diver', () {
    DownloadedDive parsedWith({required double endPressure}) => DownloadedDive(
      fingerprint: 'fp-ccr',
      startTime: DateTime(2026, 11, 20, 10, 0),
      durationSeconds: 4140,
      maxDepth: 51.0,
      profile: const [],
      tanks: [
        DownloadedTank(
          index: 0,
          o2Percent: 100.0,
          startPressure: 200.0,
          endPressure: endPressure,
          surfacingEnd: const SurfacingEndPressure(
            asLogged: 4.0,
            atSurfacing: 41.0,
          ),
        ),
      ],
    );

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
                diveMode: anyNamed('diveMode'),
                events: anyNamed('events'),
                gasSwitches: anyNamed('gasSwitches'),
                diveNumber: anyNamed('diveNumber'),
                forceNew: anyNamed('forceNew'),
                addMissingTanks: anyNamed('addMissingTanks'),
                targetDiveId: anyNamed('targetDiveId'),
                trimTankPressureAtSurfacing: anyNamed(
                  'trimTankPressureAtSurfacing',
                ),
              ),
            ).captured.single
            as List<TankData>;

    test('switch off: the logged value, though parsed at surfacing', () async {
      await serviceWith((_) async => false).importSingleDiveAsNew(
        parsedWith(endPressure: 41.0),
        computerId: computer.id,
        diverId: 'owner-2',
      );

      expect(writtenTanks().single.endPressure, 4.0);
    });

    test('switch on: the surfacing value, though parsed as logged', () async {
      await serviceWith((_) async => true).importSingleDiveAsNew(
        parsedWith(endPressure: 4.0),
        computerId: computer.id,
        diverId: 'owner-2',
      );

      expect(writtenTanks().single.endPressure, 41.0);
    });

    test('replacing a source follows the owner too', () async {
      final conflict = ImportConflict(
        downloaded: parsedWith(endPressure: 41.0),
        existingDiveId: 'existing-dive-1',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
        ),
      );

      await serviceWith((_) async => false).resolveConflict(
        conflict,
        ConflictResolution.replaceSource,
        computer.id,
        diverId: 'owner-2',
      );

      expect(writtenTanks().single.endPressure, 4.0);
    });

    test('filling a planned dive follows the switch too', () async {
      await serviceWith((_) async => false).attachToPlannedDive(
        parsedWith(endPressure: 41.0),
        'dive-id',
        computer.id,
        settled: (
          gfLow: null,
          gfHigh: null,
          decoAlgorithm: null,
          decoConservatism: null,
          computerTissue: null,
        ),
      );

      expect(writtenTanks().single.endPressure, 4.0);
    });
  });
}
