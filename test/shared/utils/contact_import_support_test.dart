import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
