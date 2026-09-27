import 'dart:io';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Channels whose mock handlers answer for every file that runs afterwards.
const _watchedChannels = [
  'plugins.flutter.io/path_provider',
  'dev.fluttercommunity.plus/share',
];

/// The process-wide state a test file may replace, recorded at one moment.
///
/// A generated test bundle (scripts/bundle_tests.py, issue #2500) takes one
/// before each file's tests and checks after them that the file put back
/// everything it changed. It is the runtime counterpart of
/// `test/architecture/test_global_state_restored_test.dart`, which catches
/// the same leaks in the source, and it does not depend on how the restore is
/// written.
class GlobalStateSnapshot {
  GlobalStateSnapshot._(this._values);

  /// A snapshot of the given values, for testing [changedSince].
  @visibleForTesting
  GlobalStateSnapshot.fromValues(Map<String, Object?> values)
    : _values = Map.of(values);

  /// Whether the Flutter test binding existed when the snapshot was taken.
  static const bindingKey = 'test binding';

  factory GlobalStateSnapshot.take() {
    return GlobalStateSnapshot._({
      bindingKey: _bindingReady(),
      'PathProviderPlatform.instance': PathProviderPlatform.instance,
      'SharePlatform.instance': SharePlatform.instance,
      'FilePickerPlatform.instance': FilePickerPlatform.instance,
      'UrlLauncherPlatform.instance': UrlLauncherPlatform.instance,
      'GoogleSignInPlatform.instance': GoogleSignInPlatform.instance,
      'PermissionHandlerPlatform.instance': PermissionHandlerPlatform.instance,
      'VideoPlayerPlatform.instance': VideoPlayerPlatform.instance,
      'FlutterWebAuth2Platform.instance': FlutterWebAuth2Platform.instance,
      'HttpOverrides.current': HttpOverrides.current,
      'QualityScanScheduler.enabled': QualityScanScheduler.enabled,
      'SensorSummaryScheduler.enabled': SensorSummaryScheduler.enabled,
      'canShareFiles': canShareFiles,
      'debugPrint': debugPrint,
      'FlutterError.onError': FlutterError.onError,
      'debugDefaultTargetPlatformOverride': debugDefaultTargetPlatformOverride,
      for (final channel in _watchedChannels)
        'mock handler on $channel': _hasMockHandler(channel),
    });
  }

  final Map<String, Object?> _values;

  static bool _bindingReady() {
    try {
      TestDefaultBinaryMessengerBinding.instance;
      return true;
    } on FlutterError {
      return false;
    }
  }

  /// Whether a mock handler is installed on [channel]. False when no test
  /// binding exists yet, since then nothing can have installed one.
  static bool _hasMockHandler(String channel) {
    final TestDefaultBinaryMessengerBinding binding;
    try {
      binding = TestDefaultBinaryMessengerBinding.instance;
    } on FlutterError {
      return false;
    }
    return !binding.defaultBinaryMessenger.checkMockMessageHandler(
      channel,
      null,
    );
  }

  /// What the Flutter test binding installs when it is first set up. A file
  /// that sets up the binding changes these once for the whole isolate, and
  /// there is nothing it could put back.
  static const _installedByBinding = {'HttpOverrides.current', 'debugPrint'};

  /// The names of the values that differ from [earlier], in a fixed order.
  List<String> changedSince(GlobalStateSnapshot earlier) {
    final bindingAppeared =
        _values[bindingKey] == true && earlier._values[bindingKey] != true;
    return [
      for (final name in _values.keys)
        if (name != bindingKey &&
            !(bindingAppeared && _installedByBinding.contains(name)) &&
            !identical(_values[name], earlier._values[name]))
          name,
    ];
  }

  /// Fails if anything recorded here has changed since.
  void expectRestored() {
    final changed = GlobalStateSnapshot.take().changedSince(this);
    if (changed.isEmpty) return;
    fail(
      'This file changed process-wide state and did not put it back: '
      '${changed.join(', ')}. The file that runs next in the same isolate '
      'starts from that state. See "Shared Isolates in CI" in '
      'docs/developer/testing.md for how to restore each one.',
    );
  }
}
