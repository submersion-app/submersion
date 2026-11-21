import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A tap off a focused text field puts the keyboard away on a touch screen
/// only through the app's own actions (#4813); without them a phone's
/// keyboard stays up over the bottom bar with nothing on the page to close it.
void main() {
  test('the app root uses appActions', () {
    final app = File(p.join('lib', 'app.dart')).readAsStringSync();

    expect(
      app,
      contains('actions: appActions()'),
      reason: 'A tap off a text field would leave a phone keyboard up.',
    );
  });
}
