import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
const _githubOwner = 'submersion-app';
const _githubRepo = 'submersion';

/// Appcast feed URL for Sparkle/WinSparkle (macOS + Windows).
const _appcastUrl =
    'https://github.com/$_githubOwner/$_githubRepo/releases/latest/download/appcast.xml';

/// CPU architecture, set at build time via --dart-define=ARCH=arm64 (or x64).
/// Defaults to x64 when not specified.
const _arch = String.fromEnvironment('ARCH', defaultValue: 'x64');

/// Resolves the GitHub release asset suffix for a given platform and
/// architecture. Pure function extracted from [platformSuffix] for
/// testability (tests run on macOS and cannot exercise Platform.isLinux).
@visibleForTesting
String resolveAssetSuffix({required String platform, required String arch}) {
  switch (platform) {
    case 'macos':
      return 'macOS.dmg';
    case 'windows':
      return 'Windows.zip';
    case 'linux':
      return arch == 'arm64' ? 'Linux-ARM64.tar.gz' : 'Linux-x64.tar.gz';
    case 'android':
      return 'Android.apk';
    default:
      return '';
  }
}

/// Platform-specific asset suffix for GitHub Releases downloads.
@visibleForTesting
String get platformSuffix =>
    resolveAssetSuffix(platform: Platform.operatingSystem, arch: _arch);

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
    platformSuffix: platformSuffix,
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
    final service = await _ref.read(updateServiceProvider.future);
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

  /// User-initiated update check. Uses the platform's interactive UI
  /// (e.g. Sparkle's native dialog on macOS) when available.
  Future<void> checkForUpdateInteractively() async {
    final service = await _ref.read(updateServiceProvider.future);
    if (service == null) return;

    state = const Checking();

    final result = await service.checkForUpdateInteractively();

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
