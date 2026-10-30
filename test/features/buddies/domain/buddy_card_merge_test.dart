import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_merge.dart';

void main() {
  final existing = Buddy(
    id: 'b1',
    name: 'Sam Rivera',
    phone: '+1 555 0134',
    email: 'old@example.com',
    cardDiveCount: 100,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('changes list only fields the card carries and that differ', () {
    const card = BuddyCard(
      id: 'diver-sam',
      name: 'Sam Rivera',
      phone: '+1 555 0134',
      email: 'sam@example.com',
      dives: 118,
    );
    final changes = buddyCardChanges(existing, card);
    expect(changes.map((c) => c.field), [
      BuddyCardChangeField.email,
      BuddyCardChangeField.dives,
    ]);
    expect(changes.first.from, 'old@example.com');
    expect(changes.first.to, 'sam@example.com');
    expect(changes.last.from, '100');
    expect(changes.last.to, '118');
  });

  test('a field absent from the card is not a change', () {
    const card = BuddyCard(id: 'diver-sam', name: 'Sam Rivera');
    expect(buddyCardChanges(existing, card), isEmpty);
  });

  test('for a new buddy every carried field is listed with no from', () {
    const card = BuddyCard(
      id: 'diver-sam',
      name: 'Sam Rivera',
      phone: '+1 555 0134',
      certs: [BuddyCardCert(agency: 'PADI', name: 'Rescue Diver')],
    );
    final changes = buddyCardChanges(null, card);
    expect(changes.map((c) => c.field), [
      BuddyCardChangeField.name,
      BuddyCardChangeField.phone,
      BuddyCardChangeField.certifications,
    ]);
    expect(changes.every((c) => c.from == null), isTrue);
    expect(changes.last.to, 'PADI Rescue Diver');
  });

  test('a card photo is listed as a change', () {
    final card = BuddyCard(
      id: 'diver-sam',
      name: 'Sam Rivera',
      photo: Uint8List.fromList([1, 2, 3]),
    );
    expect(
      buddyCardChanges(existing, card).map((c) => c.field),
      contains(BuddyCardChangeField.photo),
    );
  });

  group('merging buddies keeps what their cards said', () {
    Buddy buddy(
      String id, {
      String? cardId,
      DateTime? received,
      String? social,
    }) => Buddy(
      id: id,
      name: 'Sam',
      cardId: cardId,
      cardReceivedAt: received,
      cardDiveCount: cardId == null ? null : 100,
      socialHandle: social,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('the card source is the buddy whose card arrived last', () {
      final hand = buddy('a');
      final older = buddy('b', cardId: 'sam', received: DateTime(2026, 1));
      final newer = buddy('c', cardId: 'sam', received: DateTime(2026, 9));
      expect(mergedBuddyCardSource([hand, older, newer]), same(newer));
    });

    test('with no card among them there is no card source', () {
      expect(mergedBuddyCardSource([buddy('a'), buddy('b')]), isNull);
    });

    test('the social handle is the first one any of them has', () {
      expect(
        mergedSocialHandle([buddy('a'), buddy('b', social: '@sam')]),
        '@sam',
      );
      expect(mergedSocialHandle([buddy('a'), buddy('b')]), isNull);
    });
  });
}
