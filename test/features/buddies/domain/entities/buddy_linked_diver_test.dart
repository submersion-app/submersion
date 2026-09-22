import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

void main() {
  final base = Buddy(
    id: 'b1',
    name: 'Chris',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('linkedDiverId defaults to null and is carried by copyWith', () {
    expect(base.linkedDiverId, isNull);
    final linked = base.copyWith(linkedDiverId: 'diver-chris');
    expect(linked.linkedDiverId, 'diver-chris');
    expect(linked.copyWith(name: 'C').linkedDiverId, 'diver-chris');
  });

  test('clearLinkedDiver removes the link and keeps everything else', () {
    final linked = base.copyWith(linkedDiverId: 'diver-chris', notes: 'n');
    final cleared = linked.clearLinkedDiver();
    expect(cleared.linkedDiverId, isNull);
    expect(cleared.notes, 'n');
    expect(cleared.id, 'b1');
  });

  test('linkedDiverId takes part in equality', () {
    expect(base.copyWith(linkedDiverId: 'x'), isNot(equals(base)));
  });
}
