@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

// Real MacDive export (not committed). Skips cleanly when absent on CI.
const _path =
    '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite';

void main() {
  test('real MacDive SQLite emits 261 imageRefs', () async {
    final file = File(_path);
    if (!file.existsSync()) {
      markTestSkipped('No real MacDive sample at $_path');
      return;
    }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final payload = await const MacDiveSqliteParser().parse(bytes);
    expect(payload.imageRefs.length, 261);
  });
}
