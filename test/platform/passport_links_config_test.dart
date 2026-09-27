import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Guards the platform wiring for cylinder passport links and camera scanning
/// (issue #2335). File assertions, because CI never runs a signed build that
/// could exercise them: a missing key is invisible until a diver taps a label.

/// The value element that follows [key] in a plist's top-level dict.
XmlElement? plistValue(String path, String key) {
  final dict = XmlDocument.parse(
    File(path).readAsStringSync(),
  ).rootElement.getElement('dict')!;
  final children = dict.childElements.toList();
  for (var i = 0; i + 1 < children.length; i++) {
    if (children[i].name.local == 'key' &&
        children[i].innerText.trim() == key) {
      return children[i + 1];
    }
  }
  return null;
}

/// Every URL scheme a plist's CFBundleURLTypes registers.
Set<String> urlSchemes(String path) {
  final types = plistValue(path, 'CFBundleURLTypes');
  if (types == null) return const {};
  final schemes = <String>{};
  for (final dict in types.findElements('dict')) {
    final children = dict.childElements.toList();
    for (var i = 0; i + 1 < children.length; i++) {
      if (children[i].innerText.trim() == 'CFBundleURLSchemes') {
        schemes.addAll(
          children[i + 1].findElements('string').map((e) => e.innerText.trim()),
        );
      }
    }
  }
  return schemes;
}

void main() {
  group('iOS', () {
    const info = 'ios/Runner/Info.plist';
    const entitlements = 'ios/Runner/Runner.entitlements';

    test('Flutter deep linking is off, app_links owns links', () {
      expect(
        plistValue(info, 'FlutterDeepLinkingEnabled')?.name.local,
        'false',
      );
    });

    test('registers the submersion scheme', () {
      expect(urlSchemes(info), contains('submersion'));
    });

    test('the camera string mentions scanning cylinder labels', () {
      expect(
        plistValue(info, 'NSCameraUsageDescription')?.innerText,
        contains('cylinder'),
      );
    });

    test('claims submersion.app for universal links', () {
      final domains = plistValue(
        entitlements,
        'com.apple.developer.associated-domains',
      );
      expect(
        domains?.findElements('string').map((e) => e.innerText.trim()),
        contains('applinks:submersion.app'),
      );
    });
  });

  group('macOS', () {
    const info = 'macos/Runner/Info.plist';

    test('registers the submersion scheme', () {
      expect(urlSchemes(info), contains('submersion'));
    });

    test('explains camera use', () {
      expect(
        plistValue(info, 'NSCameraUsageDescription')?.innerText,
        contains('cylinder'),
      );
    });

    for (final file in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
      // The Developer ID DMG: unsandboxed, but signed with the hardened
      // runtime, which gates the camera on the same entitlement.
      'macos/Runner/ReleaseNoSandbox.entitlements',
    ]) {
      test('$file allows the camera', () {
        expect(
          plistValue(file, 'com.apple.security.device.camera')?.name.local,
          'true',
        );
      });
    }
  });

  group('Android', () {
    late XmlElement activity;
    late XmlElement manifest;
    const android = 'http://schemas.android.com/apk/res/android';

    setUpAll(() {
      manifest = XmlDocument.parse(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      ).rootElement;
      activity = manifest
          .findAllElements('activity')
          .firstWhere(
            (a) =>
                a.getAttribute('name', namespaceUri: android) ==
                '.MainActivity',
          );
    });

    Iterable<XmlElement> viewFiltersWithScheme(String scheme) => activity
        .findElements('intent-filter')
        .where(
          (f) => f
              .findElements('data')
              .any(
                (d) =>
                    d.getAttribute('scheme', namespaceUri: android) == scheme,
              ),
        );

    test('Flutter deep linking is off, app_links owns links', () {
      final meta = activity
          .findElements('meta-data')
          .firstWhere(
            (m) =>
                m.getAttribute('name', namespaceUri: android) ==
                'flutter_deeplinking_enabled',
          );
      expect(meta.getAttribute('value', namespaceUri: android), 'false');
    });

    test('verifies https://submersion.app/c as an app link', () {
      final filter = viewFiltersWithScheme('https').single;
      expect(filter.getAttribute('autoVerify', namespaceUri: android), 'true');
      final data = filter.findElements('data').single;
      expect(
        data.getAttribute('host', namespaceUri: android),
        'submersion.app',
      );
      expect(data.getAttribute('path', namespaceUri: android), '/c');
    });

    test('opens submersion://c links', () {
      final data = viewFiltersWithScheme(
        'submersion',
      ).single.findElements('data').single;
      expect(data.getAttribute('host', namespaceUri: android), 'c');
    });

    test('asks for the camera without requiring one', () {
      expect(
        manifest
            .findElements('uses-permission')
            .map((e) => e.getAttribute('name', namespaceUri: android)),
        contains('android.permission.CAMERA'),
      );
      // The CAMERA permission implies both features as required, which
      // would hide the app on Play from devices without them.
      for (final name in [
        'android.hardware.camera',
        'android.hardware.camera.autofocus',
      ]) {
        final feature = manifest
            .findElements('uses-feature')
            .firstWhere(
              (e) => e.getAttribute('name', namespaceUri: android) == name,
            );
        expect(
          feature.getAttribute('required', namespaceUri: android),
          'false',
          reason: name,
        );
      }
    });
  });
}
