import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/widgets/imported_dive_card.dart';

@GenerateMocks([DiveRepository, HealthImportService])
import 'dive_import_notifier_test.mocks.dart';

void main() {
  group('DiveImportNotifier', () {
    late MockDiveRepository mockRepository;
    late MockHealthImportService mockService;
    late DiveImportNotifier notifier;
    const matcher = DiveMatcher();
    const converter = ImportedDiveConverter();

    setUp(() {
      mockRepository = MockDiveRepository();
      mockService = MockHealthImportService();
      notifier = DiveImportNotifier(mockService);
    });

    ImportedDive createImportedDive({
      required String sourceId,
      required DateTime startTime,
      double maxDepth = 20.0,
      int durationMinutes = 45,
    }) {
      return ImportedDive(
        sourceId: sourceId,
        source: ImportSource.appleWatch,
        startTime: startTime,
        endTime: startTime.add(Duration(minutes: durationMinutes)),
        maxDepth: maxDepth,
        profile: const [],
      );
    }

    domain.Dive createExistingDive({
      required String id,
      required DateTime dateTime,
      double maxDepth = 20.0,
      int durationMinutes = 45,
      String? wearableId,
    }) {
      return domain.Dive(
        id: id,
        dateTime: dateTime,
        entryTime: dateTime,
        exitTime: dateTime.add(Duration(minutes: durationMinutes)),
        duration: Duration(minutes: durationMinutes),
        maxDepth: maxDepth,
        wearableId: wearableId,
      );
    }

    group('checkForDuplicates', () {
      test('marks dives with matching wearableId as alreadyImported', () async {
        // Set up notifier state with available dives and selection
        final dive1 = createImportedDive(
          sourceId: 'already-imported-id',
          startTime: DateTime(2024, 6, 15, 10, 0),
        );
        final dive2 = createImportedDive(
          sourceId: 'new-dive-id',
          startTime: DateTime(2024, 6, 16, 10, 0),
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [dive1, dive2]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        // Mock repository
        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => {'already-imported-id'});
        when(
          mockRepository.getDivesInRange(
            any,
            any,
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => []);

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        final results = notifier.state.matchResults;
        expect(
          results['already-imported-id'],
          equals(ImportMatchStatus.alreadyImported),
        );
        expect(results['new-dive-id'], equals(ImportMatchStatus.none));
      });

      test('marks fuzzy matches as probable or possible', () async {
        final wDive = createImportedDive(
          sourceId: 'fuzzy-match',
          startTime: DateTime(2024, 6, 15, 10, 0),
          maxDepth: 20.0,
          durationMinutes: 45,
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [wDive]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        // Existing dive at same time = very high match score
        final existingDive = createExistingDive(
          id: 'existing-1',
          dateTime: DateTime(2024, 6, 15, 10, 2), // 2 min diff
          maxDepth: 20.5,
          durationMinutes: 44,
        );

        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => <String>{});
        when(
          mockRepository.getDivesInRange(
            any,
            any,
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => [existingDive]);

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        expect(
          notifier.state.matchResults['fuzzy-match'],
          equals(ImportMatchStatus.probable),
        );
      });

      test('marks non-matching dives as none', () async {
        final wDive = createImportedDive(
          sourceId: 'unique-dive',
          startTime: DateTime(2024, 6, 15, 10, 0),
          maxDepth: 20.0,
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [wDive]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        // Existing dive at very different time
        final existingDive = createExistingDive(
          id: 'existing-far',
          dateTime: DateTime(2024, 6, 20, 10, 0), // 5 days later
          maxDepth: 30.0,
          durationMinutes: 60,
        );

        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => <String>{});
        when(
          mockRepository.getDivesInRange(
            any,
            any,
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer((_) async => [existingDive]);

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        expect(
          notifier.state.matchResults['unique-dive'],
          equals(ImportMatchStatus.none),
        );
      });

      test('handles empty selection gracefully', () async {
        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => []);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        expect(notifier.state.matchResults, isEmpty);
        expect(notifier.state.isLoading, isFalse);
      });

      test('sets error state on exception', () async {
        final wDive = createImportedDive(
          sourceId: 'error-dive',
          startTime: DateTime(2024, 6, 15, 10, 0),
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [wDive]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenThrow(Exception('DB error'));

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        expect(notifier.state.error, contains('Failed to check'));
        expect(notifier.state.isLoading, isFalse);
      });
    });

    group('performImport', () {
      test('imports new dives and skips duplicates', () async {
        final newDive = createImportedDive(
          sourceId: 'new-dive',
          startTime: DateTime(2024, 6, 15, 10, 0),
        );
        final dupDive = createImportedDive(
          sourceId: 'dup-dive',
          startTime: DateTime(2024, 6, 16, 10, 0),
        );
        final importedDive = createImportedDive(
          sourceId: 'imported-dive',
          startTime: DateTime(2024, 6, 17, 10, 0),
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [newDive, dupDive, importedDive]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        // Manually set match results
        // (normally checkForDuplicates does this, but we test import independently)
        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => {'imported-dive'});
        when(
          mockRepository.getDivesInRange(
            any,
            any,
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer(
          (_) async => [
            createExistingDive(
              id: 'existing-dup',
              dateTime: DateTime(2024, 6, 16, 10, 1),
              maxDepth: 20.0,
              durationMinutes: 45,
            ),
          ],
        );

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        // Now perform import
        when(
          mockRepository.getDiveNumberForDate(
            any,
            diverId: anyNamed('diverId'),
            startFrom: anyNamed('startFrom'),
          ),
        ).thenAnswer((_) async => 1);
        when(mockRepository.createDive(any)).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments[0] as domain.Dive,
        );

        await notifier.performImport(
          repository: mockRepository,
          converter: converter,
          diverId: 'diver-1',
        );

        expect(notifier.state.isImporting, isFalse);
        expect(notifier.state.importedCount, equals(1)); // Only new-dive
        expect(notifier.state.skippedCount, equals(2)); // dup + imported

        // Verify createDive was called exactly once (for new-dive)
        verify(mockRepository.createDive(any)).called(1);
      });

      test('imports possible duplicates (user chose them)', () async {
        final possibleDup = createImportedDive(
          sourceId: 'possible-dup',
          startTime: DateTime(2024, 6, 15, 10, 0),
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [possibleDup]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        // Existing dive with moderate match (possible, not probable)
        // Time 12 min diff -> score 0.3; Depth same -> score 1.0; Duration same -> score 1.0
        // Composite: 0.3*0.50 + 1.0*0.30 + 1.0*0.20 = 0.15+0.30+0.20 = 0.65
        when(
          mockRepository.getWearableIds(diverId: anyNamed('diverId')),
        ).thenAnswer((_) async => <String>{});
        when(
          mockRepository.getDivesInRange(
            any,
            any,
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer(
          (_) async => [
            createExistingDive(
              id: 'existing-moderate',
              dateTime: DateTime(2024, 6, 15, 10, 12), // 12 min diff
              maxDepth: 20.0,
              durationMinutes: 45,
            ),
          ],
        );

        await notifier.checkForDuplicates(
          repository: mockRepository,
          matcher: matcher,
        );

        // Verify it's a "possible" match (score between 0.5-0.7)
        expect(
          notifier.state.matchResults['possible-dup'],
          equals(ImportMatchStatus.possible),
        );

        // Import should still import it (possible = user chose to include)
        when(
          mockRepository.getDiveNumberForDate(
            any,
            diverId: anyNamed('diverId'),
            startFrom: anyNamed('startFrom'),
          ),
        ).thenAnswer((_) async => 1);
        when(mockRepository.createDive(any)).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments[0] as domain.Dive,
        );

        await notifier.performImport(
          repository: mockRepository,
          converter: converter,
        );

        expect(notifier.state.importedCount, equals(1));
        expect(notifier.state.skippedCount, equals(0));
      });

      test('sets error state on import failure', () async {
        final dive = createImportedDive(
          sourceId: 'fail-dive',
          startTime: DateTime(2024, 6, 15, 10, 0),
        );

        when(
          mockService.fetchDives(
            startDate: anyNamed('startDate'),
            endDate: anyNamed('endDate'),
          ),
        ).thenAnswer((_) async => [dive]);

        await notifier.fetchDives(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 30),
        );
        notifier.selectAll();

        when(
          mockRepository.getDiveNumberForDate(
            any,
            diverId: anyNamed('diverId'),
            startFrom: anyNamed('startFrom'),
          ),
        ).thenThrow(Exception('DB write error'));

        await notifier.performImport(
          repository: mockRepository,
          converter: converter,
        );

        expect(notifier.state.error, contains('Failed to import'));
        expect(notifier.state.isImporting, isFalse);
      });
    });
  });
}
