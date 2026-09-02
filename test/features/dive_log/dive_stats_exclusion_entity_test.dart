import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  Dive makeDive() => Dive(id: 'd1', dateTime: DateTime(2026, 1, 1));

  test('both exclusion flags default to false', () {
    final dive = makeDive();
    expect(dive.excludedFromStats, isFalse);
    expect(dive.excludedFromGasStats, isFalse);
  });

  test('copyWith sets each flag independently', () {
    final dive = makeDive();
    expect(dive.copyWith(excludedFromStats: true).excludedFromStats, isTrue);
    expect(
      dive.copyWith(excludedFromStats: true).excludedFromGasStats,
      isFalse,
      reason:
          'the master flag must not write through to the gas flag; '
          'the implication lives in SQL, not in the entity',
    );
    expect(
      dive.copyWith(excludedFromGasStats: true).excludedFromGasStats,
      isTrue,
    );
    expect(
      dive.copyWith(excludedFromGasStats: true).excludedFromStats,
      isFalse,
    );
  });

  test('copyWith preserves the flags when they are not passed', () {
    final excluded = makeDive().copyWith(
      excludedFromStats: true,
      excludedFromGasStats: true,
    );
    final renamed = excluded.copyWith(notes: 'changed');
    expect(renamed.excludedFromStats, isTrue);
    expect(renamed.excludedFromGasStats, isTrue);
  });

  test('the flags participate in equality', () {
    final a = makeDive();
    expect(a, isNot(equals(a.copyWith(excludedFromStats: true))));
    expect(a, isNot(equals(a.copyWith(excludedFromGasStats: true))));
  });
}
