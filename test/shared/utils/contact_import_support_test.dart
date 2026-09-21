import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/shared/utils/contact_import_support.dart';

/// Runs [body] with the target platform pinned.
///
/// The override is reset inside the test body, not in addTearDown: the test
/// binding asserts every foundation debug var is unset when the body returns,
/// and that check runs before tear-downs.
void _withPlatform(TargetPlatform platform, void Function() body) {
  debugDefaultTargetPlatformOverride = platform;
  try {
    body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  // flutter_contacts ships iOS and Android implementations only. This guard
  // was lifted out of buddy_list_content's private getter so the import flow
  // and the profile photo source sheet cannot drift apart on which platforms
  // offer contacts.
  //
  // Note the platform is pinned explicitly rather than read from the host:
  // the implementation uses defaultTargetPlatform, which flutter_test reports
  // as android regardless of the machine running the suite.
  testWidgets('iOS supports contacts', (tester) async {
    _withPlatform(TargetPlatform.iOS, () {
      expect(isContactImportSupported, isTrue);
    });
  });

  testWidgets('Android supports contacts', (tester) async {
    _withPlatform(TargetPlatform.android, () {
      expect(isContactImportSupported, isTrue);
    });
  });

  testWidgets('macOS does not support contacts', (tester) async {
    _withPlatform(TargetPlatform.macOS, () {
      expect(isContactImportSupported, isFalse);
    });
  });

  testWidgets('Linux does not support contacts', (tester) async {
    _withPlatform(TargetPlatform.linux, () {
      expect(isContactImportSupported, isFalse);
    });
  });

  testWidgets('Windows does not support contacts', (tester) async {
    _withPlatform(TargetPlatform.windows, () {
      expect(isContactImportSupported, isFalse);
    });
  });

  // The gate above and the Android manifest are two artifacts in two
  // languages with nothing linking them, which is how they drifted: the gate
  // offered contacts on Android for the whole life of the feature while the
  // manifest declared no CONTACTS permission at all. Android denies a runtime
  // request for an undeclared permission immediately, without a dialog, and
  // the permission never appears in system settings, so the user could not
  // grant it (#2191).
  //
  // Asserted in both directions. Dropping Android from the gate without
  // dropping the permission leaves a sensitive declaration nothing uses, and
  // Play reviews every one of those.
  test('offering contacts on Android implies READ_CONTACTS is declared', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final bool offeredOnAndroid;
    try {
      offeredOnAndroid = isContactImportSupported;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    final manifest = File(
      p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync();
    // Comments in this manifest explain the permissions they sit above, so
    // strip them first: a commented-out declaration must not read as one.
    final live = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final declared = RegExp(
      r'<uses-permission\s+android:name="android\.permission\.READ_CONTACTS"',
    ).hasMatch(live);

    expect(
      declared,
      offeredOnAndroid,
      reason: offeredOnAndroid
          ? 'isContactImportSupported offers contacts on Android, so '
                'android/app/src/main/AndroidManifest.xml must declare '
                'READ_CONTACTS. Without it the permission request is denied '
                'silently and the feature cannot run.'
          : 'isContactImportSupported no longer offers contacts on Android, '
                'so READ_CONTACTS should come out of '
                'android/app/src/main/AndroidManifest.xml rather than stay as '
                'an unused sensitive permission.',
    );
  });
}
