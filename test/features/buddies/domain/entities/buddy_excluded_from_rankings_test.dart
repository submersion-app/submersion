import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

void main() {
  final buddy = Buddy(
    id: 'b1',
    name: 'Unknown',
    linkedDiverId: 'd1',
    photo: Uint8List.fromList([1]),
    excludedFromRankings: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('defaults to ranked', () {
    expect(
      Buddy(
        id: 'b2',
        name: 'Anna',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ).excludedFromRankings,
      isFalse,
    );
  });

  test('copyWith keeps the flag unless told otherwise', () {
    expect(buddy.copyWith(name: 'x').excludedFromRankings, isTrue);
    expect(
      buddy.copyWith(excludedFromRankings: false).excludedFromRankings,
      isFalse,
    );
  });

  test('clearPhoto and clearLinkedDiver keep the flag', () {
    expect(buddy.clearPhoto().excludedFromRankings, isTrue);
    expect(buddy.clearLinkedDiver().excludedFromRankings, isTrue);
  });

  test('the flag is part of equality', () {
    expect(buddy == buddy.copyWith(excludedFromRankings: false), isFalse);
  });
}
