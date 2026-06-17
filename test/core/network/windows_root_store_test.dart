import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/windows_root_store.dart';

void main() {
  test(
    'readWindowsRootCertificates returns an empty list on non-Windows hosts',
    () {
      // The crypt32 read is Windows-only; everywhere else the documented
      // contract is an empty list so callers fall back cleanly.
      expect(readWindowsRootCertificates(), isEmpty);
    },
    skip: Platform.isWindows
        ? 'reads the real Windows store on Windows'
        : false,
  );
}
