import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Dismiss all lives in `AppScaffoldMessenger` (issue #3834), so a message
/// only gets it from a messenger of that type. `MaterialApp` makes a plain
/// one of its own, and a key handed to `MaterialApp.scaffoldMessengerKey`
/// would land on that instead of the app's.
void main() {
  test('the app root uses AppScaffoldMessenger', () {
    final app = File(p.join('lib', 'app.dart')).readAsStringSync();

    expect(
      app,
      contains('AppScaffoldMessenger(key: _scaffoldMessengerKey'),
      reason: 'Snack bars raised through the key would miss Dismiss all.',
    );
    expect(app, isNot(contains('scaffoldMessengerKey:')));
  });

  test('nothing in lib builds a plain ScaffoldMessenger', () {
    final plain = RegExp(r'(?<![A-Za-z_])ScaffoldMessenger\(');
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .where((f) => plain.hasMatch(f.readAsStringSync()))
        .map((f) => p.relative(f.path))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppScaffoldMessenger, which offers Dismiss all.',
    );
  });
}
