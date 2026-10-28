import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_transfer.dart';

/// Transfer file names are built from values the peer sends (issue #3731).
void main() {
  late Directory dir;
  late NearbyTransferFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nearby_transfer');
    files = NearbyTransferFiles(dir, now: DateTime.now);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('an id or peer with a path in it never names a file', () {
    expect(NearbyTransferFiles.isSafeName('3f2a-9c_X'), isTrue);
    for (final bad in ['../x', 'a/b', r'a\b', '', '..', 'x' * 65]) {
      expect(NearbyTransferFiles.isSafeName(bad), isFalse, reason: bad);
      expect(() => files.incoming('peer', bad), throwsArgumentError);
      expect(() => files.incoming(bad, 'id'), throwsArgumentError);
    }
  });
}
