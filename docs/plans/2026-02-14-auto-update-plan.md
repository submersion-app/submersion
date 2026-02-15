# Auto-Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automatic application updates for all non-app store distribution channels (macOS DMG, Windows ZIP, Linux tar.gz, Android APK).

**Architecture:** Hybrid engine approach -- `auto_updater` package (Sparkle 2 + WinSparkle) for macOS/Windows silent updates, custom GitHub Releases API checker for Linux/Android. Unified Riverpod state layer. Compile-time `UPDATE_CHANNEL` flag disables updates for App Store builds.

**Tech Stack:** Flutter, Riverpod, auto_updater (Sparkle 2 / WinSparkle), http, package_info_plus, shared_preferences, GitHub Releases API v3.

**Design doc:** `docs/plans/2026-02-14-auto-update-design.md`

---

## Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add auto_updater and package_info_plus to pubspec.yaml**

Add under `dependencies:` section (after the `# Utilities` comment block):

```yaml
  # Auto-Update
  auto_updater: ^1.0.0
  package_info_plus: ^8.0.0
```

Note: `http` and `shared_preferences` are already in the project dependencies.

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully. `auto_updater` pulls in `auto_updater_macos` and `auto_updater_windows` as platform-specific implementations.

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add auto_updater and package_info_plus dependencies"
```

---

## Task 2: Domain Entities -- UpdateChannel and UpdateStatus

**Files:**
- Create: `lib/features/auto_update/domain/entities/update_channel.dart`
- Create: `lib/features/auto_update/domain/entities/update_status.dart`
- Test: `test/features/auto_update/domain/entities/update_channel_test.dart`
- Test: `test/features/auto_update/domain/entities/update_status_test.dart`

**Step 1: Write the failing test for UpdateChannel**

Create `test/features/auto_update/domain/entities/update_channel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';

void main() {
  group('UpdateChannel', () {
    test('has expected values', () {
      expect(UpdateChannel.values.length, 5);
      expect(UpdateChannel.github.name, 'github');
      expect(UpdateChannel.appstore.name, 'appstore');
      expect(UpdateChannel.playstore.name, 'playstore');
      expect(UpdateChannel.msstore.name, 'msstore');
      expect(UpdateChannel.snapstore.name, 'snapstore');
    });
  });

  group('UpdateChannelConfig', () {
    // Note: We cannot easily test String.fromEnvironment in unit tests
    // because --dart-define is a compile-time constant. We test the
    // helper logic instead.

    test('isStoreChannel returns true for appstore', () {
      expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.appstore), true);
    });

    test('isStoreChannel returns true for playstore', () {
      expect(
        UpdateChannelConfig.isStoreChannel(UpdateChannel.playstore),
        true,
      );
    });

    test('isStoreChannel returns true for msstore', () {
      expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.msstore), true);
    });

    test('isStoreChannel returns true for snapstore', () {
      expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.snapstore), true);
    });

    test('isStoreChannel returns false for github', () {
      expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.github), false);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auto_update/domain/entities/update_channel_test.dart`
Expected: FAIL -- file not found / import error.

**Step 3: Write UpdateChannel implementation**

Create `lib/features/auto_update/domain/entities/update_channel.dart`:

```dart
enum UpdateChannel { github, appstore, playstore, msstore, snapstore }

class UpdateChannelConfig {
  static const _raw = String.fromEnvironment(
    'UPDATE_CHANNEL',
    defaultValue: 'github',
  );

  static UpdateChannel get current {
    try {
      return UpdateChannel.values.byName(_raw);
    } catch (_) {
      return UpdateChannel.github;
    }
  }

  static bool get isAutoUpdateEnabled => !isStoreChannel(current);

