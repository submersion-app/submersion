@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/sbe_frames.dart';

/// The backup frame AAD compiled to JavaScript, where ByteData.setUint64
/// throws, so an encrypted backup could not be opened in the web app
/// (issue #4194). The bytes must match the ones the desktop app wrote.
void main() {
  final keyId = List<int>.generate(16, (i) => i);

  test('frame 5, not final', () {
    expect(SbeFrames.frameAad(keyId, 5, false), [
      ...keyId,
      ...[0, 0, 0, 0, 0, 0, 0, 5],
      0,
    ]);
  });

  test('a frame index past 32 bits, final', () {
    expect(SbeFrames.frameAad(keyId, 4294967297, true), [
      ...keyId,
      ...[0, 0, 0, 1, 0, 0, 0, 1],
      1,
    ]);
  });
}
