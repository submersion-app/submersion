import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/windows_app_data_migration.dart';

/// `path_provider_windows` builds the application-support path from the
/// CompanyName/ProductName baked into the executable's VERSIONINFO resource,
/// which Dart cannot read at runtime on any other platform. The migration in
/// windows_app_data_migration.dart therefore hardcodes those names, and this
/// test is the only thing keeping the two in sync. It runs on the POSIX CI
/// matrix, which is where a drifting Runner.rc would otherwise go unnoticed.
void main() {
  String rcValue(String contents, String key) {
    final match = RegExp('VALUE\\s+"$key",\\s+"([^"]*)"').firstMatch(contents);
    expect(match, isNotNull, reason: 'no VALUE "$key" in Runner.rc');
    return match!.group(1)!;
  }

  group('windows/runner/Runner.rc', () {
    late String contents;

    setUp(() {
      contents = File('windows/runner/Runner.rc').readAsStringSync();
    });

    test('CompanyName matches windowsCompanyName', () {
      expect(rcValue(contents, 'CompanyName'), windowsCompanyName);
    });

    test('ProductName matches windowsProductName', () {
      expect(rcValue(contents, 'ProductName'), windowsProductName);
    });

    test('CompanyName has moved off the legacy name', () {
      expect(rcValue(contents, 'CompanyName'), isNot(legacyWindowsCompanyName));
    });
  });
}
