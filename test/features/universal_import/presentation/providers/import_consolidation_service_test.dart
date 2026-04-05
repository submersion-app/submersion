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

    test('maps profile data with parsed sample fidelity fields', () async {
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
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
            'profile': <Map<String, dynamic>>[
              {
                'timestamp': 10,
                'depth': 5.0,
                'temperature': 22.5,
                'heartRate': 82,
                'setpoint': 1.3,
                'ppO2': 1.1,
                'cns': 3.5,
                'ndl': 1200,
                'rbt': 1500,
                'decoType': 2,
                'tts': 240,
              },
              {
                'timestamp': 20,
                'depth': 15.0,
                'temperature': 21.0,
                'heartRate': 88,
                'setpoint': 1.4,
                'ppO2': 1.2,
                'cns': 5.0,
                'ndl': 900,
                'rbt': 1200,
                'decoType': 1,
                'tts': 180,
              },
            ],
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
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: captureAnyNamed('secondaryProfile'),
        ),
      ).captured;

      final profile = captured.first as List<DiveProfilesCompanion>;
      expect(profile, hasLength(2));

      expect(profile[0].timestamp.value, 10);
      expect(profile[0].depth.value, 5.0);
      expect(profile[0].temperature.value, 22.5);
      expect(profile[0].pressure.value, isNull);
      expect(profile[0].heartRate.value, 82);
      expect(profile[0].setpoint.value, 1.3);
      expect(profile[0].ppO2.value, 1.1);
      expect(profile[0].cns.value, 3.5);
      expect(profile[0].ndl.value, 1200);
      expect(profile[0].rbt.value, 1500);
      expect(profile[0].decoType.value, 2);
      expect(profile[0].tts.value, 240);

      expect(profile[1].timestamp.value, 20);
      expect(profile[1].depth.value, 15.0);
      expect(profile[1].heartRate.value, 88);
      expect(profile[1].cns.value, 5.0);
      expect(profile[1].ndl.value, 900);
      expect(profile[1].rbt.value, 1200);
      expect(profile[1].decoType.value, 1);
      expect(profile[1].tts.value, 180);
    });

    test(
      'accepts numeric profile fields when doubles arrive as ints',
      () async {
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
              'maxDepth': 25,
              'avgDepth': 18,
              'waterTemp': 22,
              'duration': const Duration(minutes: 45),
              'profile': <Map<String, dynamic>>[
                {
                  'timestamp': 10,
                  'depth': 5,
                  'temperature': 22,
                  'cns': 4,
                  'setpoint': 1,
                  'ppO2': 1,
                },
              ],
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
            secondaryProfile: captureAnyNamed('secondaryProfile'),
          ),
        ).captured;

        final reading = captured[0] as DiveDataSourcesCompanion;
        final profile = captured[1] as List<DiveProfilesCompanion>;

        expect(reading.maxDepth.value, 25.0);
        expect(reading.avgDepth.value, 18.0);
        expect(reading.waterTemp.value, 22.0);
        expect(profile.single.cns.value, 4.0);
        expect(profile.single.depth.value, 5.0);
        expect(profile.single.temperature.value, 22.0);
        expect(profile.single.setpoint.value, 1.0);
        expect(profile.single.ppO2.value, 1.0);
      },
    );

    test('computes exitTime from runtime when runtime is present', () async {
      when(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final entryTime = DateTime(2024, 6, 15, 9, 0);
      await performConsolidations(
        indices: {0},
        diveItems: [
          {
            'dateTime': entryTime,
            'runtime': const Duration(minutes: 50),
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
      // exitTime should be entryTime + runtime = 9:00 + 50 min = 9:50
      expect(
        reading.exitTime.value,
        entryTime.add(const Duration(minutes: 50)),
      );
    });

    test('exitTime uses duration when runtime is absent', () async {
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
      // No runtime but duration present: exitTime = entryTime + duration.
      expect(
        reading.exitTime.value,
        DateTime(2024, 6, 15, 9, 0).add(const Duration(minutes: 45)),
      );
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

    test('exitTime is null when both runtime and duration are null', () async {
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
            'maxDepth': 25.0,
            // No 'runtime' and no 'duration' keys.
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
      // With no runtime and no duration, exitTime should be null.
      expect(reading.exitTime.value, isNull);
      // duration in the companion should also be null.
      expect(reading.duration.value, isNull);
    });

    test(
      'duration field in companion uses effectiveDuration (runtime over duration)',
      () async {
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
              'runtime': const Duration(minutes: 55),
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
        // effectiveDuration should prefer runtime (55 min = 3300 sec).
        expect(reading.duration.value, 3300);
        // exitTime should be entryTime + runtime (55 min).
        expect(
          reading.exitTime.value,
          DateTime(2024, 6, 15, 9, 0).add(const Duration(minutes: 55)),
        );
      },
    );

    test('skips dive item when dateTime is null', () async {
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
            // No 'dateTime' key -- should skip this dive.
            'maxDepth': 25.0,
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

      expect(count, 0);
      verifyNever(
        mockRepository.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      );
    });

    test(
      'profile entries with missing timestamp/depth use defaults (0 / 0.0)',
      () async {
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
              'maxDepth': 25.0,
              'duration': const Duration(minutes: 45),
              'profile': <Map<String, dynamic>>[
                {
                  // Missing 'timestamp' and 'depth' -- should default.
                  'temperature': 22.0,
                },
              ],
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
            secondaryReading: anyNamed('secondaryReading'),
            secondaryProfile: captureAnyNamed('secondaryProfile'),
          ),
        ).captured;

        final profile = captured.first as List<DiveProfilesCompanion>;
        expect(profile, hasLength(1));
        expect(profile[0].timestamp.value, 0);
        expect(profile[0].depth.value, 0.0);
        expect(profile[0].temperature.value, 22.0);
      },
    );

    test(
      'profile entries with null optional fields produce null Values',
      () async {
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
              'maxDepth': 25.0,
              'duration': const Duration(minutes: 45),
              'profile': <Map<String, dynamic>>[
                {
                  'timestamp': 30,
                  'depth': 12.0,
                  // All optional fields absent.
                },
              ],
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
            secondaryReading: anyNamed('secondaryReading'),
            secondaryProfile: captureAnyNamed('secondaryProfile'),
          ),
        ).captured;

        final profile = captured.first as List<DiveProfilesCompanion>;
        expect(profile, hasLength(1));
        expect(profile[0].timestamp.value, 30);
        expect(profile[0].depth.value, 12.0);
        expect(profile[0].temperature.value, isNull);
        expect(profile[0].pressure.value, isNull);
        expect(profile[0].setpoint.value, isNull);
        expect(profile[0].ppO2.value, isNull);
      },
    );

    test(
      'secondary reading contains all expected fields from diveData',
      () async {
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
              'maxDepth': 30.5,
              'avgDepth': 22.1,
              'waterTemp': 19.5,
              'cnsEnd': 27.5,
              'otu': 64.25,
              'diveComputerModel': 'Shearwater Perdix',
              'diveComputerSerial': 'ABC123',
              'sourceFormat': 'UDDF',
              'duration': const Duration(minutes: 60),
            },
          ],
          duplicateResult: const ImportDuplicateResult(
            diveMatches: {
              0: DiveMatchResult(
                diveId: 'dive-xyz',
                score: 0.95,
                timeDifferenceMs: 50,
              ),
            },
          ),
          diveRepository: mockRepository,
        );

        final captured = verify(
          mockRepository.consolidateComputer(
            targetDiveId: 'dive-xyz',
            secondaryReading: captureAnyNamed('secondaryReading'),
            secondaryProfile: anyNamed('secondaryProfile'),
          ),
        ).captured;

        final reading = captured.first as DiveDataSourcesCompanion;
        expect(reading.diveId.value, 'dive-xyz');
        expect(reading.isPrimary.value, false);
        expect(reading.computerModel.value, 'Shearwater Perdix');
        expect(reading.computerSerial.value, 'ABC123');
        expect(reading.sourceFormat.value, 'UDDF');
        expect(reading.maxDepth.value, 30.5);
        expect(reading.avgDepth.value, 22.1);
        expect(reading.waterTemp.value, 19.5);
        expect(reading.cns.value, 27.5);
        expect(reading.otu.value, 64.25);
        expect(reading.duration.value, 3600); // 60 min in seconds
        expect(reading.entryTime.value, DateTime(2024, 6, 15, 9, 0));
        expect(
          reading.exitTime.value,
          DateTime(2024, 6, 15, 9, 0).add(const Duration(minutes: 60)),
        );
      },
    );
  });
}
