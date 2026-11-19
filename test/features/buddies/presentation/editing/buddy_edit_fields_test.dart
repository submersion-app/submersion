import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The buddy page's fields keep the edit form's rules (issue #4527, phase
/// 3).
void main() {
  Buddy alex() => Buddy(
    id: 'b1',
    name: 'Alex',
    email: 'alex@example.com',
    photo: Uint8List.fromList([1]),
    photoPath: '/a.jpg',
    linkedDiverId: 'p1',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  test('a bad email is invalid', () {
    expect(buddyEmailValid('not an email'), isFalse);
    expect(buddyEmailValid('alex@example.com'), isTrue);
    expect(buddyEmailValid(''), isTrue);
    expect(buddyEmailValid(null), isTrue);
  });

  test('a blank name is invalid', () {
    expect(buddyNameValid('  '), isFalse);
    expect(buddyNameValid('Alex'), isTrue);
  });

  test('clearing the photo clears its path', () {
    final session = EditSession(alex())..set(buddyPhotoField, null);
    expect(session.working.photo, isNull);
    expect(session.working.photoPath, isNull);
    expect(session.changedCardIds, {'header'});
  });

  test('a new photo keeps the path as stored', () {
    final session = EditSession(alex())
      ..set(buddyPhotoField, Uint8List.fromList([2]));
    expect(session.working.photo, [2]);
    expect(session.working.photoPath, '/a.jpg');
  });

  test('clearing the linked profile stores null', () {
    final session = EditSession(alex())..set(buddyLinkedDiverField, null);
    expect(session.working.linkedDiverId, isNull);
    expect(session.changedCardIds, {'contact'});
  });

  test('blank contact text stores none', () {
    final session = EditSession(alex())..set(buddyEmailField, ' ');
    expect(session.working.email, isNull);
  });

  test('each field marks its own card', () {
    final session = EditSession(alex())
      ..set(buddyFavoriteField, true)
      ..set(buddyExcludedFromRankingsField, true)
      ..set(buddyNotesField, 'Hi');
    expect(session.changedCardIds, {'header', 'statistics', 'notes'});
  });
}