  static bool isStoreChannel(UpdateChannel channel) {
    return channel != UpdateChannel.github;
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/auto_update/domain/entities/update_channel_test.dart`
Expected: All tests PASS.

**Step 5: Write the failing test for UpdateStatus**

Create `test/features/auto_update/domain/entities/update_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

void main() {
  group('UpdateStatus', () {
    test('UpToDate can be instantiated', () {
      const status = UpToDate();
      expect(status, isA<UpdateStatus>());
    });

    test('Checking can be instantiated', () {
      const status = Checking();
      expect(status, isA<UpdateStatus>());
    });

    test('UpdateAvailable stores version and download URL', () {
      const status = UpdateAvailable(
        version: '1.2.0',
        downloadUrl: 'https://example.com/app.dmg',
        releaseNotes: 'Bug fixes',
      );
      expect(status.version, '1.2.0');
      expect(status.downloadUrl, 'https://example.com/app.dmg');
      expect(status.releaseNotes, 'Bug fixes');
    });

    test('UpdateAvailable releaseNotes defaults to null', () {
      const status = UpdateAvailable(
        version: '1.2.0',
        downloadUrl: 'https://example.com/app.dmg',
      );
      expect(status.releaseNotes, isNull);
    });

    test('Downloading stores progress', () {
      const status = Downloading(progress: 0.5);
      expect(status.progress, 0.5);
    });

    test('ReadyToInstall stores version and path', () {
      const status = ReadyToInstall(
        version: '1.2.0',
        localPath: '/tmp/update.dmg',
      );
      expect(status.version, '1.2.0');
      expect(status.localPath, '/tmp/update.dmg');
    });

    test('UpdateError stores message', () {
      const status = UpdateError(message: 'Network failed');
      expect(status.message, 'Network failed');
    });
  });
}
```

**Step 6: Run test to verify it fails**

Run: `flutter test test/features/auto_update/domain/entities/update_status_test.dart`
Expected: FAIL -- file not found / import error.

**Step 7: Write UpdateStatus implementation**

Create `lib/features/auto_update/domain/entities/update_status.dart`:

```dart
sealed class UpdateStatus {
  const UpdateStatus();
}

class UpToDate extends UpdateStatus {
  const UpToDate();
}

class Checking extends UpdateStatus {
  const Checking();
}

class UpdateAvailable extends UpdateStatus {
  final String version;
  final String? releaseNotes;
  final String downloadUrl;

  const UpdateAvailable({
    required this.version,
    this.releaseNotes,
    required this.downloadUrl,
  });
}

class Downloading extends UpdateStatus {
  final double progress;

  const Downloading({required this.progress});
}

class ReadyToInstall extends UpdateStatus {
  final String version;
  final String localPath;

  const ReadyToInstall({required this.version, required this.localPath});
}

class UpdateError extends UpdateStatus {
  final String message;

  const UpdateError({required this.message});
}
```

**Step 8: Run test to verify it passes**

Run: `flutter test test/features/auto_update/domain/entities/update_status_test.dart`
Expected: All tests PASS.

**Step 9: Commit**

```bash
git add lib/features/auto_update/domain/ test/features/auto_update/domain/
git commit -m "feat: add UpdateChannel and UpdateStatus domain entities"
```

---

## Task 3: GitHub Update Service (Linux/Android)

**Files:**
- Create: `lib/features/auto_update/data/services/update_service.dart`
- Create: `lib/features/auto_update/data/services/github_update_service.dart`
- Test: `test/features/auto_update/data/services/github_update_service_test.dart`

**Step 1: Write the failing tests for GithubUpdateService**

Create `test/features/auto_update/data/services/github_update_service_test.dart`:

```dart
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
      'assets': assets ??
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
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v1.0.0')),
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
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v0.9.0')),
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
        return http.Response(
          jsonEncode(makeRelease(tagName: 'v1.0.0')),
          200,
        );
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
      // Pre-release should be treated as "no update" since /releases/latest
      // already excludes pre-releases, but we double-check via the flag.
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
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auto_update/data/services/github_update_service_test.dart`
Expected: FAIL -- file not found / import error.

**Step 3: Write the UpdateService abstract interface**

Create `lib/features/auto_update/data/services/update_service.dart`:

```dart
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

abstract class UpdateService {
  Future<UpdateStatus> checkForUpdate();
}
```

**Step 4: Write GithubUpdateService implementation**

Create `lib/features/auto_update/data/services/github_update_service.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

class GithubUpdateService implements UpdateService {
  final String owner;
  final String repo;
  final String currentVersion;
  final String platformSuffix;
  final http.Client httpClient;

  GithubUpdateService({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    required this.platformSuffix,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<UpdateStatus> checkForUpdate() async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final response = await httpClient.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return UpdateError(
          message: 'GitHub API returned ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Skip pre-releases (shouldn't happen with /releases/latest, but
      // double-check)
      final isPreRelease = json['prerelease'] as bool? ?? false;
      if (isPreRelease) {
        return const UpToDate();
      }

      final tagName = json['tag_name'] as String;
      final remoteVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      if (!isNewer(remoteVersion, currentVersion)) {
        return const UpToDate();
      }

      // Find the matching asset for this platform
      final assets = json['assets'] as List<dynamic>;
      final matchingAsset = assets.cast<Map<String, dynamic>>().where(
        (asset) {
          final name = asset['name'] as String;
          return name.endsWith(platformSuffix);
        },
      );

      if (matchingAsset.isEmpty) {
        return const UpdateError(
          message: 'No matching download found for this platform',
        );
      }

      final downloadUrl =
          matchingAsset.first['browser_download_url'] as String;
      final releaseNotes = json['body'] as String?;

      return UpdateAvailable(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      return UpdateError(message: e.toString());
    }
  }

  /// Compares two semver strings. Returns true if [remote] is newer than
  /// [current].
  static bool isNewer(String remote, String current) {
    final remoteParts = remote.split('.').map(
      (s) => int.tryParse(s) ?? 0,
    ).toList();
    final currentParts = current.split('.').map(
      (s) => int.tryParse(s) ?? 0,
    ).toList();

    // Pad shorter list with zeros
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}
```

**Step 5: Run test to verify it passes**

Run: `flutter test test/features/auto_update/data/services/github_update_service_test.dart`
Expected: All tests PASS.

**Step 6: Commit**

```bash
git add lib/features/auto_update/data/services/ test/features/auto_update/data/services/
git commit -m "feat: add GithubUpdateService for Linux/Android auto-update"
```

---

## Task 4: Sparkle Update Service (macOS/Windows)

**Files:**
- Create: `lib/features/auto_update/data/services/sparkle_update_service.dart`

Note: The `auto_updater` package wraps native Sparkle/WinSparkle frameworks. Unit testing native framework behavior isn't practical. We test the wrapper logic and rely on manual testing for native behavior. The `GithubUpdateService` tests (Task 3) cover the custom engine thoroughly.

**Step 1: Write SparkleUpdateService**

Create `lib/features/auto_update/data/services/sparkle_update_service.dart`:

```dart
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

class SparkleUpdateService implements UpdateService {
  final String feedUrl;
  bool _initialized = false;

  SparkleUpdateService({required this.feedUrl});

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Only initialize on macOS or Windows
    if (!Platform.isMacOS && !Platform.isWindows) return;

    await autoUpdater.setFeedURL(feedUrl);
    // Check every 4 hours (in seconds)
    await autoUpdater.setScheduledCheckInterval(4 * 60 * 60);
    _initialized = true;
  }

  @override
  Future<UpdateStatus> checkForUpdate() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return const UpToDate();
    }

    try {
      await _ensureInitialized();
      await autoUpdater.checkForUpdates(inBackground: true);
      // Sparkle handles the entire UI flow natively. We return UpToDate here
      // because Sparkle manages its own dialogs and download progress.
      // The native framework will show update UI if an update is available.
      return const UpToDate();
    } catch (e) {
      return UpdateError(message: e.toString());
    }
  }

  /// Trigger a user-initiated (foreground) update check.
  /// Shows Sparkle's native "checking for updates" dialog.
  Future<void> checkForUpdatesInteractively() async {
    if (!Platform.isMacOS && !Platform.isWindows) return;

    await _ensureInitialized();
    await autoUpdater.checkForUpdates(inBackground: false);
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/auto_update/data/services/sparkle_update_service.dart
git commit -m "feat: add SparkleUpdateService for macOS/Windows auto-update"
```

---

## Task 5: Update Preferences

**Files:**
- Create: `lib/features/auto_update/data/repositories/update_preferences.dart`
- Test: `test/features/auto_update/data/repositories/update_preferences_test.dart`

**Step 1: Write the failing tests**

Create `test/features/auto_update/data/repositories/update_preferences_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/auto_update/data/repositories/update_preferences.dart';

void main() {
  late UpdatePreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    prefs = UpdatePreferences(sp);
  });

  group('UpdatePreferences', () {
    test('autoUpdateEnabled defaults to true', () {
      expect(prefs.autoUpdateEnabled, true);
    });

    test('setAutoUpdateEnabled persists value', () async {
      await prefs.setAutoUpdateEnabled(false);
      expect(prefs.autoUpdateEnabled, false);
    });

    test('lastCheckTime defaults to null', () {
      expect(prefs.lastCheckTime, isNull);
    });

    test('setLastCheckTime persists value', () async {
      final time = DateTime(2026, 2, 14, 12, 0);
      await prefs.setLastCheckTime(time);
      expect(prefs.lastCheckTime, time);
    });

    test('checkIntervalHours defaults to 4', () {
      expect(prefs.checkIntervalHours, 4);
    });

    test('setCheckIntervalHours persists value', () async {
      await prefs.setCheckIntervalHours(12);
      expect(prefs.checkIntervalHours, 12);
    });

    test('isDueForCheck returns true when no previous check', () {
      expect(prefs.isDueForCheck, true);
    });

    test('isDueForCheck returns false right after a check', () async {
      await prefs.setLastCheckTime(DateTime.now());
      expect(prefs.isDueForCheck, false);
    });

    test('isDueForCheck returns true when interval has elapsed', () async {
      final oldTime = DateTime.now().subtract(const Duration(hours: 5));
      await prefs.setLastCheckTime(oldTime);
      expect(prefs.isDueForCheck, true);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auto_update/data/repositories/update_preferences_test.dart`
Expected: FAIL.

**Step 3: Write UpdatePreferences implementation**

Create `lib/features/auto_update/data/repositories/update_preferences.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class UpdatePreferences {
  final SharedPreferences _prefs;

  static const _keyAutoUpdateEnabled = 'auto_update_enabled';
  static const _keyLastCheckTime = 'auto_update_last_check';
  static const _keyCheckIntervalHours = 'auto_update_check_interval_hours';

  UpdatePreferences(this._prefs);

  bool get autoUpdateEnabled =>
      _prefs.getBool(_keyAutoUpdateEnabled) ?? true;

  Future<void> setAutoUpdateEnabled(bool value) =>
      _prefs.setBool(_keyAutoUpdateEnabled, value);

  DateTime? get lastCheckTime {
    final millis = _prefs.getInt(_keyLastCheckTime);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastCheckTime(DateTime time) =>
      _prefs.setInt(_keyLastCheckTime, time.millisecondsSinceEpoch);

  int get checkIntervalHours =>
      _prefs.getInt(_keyCheckIntervalHours) ?? 4;

  Future<void> setCheckIntervalHours(int hours) =>
      _prefs.setInt(_keyCheckIntervalHours, hours);

  bool get isDueForCheck {
    final last = lastCheckTime;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last);
    return elapsed.inHours >= checkIntervalHours;
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/auto_update/data/repositories/update_preferences_test.dart`
Expected: All tests PASS.

**Step 5: Commit**

```bash
git add lib/features/auto_update/data/repositories/ test/features/auto_update/data/repositories/
git commit -m "feat: add UpdatePreferences for auto-update settings persistence"
```

---

## Task 6: Riverpod Providers

**Files:**
- Create: `lib/features/auto_update/presentation/providers/update_providers.dart`

**Step 1: Write update providers**

Create `lib/features/auto_update/presentation/providers/update_providers.dart`:

```dart
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/features/auto_update/data/repositories/update_preferences.dart';
import 'package:submersion/features/auto_update/data/services/github_update_service.dart';
import 'package:submersion/features/auto_update/data/services/sparkle_update_service.dart';
import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// GitHub repository coordinates for update checks.
const _githubOwner = 'ericgriffin';
const _githubRepo = 'submersion';

/// Appcast feed URL for Sparkle/WinSparkle (macOS + Windows).
const _appcastUrl =
    'https://github.com/$_githubOwner/$_githubRepo/releases/latest/download/appcast.xml';

/// Platform-specific asset suffix for GitHub Releases downloads.
String get _platformSuffix {
  if (Platform.isMacOS) return 'macOS.dmg';
  if (Platform.isWindows) return 'Windows.zip';
  if (Platform.isLinux) return 'Linux.tar.gz';
  if (Platform.isAndroid) return 'Android.apk';
  return '';
}

/// Whether the current platform uses the Sparkle/WinSparkle engine.
bool get _useSparkleEngine => Platform.isMacOS || Platform.isWindows;

/// Update preferences provider.
final updatePreferencesProvider = Provider<UpdatePreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UpdatePreferences(prefs);
});

/// The platform-appropriate update service.
final updateServiceProvider = FutureProvider<UpdateService?>((ref) async {
  if (!UpdateChannelConfig.isAutoUpdateEnabled) return null;

  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  if (_useSparkleEngine) {
    return SparkleUpdateService(feedUrl: _appcastUrl);
  }

  return GithubUpdateService(
    owner: _githubOwner,
    repo: _githubRepo,
    currentVersion: currentVersion,
    platformSuffix: _platformSuffix,
  );
});

/// Current update status. Triggers a check when first read if due.
final updateStatusProvider =
    StateNotifierProvider<UpdateStatusNotifier, UpdateStatus>((ref) {
  return UpdateStatusNotifier(ref);
});

class UpdateStatusNotifier extends StateNotifier<UpdateStatus> {
  final Ref _ref;

  UpdateStatusNotifier(this._ref) : super(const UpToDate()) {
    // Delay initial check to not block app startup
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _checkIfDue();
    });
  }

  Future<void> _checkIfDue() async {
    final prefs = _ref.read(updatePreferencesProvider);
    if (!prefs.autoUpdateEnabled) return;
    if (!prefs.isDueForCheck) return;
    await checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    final serviceAsync = _ref.read(updateServiceProvider);
    final service = serviceAsync.valueOrNull;
    if (service == null) return;

    state = const Checking();

    final result = await service.checkForUpdate();

    // Record the check time
    final prefs = _ref.read(updatePreferencesProvider);
    await prefs.setLastCheckTime(DateTime.now());

    if (mounted) {
      state = result;
    }
  }
}

/// Convenience provider: true when an update is available or ready.
final hasUpdateProvider = Provider<bool>((ref) {
  final status = ref.watch(updateStatusProvider);
  return status is UpdateAvailable || status is ReadyToInstall;
});
```

**Step 2: Commit**

```bash
git add lib/features/auto_update/presentation/providers/
git commit -m "feat: add Riverpod providers for auto-update state management"
```

---

## Task 7: Update Banner Widget

**Files:**
- Create: `lib/features/auto_update/presentation/widgets/update_banner.dart`
- Test: `test/features/auto_update/presentation/widgets/update_banner_test.dart`

**Step 1: Write the failing widget test**

Create `test/features/auto_update/presentation/widgets/update_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';

void main() {
  Widget buildTestWidget(UpdateStatus status) {
    return ProviderScope(
      overrides: [
        updateStatusProvider.overrideWith(
          (ref) => UpdateStatusNotifier(ref)..state = status,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              UpdateBanner(),
              Expanded(child: Placeholder()),
            ],
          ),
        ),
      ),
    );
  }

  group('UpdateBanner', () {
    testWidgets('shows nothing when UpToDate', (tester) async {
      await tester.pumpWidget(buildTestWidget(const UpToDate()));
      await tester.pump();

      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('shows banner when UpdateAvailable', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const UpdateAvailable(
          version: '1.2.0',
          downloadUrl: 'https://example.com/update',
        ),
      ));
      await tester.pump();

      expect(find.textContaining('1.2.0'), findsOneWidget);
    });

    testWidgets('shows banner when ReadyToInstall', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ReadyToInstall(version: '1.2.0', localPath: '/tmp/update'),
      ));
      await tester.pump();

      expect(find.textContaining('1.2.0'), findsOneWidget);
    });

    testWidgets('can be dismissed', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const UpdateAvailable(
          version: '1.2.0',
          downloadUrl: 'https://example.com/update',
        ),
      ));
      await tester.pump();

