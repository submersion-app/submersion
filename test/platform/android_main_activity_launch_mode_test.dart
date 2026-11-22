import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Guards how Android starts the main activity for an intent sent from
/// another app while Submersion is running (issue #4843). A file assertion,
/// because the launch mode is read by the operating system: no Dart test can
/// see a second activity start.

const _androidNs = 'http://schemas.android.com/apk/res/android';

XmlElement _mainActivity() {
  final manifest = XmlDocument.parse(
    File(
      p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync(),
  );
  return manifest
      .findAllElements('activity')
      .singleWhere(
        (a) =>
            a.getAttribute('name', namespaceUri: _androidNs) == '.MainActivity',
      );
}

void main() {
  test('a share to the running app reaches the running instance', () {
    expect(
      _mainActivity().getAttribute('launchMode', namespaceUri: _androidNs),
      'singleTask',
      reason:
          'singleTop starts a second activity, and with it a second Flutter '
          'engine and sync, for a share sent from another app\'s task',
    );
  });

  test('the main activity keeps an empty task affinity', () {
    expect(
      _mainActivity().getAttribute('taskAffinity', namespaceUri: _androidNs),
      '',
      reason: 'flutter_web_auth_2 asks for it on every exported activity',
    );
  });
}
