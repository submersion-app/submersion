import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveRepository])
import 'dive_import_service_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late DiveImportService service;

  final computer = DiveComputer(
    id: 'comp-1',
    name: 'Test Computer',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();

    service = DiveImportService(
      repository: mockComputerRepo,
      diveRepository: mockDiveRepo,
    );

    // Default: no duplicates found
    when(
      mockComputerRepo.findMatchingDiveWithScore(
        profileStartTime: anyNamed('profileStartTime'),
        toleranceMinutes: anyNamed('toleranceMinutes'),
        durationSeconds: anyNamed('durationSeconds'),
        maxDepth: anyNamed('maxDepth'),
        fingerprint: anyNamed('fingerprint'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => null);

    // Default: importProfile returns a dive id
    when(
      mockComputerRepo.importProfile(
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
        gfLow: anyNamed('gfLow'),
        gfHigh: anyNamed('gfHigh'),
        decoConservatism: anyNamed('decoConservatism'),
        events: anyNamed('events'),
        diveNumber: anyNamed('diveNumber'),
        forceNew: anyNamed('forceNew'),
        rawData: anyNamed('rawData'),
        rawFingerprint: anyNamed('rawFingerprint'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
        descriptorModel: anyNamed('descriptorModel'),
        libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
      ),
    ).thenAnswer((_) async => 'dive-id');
  });

  group('DiveImportService dive numbering', () {
    test('assigns sequential dive numbers in chronological order', () async {
      final dive1 = DownloadedDive(
        fingerprint: 'fp1',
        startTime: DateTime(2026, 1, 1, 9, 0),
        durationSeconds: 3600,
        maxDepth: 20.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );
      final dive2 = DownloadedDive(
        fingerprint: 'fp2',
        startTime: DateTime(2026, 1, 2, 9, 0),
        durationSeconds: 3600,
        maxDepth: 25.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );
      final dive3 = DownloadedDive(
        fingerprint: 'fp3',
        startTime: DateTime(2026, 1, 3, 9, 0),
        durationSeconds: 3600,
        maxDepth: 30.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );

      // Simulate: 0 dives before dive1, 1 before dive2, 2 before dive3
      when(
        mockDiveRepo.getDiveNumberForDate(
          DateTime(2026, 1, 1, 9, 0),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        mockDiveRepo.getDiveNumberForDate(
          DateTime(2026, 1, 2, 9, 0),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer((_) async => 2);
      when(
        mockDiveRepo.getDiveNumberForDate(
          DateTime(2026, 1, 3, 9, 0),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer((_) async => 3);

      await service.importDives(
        dives: [dive1, dive2, dive3],
        computer: computer,
      );

      // Verify each dive got the correct number
      verify(
        mockComputerRepo.importProfile(
          computerId: anyNamed('computerId'),
          profileStartTime: DateTime(2026, 1, 1, 9, 0),
          points: anyNamed('points'),
          durationSeconds: anyNamed('durationSeconds'),
          maxDepth: anyNamed('maxDepth'),
          avgDepth: anyNamed('avgDepth'),
          isPrimary: anyNamed('isPrimary'),
          diverId: anyNamed('diverId'),
          tanks: anyNamed('tanks'),
          decoAlgorithm: anyNamed('decoAlgorithm'),
          gfLow: anyNamed('gfLow'),
          gfHigh: anyNamed('gfHigh'),
          decoConservatism: anyNamed('decoConservatism'),
          events: anyNamed('events'),
          diveNumber: 1,
          rawData: anyNamed('rawData'),
          rawFingerprint: anyNamed('rawFingerprint'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        ),
      ).called(1);

      verify(
        mockComputerRepo.importProfile(
          computerId: anyNamed('computerId'),
          profileStartTime: DateTime(2026, 1, 2, 9, 0),
          points: anyNamed('points'),
          durationSeconds: anyNamed('durationSeconds'),
          maxDepth: anyNamed('maxDepth'),
          avgDepth: anyNamed('avgDepth'),
          isPrimary: anyNamed('isPrimary'),
          diverId: anyNamed('diverId'),
          tanks: anyNamed('tanks'),
          decoAlgorithm: anyNamed('decoAlgorithm'),
          gfLow: anyNamed('gfLow'),
          gfHigh: anyNamed('gfHigh'),
          decoConservatism: anyNamed('decoConservatism'),
          events: anyNamed('events'),
          diveNumber: 2,
          rawData: anyNamed('rawData'),
          rawFingerprint: anyNamed('rawFingerprint'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        ),
      ).called(1);

      verify(
        mockComputerRepo.importProfile(
          computerId: anyNamed('computerId'),
          profileStartTime: DateTime(2026, 1, 3, 9, 0),
          points: anyNamed('points'),
          durationSeconds: anyNamed('durationSeconds'),
          maxDepth: anyNamed('maxDepth'),
          avgDepth: anyNamed('avgDepth'),
          isPrimary: anyNamed('isPrimary'),
          diverId: anyNamed('diverId'),
          tanks: anyNamed('tanks'),
          decoAlgorithm: anyNamed('decoAlgorithm'),
          gfLow: anyNamed('gfLow'),
          gfHigh: anyNamed('gfHigh'),
          decoConservatism: anyNamed('decoConservatism'),
          events: anyNamed('events'),
          diveNumber: 3,
          rawData: anyNamed('rawData'),
          rawFingerprint: anyNamed('rawFingerprint'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        ),
      ).called(1);
    });

    test(
      'sorts newest-first device data to oldest-first before import',
      () async {
        // Device sends newest-first (common for dive computers)
        final newerDive = DownloadedDive(
          fingerprint: 'fp-newer',
          startTime: DateTime(2026, 3, 2, 14, 0),
          durationSeconds: 2400,
          maxDepth: 25.0,
          profile: const [],
          tanks: const [],
          events: const [],
        );
        final olderDive = DownloadedDive(
          fingerprint: 'fp-older',
          startTime: DateTime(2026, 3, 1, 10, 0),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: const [],
          tanks: const [],
          events: const [],
        );

        when(
          mockDiveRepo.getDiveNumberForDate(
            DateTime(2026, 3, 1, 10, 0),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => 1);
        when(
          mockDiveRepo.getDiveNumberForDate(
            DateTime(2026, 3, 2, 14, 0),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => 2);

        // Pass dives newest-first (as dive computers deliver them)
        await service.importDives(
          dives: [newerDive, olderDive],
          computer: computer,
        );

        // Older dive should be imported first (dive number 1)
        verify(
          mockComputerRepo.importProfile(
            computerId: anyNamed('computerId'),
            profileStartTime: DateTime(2026, 3, 1, 10, 0),
            points: anyNamed('points'),
            durationSeconds: anyNamed('durationSeconds'),
            maxDepth: anyNamed('maxDepth'),
            avgDepth: anyNamed('avgDepth'),
            isPrimary: anyNamed('isPrimary'),
            diverId: anyNamed('diverId'),
            tanks: anyNamed('tanks'),
            decoAlgorithm: anyNamed('decoAlgorithm'),
            gfLow: anyNamed('gfLow'),
            gfHigh: anyNamed('gfHigh'),
            decoConservatism: anyNamed('decoConservatism'),
            events: anyNamed('events'),
            diveNumber: 1,
            rawData: anyNamed('rawData'),
            rawFingerprint: anyNamed('rawFingerprint'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).called(1);

        // Newer dive should be imported second (dive number 2)
        verify(
          mockComputerRepo.importProfile(
            computerId: anyNamed('computerId'),
            profileStartTime: DateTime(2026, 3, 2, 14, 0),
            points: anyNamed('points'),
            durationSeconds: anyNamed('durationSeconds'),
            maxDepth: anyNamed('maxDepth'),
            avgDepth: anyNamed('avgDepth'),
            isPrimary: anyNamed('isPrimary'),
            diverId: anyNamed('diverId'),
            tanks: anyNamed('tanks'),
            decoAlgorithm: anyNamed('decoAlgorithm'),
            gfLow: anyNamed('gfLow'),
            gfHigh: anyNamed('gfHigh'),
            decoConservatism: anyNamed('decoConservatism'),
            events: anyNamed('events'),
            diveNumber: 2,
            rawData: anyNamed('rawData'),
            rawFingerprint: anyNamed('rawFingerprint'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).called(1);
      },
    );

    test(
      'assigns correct number when importing between existing dives',
      () async {
        final dive = DownloadedDive(
          fingerprint: 'fp-mid',
          startTime: DateTime(2026, 6, 15, 10, 0),
          durationSeconds: 3600,
          maxDepth: 30.0,
          profile: const [],
          tanks: const [],
          events: const [],
        );

        // 5 dives already exist before this date, so this becomes dive #6
        when(
          mockDiveRepo.getDiveNumberForDate(
            DateTime(2026, 6, 15, 10, 0),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => 6);

        await service.importDives(dives: [dive], computer: computer);

        verify(
          mockComputerRepo.importProfile(
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
            gfLow: anyNamed('gfLow'),
            gfHigh: anyNamed('gfHigh'),
            decoConservatism: anyNamed('decoConservatism'),
            events: anyNamed('events'),
            diveNumber: 6,
            rawData: anyNamed('rawData'),
            rawFingerprint: anyNamed('rawFingerprint'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).called(1);
      },
    );

    test(
      'low-confidence duplicate in all mode passes forceNew to importProfile',
      () async {
        final dive = DownloadedDive(
          fingerprint: 'fp-lowconf',
          startTime: DateTime(2026, 3, 10, 9, 0),
          durationSeconds: 2400,
          maxDepth: 15.0,
          profile: const [],
          tanks: const [],
          events: const [],
        );

        // Return a low-confidence match (score 0.6 → possible, not likely)
        when(
          mockComputerRepo.findMatchingDiveWithScore(
            profileStartTime: anyNamed('profileStartTime'),
            toleranceMinutes: anyNamed('toleranceMinutes'),
            durationSeconds: anyNamed('durationSeconds'),
            maxDepth: anyNamed('maxDepth'),
            fingerprint: anyNamed('fingerprint'),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer(
          (_) async => const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.6,
            timeDifferenceMs: 60000,
          ),
        );

        when(
          mockDiveRepo.getDiveNumberForDate(any, diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => 1);

        await service.importDives(
          dives: [dive],
          computer: computer,
          mode: ImportMode.all,
          defaultResolution: ConflictResolution.importAsNew,
          diverId: 'diver-1',
        );

        // Verify importProfile was called with forceNew: true
        verify(
          mockComputerRepo.importProfile(
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
            gfLow: anyNamed('gfLow'),
            gfHigh: anyNamed('gfHigh'),
            decoConservatism: anyNamed('decoConservatism'),
            events: anyNamed('events'),
            diveNumber: anyNamed('diveNumber'),
            forceNew: true,
            rawData: anyNamed('rawData'),
            rawFingerprint: anyNamed('rawFingerprint'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).called(1);
      },
    );

    test('importSingleDiveAsNew passes forceNew to importProfile', () async {
      final dive = DownloadedDive(
        fingerprint: 'fp-single',
        startTime: DateTime(2026, 3, 10, 10, 0),
        durationSeconds: 1800,
        maxDepth: 12.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );

      when(
        mockDiveRepo.getDiveNumberForDate(any, diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => 5);

      await service.importSingleDiveAsNew(
        dive,
        computerId: computer.id,
        diverId: 'diver-1',
      );

      verify(
        mockComputerRepo.importProfile(
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
          gfLow: anyNamed('gfLow'),
          gfHigh: anyNamed('gfHigh'),
          decoConservatism: anyNamed('decoConservatism'),
          events: anyNamed('events'),
          diveNumber: anyNamed('diveNumber'),
          forceNew: true,
          rawData: anyNamed('rawData'),
          rawFingerprint: anyNamed('rawFingerprint'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        ),
      ).called(1);
    });

    test('resolveConflict with importAsNew assigns dive number', () async {
      final dive = DownloadedDive(
        fingerprint: 'fp-conflict',
        startTime: DateTime(2026, 5, 10, 9, 0),
        durationSeconds: 2700,
        maxDepth: 18.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );

      final conflict = ImportConflict(
        downloaded: dive,
        existingDiveId: 'existing-dive-id',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing-dive-id',
          confidence: DuplicateConfidence.likely,
          score: 0.85,
        ),
      );

      // 3 existing dives before this date
      when(
        mockDiveRepo.getDiveNumberForDate(
          DateTime(2026, 5, 10, 9, 0),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer((_) async => 4);

      await service.resolveConflict(
        conflict,
        ConflictResolution.importAsNew,
        computer.id,
        diverId: 'diver-1',
      );

      verify(
        mockComputerRepo.importProfile(
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
          gfLow: anyNamed('gfLow'),
          gfHigh: anyNamed('gfHigh'),
          decoConservatism: anyNamed('decoConservatism'),
          events: anyNamed('events'),
          diveNumber: 4,
          rawData: anyNamed('rawData'),
          rawFingerprint: anyNamed('rawFingerprint'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
        ),
      ).called(1);
    });

    test(
      'resolveConflict with replaceSource calls clearSourceAndProfiles then importProfile',
      () async {
        final dive = DownloadedDive(
          fingerprint: 'fp-replace',
          startTime: DateTime(2026, 4, 5, 8, 30),
          durationSeconds: 3000,
          maxDepth: 22.0,
          avgDepth: 14.5,
          profile: const [],
          tanks: const [],
          events: const [],
          rawData: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
          rawFingerprint: Uint8List.fromList([0x01, 0x02, 0x03]),
        );

        final conflict = ImportConflict(
          downloaded: dive,
          existingDiveId: 'existing-dive-42',
          duplicateResult: const DuplicateResult(
            matchingDiveId: 'existing-dive-42',
            confidence: DuplicateConfidence.exact,
            score: 0.95,
          ),
        );

        // Stub clearSourceAndProfiles
        when(
          mockComputerRepo.clearSourceAndProfiles(
            diveId: anyNamed('diveId'),
            computerId: anyNamed('computerId'),
          ),
        ).thenAnswer((_) async {});

        final result = await service.resolveConflict(
          conflict,
          ConflictResolution.replaceSource,
          computer.id,
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 42,
          libdivecomputerVersion: '0.8.0',
        );

        // Returns the existing dive ID
        expect(result, equals('existing-dive-42'));

        // Verify clearSourceAndProfiles was called with correct IDs
        verify(
          mockComputerRepo.clearSourceAndProfiles(
            diveId: 'existing-dive-42',
            computerId: computer.id,
          ),
        ).called(1);

        // Verify importProfile was called with isPrimary: true, descriptor
        // fields, rawData, rawFingerprint, and avgDepth
        verify(
          mockComputerRepo.importProfile(
            computerId: computer.id,
            profileStartTime: DateTime(2026, 4, 5, 8, 30),
            points: anyNamed('points'),
            durationSeconds: 3000,
            maxDepth: 22.0,
            avgDepth: 14.5,
            isPrimary: true,
            diverId: anyNamed('diverId'),
            tanks: anyNamed('tanks'),
            decoAlgorithm: anyNamed('decoAlgorithm'),
            gfLow: anyNamed('gfLow'),
            gfHigh: anyNamed('gfHigh'),
            decoConservatism: anyNamed('decoConservatism'),
            events: anyNamed('events'),
            diveNumber: anyNamed('diveNumber'),
            forceNew: anyNamed('forceNew'),
            rawData: anyNamed('rawData'),
            rawFingerprint: anyNamed('rawFingerprint'),
            descriptorVendor: 'Shearwater',
            descriptorProduct: 'Perdix',
            descriptorModel: 42,
            libdivecomputerVersion: '0.8.0',
          ),
        ).called(1);
      },
    );

    test('resolveConflict with consolidate returns null', () async {
      final dive = DownloadedDive(
        fingerprint: 'fp-consolidate',
        startTime: DateTime(2026, 4, 10, 11, 0),
        durationSeconds: 2400,
        maxDepth: 18.0,
        profile: const [],
        tanks: const [],
        events: const [],
      );

      final conflict = ImportConflict(
        downloaded: dive,
        existingDiveId: 'existing-dive-99',
        duplicateResult: const DuplicateResult(
          matchingDiveId: 'existing-dive-99',
          confidence: DuplicateConfidence.likely,
          score: 0.80,
        ),
      );

      final result = await service.resolveConflict(
        conflict,
        ConflictResolution.consolidate,
        computer.id,
      );

      expect(result, isNull);
      expect(conflict.resolution, ConflictResolution.consolidate);

      // Neither clearSourceAndProfiles nor importProfile should be called
      verifyNever(
        mockComputerRepo.clearSourceAndProfiles(
          diveId: anyNamed('diveId'),
          computerId: anyNamed('computerId'),
        ),
      );
    });
  });
}
