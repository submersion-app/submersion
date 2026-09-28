import 'dart:io';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'global_test_defaults.dart';

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

  factory GlobalStateSnapshot.take() {
    return GlobalStateSnapshot._({
      'PathProviderPlatform.instance': PathProviderPlatform.instance,
      'SharePlatform.instance': SharePlatform.instance,
      'FilePickerPlatform.instance': FilePickerPlatform.instance,
      'UrlLauncherPlatform.instance': UrlLauncherPlatform.instance,
      'GoogleSignInPlatform.instance': GoogleSignInPlatform.instance,
      'PermissionHandlerPlatform.instance': PermissionHandlerPlatform.instance,
      'VideoPlayerPlatform.instance': VideoPlayerPlatform.instance,
      'FlutterWebAuth2Platform.instance': FlutterWebAuth2Platform.instance,
      'HttpOverrides.current': HttpOverrides.current,
      'IOOverrides.current': IOOverrides.current,
      'QualityScanScheduler.enabled': QualityScanScheduler.enabled,
      'SensorSummaryScheduler.enabled': SensorSummaryScheduler.enabled,
      'GoogleFonts.config.allowRuntimeFetching':
          GoogleFonts.config.allowRuntimeFetching,
      'canShareFiles': canShareFiles,
      'debugPrint': debugPrint,
      'FlutterError.onError': FlutterError.onError,
      'debugDefaultTargetPlatformOverride': debugDefaultTargetPlatformOverride,
      'PdfFonts.debugLatinFontLoader': PdfFonts.debugLatinFontLoader,
      'PdfFonts.debugScriptFontLoader': PdfFonts.debugScriptFontLoader,
      for (final channel in _watchedChannels)
        'mock handler on $channel': _hasMockHandler(channel),
    });
  }

  final Map<String, Object?> _values;

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

  /// The names of the values that differ from [earlier], in a fixed order.
  ///
  /// The test binding exists before any file runs
  /// (test/flutter_test_config.dart), so a value it installs when set up is
  /// never mistaken for a file's change.
  List<String> changedSince(GlobalStateSnapshot earlier) => [
    for (final name in _values.keys)
      if (!identical(_values[name], earlier._values[name])) name,
  ];

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

/// What happened while a test file declared its tests.
typedef DeclarationResult = ({
  Object? error,
  StackTrace? stack,
  List<String> changed,
});

/// Runs [declare], a test file's `main()`, from the harness defaults, and
/// reports what it threw and what process-wide state it left changed.
///
/// A generated bundle calls every file's `main()` while the bundle itself is
/// being declared, before any `setUpAll` runs. Without this, a file that
/// changes a global while declaring would hand that change to the next
/// file's declaration, and the per-file check in [GlobalStateSnapshot] would
/// never see it.
DeclarationResult declareAndCheck(void Function() declare) {
  applyGlobalTestDefaults();
  final before = GlobalStateSnapshot.take();
  Object? error;
  StackTrace? stack;
  try {
    declare();
  } catch (caught, trace) {
    error = caught;
    stack = trace;
  }
  return (
    error: error,
    stack: stack,
    changed: GlobalStateSnapshot.take().changedSince(before),
  );
}

/// Declares a test file's tests in a generated bundle.
///
/// What [declareAndCheck] finds becomes a failing test of the file's own,
/// so the other files in the bundle still run and the failure names the file.
void declareIsolated(void Function() declare) {
  final result = declareAndCheck(declare);
  final error = result.error;
  if (error != null) {
    test(
      'declares its tests',
      () => Error.throwWithStackTrace(error, result.stack!),
    );
  }
  if (result.changed.isNotEmpty) {
    test(
      'declares its tests without changing global state',
      () => fail(
        'Declaring this file changed process-wide state: '
        '${result.changed.join(', ')}. Code in the body of main() or group() '
        'runs before any test, so it reaches every file declared after this '
        'one. Move it into setUp or the test.',
      ),
    );
  }
}
