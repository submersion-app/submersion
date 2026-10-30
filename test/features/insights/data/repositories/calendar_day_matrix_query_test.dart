import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3127: dives counted by the calendar date they were logged on.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  /// A wall clock flagged as UTC, the way dive_date_time stores it.
  int utc(int year, int month, int day, [int hour = 9, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

  Future<void> dive(
    String id, {
    required int start,
    String? diverId,
    bool excluded = false,
    double? maxDepth,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(start),
          maxDepth: Value(maxDepth),
          excludedFromStats: Value(excluded),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  test('no dives is an empty matrix', () async {
    final m = await repository.getCalendarDayMatrix();
    expect(m.isEmpty, isTrue);
  });

  test('counts dives by their calendar date across years', () async {
    await dive('a', start: utc(2019, 5, 6));
    await dive('b', start: utc(2024, 5, 6, 14));
    await dive('c', start: utc(2024, 2, 29, 10));

    final m = await repository.getCalendarDayMatrix();

    expect(m.count(5, 6), 2);
    expect(m.count(2, 29), 1);
    expect(m.total, 3);
  });

  test('a 23:30 dive stays on its own date', () async {
    await dive('late', start: utc(2025, 5, 6, 23, 30));

    final m = await repository.getCalendarDayMatrix();

    expect(m.count(5, 6), 1);
    expect(m.count(5, 7), 0);
  });

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          medicalNotes: const Value(''),
          notes: const Value(''),
          isDefault: const Value(false),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  test('only the given diver', () async {
    await diver('me');
    await diver('them');
    await dive('mine', start: utc(2025, 1, 1), diverId: 'me');
    await dive('theirs', start: utc(2025, 1, 1), diverId: 'them');

    final m = await repository.getCalendarDayMatrix(diverId: 'me');

    expect(m.total, 1);
  });

  test('dives excluded from statistics are not counted', () async {
    await dive('kept', start: utc(2025, 3, 3));
    await dive('excluded', start: utc(2025, 3, 3), excluded: true);

    final m = await repository.getCalendarDayMatrix();

    expect(m.count(3, 3), 1);
  });

  test('the Insights filter narrows the count', () async {
    await dive('deep', start: utc(2025, 3, 3), maxDepth: 30);
    await dive('shallow', start: utc(2025, 3, 3), maxDepth: 5);

    final m = await repository.getCalendarDayMatrix(
      filter: const DiveFilterState(minDepth: 20),
    );

    expect(m.count(3, 3), 1);
  });
}
