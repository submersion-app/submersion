import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/utils/app_version.dart';

PackageInfo _info({required String version, required String buildNumber}) =>
    PackageInfo(
      appName: 'Submersion',
      packageName: 'app.submersion',
      version: version,
      buildNumber: buildNumber,
    );

void main() {
  group('formatVersionWithBuild', () {
    test('appends the build number as a fourth segment', () {
      expect(formatVersionWithBuild('1.7.6', '123'), '1.7.6.123');
    });

    test('does not double a build number the version already carries', () {
      // Some platforms report a four-segment version. Without this guard a
      // release comparison would see "1.7.6.123.123" and never match its tag.
      expect(formatVersionWithBuild('1.7.6.123', '123'), '1.7.6.123');
    });

    test('leaves the version alone when there is no build number', () {
      expect(formatVersionWithBuild('1.7.6', ''), '1.7.6');
    });

    test('appends a build number that merely repeats a digit run', () {
      // "1.7.23" does not end with ".3" as a segment even though it ends with
      // the characters; endsWith('.3') is false here, so nothing is swallowed.
      expect(formatVersionWithBuild('1.7.23', '3'), '1.7.23.3');
    });
  });

  group('formatAppVersion', () {
    test('appends the build number to a three-segment marketing version', () {
      expect(
        formatAppVersion(_info(version: '1.7.6', buildNumber: '123')),
        '1.7.6.123',
      );
    });

    test('does not double a build number the platform already reported', () {
      // The case every caller has to survive: PackageInfo.version is not
      // guaranteed to be the three-segment marketing version. Open-coding
      // "$version.$buildNumber" here yields the five-segment "1.7.6.123.123",
      // which reaches the user in the restore confirmation dialog as the
      // version that produced a backup.
      expect(
        formatAppVersion(_info(version: '1.7.6.123', buildNumber: '123')),
        '1.7.6.123',
      );
    });

    test('leaves the version alone when the platform reports no build', () {
      expect(
        formatAppVersion(_info(version: '1.7.6', buildNumber: '')),
        '1.7.6',
      );
    });
  });
}
