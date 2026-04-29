import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';

import 'local_bookmark_storage_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  late MockFlutterSecureStorage mockStorage;
  late LocalBookmarkStorage subject;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    subject = LocalBookmarkStorage(storage: mockStorage);
  });

  test('write stores blob keyed by bookmark:<ref>', () async {
    when(
      mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
    ).thenAnswer((_) async {});
    final blob = Uint8List.fromList([1, 2, 3]);
    await subject.write('ref-1', blob);
    verify(
      mockStorage.write(
        key: 'bookmark:ref-1',
        value: 'AQID', // base64 of [1,2,3]
      ),
    ).called(1);
  });

  test('read returns blob bytes', () async {
    when(
      mockStorage.read(key: 'bookmark:ref-1'),
    ).thenAnswer((_) async => 'AQID'); // base64 of [1,2,3]
    final blob = await subject.read('ref-1');
    expect(blob, [1, 2, 3]);
  });

  test('read returns null when key absent', () async {
    when(
      mockStorage.read(key: 'bookmark:absent'),
    ).thenAnswer((_) async => null);
    expect(await subject.read('absent'), isNull);
  });

  test('delete removes stored blob', () async {
    when(mockStorage.delete(key: anyNamed('key'))).thenAnswer((_) async {});
    await subject.delete('ref-1');
    verify(mockStorage.delete(key: 'bookmark:ref-1')).called(1);
  });
}
