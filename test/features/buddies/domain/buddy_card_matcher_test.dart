import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_matcher.dart';

Buddy _buddy(
  String id,
  String name, {
  String? cardId,
  String? phone,
  String? email,
}) => Buddy(
  id: id,
  name: name,
  cardId: cardId,
  phone: phone,
  email: email,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _card = BuddyCard(
  id: 'diver-sam',
  name: 'Sam Rivera',
  phone: '+1 (555) 013-4000',
  email: 'Sam@Example.com',
);

void main() {
  test('recognises by cardId even when the name changed', () {
    final match = matchBuddyCard(_card, [
      _buddy('b1', 'Samuel R', cardId: 'diver-sam'),
    ]);
    expect(match, isA<CardRecognised>());
    expect((match as CardRecognised).buddy.id, 'b1');
  });

  test('possible match by name ignoring case and spaces', () {
    final match = matchBuddyCard(_card, [_buddy('b1', '  sam rivera ')]);
    expect((match as CardPossibleMatch).buddy.id, 'b1');
  });

  test('possible match by phone ignoring formatting', () {
    final match = matchBuddyCard(_card, [
      _buddy('b1', 'S', phone: '15550134000'),
    ]);
    expect((match as CardPossibleMatch).buddy.id, 'b1');
  });

  test('possible match by email ignoring case', () {
    final match = matchBuddyCard(_card, [
      _buddy('b1', 'S', email: 'sam@example.com'),
    ]);
    expect((match as CardPossibleMatch).buddy.id, 'b1');
  });

  test('a cardId match wins over a name match on another buddy', () {
    final match = matchBuddyCard(_card, [
      _buddy('b1', 'Sam Rivera'),
      _buddy('b2', 'Someone', cardId: 'diver-sam'),
    ]);
    expect((match as CardRecognised).buddy.id, 'b2');
  });

  test('a buddy carded by someone else is not a possible match', () {
    final match = matchBuddyCard(_card, [
      _buddy('b1', 'Sam Rivera', cardId: 'diver-other-sam'),
    ]);
    expect(match, isA<CardNew>());
  });

  test('short phone numbers do not match', () {
    final match = matchBuddyCard(
      const BuddyCard(id: 'x', name: 'A', phone: '123'),
      [_buddy('b1', 'B', phone: '123')],
    );
    expect(match, isA<CardNew>());
  });

  test('no match is new', () {
    expect(matchBuddyCard(_card, [_buddy('b1', 'Alex')]), isA<CardNew>());
  });
}
