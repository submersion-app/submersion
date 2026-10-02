import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_timeouts.dart';

void main() {
  test('dart_test.yaml gives plain tests the same limit', () {
    final config = File('dart_test.yaml').readAsStringSync();
    final match = RegExp(
      r'^timeout:\s*(\d+)m\s*$',
      multiLine: true,
    ).firstMatch(config);

    expect(match, isNotNull, reason: 'dart_test.yaml has no "timeout: <N>m"');
    expect(int.parse(match!.group(1)!), testTimeLimit.inMinutes);
  });

  test('widget tests get the same limit from the binding', () {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();

    expect(binding.defaultTestTimeout.duration, testTimeLimit);
  });
}
