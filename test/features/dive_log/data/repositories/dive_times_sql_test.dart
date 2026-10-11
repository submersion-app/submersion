import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  /// The chain must stay INTEGER-valued end to end. Every column it reads is
  /// an `IntColumn`, and SQLite's `/` on two integers is integer division, so
  /// the millisecond step cannot produce a REAL. This pins that, because a
  /// REAL leaking into the expression would make `SUM(...)` REAL too and the
  /// `readNullable<int>` on the far side of both aggregates would break.
  test('every step of the chain is INTEGER-typed, including a millisecond '
      'delta that is not a whole number of seconds', () async {
    await repository.createDive(
      domain.Dive(
        id: 'ms-remainder',
        dateTime: DateTime.utc(2026, 4, 1, 10),
        // 40 min and 500 ms: deliberately not divisible by 1000.
        entryTime: DateTime.utc(2026, 4, 1, 10),
        exitTime: DateTime.utc(2026, 4, 1, 10, 40, 0, 500),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'profile-only',
        dateTime: DateTime.utc(2026, 4, 2, 10),
        profile: [
          for (var t = 0; t <= 600; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t == 0 || t == 600 ? 0 : 18,
            ),
        ],
      ),
    );

    final row = await db
        .customSelect(
          'SELECT '
          "typeof(${timestampRuntimeSecondsSql('d')}) AS ts_type, "
          "${timestampRuntimeSecondsSql('d')} AS ts_value, "
          "typeof(${profileSpanSecondsSql('d')}) AS span_type, "
          "typeof(${effectiveRuntimeSecondsSql('d')}) AS chain_type "
          'FROM dives d WHERE d.id = ?',
          variables: [const Variable<String>('ms-remainder')],
        )
        .getSingle();

    expect(row.read<String>('ts_type'), 'integer');
    // Truncated, not rounded: the trailing 500 ms is dropped, matching
    // Duration.inSeconds on the Dart side of the same chain.
    expect(row.read<int>('ts_value'), 40 * 60);
    expect(row.read<String>('chain_type'), 'integer');
    // Null for this dive, which typeof reports as 'null', so read the span
    // type off the dive that actually reaches that step.
    expect(row.read<String>('span_type'), 'null');

    final spanRow = await db
        .customSelect(
          "SELECT typeof(${profileSpanSecondsSql('d')}) AS span_type, "
          "typeof(${effectiveRuntimeSecondsSql('d')}) AS chain_type "
          'FROM dives d WHERE d.id = ?',
          variables: [const Variable<String>('profile-only')],
        )
        .getSingle();
    expect(spanRow.read<String>('span_type'), 'integer');
    expect(spanRow.read<String>('chain_type'), 'integer');

    // The aggregate both callers actually run: SUM must stay INTEGER so the
    // readNullable<int> on the other side is safe.
    final sumRow = await db
        .customSelect(
          "SELECT typeof(SUM(${effectiveRuntimeSecondsSql('d')})) AS sum_type, "
          "SUM(${effectiveRuntimeSecondsSql('d')}) AS total "
          'FROM dives d',
        )
        .getSingle();
    expect(sumRow.read<String>('sum_type'), 'integer');
    expect(sumRow.readNullable<int>('total'), 40 * 60 + 600);
  });

  /// Run time on Insights (#3059) is the chain without its bottom-time step:
  /// bottom time is derived from a depth threshold and never stands in for
  /// a measured duration.
  test('the measured chain stops before bottom time; the effective chain '
      'still ends on it', () async {
    await repository.createDive(
      domain.Dive(
        id: 'table-era',
        dateTime: DateTime.utc(2026, 4, 3, 10),
        bottomTime: const Duration(minutes: 35),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'timestamps',
        dateTime: DateTime.utc(2026, 4, 4, 10),
        entryTime: DateTime.utc(2026, 4, 4, 10),
        exitTime: DateTime.utc(2026, 4, 4, 10, 52),
        bottomTime: const Duration(minutes: 40),
      ),
    );

    Future<({int? measured, int? effective})> read(String id) async {
      final row = await db
          .customSelect(
            "SELECT ${measuredRuntimeSecondsSql('d')} AS measured, "
            "${effectiveRuntimeSecondsSql('d')} AS effective "
            'FROM dives d WHERE d.id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingle();
      return (
        measured: row.readNullable<int>('measured'),
        effective: row.readNullable<int>('effective'),
      );
    }

    final tableEra = await read('table-era');
    expect(tableEra.measured, isNull);
    expect(tableEra.effective, 35 * 60);

    final timestamps = await read('timestamps');
    expect(timestamps.measured, 52 * 60);
    expect(timestamps.effective, 52 * 60);
  });
}
