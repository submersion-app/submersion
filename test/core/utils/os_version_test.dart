import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/os_version.dart';

void main() {
  group('normalizeOsVersion on Windows', () {
    test('names Windows 11 when the build says so', () {
      // Issue #1982: a Windows 11 machine reported itself as "Windows 10
      // Home". Windows keeps the old product name in the registry, so the
      // build number is the only field that tells the two apart.
      expect(
        normalizeOsVersion(
          platform: 'windows',
          version: '"Windows 10 Home" 10.0 (Build 26200)',
        ),
        '"Windows 11 Home" 10.0 (Build 26200)',
      );
    });

    test('corrects every edition, not just Home', () {
      expect(
        normalizeOsVersion(
          platform: 'windows',
          version: '"Windows 10 Pro" 10.0 (Build 22631)',
        ),
        '"Windows 11 Pro" 10.0 (Build 22631)',
      );
      expect(
        normalizeOsVersion(
          platform: 'windows',
          version: '"Windows 10 Enterprise" 10.0 (Build 22000)',
        ),
        '"Windows 11 Enterprise" 10.0 (Build 22000)',
      );
    });

    test('corrects a product name with no edition suffix', () {
      expect(
        normalizeOsVersion(
          platform: 'windows',
          version: '"Windows 10" 10.0 (Build 26100)',
        ),
        '"Windows 11" 10.0 (Build 26100)',
      );
    });

    test('leaves a genuine Windows 10 build alone', () {
      // Windows 10 shipped up to build 19045, and 22000 opens the Windows 11
      // line, so every build below 22000 is left as the Windows 10 it says.
      const raw = '"Windows 10 Pro" 10.0 (Build 19045)';

      expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
    });

    test('leaves the build just below the threshold alone', () {
      // Pins the off-by-one: 21999 is the highest build the helper still
      // treats as Windows 10, paired with the 22000 case above.
      const raw = '"Windows 10 Enterprise" 10.0 (Build 21999)';

      expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
    });

    test('is idempotent when Windows already reports the right name', () {
      // Never rewrite a name that is already correct, and never turn a
      // corrected string into "Windows 12" on a second pass.
      const raw = '"Windows 11 Pro" 10.0 (Build 26100)';

      expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
    });

    test('leaves Windows Server alone', () {
      // Server 2025 is build 26100, above the client threshold, but its
      // product name never says "Windows 10" so nothing should change.
      const raw = '"Windows Server 2025 Datacenter" 10.0 (Build 26100)';

      expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
    });

    test('leaves a string it cannot parse alone', () {
      // Degrading to the raw string keeps a triager reading something real
      // rather than nothing.
      for (final raw in const [
        '',
        'unknown',
        '"Windows 10 Home"',
        '"Windows 10 Home" 10.0 (Build )',
        '"Windows 10 Home" 10.0 (Build abc)',
      ]) {
        expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
      }
    });

    test('leaves a build number too large to parse alone', () {
      const raw = '"Windows 10 Home" 10.0 (Build 99999999999999999999999)';

      expect(normalizeOsVersion(platform: 'windows', version: raw), raw);
    });

    test('rewrites only the product name, never a matching build number', () {
      // The digits 10 appear in the version field too; only the quoted
      // product name may be touched.
      expect(
        normalizeOsVersion(
          platform: 'windows',
          version: '"Windows 10 Home" 10.0 (Build 26200)',
        ),
        contains('10.0 (Build 26200)'),
      );
    });
  });

  group('normalizeOsVersion off Windows', () {
    test('passes other platforms through untouched', () {
      const mac = 'Version 26.6 (Build 23G93)';
      const linux = 'Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP';

      expect(normalizeOsVersion(platform: 'macos', version: mac), mac);
      expect(normalizeOsVersion(platform: 'linux', version: linux), linux);
      expect(normalizeOsVersion(platform: 'android', version: '13'), '13');
    });

    test('does not correct a Windows string reported by another platform', () {
      // The platform field is the gate, so a lookalike string elsewhere is
      // left exactly as the host reported it.
      const raw = '"Windows 10 Home" 10.0 (Build 26200)';

      expect(normalizeOsVersion(platform: 'linux', version: raw), raw);
    });
  });
}
