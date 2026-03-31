import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart';

@GenerateMocks([DiveRepository])
import 'import_consolidation_service_test.mocks.dart';

void main() {
  late MockDiveRepository mockRepository;

  setUp(() {
    mockRepository = MockDiveRepository();
  });

  group('performConsolidations', () {
    test('returns 0 for empty indices', () async {
      final count = await performConsolidations(
        indices: <int>{},
        diveItems: [
          {'dateTime': DateTime(2024, 6, 15), 'maxDepth': 25.0},
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 0);
      verifyNever(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      );
    });

    test('returns 0 when duplicateResult is null', () async {
      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {'dateTime': DateTime(2024, 6, 15), 'maxDepth': 25.0},
        ],
        duplicateResult: null,
        diveRepository: mockRepository,
      );

      expect(count, 0);
      verifyNever(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      );
    });

    test('returns 0 when duplicateResult has no match for index', () async {
      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {'dateTime': DateTime(2024, 6, 15), 'maxDepth': 25.0},
        ],
        duplicateResult: const ImportDuplicateResult(diveMatches: {}),
        diveRepository: mockRepository,
      );

      expect(count, 0);
      verifyNever(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      );
    });

    test('successful consolidation increments count', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
            'avgDepth': 18.0,
            'waterTemp': 22.0,
            'diveComputerModel': 'Suunto D5',
            'diveComputerSerial': 'SN12345',
            'sourceFormat': 'CSV',
            'duration': const Duration(minutes: 45),
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 1);
      verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'existing-dive-1',
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).called(1);
    });

    test('consolidates multiple indices', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0, 1},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
          },
          {
            'dateTime': DateTime(2024, 6, 16, 10, 0),
            'maxDepth': 30.0,
            'duration': const Duration(minutes: 50),
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'dive-a',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            1: DiveMatchResult(
              diveId: 'dive-b',
              score: 0.85,
              timeDifferenceMs: 200,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 2);
      verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'dive-a',
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).called(1);
      verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'dive-b',
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).called(1);
    });

    test('uses runtime as effective duration when available', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'runtime': const Duration(minutes: 50),
            'duration': const Duration(minutes: 45),
            'maxDepth': 25.0,
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 1);

      // Capture the secondaryReading to verify the duration used runtime.
      final captured = verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'existing-dive-1',
          secondaryReading: captureAnyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).captured;

      final reading = captured.first as DiveDataSourcesCompanion;
      // runtime is 50 min = 3000 sec
      expect(reading.duration.value, 3000);
    });

    test('falls back to duration when runtime is null', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'duration': const Duration(minutes: 45),
            'maxDepth': 25.0,
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      final captured = verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'existing-dive-1',
          secondaryReading: captureAnyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).captured;

      final reading = captured.first as DiveDataSourcesCompanion;
      // duration is 45 min = 2700 sec
      expect(reading.duration.value, 2700);
    });

    test('handles empty profile data', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
            'profile': <Map<String, dynamic>>[],
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 1);

      final captured = verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'existing-dive-1',
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: captureAnyNamed('secondaryProfile'),
        ),
      ).captured;

      final profile = captured.first as List<DiveProfilesCompanion>;
      expect(profile, isEmpty);
    });

    test('handles missing profile key (null)', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
            // no 'profile' key
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 1);

      final captured = verify(
        mockRepository.consolidateComputer(
          targetDiveId: 'existing-dive-1',
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: captureAnyNamed('secondaryProfile'),
        ),
      ).captured;

      final profile = captured.first as List<DiveProfilesCompanion>;
      expect(profile, isEmpty);
    });

    test('skips indices without match but processes matched ones', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final count = await performConsolidations(
        indices: {0, 1, 2},
        diveItems: [
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
          },
          {
            'dateTime': DateTime(2024, 6, 16, 10, 0),
            'maxDepth': 30.0,
            'duration': const Duration(minutes: 50),
          },
          {
            'dateTime': DateTime(2024, 6, 17, 11, 0),
            'maxDepth': 20.0,
            'duration': const Duration(minutes: 40),
          },
        ],
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            // Only index 0 and 2 have matches; index 1 does not.
            0: DiveMatchResult(
              diveId: 'dive-a',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            2: DiveMatchResult(
              diveId: 'dive-c',
              score: 0.85,
              timeDifferenceMs: 200,
            ),
          },
        ),
        diveRepository: mockRepository,
      );

      expect(count, 2);
    });
  });
}
