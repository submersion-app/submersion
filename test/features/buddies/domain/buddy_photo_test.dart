import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

Buddy _buddy({Uint8List? photo}) => Buddy(
  id: 'b1',
  name: 'Jane Doe',
  photo: photo,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test('photo defaults to null', () {
    expect(_buddy().photo, isNull);
  });

  test('copyWith carries the photo through', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(_buddy().copyWith(photo: bytes).photo, bytes);
  });

  test('copyWith without a photo argument keeps the existing one', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(_buddy(photo: bytes).copyWith(name: 'Other').photo, bytes);
  });

  test('clearPhoto removes the photo and keeps every other field', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final withPhoto = _buddy(photo: bytes);
    final cleared = withPhoto.clearPhoto();

    expect(cleared.photo, isNull);
    expect(cleared.id, withPhoto.id);
    expect(cleared.name, withPhoto.name);
    expect(cleared.createdAt, withPhoto.createdAt);
    expect(cleared.updatedAt, withPhoto.updatedAt);
  });

  test('copyWith cannot clear the photo, which is why clearPhoto exists', () {
    // Documents the plain `??` idiom deliberately: passing null keeps the
    // current value. A future caller reaching for copyWith(photo: null) to
    // remove a photo would silently do nothing, so clearPhoto is the only
    // supported removal path.
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(_buddy(photo: bytes).copyWith(photo: null).photo, bytes);
  });

  test('photo participates in equality', () {
    final shared = Uint8List.fromList([1]);
    expect(_buddy(photo: shared), equals(_buddy(photo: shared)));
    expect(_buddy(photo: shared), isNot(equals(_buddy())));
  });
}
