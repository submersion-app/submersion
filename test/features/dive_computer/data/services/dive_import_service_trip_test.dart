import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import 'dive_import_service_test.mocks.dart';

/// Issue #3022: a downloaded dive joins the diver's trip whose dates cover
/// it, as a dive imported from a file already does (#2743).
void main() {
  late MockDiveComputerRepository repo;
  late MockDiveRepository diveRepo;

  final computer = DiveComputer(
    id: 'comp-1',
    name: 'Perdix 2',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final dive = DownloadedDive(
    fingerprint: 'fp-maldives',
    startTime: DateTime.utc(2026, 11, 8, 9, 30),
    durationSeconds: 3000,
    maxDepth: 24.0,
    profile: const [],
  );

  // Every route into importProfile, the planned-dive fill and the
  // replace-source re-import included.
  Future<String> importProfileCall({String? tripId}) => repo.importProfile(
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
    targetDiveId: anyNamed('targetDiveId'),
    addMissingTanks: anyNamed('addMissingTanks'),
    tripId: tripId,
  );

  String? capturedTripId() =>
      verify(
            importProfileCall(tripId: captureAnyNamed('tripId')),
          ).captured.single
          as String?;

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
      importProfileCall(tripId: anyNamed('tripId')),
    ).thenAnswer((_) async => 'dive-id');
  });

  DiveImportService serviceWith(ImportTripResolver? tripForImports) =>
      DiveImportService(
        repository: repo,
        diveRepository: diveRepo,
        tripForImports: tripForImports,
      );

  test('a new dive joins the trip the resolver finds for it', () async {
    final asked = <(DateTime, String?)>[];
    final service = serviceWith((start, diverId) async {
      asked.add((start, diverId));
      return 'maldives';
    });

    await service.importDives(
      dives: [dive],
      computer: computer,
      diverId: 'eric',
    );

    expect(capturedTripId(), 'maldives');
    expect(asked, [(dive.startTime, 'eric')]);
  });

  test('a dive no trip covers joins none', () async {
    final service = serviceWith((_, _) async => null);

    await service.importDives(dives: [dive], computer: computer);

    expect(capturedTripId(), isNull);
  });

  test('without a resolver a dive joins no trip', () async {
    await serviceWith(null).importDives(dives: [dive], computer: computer);

    expect(capturedTripId(), isNull);
  });

  test('a resolver that fails leaves the dive out of trips, '
      'and the dive is still imported', () async {
    final service = serviceWith((_, _) async => throw StateError('db gone'));

    final result = await service.importDives(dives: [dive], computer: computer);

    expect(result.imported, 1);
    expect(capturedTripId(), isNull);
  });

  test('the wizard importing a dive as new places it too', () async {
    final service = serviceWith((_, _) async => 'maldives');

    await service.importSingleDiveAsNew(
      dive,
      computerId: computer.id,
      diverId: 'eric',
    );

    expect(capturedTripId(), 'maldives');
  });

  test('a conflict resolved as a new dive places it too', () async {
    final service = serviceWith((_, _) async => 'maldives');

    await service.resolveConflict(
      ImportConflict(
        downloaded: dive,
        existingDiveId: 'other-dive',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'other-dive',
          confidence: DuplicateConfidence.possible,
          score: 0.4,
        ),
      ),
      ConflictResolution.importAsNew,
      computer.id,
    );

    expect(capturedTripId(), 'maldives');
  });

  test('replacing an existing dive\'s source never asks for a trip', () async {
    var asked = false;
    final service = serviceWith((_, _) async {
      asked = true;
      return 'maldives';
    });

    await service.resolveConflict(
      ImportConflict(
        downloaded: dive,
        existingDiveId: 'dive-id',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'dive-id',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
        ),
      ),
      ConflictResolution.replaceSource,
      computer.id,
    );

    expect(asked, isFalse);
    expect(capturedTripId(), isNull);
  });

  test('filling a planned dive never asks for a trip', () async {
    var asked = false;
    final service = serviceWith((_, _) async {
      asked = true;
      return 'maldives';
    });

    await service.attachToPlannedDive(
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

    expect(asked, isFalse);
    expect(capturedTripId(), isNull);
  });
}
