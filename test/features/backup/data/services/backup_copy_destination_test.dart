import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/services/backup_copy_destination.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('copy_destination_');
  });

  tearDown(() => dir.delete(recursive: true));

  test('uniqueDestinationPath returns the plain name when free', () async {
    expect(
      await uniqueDestinationPath(dir.path, 'a.db'),
      p.join(dir.path, 'a.db'),
    );
  });

  test('uniqueDestinationPath skips existing names', () async {
    await File(p.join(dir.path, 'a.db')).writeAsString('x');
    await File(p.join(dir.path, 'a (1).db')).writeAsString('x');

    expect(
      await uniqueDestinationPath(dir.path, 'a.db'),
      p.join(dir.path, 'a (2).db'),
    );
  });
}
