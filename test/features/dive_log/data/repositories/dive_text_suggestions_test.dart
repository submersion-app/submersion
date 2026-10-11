import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';

import '../../../../helpers/test_database.dart';

/// The editor's suggestions for the free-text boat fields (#3229).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> logBoat(String? boat, int day, {String? diverId}) =>
      repository.createDive(
        domain.Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime.utc(2026, 7, day, 10),
          boatName: boat,
        ),
      );

  test('distinct values, most recently used first', () async {
    await logBoat('Alpha', 1);
    await logBoat('Bravo', 2);
    await logBoat('Alpha', 3);

    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
      ['Alpha', 'Bravo'],
    );
  });

  test(
    'values differing only by surrounding whitespace suggest once',
    () async {
      await logBoat('Calm Seas ', 1);
      await logBoat('Calm Seas', 2);

      expect(
        await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
        ['Calm Seas'],
      );
    },
  );

  test('null and blank values are not suggested', () async {
    await logBoat(null, 1);
    await logBoat('   ', 2);
    await logBoat('', 3);

    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatName),
      isEmpty,
    );
  });

  test('scoped to the diver', () async {
    await insertDiver('eric');
    await insertDiver('chris');
    await logBoat('Mine', 1, diverId: 'eric');
    await logBoat('Theirs', 2, diverId: 'chris');

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.boatName,
        diverId: 'eric',
      ),
      ['Mine'],
    );
  });

  test('capped at the limit', () async {
    for (var day = 1; day <= 5; day++) {
      await logBoat('Boat $day', day);
    }

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.boatName,
        limit: 2,
      ),
      ['Boat 5', 'Boat 4'],
    );
  });

  test('each field reads its own column', () async {
    await repository.createDive(
      domain.Dive(
        id: '',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        diveOperator: 'Buddy Dive',
        boatCaptain: 'Rik',
        surfaceConditions: 'Choppy',
      ),
    );

    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.diveOperator,
      ),
      ['Buddy Dive'],
    );
    expect(
      await repository.getRecentTextValues(DiveTextSuggestionField.boatCaptain),
      ['Rik'],
    );
    expect(
      await repository.getRecentTextValues(
        DiveTextSuggestionField.surfaceConditions,
      ),
      ['Choppy'],
    );
  });
}
