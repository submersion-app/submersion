import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Diver base() => Diver(id: 'd1', name: 'A', createdAt: now, updatedAt: now);

  test('defaults to null prior experience', () {
    final d = base();
    expect(d.priorDiveCount, isNull);
    expect(d.priorDiveTimeSeconds, isNull);
    expect(d.divingSince, isNull);
  });

  test('copyWith sets and preserves prior-experience fields', () {
    final since = DateTime(1990);
    final d = base().copyWith(
      priorDiveCount: 1200,
      priorDiveTimeSeconds: 1150 * 3600,
      divingSince: since,
    );
    expect(d.priorDiveCount, 1200);
    expect(d.priorDiveTimeSeconds, 1150 * 3600);
    expect(d.divingSince, since);

    final d2 = d.copyWith(name: 'B');
    expect(d2.priorDiveCount, 1200);
    expect(d2.divingSince, since);
  });

  test('props include prior-experience fields (value equality)', () {
    expect(base().copyWith(priorDiveCount: 5) == base(), isFalse);
  });
}
