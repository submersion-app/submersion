import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/auto_update/data/repositories/update_preferences.dart';
import 'package:submersion/features/auto_update/data/services/github_update_service.dart';
import 'package:submersion/features/auto_update/data/services/sparkle_update_service.dart';
import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// GitHub repository coordinates for update checks.
const _githubOwner = 'submersion-app';
const _githubRepo = 'submersion';

/// Repository holding per-merge beta releases (superset appcast + artifacts).
const _betaRepo = 'beta-builds';

/// Appcast feed URL for Sparkle/WinSparkle (macOS + Windows) per channel.
/// The beta feed is a superset (beta items first, stable items appended), so
/// a device switched back to stable still walks forward onto the next stable.
String appcastUrlFor(ReleaseChannel channel) => switch (channel) {
  ReleaseChannel.stable =>
    'https://github.com/$_githubOwner/$_githubRepo/releases/latest/download/appcast.xml',
  ReleaseChannel.beta =>
    'https://github.com/$_githubOwner/$_betaRepo/releases/latest/download/appcast-beta.xml',
};

/// GitHub repo polled by the non-Sparkle updater (Linux/Android) per channel.
String githubRepoFor(ReleaseChannel channel) => switch (channel) {
  ReleaseChannel.stable => _githubRepo,
  ReleaseChannel.beta => _betaRepo,
};

/// Platform-specific asset suffix for GitHub Releases downloads.
String get _platformSuffix {
  if (Platform.isMacOS) return 'macOS.dmg';
  if (Platform.isWindows) return 'Windows-Setup.exe';
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

/// The user-selected release channel, re-evaluated when preferences reload.
final releaseChannelProvider = Provider<ReleaseChannel>((ref) {
  return ref.watch(updatePreferencesProvider).releaseChannel;
});

/// The platform-appropriate update service.
final updateServiceProvider = FutureProvider<UpdateService?>((ref) async {
  if (!UpdateChannelConfig.isAutoUpdateEnabled) return null;

  final channel = ref.watch(releaseChannelProvider);
  final packageInfo = await PackageInfo.fromPlatform();
  // Release tags are 4-segment (vX.Y.Z.N) while packageInfo.version is the
  // 3-segment marketing version; without the build number appended, a
  // current install always compares as older than its own release tag.
  final currentVersion = formatAppVersion(packageInfo);

  if (_useSparkleEngine) {
    return SparkleUpdateService(feedUrl: appcastUrlFor(channel));
  }

  return GithubUpdateService(
    owner: _githubOwner,
    repo: githubRepoFor(channel),
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
  bool _backgroundCheckInFlight = false;

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

    _backgroundCheckInFlight = true;
    state = const Checking();

    try {
      final result = await service.checkForUpdate();

      // Record the check time
      final prefs = _ref.read(updatePreferencesProvider);
      await prefs.setLastCheckTime(DateTime.now());

      if (mounted) {
        state = result;
      }
    } finally {
      _backgroundCheckInFlight = false;
    }
  }

  /// User-initiated update check. Uses the platform's interactive UI
  /// (e.g. Sparkle's native dialog on macOS) when available.
  ///
  /// If a background check is still in flight, waits for it to finish
  /// before issuing the interactive check. This prevents Sparkle from
  /// suppressing the dialog due to an in-progress session (#107).
  Future<void> checkForUpdateInteractively() async {
    // Wait for any in-flight background check to finish so Sparkle's
    // SPUUpdater is not mid-session when we request the foreground dialog.
    if (_backgroundCheckInFlight) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

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
