import 'dart:io';

import 'package:flutter/foundation.dart'
    show kDebugMode, kProfileMode, visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/app_version.dart';

/// Value shown wherever a field could not be determined.
const _unknown = 'unknown';

/// A snapshot of the build and device that produced a debug log.
///
/// Bug reports arrive as pasted log excerpts, and every triage starts with the
/// same question: which build wrote these lines? Issue #1246 is the worked
/// example: an OSTC Sport download failure that had already been fixed
/// months earlier, but the report carried no version, so establishing that the
/// reporter was simply on an older build meant inferring it from a numeric
/// score in a BLE selection log line and from the *absence* of a log statement
/// that newer builds emit. Attaching this to the logs makes that a read
/// instead of an inference.
class LogEnvironment {
  /// Four-segment app version, e.g. `1.7.6.123`.
  final String appVersion;

  /// Operating system identifier, e.g. `ios`, `android`, `macos`.
  final String platform;

  /// Full OS version string, e.g. `Version 26.6 (Build 23G93)`.
  final String osVersion;

  /// Host locale, e.g. `de_DE.UTF-8`.
  final String locale;

  /// Flutter build mode: `release`, `profile` or `debug`.
  final String buildMode;

  /// When this snapshot was taken.
  ///
  /// A field rather than a `DateTime.now()` inside [toExportHeader] so the
  /// header is a pure function of the value: rendering it twice must produce
  /// the same string. Capture happens at export time, so this is also the
  /// moment the export was produced.
  final DateTime capturedAt;

  const LogEnvironment({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.locale,
    required this.buildMode,
    required this.capturedAt,
  });

  /// How long [capture] waits for the app version before giving up.
  ///
  /// A platform channel that never answers is just as damaging as one that
  /// throws: the caller is a user pressing Copy or Share, and an unbounded
  /// wait would hang the export outright rather than degrade it. That is not
  /// hypothetical, because `PackageInfo.fromPlatform` never completes under
  /// `testWidgets`, and a headless isolate has no plugin registrant either.
  static const versionLookupTimeout = Duration(seconds: 2);

  /// Seam for the version lookup, so tests can drive its failure modes.
  @visibleForTesting
  static Future<PackageInfo> Function() packageInfoLoader =
      PackageInfo.fromPlatform;

  /// Read the environment from the platform.
  ///
  /// Never throws and always completes. Anything that cannot be determined
  /// degrades to [_unknown] rather than failing the caller: this only ever
  /// decorates a log export or a log line, so losing the app version must not
  /// cost the user the logs themselves.
  static Future<LogEnvironment> capture({Duration? versionTimeout}) async {
    var appVersion = _unknown;
    try {
      final info = await packageInfoLoader().timeout(
        versionTimeout ?? versionLookupTimeout,
      );
      appVersion = formatAppVersion(info);
    } on Object {
      // A throw or a timeout both land here; see the doc comment.
    }

    var platform = _unknown;
    var osVersion = _unknown;
    var locale = _unknown;
    try {
      platform = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
      locale = Platform.localeName;
    } on Object {
      // Platform getters throw on unsupported hosts (e.g. web).
    }

    return LogEnvironment(
      appVersion: appVersion,
      platform: platform,
      osVersion: osVersion,
      locale: locale,
      buildMode: kDebugMode
          ? 'debug'
          : kProfileMode
          ? 'profile'
          : 'release',
      capturedAt: DateTime.now(),
    );
  }

  /// One-line form, used for the session marker written into the log file.
  ///
  /// Deliberately a single line so it survives [LogEntry.tryParse] and shows
  /// up in the log viewer like any other entry.
  String toSummaryLine() =>
      'Session start: Submersion $appVersion'
      ' | $platform $osVersion'
      ' | locale $locale'
      ' | $buildMode build';

  /// Multi-line header prepended to an exported or copied log.
  ///
  /// Regenerated at export time rather than read back from the file, because
  /// the file's head is what log rotation discards and what the viewer's
  /// category/severity filters exclude.
  String toExportHeader() {
    final exportedAt = capturedAt.toIso8601String();
    return '''
=== Submersion debug log ===
app:      Submersion $appVersion
platform: $platform $osVersion
locale:   $locale
build:    $buildMode
exported: $exportedAt
============================
''';
  }
}

/// Record the current build and device at the top of a logging session.
///
/// Called wherever file logging is switched on, so a log file that spans
/// several app versions attributes each run to the build that wrote it.
Future<void> logSessionEnvironment() async {
  final environment = await LogEnvironment.capture();
  const LoggerService(
    'Submersion',
  ).info(environment.toSummaryLine(), category: LogCategory.app);
}
