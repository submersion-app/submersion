import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Windows installer's licence page (`LicenseFile` in
/// windows/installer/submersion.iss) is where people agree to Microsoft's
/// terms for the Windows ML files the build ships, as those terms require
/// (accepted by the maintainer on 2026-11-20). The page shows one file, so
/// it holds the GPL and then Microsoft's terms; this keeps it in step with
/// LICENSE and assets/licenses/windows_ml_license.txt. When either changes,
/// rebuild the file as: the header below, LICENSE, a blank line, the terms,
/// saved as UTF-8 with a byte order mark and CRLF line endings.
void main() {
  String normalised(String text) =>
      text.replaceAll('\r\n', '\n').replaceFirst('﻿', '').trim();

  final installer = File(p.join('windows', 'installer', 'license.txt'));

  test('the installer shows the GPL, then Windows ML\'s terms', () {
    final shown = normalised(installer.readAsStringSync());
    final gpl = normalised(File('LICENSE').readAsStringSync());
    final terms = normalised(
      File(
        p.join('assets', 'licenses', 'windows_ml_license.txt'),
      ).readAsStringSync(),
    );

    expect(shown, startsWith('Submersion is free software'));
    expect(shown, contains('By accepting, you agree'));
    final gplAt = shown.indexOf(gpl);
    final termsAt = shown.indexOf(terms);
    expect(gplAt, greaterThan(0), reason: 'LICENSE, unchanged');
    expect(termsAt, greaterThan(gplAt), reason: 'the terms, after the GPL');
  });

  test('it is UTF-8 with a byte order mark, so Inno Setup shows Microsoft\'s '
      'quotes as written', () {
    expect(installer.readAsBytesSync().take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('the installer script uses it', () {
    expect(
      File(p.join('windows', 'installer', 'submersion.iss')).readAsStringSync(),
      contains('LicenseFile=license.txt'),
    );
  });
}
