import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/desktop_target_platform.dart';

void main() {
  test('macOS, Windows and Linux are desktop', () {
    expect(isDesktopTargetPlatform(TargetPlatform.macOS), isTrue);
    expect(isDesktopTargetPlatform(TargetPlatform.windows), isTrue);
    expect(isDesktopTargetPlatform(TargetPlatform.linux), isTrue);
  });

  test('Android, iOS and Fuchsia are not desktop', () {
    expect(isDesktopTargetPlatform(TargetPlatform.android), isFalse);
    expect(isDesktopTargetPlatform(TargetPlatform.iOS), isFalse);
    expect(isDesktopTargetPlatform(TargetPlatform.fuchsia), isFalse);
  });
}
