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
              'name': 'Submersion-$tagName-Windows.zip',
              'browser_download_url':
                  'https://github.com/$owner/$repo/releases/download/$tagName/Submersion-$tagName-Windows.zip',
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
  });
}
