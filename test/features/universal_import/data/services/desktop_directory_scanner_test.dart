import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/desktop_directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('desktop_scanner_');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    'enumerates files recursively with basename + desktop-path handle',
    () async {
      File('${tmp.path}/a.jpg').writeAsBytesSync([1]);
      final sub = Directory('${tmp.path}/nested')..createSync();
      File('${sub.path}/b.png').writeAsBytesSync([2]);

      final scanner = DesktopDirectoryScanner();
      final files = await scanner.scan(GrantedFolder(path: tmp.path)).toList();

      expect(files.length, 2);
      final byName = {for (final f in files) f.basename: f};
      expect(byName.keys.toSet(), {'a.jpg', 'b.png'});
      expect(byName['a.jpg']!.handle.localPath, '${tmp.path}/a.jpg');
      expect(byName['a.jpg']!.handle.bookmarkRef, isNull);
      expect(byName['b.png']!.handle.localPath, '${sub.path}/b.png');
    },
  );

  test('yields nothing for a missing folder (no throw)', () async {
    final scanner = DesktopDirectoryScanner();
    final files = await scanner
        .scan(const GrantedFolder(path: '/does/not/exist/xyz'))
        .toList();
    expect(files, isEmpty);
  });

  test('skips directories, yields only files', () async {
    Directory('${tmp.path}/onlydir').createSync();
    File('${tmp.path}/c.jpg').writeAsBytesSync([3]);
    final scanner = DesktopDirectoryScanner();
    final files = await scanner.scan(GrantedFolder(path: tmp.path)).toList();
    expect(files.map((f) => f.basename), ['c.jpg']);
  });
}
