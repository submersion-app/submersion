import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/data/services/linux_install_method_reader.dart';
import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('install_method_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  LinuxInstallMethodReader readerIn(Directory dir) =>
      LinuxInstallMethodReader(executablePath: '${dir.path}/submersion');

  test('reads deb from the marker beside the executable', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('deb\n');
    expect(readerIn(tempDir).read(), LinuxInstallMethod.deb);
  });

  test('reads rpm from the marker', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('rpm\n');
    expect(readerIn(tempDir).read(), LinuxInstallMethod.rpm);
  });

  test('falls back to tarball when the marker is absent', () {
    expect(readerIn(tempDir).read(), LinuxInstallMethod.tarball);
  });

  test('falls back to tarball when the marker holds something unknown', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('snap\n');
    expect(readerIn(tempDir).read(), LinuxInstallMethod.tarball);
  });

  test('tolerates surrounding whitespace in the marker', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('  deb  \n\n');
    expect(readerIn(tempDir).read(), LinuxInstallMethod.deb);
  });

  test('a packaged install reports isPackaged, a tarball does not', () {
    expect(LinuxInstallMethod.deb.isPackaged, isTrue);
    expect(LinuxInstallMethod.rpm.isPackaged, isTrue);
    expect(LinuxInstallMethod.tarball.isPackaged, isFalse);
  });
}