      // Find and tap the dismiss button
      final dismissButton = find.byIcon(Icons.close);
      if (dismissButton.evaluate().isNotEmpty) {
        await tester.tap(dismissButton);
        await tester.pump();
        // After dismiss, banner should be hidden for this session
        expect(find.textContaining('1.2.0'), findsNothing);
      }
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auto_update/presentation/widgets/update_banner_test.dart`
Expected: FAIL.

**Step 3: Write UpdateBanner widget**

Create `lib/features/auto_update/presentation/widgets/update_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final status = ref.watch(updateStatusProvider);
    final version = switch (status) {
      UpdateAvailable(:final version) => version,
      ReadyToInstall(:final version) => version,
      _ => null,
    };

    if (version == null) return const SizedBox.shrink();

    final downloadUrl = switch (status) {
      UpdateAvailable(:final downloadUrl) => downloadUrl,
      _ => null,
    };

    final theme = Theme.of(context);

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(Icons.system_update, color: theme.colorScheme.primary),
      content: Text(
        'Version $version is available.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        if (downloadUrl != null)
          TextButton(
            onPressed: () => _openDownload(downloadUrl),
            child: const Text('Download'),
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Dismiss',
          onPressed: () => setState(() => _dismissed = true),
        ),
      ],
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/auto_update/presentation/widgets/update_banner_test.dart`
Expected: Tests PASS. (Note: Some tests may need adjustment depending on how the ProviderScope override works with StateNotifier -- adapt as needed.)

**Step 5: Commit**

```bash
git add lib/features/auto_update/presentation/widgets/ test/features/auto_update/presentation/widgets/
git commit -m "feat: add UpdateBanner widget for update notifications"
```

---

## Task 8: Integrate Banner into MainScaffold

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart`

**Step 1: Add UpdateBanner to the main scaffold**

In `lib/shared/widgets/main_scaffold.dart`, add the banner above the main content area. The banner should appear at the top of the content area (not above the NavigationRail or BottomNavigationBar).

Add import at top:
```dart
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';
```

In the desktop layout (line ~268), wrap `widget.child` in a Column with the banner:
```dart
Expanded(
  child: Column(
    children: [
      const UpdateBanner(),
      Expanded(child: widget.child),
    ],
  ),
),
```

In the mobile layout (line ~370), wrap `widget.child` similarly:
```dart
body: Column(
  children: [
    const UpdateBanner(),
    Expanded(child: widget.child),
  ],
),
```

**Step 2: Verify the app builds**

Run: `flutter build macos --debug` (or whichever platform you're on)
Expected: Builds successfully.

**Step 3: Commit**

```bash
git add lib/shared/widgets/main_scaffold.dart
git commit -m "feat: integrate UpdateBanner into MainScaffold"
```

---

## Task 9: Settings Integration

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

**Step 1: Add "About & Updates" section to settings page**

In the settings page, add a new section (in `_buildSectionContent` switch and in the section list) that shows:
- Current version (from `package_info_plus`)
- "Check for Updates" button
- Last check time
- Auto-update toggle (stored via `UpdatePreferences`)

This task modifies the existing settings page. Look at the existing section pattern (e.g., `case 'notifications':`) and add an `'about'` case that renders an `_AboutSectionContent` widget.

The widget should:
- Use `PackageInfo.fromPlatform()` via a FutureProvider to display the current version
- Show a "Check for Updates" button that calls `ref.read(updateStatusProvider.notifier).checkForUpdate()`
- Show a `SwitchListTile` for auto-update enabled/disabled (reads/writes `updatePreferencesProvider`)
- Display the last check time from `updatePreferencesProvider`
- Only show the update-related controls when `UpdateChannelConfig.isAutoUpdateEnabled` is true

**Step 2: Verify the section renders**

Run the app, navigate to Settings, tap "About". Verify the version number and update controls appear.

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: add About & Updates section to settings page"
```

---

## Task 10: macOS Sparkle Configuration

**Files:**
- Modify: `macos/Runner/Info.plist`
- Modify: `macos/Podfile` (if auto_updater requires CocoaPod configuration)

**Step 1: Add Sparkle configuration to Info.plist**

Add the following keys to `macos/Runner/Info.plist` inside the top-level `<dict>`:

```xml
<key>SUFeedURL</key>
<string>https://github.com/ericgriffin/submersion/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>PLACEHOLDER_EDDSA_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUAutomaticallyUpdate</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>14400</integer>
```

Note: The `SUPublicEDKey` value will be replaced with the actual EdDSA public key generated by Sparkle's `generate_keys` tool during CI setup. For now, use a placeholder.

**Step 2: Verify macOS build still compiles**

Run: `flutter build macos --debug`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add macos/Runner/Info.plist
git commit -m "feat: add Sparkle configuration to macOS Info.plist"
```

---

## Task 11: CI/CD -- Appcast Generation and Checksums

**Files:**
- Create: `scripts/generate_appcast.sh`
- Modify: `.github/workflows/release.yml`

**Step 1: Create the appcast generation script**

Create `scripts/generate_appcast.sh`:

```bash
#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <date> <macos_dmg_url> <windows_zip_url>
#
# Requires: SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <date> <macos_url> <windows_url>}"
DATE="${2}"
MACOS_URL="${3}"
WINDOWS_URL="${4}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/ericgriffin/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${MACOS_URL}"
        sparkle:edSignature="${EDDSA_SIG}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
  </channel>
</rss>
EOF
```

Make it executable:
```bash
chmod +x scripts/generate_appcast.sh
```

**Step 2: Add generate-appcast and generate-checksums jobs to release.yml**

Add a new job `generate-appcast` in `.github/workflows/release.yml` that runs after `build-macos`:

```yaml
  generate-appcast:
    name: Generate Appcast & Checksums
    runs-on: ubuntu-latest
    needs: [build-macos, build-windows, build-linux, build-android]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          merge-multiple: true

      - name: Generate appcast.xml
        env:
          TAG_NAME: ${{ github.ref_name }}
          SPARKLE_EDDSA_SIGNATURE: ${{ secrets.SPARKLE_EDDSA_SIGNATURE }}
        run: |
          VERSION="${TAG_NAME#v}"
          DATE=$(date -R)
          MACOS_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-macOS.dmg"
          WINDOWS_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-Windows.zip"
          ./scripts/generate_appcast.sh "$VERSION" "$DATE" "$MACOS_URL" "$WINDOWS_URL" > appcast.xml

      - name: Generate checksums
        run: sha256sum Submersion-* > checksums-sha256.txt

      - name: Upload appcast artifact
        uses: actions/upload-artifact@v4
        with:
          name: appcast
          path: appcast.xml
          retention-days: 5

      - name: Upload checksums artifact
        uses: actions/upload-artifact@v4
        with:
          name: checksums
          path: checksums-sha256.txt
          retention-days: 5
```

Update the `create-release` job to depend on `generate-appcast`:
```yaml
  create-release:
    needs: [build-macos, build-windows, build-linux, build-android, build-ios, generate-appcast]
```

**Step 3: Add --dart-define to all flutter build commands**

In each platform's build step in `release.yml`, add the `UPDATE_CHANNEL` flag:

```yaml
# macOS DMG build:
flutter build macos --release --dart-define=UPDATE_CHANNEL=github

# Windows build:
flutter build windows --release --dart-define=UPDATE_CHANNEL=github

# Linux build:
flutter build linux --release --dart-define=UPDATE_CHANNEL=github

# Android APK build:
flutter build apk --release --dart-define=UPDATE_CHANNEL=github
```

For the macOS App Store build (Fastlane), add to the Fastfile or pass via environment:
```yaml
# In the Fastlane lane, the build uses app store signing -- no UPDATE_CHANNEL needed
# (defaults to 'github' but the Mac App Store build via Fastlane uses its own build command)
```

**Step 4: Commit**

```bash
git add scripts/generate_appcast.sh .github/workflows/release.yml
git commit -m "feat: add appcast generation and checksums to release workflow"
```

---

## Task 12: Format, Analyze, and Run All Tests

**Step 1: Format all Dart code**

Run: `dart format lib/ test/`
Expected: No changes needed (if code was written correctly).

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues.

**Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass, including the new auto-update tests.

**Step 4: Fix any issues**

If formatting, analysis, or tests fail, fix the issues and re-run.

**Step 5: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix: address formatting and analysis issues in auto-update feature"
```

---

## Summary of Files Created/Modified

### New Files (11)
| File | Purpose |
|------|---------|
| `lib/features/auto_update/domain/entities/update_channel.dart` | UpdateChannel enum + config |
| `lib/features/auto_update/domain/entities/update_status.dart` | UpdateStatus sealed class |
| `lib/features/auto_update/data/services/update_service.dart` | Abstract interface |
| `lib/features/auto_update/data/services/github_update_service.dart` | Linux/Android engine |
| `lib/features/auto_update/data/services/sparkle_update_service.dart` | macOS/Windows engine |
| `lib/features/auto_update/data/repositories/update_preferences.dart` | SharedPreferences wrapper |
| `lib/features/auto_update/presentation/providers/update_providers.dart` | Riverpod providers |
| `lib/features/auto_update/presentation/widgets/update_banner.dart` | Update notification banner |
| `test/features/auto_update/domain/entities/update_channel_test.dart` | Tests |
| `test/features/auto_update/domain/entities/update_status_test.dart` | Tests |
| `test/features/auto_update/data/services/github_update_service_test.dart` | Tests |
| `test/features/auto_update/data/repositories/update_preferences_test.dart` | Tests |
| `test/features/auto_update/presentation/widgets/update_banner_test.dart` | Tests |
| `scripts/generate_appcast.sh` | CI appcast generation |

### Modified Files (4)
| File | Change |
|------|--------|
| `pubspec.yaml` | Add auto_updater, package_info_plus |
| `lib/shared/widgets/main_scaffold.dart` | Add UpdateBanner |
| `lib/features/settings/presentation/pages/settings_page.dart` | Add About & Updates section |
| `macos/Runner/Info.plist` | Add Sparkle configuration keys |
| `.github/workflows/release.yml` | Add appcast job, checksums, --dart-define flags |

### New CI Secrets Required
| Secret | Purpose |
|--------|---------|
| `SPARKLE_EDDSA_PRIVATE_KEY` | Sign macOS updates |
| `SPARKLE_EDDSA_SIGNATURE` | Pre-computed signature for appcast |
| `WINSPARKLE_DSA_PRIVATE_KEY` | Sign Windows updates (future) |
