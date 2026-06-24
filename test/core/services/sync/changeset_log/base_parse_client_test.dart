import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/base_parse_client.dart';

File _writeBase(Directory dir, Map<String, dynamic> doc) {
  final f = File(p.join(dir.path, 'base.json'));
  f.writeAsStringSync(jsonEncode(doc));
  return f;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('s3base'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('spawns and disposes without hanging', () async {
    final f = _writeBase(tmp, {
      'exportedAt': 1,
      'deletions': <String, dynamic>{},
      'data': <String, dynamic>{},
    });
    final client = await BaseParseClient.spawn(f.path);
    await client.dispose();
  });
}
