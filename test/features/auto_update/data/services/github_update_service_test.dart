import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/features/auto_update/data/services/github_update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

void main() {
  const owner = 'test-owner';
  const repo = 'test-repo';
  const currentVersion = '1.0.0';

  Map<String, dynamic> makeRelease({
    required String tagName,
    String? body,
    List<Map<String, dynamic>>? assets,
  }) {
    return {
      'tag_name': tagName,
      'body': body ?? 'Release notes',
      'assets':
          assets ??
          [
            {
              'name': 'Submersion-$tagName-macOS.dmg',
              'browser_download_url':
                  'https://github.com/$owner/$repo/releases/download/$tagName/Submersion-$tagName-macOS.dmg',
            },
            {
              'name': 'Submersion-$tagName-Linux.tar.gz',
              'browser_download_url':
                  'https://github.com/$owner/$repo/releases/download/$tagName/Submersion-$tagName-Linux.tar.gz',
            },
            {
              'name': 'Submersion-$tagName-Android.apk',
              'browser_download_url':
                  'https://github.com/$owner/$repo/releases/download/$tagName/Submersion-$tagName-Android.apk',
            },
            {
              'name': 'Submersion-$tagName-Windows-Setup.exe',
              'browser_download_url':
                  'https://github.com/$owner/$repo/releases/download/$tagName/Submersion-$tagName-Windows-Setup.exe',
            },
          ],
    };
  }

  group('GithubUpdateService', () {
    test('returns UpToDate when latest version equals current', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(makeRelease(tagName: 'v1.0.0')), 200);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpToDate>());
    });

    test('returns UpdateAvailable when newer version exists', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v1.1.0', body: 'New features')),
          200,
        );
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateAvailable>());

      final available = status as UpdateAvailable;
      expect(available.version, '1.1.0');
      expect(available.releaseNotes, 'New features');
      expect(available.downloadUrl, contains('Linux.tar.gz'));
    });

    test(
      '4-segment current version equal to the release tag is up to date',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode(makeRelease(tagName: 'v1.7.1.118')),
            200,
          );
        });

        final service = GithubUpdateService(
          owner: owner,
          repo: repo,
          currentVersion: '1.7.1.118',
          platformSuffix: 'Linux.tar.gz',
          httpClient: client,
        );

        expect(await service.checkForUpdate(), isA<UpToDate>());
      },
    );

    test('finds the Windows installer asset by its real suffix', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v9.9.9.999')),
          200,
        );
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Windows-Setup.exe',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateAvailable>());
      expect(
        (status as UpdateAvailable).downloadUrl,
        endsWith('Windows-Setup.exe'),
      );
    });

    // The scenario from #1258: a phone sitting on v1.7.4.6062 while
    // v1.7.5.6772 was published. currentVersion is assembled in
    // update_providers.dart from PackageInfo, whose Android values are the
    // APK's versionName and versionCode. Promoted stable APKs carry the
    // tag's build number as their versionCode (promote.yml copies the beta
    // artifacts, and beta APKs are built with build-number = commit count),
    // so the assembled string is directly comparable to the 4-segment tag.
    test(
      'an Android install is offered the APK asset for a newer tag',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode(makeRelease(tagName: 'v1.7.5.6772')),
            200,
          );
        });

        final service = GithubUpdateService(
          owner: owner,
          repo: repo,
          currentVersion: '1.7.4.6062',
          platformSuffix: 'Android.apk',
          httpClient: client,
        );

        final status = await service.checkForUpdate();
        expect(status, isA<UpdateAvailable>());
        expect((status as UpdateAvailable).version, '1.7.5.6772');
        expect(status.downloadUrl, endsWith('Android.apk'));
      },
    );

    test('an Android install on the published build stays quiet', () async {
      // The other half of the same wiring: if versionCode did not line up
      // with the tag's build number, every check would report the version
      // the device is already running as an available update, forever.
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v1.7.5.6772')),
          200,
        );
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: '1.7.5.6772',
        platformSuffix: 'Android.apk',
        httpClient: client,
      );

      expect(await service.checkForUpdate(), isA<UpToDate>());
    });

    test('returns UpToDate when current is newer than remote', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(makeRelease(tagName: 'v0.9.0')), 200);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpToDate>());
    });

    test('returns UpdateError on network failure', () async {
      final client = MockClient((request) async {
        throw const SocketException('No internet');
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateError>());
    });

    test('returns UpdateError on non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateError>());
    });

    test('returns UpdateError when no matching asset for platform', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v1.1.0', assets: [])),
          200,
        );
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateError>());
    });

    test('strips v prefix from tag name for comparison', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(makeRelease(tagName: 'v1.0.0')), 200);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: '1.0.0',
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpToDate>());
    });

    test('skips pre-release tags', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            ...makeRelease(tagName: 'v2.0.0-beta.1'),
            'prerelease': true,
          }),
          200,
        );
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpToDate>());
    });

    test('returns UpdateError on malformed JSON response', () async {
      final client = MockClient((request) async {
        return http.Response('<html>Error</html>', 200);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      final status = await service.checkForUpdate();
      expect(status, isA<UpdateError>());
    });
  });

  group('Version comparison', () {
    test('isNewer detects major version bump', () {
      expect(GithubUpdateService.isNewer('2.0.0', '1.0.0'), true);
    });

    test('isNewer detects minor version bump', () {
      expect(GithubUpdateService.isNewer('1.1.0', '1.0.0'), true);
    });

    test('isNewer detects patch version bump', () {
      expect(GithubUpdateService.isNewer('1.0.1', '1.0.0'), true);
    });

    test('isNewer returns false for same version', () {
      expect(GithubUpdateService.isNewer('1.0.0', '1.0.0'), false);
    });

    test('isNewer returns false for older version', () {
      expect(GithubUpdateService.isNewer('0.9.0', '1.0.0'), false);
    });

    test('isNewer handles versions with different segment counts', () {
      expect(GithubUpdateService.isNewer('1.1', '1.0.0'), true);
    });

    test('isNewer strips pre-release suffix before comparing', () {
      expect(GithubUpdateService.isNewer('2.0.0-beta.1', '1.9.9'), true);
      expect(GithubUpdateService.isNewer('1.0.0-beta.1', '1.0.0'), false);
    });

    test('isNewer detects build number bump in 4-segment version', () {
      expect(GithubUpdateService.isNewer('1.2.21.65', '1.2.21.64'), true);
    });

    test('isNewer returns false for same 4-segment version', () {
      expect(GithubUpdateService.isNewer('1.2.21.65', '1.2.21.65'), false);
    });

    test('isNewer returns false when 4-segment remote is older', () {
      expect(GithubUpdateService.isNewer('1.2.21.64', '1.2.21.65'), false);
    });

    test('isNewer compares 4-segment remote against 3-segment current', () {
      expect(GithubUpdateService.isNewer('1.2.21.1', '1.2.21'), true);
      expect(GithubUpdateService.isNewer('1.2.21.0', '1.2.21'), false);
    });

    test('isNewer compares 3-segment remote against 4-segment current', () {
      expect(GithubUpdateService.isNewer('1.2.21', '1.2.21.1'), false);
      expect(GithubUpdateService.isNewer('1.2.22', '1.2.21.99'), true);
    });
  });
}
