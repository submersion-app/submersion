import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'plist_test_helpers.dart';

/// Guards the platform wiring that offers Submersion in the Share sheet for a
/// Suunto app JSON export (issue #3670). File assertions, because the sheet
/// is built by the operating system from these declarations: a dropped entry
/// is invisible to every test that runs Dart code.

const _androidNs = 'http://schemas.android.com/apk/res/android';

/// The mime types an Android intent filter for [action] accepts, keyed by
/// scheme ('' for a data element that names none).
Map<String, Set<String>> androidMimeTypes(String action) {
  final manifest = XmlDocument.parse(
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  );
  final byScheme = <String, Set<String>>{};
  for (final filter in manifest.findAllElements('intent-filter')) {
    final actions = filter
        .findElements('action')
        .map((e) => e.getAttribute('name', namespaceUri: _androidNs));
    if (!actions.contains(action)) continue;
    for (final data in filter.findElements('data')) {
      final mime = data.getAttribute('mimeType', namespaceUri: _androidNs);
      if (mime == null) continue;
      final scheme =
          data.getAttribute('scheme', namespaceUri: _androidNs) ?? '';
      byScheme.putIfAbsent(scheme, () => <String>{}).add(mime);
    }
  }
  return byScheme;
}

/// The CFBundleDocumentTypes entry of [path] that lists [contentType].
XmlElement? documentTypeFor(String path, String contentType) {
  final types = plistValue(path, 'CFBundleDocumentTypes');
  if (types == null) return null;
  for (final type in types.findElements('dict')) {
    final items = dictValue(type, 'LSItemContentTypes');
    final listed = items?.findElements('string').map((e) => e.innerText.trim());
    if (listed?.contains(contentType) ?? false) return type;
  }
  return null;
}

void main() {
  group('Android', () {
    test('a single shared JSON file is accepted', () {
      expect(
        androidMimeTypes('android.intent.action.SEND')[''],
        contains('application/json'),
      );
    });

    test('several shared JSON files are accepted together', () {
      expect(
        androidMimeTypes('android.intent.action.SEND_MULTIPLE')[''],
        contains('application/json'),
      );
    });

    test('Open with offers Submersion for a JSON file', () {
      final view = androidMimeTypes('android.intent.action.VIEW');
      expect(view['content'], contains('application/json'));
      expect(view['file'], contains('application/json'));
    });
  });

  group('iOS', () {
    const info = 'ios/Runner/Info.plist';

    test('declares JSON as a document it can open', () {
      final type = documentTypeFor(info, 'public.json');
      expect(type, isNotNull);
      expect(dictValue(type!, 'CFBundleTypeRole')?.innerText, 'Viewer');
      // Alternate, like the other dive log types: Submersion is offered for
      // JSON, never made the default app for every JSON file.
      expect(dictValue(type, 'LSHandlerRank')?.innerText, 'Alternate');
    });
  });
}
