import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() {
  // Android 14 and later let the user grant access to selected photos only.
  // An app that does not declare READ_MEDIA_VISUAL_USER_SELECTED runs that
  // choice in compatibility mode: READ_MEDIA_IMAGES and READ_MEDIA_VIDEO are
  // granted for the session and revoked when the app leaves the foreground,
  // and photo_manager reports the grant as full access, never as limited. A
  // later session that selects different photos then hides the earlier
  // links while permission still reads as full access, so the gallery
  // search misses them and they are flagged missing on every device (#3103,
  // #1625).
  //
  // Asserted in both directions. Dropping the library permissions (for the
  // system photo picker) without dropping this one leaves a declaration
  // nothing uses.
  test('READ_MEDIA_VISUAL_USER_SELECTED is declared with the library '
      'permissions', () {
    const android = 'http://schemas.android.com/apk/res/android';
    final manifest = File(
      p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync();
    final declared = XmlDocument.parse(manifest).rootElement
        .findElements('uses-permission')
        .map((e) => e.getAttribute('name', namespaceUri: android))
        .toSet();
    bool declares(String permission) =>
        declared.contains('android.permission.$permission');

    final readsLibrary =
        declares('READ_MEDIA_IMAGES') || declares('READ_MEDIA_VIDEO');

    expect(
      declares('READ_MEDIA_VISUAL_USER_SELECTED'),
      readsLibrary,
      reason: readsLibrary
          ? 'android/app/src/main/AndroidManifest.xml declares '
                'READ_MEDIA_IMAGES or READ_MEDIA_VIDEO, so it must also '
                'declare READ_MEDIA_VISUAL_USER_SELECTED. Without it a '
                '"Select photos" grant lasts one session and is reported as '
                'full access, and earlier links read as missing (#3103).'
          : 'android/app/src/main/AndroidManifest.xml no longer reads the '
                'photo library, so READ_MEDIA_VISUAL_USER_SELECTED should '
                'come out too rather than stay as an unused declaration.',
    );
  });
}
