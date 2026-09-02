import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

void main() {
  final environment = LogEnvironment(
    appVersion: '1.7.6.123',
    platform: 'ios',
    osVersion: 'Version 26.6 (Build 23G93)',
    locale: 'de_DE.UTF-8',
    buildMode: 'release',
    capturedAt: DateTime(2026, 8, 25, 20, 25, 19),
  );

  group('toSummaryLine', () {
    test('names the build, platform, locale and build mode', () {
      final line = environment.toSummaryLine();

      expect(line, contains('1.7.6.123'));
      expect(line, contains('ios'));
      expect(line, contains('Version 26.6 (Build 23G93)'));
      expect(line, contains('de_DE.UTF-8'));
      expect(line, contains('release'));
    });

    test('is a single line so it survives the log-line parser', () {
      // LogFileService.readEntries drops anything LogEntry.tryParse rejects,
      // and the parser is line-oriented: a multi-line summary would be
      // silently discarded from the log viewer.
      expect(environment.toSummaryLine(), isNot(contains('\n')));
    });
  });

  group('toExportHeader', () {
    test('carries every field an incoming bug report needs', () {
      final header = environment.toExportHeader();

      expect(header, contains('1.7.6.123'));
      expect(header, contains('ios'));
      expect(header, contains('Version 26.6 (Build 23G93)'));
      expect(header, contains('de_DE.UTF-8'));
      expect(header, contains('release'));
      expect(header, contains('exported:'));
    });

    test('ends with a newline so log lines start on their own line', () {
      expect(environment.toExportHeader(), endsWith('\n'));
    });

    test('renders identically twice', () {
      // The exported timestamp is a captured field, not a DateTime.now()
      // inside the getter, so callers can compare two renderings.
      expect(environment.toExportHeader(), environment.toExportHeader());
      expect(environment.toExportHeader(), contains('2026-08-25T20:25:19'));
    });
  });

  group('logSessionEnvironment', () {
    late Directory tempDir;
    late LogFileService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('log_environment_test_');
      service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();
      LoggerService.setFileService(service);
    });

    tearDown(() {
      LoggerService.setFileService(null);
      tempDir.deleteSync(recursive: true);
    });

    test('writes an entry the log file parser accepts', () async {
      // LogFileService.readEntries silently drops anything tryParse rejects,
      // so a session marker that does not round-trip would never reach the
      // log viewer at all.
      await logSessionEnvironment();
      await LoggerService.flushPendingWrites();

      final entries = await service.readEntries();

      expect(entries, hasLength(1));
      expect(entries.single.message, startsWith('Session start: Submersion'));
      expect(entries.single.category, LogCategory.app);
      expect(entries.single.level, LogLevel.info);
    });

    test('records the platform the run happened on', () async {
      await logSessionEnvironment();
      await LoggerService.flushPendingWrites();

      final entries = await service.readEntries();

      expect(entries.single.message, contains(Platform.operatingSystem));
    });
  });

  group('capture', () {
    test('never throws when the platform channel is unavailable', () async {
      // PackageInfo.fromPlatform needs a platform channel that does not exist
      // under flutter test. Losing the version must not cost the caller the
      // logs, so capture degrades instead of failing.
      final captured = await LogEnvironment.capture();

      expect(captured.appVersion, 'unknown');
    });

    test('reads the real platform identity', () async {
      final captured = await LogEnvironment.capture();

      expect(captured.platform, Platform.operatingSystem);
      expect(captured.osVersion, Platform.operatingSystemVersion);
      expect(captured.locale, Platform.localeName);
    });

    test('degrades when the version lookup never answers', () async {
      // An unbounded wait would hang a Copy or Share outright. Proven
      // reachable: PackageInfo.fromPlatform never completes under testWidgets.
      LogEnvironment.packageInfoLoader = () => Completer<PackageInfo>().future;
      addTearDown(() {
        LogEnvironment.packageInfoLoader = PackageInfo.fromPlatform;
      });

      final captured = await LogEnvironment.capture(
        versionTimeout: const Duration(milliseconds: 20),
      );

      expect(captured.appVersion, 'unknown');
      expect(captured.platform, Platform.operatingSystem);
    });

    test('uses the version when the lookup answers', () async {
      LogEnvironment.packageInfoLoader = () async => PackageInfo(
        appName: 'Submersion',
        packageName: 'app.submersion',
        version: '1.7.6',
        buildNumber: '123',
        buildSignature: '',
      );
      addTearDown(() {
        LogEnvironment.packageInfoLoader = PackageInfo.fromPlatform;
      });

      final captured = await LogEnvironment.capture();

      expect(captured.appVersion, '1.7.6.123');
    });

    test('reports the build mode flutter test runs in', () async {
      final captured = await LogEnvironment.capture();

      expect(captured.buildMode, anyOf('debug', 'profile', 'release'));
    });

    test(
      'still produces a usable header when the version is unknown',
      () async {
        final captured = await LogEnvironment.capture();

        expect(captured.toExportHeader(), contains('Submersion debug log'));
        expect(captured.toExportHeader(), contains(Platform.operatingSystem));
      },
    );
  });
}
