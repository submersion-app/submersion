import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  final base = Dive(id: 'd1', dateTime: DateTime(2026, 6, 1, 9));

  test('outingId defaults to null and copyWith carries it', () {
    expect(base.outingId, isNull);
    final withOuting = base.copyWith(outingId: 'outing-1');
    expect(withOuting.outingId, 'outing-1');
    expect(withOuting.copyWith(name: 'x').outingId, 'outing-1');
    expect(withOuting, isNot(equals(base)));
  });

  test('copyWith(clearOutingId: true) removes the outing id', () {
    final withOuting = base.copyWith(outingId: 'outing-1');
    expect(withOuting.copyWith(clearOutingId: true).outingId, isNull);
  });
}
