import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

void main() {
  group('resolveAssetSuffix', () {
    test('returns macOS DMG suffix', () {
      expect(resolveAssetSuffix(platform: 'macos', arch: 'x64'), 'macOS.dmg');
    });

    test('returns macOS DMG suffix regardless of arch', () {
      expect(resolveAssetSuffix(platform: 'macos', arch: 'arm64'), 'macOS.dmg');
    });

    test('returns Windows zip suffix', () {
      expect(
        resolveAssetSuffix(platform: 'windows', arch: 'x64'),
        'Windows.zip',
      );
    });

    test('returns Windows zip suffix regardless of arch', () {
      expect(
        resolveAssetSuffix(platform: 'windows', arch: 'arm64'),
        'Windows.zip',
      );
    });

    test('returns Linux x64 suffix for x64 architecture', () {
      expect(
        resolveAssetSuffix(platform: 'linux', arch: 'x64'),
        'Linux-x64.tar.gz',
      );
    });

    test('returns Linux ARM64 suffix for arm64 architecture', () {
      expect(
        resolveAssetSuffix(platform: 'linux', arch: 'arm64'),
        'Linux-ARM64.tar.gz',
      );
    });

    test('returns Android APK suffix', () {
      expect(
        resolveAssetSuffix(platform: 'android', arch: 'x64'),
        'Android.apk',
      );
    });

    test('returns empty string for unknown platform', () {
      expect(resolveAssetSuffix(platform: 'unknown', arch: 'x64'), '');
    });
  });
}
